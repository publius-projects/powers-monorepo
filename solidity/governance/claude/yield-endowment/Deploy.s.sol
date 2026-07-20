// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

// Run with: forge script governance/claude/yield-endowment/Deploy.s.sol:Deploy --rpc-url $SEPOLIA_RPC_URL --broadcast

import { console2 } from "forge-std/console2.sol";
import { Configurations } from "@script/Configurations.s.sol";
import { DeployHelpers } from "../../DeployHelpers.s.sol";
import { IMandateRegistry } from "@src/core/helpers/MandateRegistry.sol";

import { PowersTypes } from "@src/interfaces/PowersTypes.sol";
import { Powers } from "@src/Powers.sol";
import { IPowers } from "@src/interfaces/IPowers.sol";

import { PowersPaymaster } from "@src/core/helpers/PowersPaymaster.sol";
import { IEntryPoint } from "@lib/account-abstraction/contracts/interfaces/IEntryPoint.sol";

import { SlateRegistry } from "@src/core/helpers/SlateRegistry.sol";
import { SlateRegistry_AddSlate } from "@src/core/mandates/integrations/SlateRegistry/SlateRegistry_AddSlate.sol";
import { SlateRegistry_RemoveSlate } from "@src/core/mandates/integrations/SlateRegistry/SlateRegistry_RemoveSlate.sol";
import { SlateRegistry_ExecuteResult } from "@src/core/mandates/integrations/SlateRegistry/SlateRegistry_ExecuteResult.sol";

/// @title Yield Endowment — Deploy Script
///
/// Governance structure:
///   0 — Admin           : deployer; used only for initial setup
///   1 — Founding Members: 5 permanent stewards; hold veto, emergency, and reform authority
///   2 — Members         : past grantees admitted by Founding Members; drive elections
///   3 — SlateRegistry   : internal role assigned to the SlateRegistry contract
///
/// Flows:
///   A — Slate Election  : Members create elections → vote → Founding Members veto window → execute
///   B — Slate Submission: Members submit slates; members can withdraw their own
///   C — Mission Statement: Founding members vote → execute URI change
///   D — Membership      : Founders grant/revoke; majority vote to run lapse sweep; members can leave
///   E — Governance Reform: Founder proposes → members ratify → execute after timelock
///   F — Emergency       : Founding member pauses or restarts critical mandates instantly
///
/// Timing note: SUBMISSION_DURATION and VOTE_DURATION below use short windows for testing.
/// For production replace with minutesToBlocks(14 * 24 * 60, ...) (2 weeks each).
/// Similarly, the 6-month throttle on Create Election uses a 30-min test value.
contract Deploy is DeployHelpers {
    Configurations helperConfig;
    IMandateRegistry registry;
    PowersTypes.MandateInitData[] constitution;
    PowersTypes.Conditions conditions;
    PowersTypes.Flow[] flows;
    Powers powers;
    PowersPaymaster powersPaymaster;

    SlateRegistry slateRegistry;
    SlateRegistry_AddSlate addSlate;
    SlateRegistry_RemoveSlate removeSlate;
    SlateRegistry_ExecuteResult executeResult;

    address[] targets;
    uint256[] values;
    bytes[] calldatas;
    string[] inputParams;
    string[] dynamicParams;

    address deployer;

    uint256 constant SLATE_REGISTRY_ROLE_ID = 3;

    // TODO: Replace these placeholder addresses with the actual founding member addresses
    //       before deploying to a live network. The five founders are assigned role 1
    //       (Founding Members) in the initial setup mandate.
    address constant FOUNDER_1 = 0x328735d26e5Ada93610F0006c32abE2278c46211; // 7Cedars
    address constant FOUNDER_2 = 0xc9ce1DC547C42F66464f5a7f0E3cd60EBf1C5Bd2; // Hannah 
    address constant FOUNDER_3 = 0x3F46F636F78929a4336de0a435E3930092900f06; // agent 1 
    address constant FOUNDER_4 = 0xa221eB405d87B624be08fAbf949F05D19C765f68; // agent 2
    address constant FOUNDER_5 = 0x3cc18745C907979BdF19e6F2B5f243416eeaBba1; // cedars7+powers@proton.me

    uint16 constant MAJOR = 0;
    uint16 constant MINOR = 1;
    uint16 constant PATCH = 9;

    // Canonical ERC-4337 v0.7 EntryPoint — same address on all supported networks.
    address constant ENTRY_POINT = 0x0000000071727De22E5E9d8BAf0edAc6f37da032;

    function run() external returns (Powers, SlateRegistry) {
        deployer = msg.sender;
        helperConfig = new Configurations();
        registry = IMandateRegistry(helperConfig.getMandateRegistry(block.chainid));

        vm.startBroadcast();
        // Test timing: 20-min submission window, 30-min voting window.
        // Production: replace with minutesToBlocks(14 * 24 * 60, ...) for 2-week windows.
        slateRegistry = new SlateRegistry(
            minutesToBlocks(20, helperConfig.getBlocksPerHour(block.chainid)),
            minutesToBlocks(30, helperConfig.getBlocksPerHour(block.chainid)),
            SLATE_REGISTRY_ROLE_ID
        );
        addSlate     = new SlateRegistry_AddSlate();
        removeSlate  = new SlateRegistry_RemoveSlate();
        executeResult = new SlateRegistry_ExecuteResult();
        powers = new Powers(
            "Yield Endowment",
            "",  // TODO: set metadata URI before deploying — upload a JSON file to Pinata
                 // (https://pinata.cloud) with name/description/image fields and paste the URL here.
            helperConfig.getMaxCallDataLength(block.chainid),
            helperConfig.getMaxReturnDataLength(block.chainid),
            helperConfig.getMaxExecutionsLength(block.chainid),
            address(registry)
        );
        powersPaymaster = new PowersPaymaster(IEntryPoint(ENTRY_POINT), address(powers));
        powersPaymaster.deposit{value: 0.05 ether}();
        vm.stopBroadcast();
        console2.log("Powers deployed at:", address(powers));
        console2.log("SlateRegistry deployed at:", address(slateRegistry));
        console2.log("PowersPaymaster deployed at:", address(powersPaymaster));

        uint256 len = createConstitution();
        console2.log("Constitution length:", len);

        vm.startBroadcast();
        powers.constitute(constitution);
        powers.closeConstitute(deployer, flows);
        slateRegistry.transferOwnership(address(powers));
        vm.stopBroadcast();
        console2.log("Powers successfully constituted.");

        return (powers, slateRegistry);
    }

    function createConstitution() internal returns (uint256) {
        uint16 mandateCount = 0;

        ////////////////////////////////////////////////////////////////////////
        //                     SETUP (mandateId = 1)                          //
        // Labels all roles, sets the internal treasury, pre-assigns the five  //
        // Founding Members and the SlateRegistry contract, then revokes this  //
        // mandate so it can never be called again.                            //
        ////////////////////////////////////////////////////////////////////////

        targets   = new address[](15);
        values    = new uint256[](15);
        calldatas = new bytes[](15);
        for (uint256 i; i < targets.length; i++) targets[i] = address(powers);
        targets[13] = address(powersPaymaster); // addSponsoredTarget is called on the paymaster, not on powers

        calldatas[0]  = abi.encodeWithSelector(IPowers.labelRole.selector, 0, "Admin", "");
        calldatas[1]  = abi.encodeWithSelector(IPowers.labelRole.selector, type(uint256).max, "Public", "");
        calldatas[2]  = abi.encodeWithSelector(IPowers.labelRole.selector, 1, "Founding Members", "");
        calldatas[3]  = abi.encodeWithSelector(IPowers.labelRole.selector, 2, "Members", "");
        calldatas[4]  = abi.encodeWithSelector(IPowers.labelRole.selector, SLATE_REGISTRY_ROLE_ID, "SlateRegistry", "");
        calldatas[5]  = abi.encodeWithSelector(IPowers.setTreasury.selector, address(powers));
        calldatas[6]  = abi.encodeWithSelector(IPowers.assignRole.selector, 1, FOUNDER_1);
        calldatas[7]  = abi.encodeWithSelector(IPowers.assignRole.selector, 1, FOUNDER_2);
        calldatas[8]  = abi.encodeWithSelector(IPowers.assignRole.selector, 1, FOUNDER_3);
        calldatas[9]  = abi.encodeWithSelector(IPowers.assignRole.selector, 1, FOUNDER_4);
        calldatas[10] = abi.encodeWithSelector(IPowers.assignRole.selector, 1, FOUNDER_5);
        calldatas[11] = abi.encodeWithSelector(IPowers.assignRole.selector, SLATE_REGISTRY_ROLE_ID, address(slateRegistry));
        calldatas[12] = abi.encodeWithSelector(IPowers.setPaymaster.selector, address(powersPaymaster));
        calldatas[13] = abi.encodeWithSelector(PowersPaymaster.addSponsoredTarget.selector, address(powers));
        calldatas[14] = abi.encodeWithSelector(IPowers.revokeMandate.selector, mandateCount + 1);

        mandateCount++;
        conditions.allowedRole = type(uint256).max; //public; runs setup once
        constitution.push(PowersTypes.MandateInitData({
            nameDescription: "Initial Setup: Assign role labels, set treasury, assign founding members and SlateRegistry roles, then self-revoke.",
            targetMandate: registry.getMandateAddress(MAJOR, MINOR, PATCH, "PresetActions"),
            config: abi.encode(targets, values, calldatas),
            conditions: conditions
        }));
        delete conditions;

        ////////////////////////////////////////////////////////////////////////
        //                      FLOW A: SLATE ELECTION                        //
        // Members open elections (throttled to ~6 months), vote on slates,   //
        // and Founding Members have a veto window before execution.           //
        ////////////////////////////////////////////////////////////////////////

        uint16[] memory flowA = new uint16[](4);
        flowA[0] = mandateCount + 1; // Create Election  → mandateId 2
        flowA[1] = mandateCount + 2; // Cast Vote         → mandateId 3
        flowA[2] = mandateCount + 3; // Veto Execution    → mandateId 4
        flowA[3] = mandateCount + 4; // Execute Results   → mandateId 5
        flows.push(PowersTypes.Flow({
            mandateIds: flowA,
            nameDescription: "Slate Election: Members create elections and vote; Founding Members have a veto window; anyone executes after the timelock."
        }));

        // Mandate: A member opens a new yield distribution election.
        // Throttled to enforce a minimum 6-month gap between elections.
        // Test timing: 30-min throttle. Production: minutesToBlocks(182 * 24 * 60, ...)
        dynamicParams = new string[](4);
        dynamicParams[0] = "string ElectionTitle";
        dynamicParams[1] = "uint8 MaxSlates";
        dynamicParams[2] = "uint8 MaxVotes";
        dynamicParams[3] = "uint8 MaxWinners";

        mandateCount++;
        conditions.allowedRole = 2; // Members
        conditions.throttleExecution = minutesToBlocks(30, helperConfig.getBlocksPerHour(block.chainid));
        constitution.push(PowersTypes.MandateInitData({
            nameDescription: "Create Election: A member opens a new yield distribution election in the SlateRegistry.",
            targetMandate: registry.getMandateAddress(MAJOR, MINOR, PATCH, "BespokeAction_Simple"),
            config: abi.encode(address(slateRegistry), SlateRegistry.createElection.selector, dynamicParams),
            conditions: conditions
        }));
        delete conditions;

        // Mandate: Members cast votes for their preferred funding slates.
        // Voters pass their own address as the second argument so the registry can
        // prevent double-voting on the same election.
        dynamicParams = new string[](3);
        dynamicParams[0] = "uint256 ElectionId";
        dynamicParams[1] = "address Voter";
        dynamicParams[2] = "uint16[] SlateIndexes";

        mandateCount++;
        conditions.allowedRole = 2; // Members
        constitution.push(PowersTypes.MandateInitData({
            nameDescription: "Cast Vote: Members vote for their preferred funding slates during the voting window.",
            targetMandate: registry.getMandateAddress(MAJOR, MINOR, PATCH, "BespokeAction_Simple"),
            config: abi.encode(address(slateRegistry), SlateRegistry.vote.selector, dynamicParams),
            conditions: conditions
        }));
        delete conditions;

        // Mandate: Founding Members veto election results before they can be executed.
        // Must be fulfilled (vote passed + executed) with the same ElectionTitle + nonce
        // as the Execute Results call to block execution.
        // Test timing: 5-min vote. Production: 3-day vote — minutesToBlocks(3 * 24 * 60, ...)
        inputParams = new string[](1);
        inputParams[0] = "string ElectionTitle";

        mandateCount++;
        conditions.allowedRole = 1; // Founding Members
        conditions.votingPeriod = minutesToBlocks(5, helperConfig.getBlocksPerHour(block.chainid));
        conditions.quorum = 60; // 3 of 5 founders must participate
        conditions.succeedAt = 51;
        constitution.push(PowersTypes.MandateInitData({
            nameDescription: "Veto Execution: Founding members vote to block execution of election results.",
            targetMandate: registry.getMandateAddress(MAJOR, MINOR, PATCH, "StatementOfIntent"),
            config: abi.encode(inputParams),
            conditions: conditions
        }));
        delete conditions;

        // Mandate: After the veto window closes, anyone triggers execution of winning slates.
        // The timelock must exceed the veto voting period so a successful veto can land first.
        // Test timing: 10-min timelock (> 5-min veto). Production: 4 days — minutesToBlocks(4 * 24 * 60, ...)
        mandateCount++;
        conditions.allowedRole = type(uint256).max; // Public — anyone can trigger
        conditions.needNotFulfilled = mandateCount - 1; // blocked if veto was executed
        conditions.timelock = minutesToBlocks(10, helperConfig.getBlocksPerHour(block.chainid));
        constitution.push(PowersTypes.MandateInitData({
            nameDescription: "Execute Results: After voting has closed and the veto window has expired, execute the winning slates on-chain.",
            targetMandate: address(executeResult),
            config: abi.encode(address(slateRegistry)),
            conditions: conditions
        }));
        delete conditions;

        ////////////////////////////////////////////////////////////////////////
        //                     FLOW B: SLATE SUBMISSION                       //
        // Members submit funding slates to an open election and may withdraw  //
        // their own before the voting window opens.                           //
        ////////////////////////////////////////////////////////////////////////

        uint16[] memory flowB = new uint16[](2);
        flowB[0] = mandateCount + 1; // Add Slate    → mandateId 6
        flowB[1] = mandateCount + 2; // Remove Slate → mandateId 7
        flows.push(PowersTypes.Flow({
            mandateIds: flowB,
            nameDescription: "Slate Submission: Members propose funding slates and can withdraw them before voting opens."
        }));

        // Mandate: A member submits a slate of funding actions to compete in an election.
        mandateCount++;
        conditions.allowedRole = 2; // Members only
        constitution.push(PowersTypes.MandateInitData({
            nameDescription: "Add Slate: A member proposes a slate of funding actions to compete in an election.",
            targetMandate: address(addSlate),
            config: abi.encode(
                address(slateRegistry),
                registry.getMandateAddress(MAJOR, MINOR, PATCH, "PresetActions")
            ),
            conditions: conditions
        }));
        delete conditions;

        // Mandate: A member withdraws their own slate before voting opens.
        // needFulfilled = Add Slate: same calldata + nonce links the removal to the original
        // submission — only the original submitter can reproduce the exact calldata.
        mandateCount++;
        conditions.allowedRole = 2; // Members
        conditions.needFulfilled = mandateCount - 1; // AddSlate must have been fulfilled with same calldata
        constitution.push(PowersTypes.MandateInitData({
            nameDescription: "Remove Slate: A member withdraws their own submitted slate before the voting window opens.",
            targetMandate: address(removeSlate),
            config: abi.encode(address(slateRegistry), uint16(mandateCount - 1)),
            conditions: conditions
        }));
        delete conditions;

        ////////////////////////////////////////////////////////////////////////
        //                    FLOW C: MISSION STATEMENT                       //
        // Founding Members vote to update the organisation URI (mission       //
        // statement). Requires majority vote and a short timelock.            //
        ////////////////////////////////////////////////////////////////////////

        uint16[] memory flowC = new uint16[](2);
        flowC[0] = mandateCount + 1; // Propose URI Change → mandateId 8
        flowC[1] = mandateCount + 2; // Execute URI Change → mandateId 9
        flows.push(PowersTypes.Flow({
            mandateIds: flowC,
            nameDescription: "Mission Statement: Founding members vote to update the organisation URI."
        }));

        // Mandate: Founding Members vote on a proposed new URI.
        // Test timing: 5-min vote. Production: 3-day vote — minutesToBlocks(3 * 24 * 60, ...)
        inputParams = new string[](1);
        inputParams[0] = "string NewUri";

        mandateCount++;
        conditions.allowedRole = 1; // Founding Members
        conditions.votingPeriod = minutesToBlocks(5, helperConfig.getBlocksPerHour(block.chainid));
        conditions.quorum = 60;
        conditions.succeedAt = 51;
        constitution.push(PowersTypes.MandateInitData({
            nameDescription: "Propose URI Change: Founding members vote to update the organisation mission statement URI.",
            targetMandate: registry.getMandateAddress(MAJOR, MINOR, PATCH, "StatementOfIntent"),
            config: abi.encode(inputParams),
            conditions: conditions
        }));
        delete conditions;

        // Mandate: Execute the URI change after vote passes and timelock expires.
        // Test timing: 10-min timelock. Production: 4 days — minutesToBlocks(4 * 24 * 60, ...)
        mandateCount++;
        conditions.allowedRole = 1; // Founding Members
        conditions.needFulfilled = mandateCount - 1; // proposal must have passed
        conditions.timelock = minutesToBlocks(10, helperConfig.getBlocksPerHour(block.chainid));
        constitution.push(PowersTypes.MandateInitData({
            nameDescription: "Execute URI Change: Update the Powers contract metadata URI to the approved new value.",
            targetMandate: registry.getMandateAddress(MAJOR, MINOR, PATCH, "BespokeAction_Simple"),
            config: abi.encode(address(powers), IPowers.setUri.selector, inputParams),
            conditions: conditions
        }));
        delete conditions;

        ////////////////////////////////////////////////////////////////////////
        //                       FLOW D: MEMBERSHIP                           //
        // Founding Members grant/revoke membership. A majority vote authorises//
        // the annual lapse sweep. Members can leave voluntarily at any time.  //
        ////////////////////////////////////////////////////////////////////////

        uint16[] memory flowD = new uint16[](5);
        flowD[0] = mandateCount + 1; // Grant Membership      → mandateId 10
        flowD[1] = mandateCount + 2; // Revoke Membership     → mandateId 11
        flowD[2] = mandateCount + 3; // Propose Lapse Sweep   → mandateId 12
        flowD[3] = mandateCount + 4; // Run Lapse Sweep       → mandateId 13
        flowD[4] = mandateCount + 5; // Leave Voluntarily     → mandateId 14
        flows.push(PowersTypes.Flow({
            mandateIds: flowD,
            nameDescription: "Membership: Founding members grant and revoke membership; members can leave voluntarily."
        }));

        // Mandate: Founding Members assign the Member role to a verified past grantee.
        // The roleId (2) is baked in as the static prefix; the caller provides the account.
        dynamicParams = new string[](1);
        dynamicParams[0] = "address Account";

        mandateCount++;
        conditions.allowedRole = 1; // Founding Members
        constitution.push(PowersTypes.MandateInitData({
            nameDescription: "Grant Membership: Founding members assign the Member role to a verified past grantee.",
            targetMandate: registry.getMandateAddress(MAJOR, MINOR, PATCH, "BespokeAction_Advanced"),
            config: abi.encode(
                address(powers),
                IPowers.assignRole.selector,
                abi.encode(uint256(2)), // staticPrefix: roleId = 2 (Members)
                dynamicParams,
                abi.encode()           // staticSuffix: empty
            ),
            conditions: conditions
        }));
        delete conditions;

        // Mandate: Founding Members remove the Member role from a specified account.
        mandateCount++;
        conditions.allowedRole = 1; // Founding Members
        constitution.push(PowersTypes.MandateInitData({
            nameDescription: "Revoke Membership: Founding members remove the Member role from a specified account.",
            targetMandate: registry.getMandateAddress(MAJOR, MINOR, PATCH, "BespokeAction_Advanced"),
            config: abi.encode(
                address(powers),
                IPowers.revokeRole.selector,
                abi.encode(uint256(2)), // staticPrefix: roleId = 2 (Members)
                dynamicParams,
                abi.encode()
            ),
            conditions: conditions
        }));
        delete conditions;

        // Mandate: Founding Members vote to authorise a lapse sweep.
        // No inputParams — the vote is simply "run the sweep" with no parameters.
        // Test timing: 5-min vote. Production: 3-day vote — minutesToBlocks(3 * 24 * 60, ...)
        inputParams = new string[](0);

        mandateCount++;
        conditions.allowedRole = 1; // Founding Members
        conditions.votingPeriod = minutesToBlocks(5, helperConfig.getBlocksPerHour(block.chainid));
        conditions.quorum = 60;
        conditions.succeedAt = 51;
        constitution.push(PowersTypes.MandateInitData({
            nameDescription: "Propose Lapse Sweep: Founding members vote to authorise sweeping inactive member accounts.",
            targetMandate: registry.getMandateAddress(MAJOR, MINOR, PATCH, "StatementOfIntent"),
            config: abi.encode(inputParams),
            conditions: conditions
        }));
        delete conditions;

        // Mandate: Revoke Members who participated in fewer than 1 of the last 500 actions.
        // This approximates annual lapse for a moderately active organisation.
        // The 500-action window can be adjusted via governance reform if activity levels differ.
        mandateCount++;
        conditions.allowedRole = 1; // Founding Members
        conditions.needFulfilled = mandateCount - 1; // majority vote to authorise
        constitution.push(PowersTypes.MandateInitData({
            nameDescription: "Run Lapse Sweep: Revoke the Member role from accounts that have been inactive in recent governance.",
            targetMandate: registry.getMandateAddress(MAJOR, MINOR, PATCH, "RevokeInactiveAccounts"),
            config: abi.encode(
                uint256(2),   // roleId = 2 (Members)
                uint256(1),   // minimumActionsNeeded
                uint256(500)  // numberActionsToCheck
            ),
            conditions: conditions
        }));
        delete conditions;

        // Mandate: A member voluntarily gives up their Member role (exit right).
        uint256[] memory renounceableRoles = new uint256[](1);
        renounceableRoles[0] = 2;

        mandateCount++;
        conditions.allowedRole = 2; // Members only
        constitution.push(PowersTypes.MandateInitData({
            nameDescription: "Leave Voluntarily: A member renounces their own Member role.",
            targetMandate: registry.getMandateAddress(MAJOR, MINOR, PATCH, "RenounceRole"),
            config: abi.encode(renounceableRoles),
            conditions: conditions
        }));
        delete conditions;

        ////////////////////////////////////////////////////////////////////////
        //                    FLOW E: GOVERNANCE REFORM                       //
        // A single Founding Member proposes a reform. Members ratify via vote.//
        // Founding Members execute after the ratification timelock expires.   //
        ////////////////////////////////////////////////////////////////////////

        uint16[] memory flowE = new uint16[](3);
        flowE[0] = mandateCount + 1; // Propose Reform    → mandateId 15
        flowE[1] = mandateCount + 2; // Member Ratification → mandateId 16
        flowE[2] = mandateCount + 3; // Execute Reform    → mandateId 17
        flows.push(PowersTypes.Flow({
            mandateIds: flowE,
            nameDescription: "Governance Reform: A founding member proposes; members ratify; then execute after timelock."
        }));

        // Mandate: A single Founding Member proposes a governance reform (no vote required).
        // Any one of the five founders can initiate; the reform carries the list of new
        // mandate addresses and their associated role IDs.
        // Adopt_Mandates v0.2.0 takes one full MandateInitData[]. The propose/veto/ratify
        // steps are matched to the execute step by hashing the *same* mandateCalldata, so this
        // must mirror the executor exactly or an approved proposal cannot be executed.
        string[] memory reformParams = new string[](1);
        reformParams[0] =
            "(string,address,bytes,(uint256,uint32,uint32,uint32,uint16,uint16,uint8,uint8,uint32))[] mandateInitData";

        mandateCount++;
        conditions.allowedRole = 1; // Any Founding Member can propose
        constitution.push(PowersTypes.MandateInitData({
            nameDescription: "Propose Governance Reform: A founding member proposes adopting new governance mandates.",
            targetMandate: registry.getMandateAddress(MAJOR, MINOR, PATCH, "StatementOfIntent"),
            config: abi.encode(reformParams),
            conditions: conditions
        }));
        delete conditions;

        // Mandate: Members ratify a proposed governance reform via vote.
        // needFulfilled links to the proposal: same calldata (mandate list + role IDs) + nonce.
        // Test timing: 10-min vote. Production: 1-week vote — minutesToBlocks(7 * 24 * 60, ...)
        mandateCount++;
        conditions.allowedRole = 2; // Members ratify
        conditions.needFulfilled = mandateCount - 1; // proposal must have been submitted first
        conditions.votingPeriod = minutesToBlocks(10, helperConfig.getBlocksPerHour(block.chainid));
        conditions.quorum = 30;
        conditions.succeedAt = 51;
        constitution.push(PowersTypes.MandateInitData({
            nameDescription: "Ratify Governance Reform: Members vote to approve a proposed governance reform.",
            targetMandate: registry.getMandateAddress(MAJOR, MINOR, PATCH, "StatementOfIntent"),
            config: abi.encode(reformParams),
            conditions: conditions
        }));
        delete conditions;

        // Mandate: Founding Members execute the reform after ratification and timelock.
        // The timelock must exceed the ratification voting period.
        // Test timing: 15-min timelock. Production: 8 days — minutesToBlocks(8 * 24 * 60, ...)
        mandateCount++;
        conditions.allowedRole = 1; // Founding Members execute
        conditions.needFulfilled = mandateCount - 1; // ratification must have passed
        conditions.timelock = minutesToBlocks(15, helperConfig.getBlocksPerHour(block.chainid));
        constitution.push(PowersTypes.MandateInitData({
            nameDescription: "Execute Governance Reform: Adopt the approved new governance mandates after member ratification.",
            targetMandate: _latestAdoptMandates(),
            config: abi.encode(),
            conditions: conditions
        }));
        delete conditions;

        ////////////////////////////////////////////////////////////////////////
        //                      FLOW F: EMERGENCY                             //
        // Any Founding Member can pause or restart Cast Vote, Execute Results //
        // and Add Slate instantly — no vote, no timelock.                    //
        ////////////////////////////////////////////////////////////////////////

        uint16[] memory flowF = new uint16[](1);
        flowF[0] = mandateCount + 1; // Pause/Restart → mandateId 18
        flows.push(PowersTypes.Flow({
            mandateIds: flowF,
            nameDescription: "Emergency: A founding member pauses or restarts critical election mandates instantly."
        }));

        // PauseMandates targets (0-based within the flows array):
        //   flows[0] (Flow A) position 1 → Cast Vote        (mandateId 3)
        //   flows[0] (Flow A) position 3 → Execute Results  (mandateId 5)
        //   flows[1] (Flow B) position 0 → Add Slate        (mandateId 6)
        uint8[] memory indexFlow    = new uint8[](3);
        uint8[] memory indexMandate = new uint8[](3);
        indexFlow[0] = 0; indexMandate[0] = 1; // Cast Vote
        indexFlow[1] = 0; indexMandate[1] = 3; // Execute Results
        indexFlow[2] = 1; indexMandate[2] = 0; // Add Slate

        mandateCount++;
        conditions.allowedRole = 1; // Any Founding Member — speed is the priority
        constitution.push(PowersTypes.MandateInitData({
            nameDescription: "Pause or Restart Critical Mandates: A founding member pauses or restarts election and voting mandates in an emergency.",
            targetMandate: registry.getMandateAddress(MAJOR, MINOR, PATCH, "PauseMandates"),
            config: abi.encode(indexFlow, indexMandate),
            conditions: conditions
        }));
        delete conditions;

        ////////////////////////////////////////////////////////////////////////
        //                    FLOW G: FUND PAYMASTER                          //
        // A Founding Member proposes topping up the paymaster; Founding       //
        // Members vote and execute the ETH transfer to cover gas for members. //
        // Test timing: 5-min vote. Production: minutesToBlocks(3 * 24 * 60, ...)
        ////////////////////////////////////////////////////////////////////////

        uint16[] memory flowG = new uint16[](2);
        flowG[0] = mandateCount + 1;
        flowG[1] = mandateCount + 2;
        flows.push(PowersTypes.Flow({
            mandateIds: flowG,
            nameDescription: "Fund Paymaster: A founding member proposes topping up the gasless paymaster; founding members vote to execute."
        }));

        // Mandate: A Founding Member proposes funding the paymaster.
        mandateCount++;
        conditions.allowedRole = 1; // Founding Members
        constitution.push(PowersTypes.MandateInitData({
            nameDescription: "Propose to Fund Paymaster: A founding member proposes an ETH top-up for the gasless transaction paymaster.",
            targetMandate: registry.getMandateAddress(MAJOR, MINOR, PATCH, "StatementOfIntent"),
            config: abi.encode(),
            conditions: conditions
        }));
        delete conditions;

        // Mandate: Founding Members vote and execute a 0.05 ETH transfer to the paymaster.
        targets    = new address[](1);
        values     = new uint256[](1);
        calldatas  = new bytes[](1);
        targets[0]   = address(powersPaymaster);
        values[0]    = 0.05 ether;
        calldatas[0] = abi.encodeWithSignature("deposit()");

        mandateCount++;
        conditions.allowedRole  = 1; // Founding Members
        conditions.votingPeriod = minutesToBlocks(5, helperConfig.getBlocksPerHour(block.chainid));
        conditions.quorum       = 60; // 3 of 5 founders must participate
        conditions.succeedAt    = 51;
        conditions.needFulfilled = mandateCount - 1;
        constitution.push(PowersTypes.MandateInitData({
            nameDescription: "Execute Fund Paymaster: Transfer 0.05 ETH to the paymaster after a successful founding member vote.",
            targetMandate: registry.getMandateAddress(MAJOR, MINOR, PATCH, "PresetActions"),
            config: abi.encode(targets, values, calldatas),
            conditions: conditions
        }));
        delete conditions;

        ////////////////////////////////////////////////////////////////////////
        //                  FLOW H: WITHDRAW FROM PAYMASTER                   //
        // A Founding Member proposes withdrawing ETH from the paymaster;      //
        // Founding Members vote and execute the withdrawal to the treasury.   //
        // Test timing: 5-min vote. Production: minutesToBlocks(3 * 24 * 60, ...)
        ////////////////////////////////////////////////////////////////////////

        uint16[] memory flowH = new uint16[](2);
        flowH[0] = mandateCount + 1;
        flowH[1] = mandateCount + 2;
        flows.push(PowersTypes.Flow({
            mandateIds: flowH,
            nameDescription: "Withdraw from Paymaster: A founding member proposes withdrawing ETH from the paymaster; founding members vote to execute."
        }));

        string[] memory withdrawParams = new string[](2);
        withdrawParams[0] = "address withdrawAddress";
        withdrawParams[1] = "uint256 amount";

        // Mandate: A Founding Member proposes withdrawing ETH from the paymaster.
        mandateCount++;
        conditions.allowedRole = 1; // Founding Members
        constitution.push(PowersTypes.MandateInitData({
            nameDescription: "Propose to Withdraw from Paymaster: A founding member proposes withdrawing ETH from the gasless paymaster.",
            targetMandate: registry.getMandateAddress(MAJOR, MINOR, PATCH, "StatementOfIntent"),
            config: abi.encode(withdrawParams),
            conditions: conditions
        }));
        delete conditions;

        // Mandate: Founding Members vote and execute the proposed ETH withdrawal.
        mandateCount++;
        conditions.allowedRole  = 1; // Founding Members
        conditions.votingPeriod = minutesToBlocks(5, helperConfig.getBlocksPerHour(block.chainid));
        conditions.quorum       = 60; // 3 of 5 founders must participate
        conditions.succeedAt    = 51;
        conditions.needFulfilled = mandateCount - 1;
        constitution.push(PowersTypes.MandateInitData({
            nameDescription: "Execute Withdraw from Paymaster: Execute the approved ETH withdrawal from the paymaster.",
            targetMandate: registry.getMandateAddress(MAJOR, MINOR, PATCH, "BespokeAction_Simple"),
            config: abi.encode(
                address(powersPaymaster),
                bytes4(keccak256("withdrawTo(address,uint256)")),
                withdrawParams
            ),
            conditions: conditions
        }));
        delete conditions;

        return constitution.length;
    }

    /// @notice Adopt_Mandates is at version 0.2.0 (full MandateInitData payload), not the
    /// repo-wide (MAJOR, MINOR, PATCH) pin used for the other mandates.
    function _latestAdoptMandates() internal view returns (address) {
        (uint16 major, uint16 minor, uint16 patch) = registry.getLatestVersion("Adopt_Mandates");
        return registry.getMandateAddress(major, minor, patch, "Adopt_Mandates");
    }
}
