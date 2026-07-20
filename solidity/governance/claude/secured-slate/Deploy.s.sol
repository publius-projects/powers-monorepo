// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import { console2 } from "forge-std/console2.sol";
import { Configurations } from "@script/Configurations.s.sol";
import { DeployHelpers } from "../../DeployHelpers.s.sol";
import { IMandateRegistry } from "@src/core/helpers/MandateRegistry.sol";

import { PowersTypes } from "@src/interfaces/PowersTypes.sol";
import { Powers } from "@src/Powers.sol";
import { IPowers } from "@src/interfaces/IPowers.sol";

import { SlateRegistry } from "@src/core/helpers/SlateRegistry.sol";
import { SlateRegistry_AddSlate } from "@src/core/mandates/integrations/SlateRegistry/SlateRegistry_AddSlate.sol";
import { SlateRegistry_RemoveSlate } from "@src/core/mandates/integrations/SlateRegistry/SlateRegistry_RemoveSlate.sol";
import { SlateRegistry_ExecuteResult } from "@src/core/mandates/integrations/SlateRegistry/SlateRegistry_ExecuteResult.sol";

/// @title Secured Slate Governance — Deploy Script
///
/// Governance structure:
///   - Public:           propose slates in any election
///   - Members (1):      vote on slates; onboard new members by peer vote
///   - Security Council (2): vet slates by removal; manage blacklist; pause elections
///   - SlateRegistry (3):    internal role assigned to the SlateRegistry contract
///   - Blacklisted (4):      accounts marked for misconduct by the Security Council
///
/// Flows:
///   A — Slate Elections:   Members create elections → Members vote → anyone executes results
///   B — Slate Submission:  Anyone adds slates → Security Council can remove (veto)
///   C — Member Management: Members vote to add members; members can renounce
///   D — Blacklist:         Security Council marks, revokes membership, de-blacklists
///   E — Emergency:         Security Council pauses / restarts Cast Vote, Execute Results, Add Slate
///
/// Test timing: 20-min submission window, 30-min voting window (≈ 10× speed-up).
/// For production replace with 2-day and 3-day windows.
contract Deploy is DeployHelpers {
    Configurations helperConfig;
    IMandateRegistry registry;
    PowersTypes.MandateInitData[] constitution;
    PowersTypes.Conditions conditions;
    PowersTypes.Flow[] flows;
    Powers powers;

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
    uint256 constant BLACKLISTED_ROLE_ID = 4;

    // Pre-assigned Security Council members
    address constant COUNCIL_1 = 0x3F46F636F78929a4336de0a435E3930092900f06;
    address constant COUNCIL_2 = 0xa221eB405d87B624be08fAbf949F05D19C765f68;
    address constant COUNCIL_3 = 0x7507F9F06103D7D462DaE11C0A6f4A415c69DcF9;

    uint16 constant MAJOR = 0;
    uint16 constant MINOR = 1;
    uint16 constant PATCH = 9;

    function run() external returns (Powers, SlateRegistry) {
        deployer = msg.sender;

        helperConfig = new Configurations();
        registry = IMandateRegistry(helperConfig.getMandateRegistry(block.chainid));

        vm.startBroadcast();
        // Deploy SlateRegistry: 20-min submission window, 30-min voting window (test timing)
        slateRegistry = new SlateRegistry(
            minutesToBlocks(20, helperConfig.getBlocksPerHour(block.chainid)),
            minutesToBlocks(30, helperConfig.getBlocksPerHour(block.chainid)),
            SLATE_REGISTRY_ROLE_ID
        );
        addSlate    = new SlateRegistry_AddSlate();
        removeSlate = new SlateRegistry_RemoveSlate();
        executeResult = new SlateRegistry_ExecuteResult();
        powers = new Powers(
            "Secured Slate Governance",
            "https://aqua-famous-sailfish-288.mypinata.cloud/ipfs/bafybeiecp4sftsohsmaqqnzojxu5qlhs44qzhfb3ym7qoyormx36v2a77q/securedSlate.json",
            helperConfig.getMaxCallDataLength(block.chainid),
            helperConfig.getMaxReturnDataLength(block.chainid),
            helperConfig.getMaxExecutionsLength(block.chainid),
            address(registry)
        );
        vm.stopBroadcast();
        console2.log("Powers deployed at:", address(powers));
        console2.log("SlateRegistry deployed at:", address(slateRegistry));

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
        // Labels all roles, sets treasury, pre-assigns Security Council and   //
        // SlateRegistry roles, seeds deployer as first Member, then revokes  //
        // this mandate so it can never be called again.                       //
        ////////////////////////////////////////////////////////////////////////

        targets   = new address[](13);
        values    = new uint256[](13);
        calldatas = new bytes[](13);
        for (uint256 i; i < targets.length; i++) targets[i] = address(powers);

        calldatas[0]  = abi.encodeWithSelector(IPowers.labelRole.selector, 0, "Admin", "");
        calldatas[1]  = abi.encodeWithSelector(IPowers.labelRole.selector, type(uint256).max, "Public", "");
        calldatas[2]  = abi.encodeWithSelector(IPowers.labelRole.selector, 1, "Members", "");
        calldatas[3]  = abi.encodeWithSelector(IPowers.labelRole.selector, 2, "Security Council", "");
        calldatas[4]  = abi.encodeWithSelector(IPowers.labelRole.selector, SLATE_REGISTRY_ROLE_ID, "SlateRegistry", "");
        calldatas[5]  = abi.encodeWithSelector(IPowers.labelRole.selector, BLACKLISTED_ROLE_ID, "Blacklisted", "");
        calldatas[6]  = abi.encodeWithSelector(IPowers.setTreasury.selector, address(powers));
        calldatas[7]  = abi.encodeWithSelector(IPowers.assignRole.selector, 2, COUNCIL_1);
        calldatas[8]  = abi.encodeWithSelector(IPowers.assignRole.selector, 2, COUNCIL_2);
        calldatas[9]  = abi.encodeWithSelector(IPowers.assignRole.selector, 2, COUNCIL_3);
        calldatas[10] = abi.encodeWithSelector(IPowers.assignRole.selector, SLATE_REGISTRY_ROLE_ID, address(slateRegistry));
        calldatas[11] = abi.encodeWithSelector(IPowers.assignRole.selector, 1, deployer); // bootstrap: first member
        calldatas[12] = abi.encodeWithSelector(IPowers.revokeMandate.selector, mandateCount + 1);

        mandateCount++;
        conditions.allowedRole = 0; // Admin triggers setup once
        constitution.push(PowersTypes.MandateInitData({
            nameDescription: "Initial Setup: Assign role labels, set treasury, pre-assign Security Council and SlateRegistry roles, seed first member, then self-revoke.",
            targetMandate: registry.getMandateAddress(MAJOR, MINOR, PATCH, "PresetActions"),
            config: abi.encode(targets, values, calldatas),
            conditions: conditions
        }));
        delete conditions;

        ////////////////////////////////////////////////////////////////////////
        //                   FLOW A: SLATE ELECTIONS                          //
        // Members open elections, members vote, anyone triggers execution.    //
        ////////////////////////////////////////////////////////////////////////

        uint16[] memory flowA = new uint16[](3);
        flowA[0] = mandateCount + 1;
        flowA[1] = mandateCount + 2;
        flowA[2] = mandateCount + 3;
        flows.push(PowersTypes.Flow({
            mandateIds: flowA,
            nameDescription: "Slate Elections: Members create and vote in grant elections; winning slates execute automatically."
        }));

        // Mandate: Members open a new election (throttled to prevent spam)
        dynamicParams = new string[](4);
        dynamicParams[0] = "string ElectionTitle";
        dynamicParams[1] = "uint8 MaxSlates";
        dynamicParams[2] = "uint8 MaxVotes";
        dynamicParams[3] = "uint8 MaxWinners";

        mandateCount++;
        conditions.allowedRole = 1; // Members
        conditions.throttleExecution = minutesToBlocks(30, helperConfig.getBlocksPerHour(block.chainid));
        constitution.push(PowersTypes.MandateInitData({
            nameDescription: "Create Election: A member opens a new slate election in the SlateRegistry.",
            targetMandate: registry.getMandateAddress(MAJOR, MINOR, PATCH, "BespokeAction_Simple"),
            config: abi.encode(address(slateRegistry), SlateRegistry.createElection.selector, dynamicParams),
            conditions: conditions
        }));
        delete conditions;

        // Mandate: Members cast votes for slates during the voting window.
        // Each voter passes their own address as the caller argument to prevent double-voting.
        dynamicParams = new string[](3);
        dynamicParams[0] = "uint256 ElectionId";
        dynamicParams[1] = "address Voter";
        dynamicParams[2] = "uint16[] SlateIndexes";

        mandateCount++;
        conditions.allowedRole = 1; // Members
        constitution.push(PowersTypes.MandateInitData({
            nameDescription: "Cast Vote: Members vote for their preferred slates during the voting window.",
            targetMandate: registry.getMandateAddress(MAJOR, MINOR, PATCH, "BespokeAction_Simple"),
            config: abi.encode(address(slateRegistry), SlateRegistry.vote.selector, dynamicParams),
            conditions: conditions
        }));
        delete conditions;

        // Mandate: Anyone triggers execution of winning slates after the voting window closes.
        // SlateRegistry_ExecuteResult reverts if block.number <= election.endBlock.
        mandateCount++;
        conditions.allowedRole = type(uint256).max; // Public
        constitution.push(PowersTypes.MandateInitData({
            nameDescription: "Execute Results: After voting has closed, execute the winning slates on-chain.",
            targetMandate: address(executeResult),
            config: abi.encode(address(slateRegistry)),
            conditions: conditions
        }));
        delete conditions;

        ////////////////////////////////////////////////////////////////////////
        //                   FLOW B: SLATE SUBMISSION                         //
        // Anyone proposes slates; Security Council can veto by removal.       //
        ////////////////////////////////////////////////////////////////////////

        uint16[] memory flowB = new uint16[](2);
        flowB[0] = mandateCount + 1;
        flowB[1] = mandateCount + 2;
        flows.push(PowersTypes.Flow({
            mandateIds: flowB,
            nameDescription: "Slate Submission: Anyone proposes slates; Security Council vetoes by removing them before voting opens."
        }));

        // Mandate: Anyone submits a slate of actions to compete in an election.
        mandateCount++;
        conditions.allowedRole = type(uint256).max; // Public — open proposals
        constitution.push(PowersTypes.MandateInitData({
            nameDescription: "Add Slate: Any account can propose a slate of actions to compete in an election.",
            targetMandate: address(addSlate),
            config: abi.encode(
                address(slateRegistry),
                registry.getMandateAddress(MAJOR, MINOR, PATCH, "PresetActions")
            ),
            conditions: conditions
        }));
        delete conditions;

        // Mandate: Security Council vetoes a slate by reproducing its calldata and removing it.
        // needFulfilled = AddSlate mandateId: ensures the removal uniquely identifies the submission.
        mandateCount++;
        conditions.allowedRole = 2; // Security Council
        conditions.needFulfilled = mandateCount - 1; // AddSlate must have been fulfilled with same calldata
        constitution.push(PowersTypes.MandateInitData({
            nameDescription: "Remove Slate: Security Council vetoes and removes a submitted slate before voting opens.",
            targetMandate: address(removeSlate),
            config: abi.encode(address(slateRegistry), uint16(mandateCount - 1)),
            conditions: conditions
        }));
        delete conditions;

        ////////////////////////////////////////////////////////////////////////
        //                   FLOW C: MEMBER MANAGEMENT                        //
        // Members vote to onboard new members (2% quorum, simple majority).   //
        // Members can also voluntarily renounce their own role.                //
        ////////////////////////////////////////////////////////////////////////

        uint16[] memory flowC = new uint16[](3);
        flowC[0] = mandateCount + 1;
        flowC[1] = mandateCount + 2;
        flowC[2] = mandateCount + 3;
        flows.push(PowersTypes.Flow({
            mandateIds: flowC,
            nameDescription: "Member Management: Peer-vote onboarding (2% quorum) and voluntary exit."
        }));

        // Mandate: Members vote to admit a new member address.
        inputParams = new string[](1);
        inputParams[0] = "address Account";

        mandateCount++;
        conditions.allowedRole = 1; // Members
        conditions.votingPeriod = minutesToBlocks(30, helperConfig.getBlocksPerHour(block.chainid));
        conditions.quorum = 2;  // 2% quorum — very accessible
        conditions.succeedAt = 51; // simple majority
        constitution.push(PowersTypes.MandateInitData({
            nameDescription: "Propose Member Addition: Members vote to onboard a new member.",
            targetMandate: registry.getMandateAddress(MAJOR, MINOR, PATCH, "StatementOfIntent"),
            config: abi.encode(inputParams),
            conditions: conditions
        }));
        delete conditions;

        // Mandate: Assign the Member role after the vote passes.
        // needFulfilled = ProposeMemberAddition: same calldata (address) + nonce must have passed.
        // staticPrefix encodes the fixed roleId=1; caller provides the account address.
        dynamicParams = new string[](1);
        dynamicParams[0] = "address Account";

        mandateCount++;
        conditions.allowedRole = 1; // Members
        conditions.needFulfilled = mandateCount - 1; // ProposeMemberAddition must be fulfilled first
        constitution.push(PowersTypes.MandateInitData({
            nameDescription: "Add Member: Execute an approved member onboarding by assigning the Member role.",
            targetMandate: registry.getMandateAddress(MAJOR, MINOR, PATCH, "BespokeAction_Advanced"),
            config: abi.encode(
                address(powers),
                IPowers.assignRole.selector,
                abi.encode(uint256(1)), // staticPrefix: roleId = 1 (Members)
                dynamicParams,
                abi.encode()            // staticSuffix: empty
            ),
            conditions: conditions
        }));
        delete conditions;

        // Mandate: A member voluntarily gives up their Member role (exit right).
        uint256[] memory renounceableRoles = new uint256[](1);
        renounceableRoles[0] = 1;

        mandateCount++;
        conditions.allowedRole = 1; // Members only
        constitution.push(PowersTypes.MandateInitData({
            nameDescription: "Renounce Membership: A member voluntarily gives up their Member role.",
            targetMandate: registry.getMandateAddress(MAJOR, MINOR, PATCH, "RenounceRole"),
            config: abi.encode(renounceableRoles),
            conditions: conditions
        }));
        delete conditions;

        ////////////////////////////////////////////////////////////////////////
        //                   FLOW D: BLACKLIST MANAGEMENT                     //
        // Security Council marks accounts, revokes their membership           //
        // separately (to remove dead votes), and can de-blacklist.            //
        ////////////////////////////////////////////////////////////////////////

        uint16[] memory flowD = new uint16[](3);
        flowD[0] = mandateCount + 1;
        flowD[1] = mandateCount + 2;
        flowD[2] = mandateCount + 3;
        flows.push(PowersTypes.Flow({
            mandateIds: flowD,
            nameDescription: "Blacklist Management: Security Council marks, de-votes, and de-blacklists accounts."
        }));

        dynamicParams = new string[](1);
        dynamicParams[0] = "address Account";

        // Mandate: Mark an account as Blacklisted (assign role 4).
        // Does NOT automatically remove the Member role — that is a separate step.
        mandateCount++;
        conditions.allowedRole = 2; // Security Council
        constitution.push(PowersTypes.MandateInitData({
            nameDescription: "Blacklist Account: Security Council marks an account as blacklisted.",
            targetMandate: registry.getMandateAddress(MAJOR, MINOR, PATCH, "BespokeAction_Advanced"),
            config: abi.encode(
                address(powers),
                IPowers.assignRole.selector,
                abi.encode(uint256(BLACKLISTED_ROLE_ID)), // staticPrefix: roleId = 4 (Blacklisted)
                dynamicParams,
                abi.encode()
            ),
            conditions: conditions
        }));
        delete conditions;

        // Mandate: Revoke the Member role (role 1) from a blacklisted account.
        // needFulfilled = BlacklistAccount: the same account must have been blacklisted first
        // (same calldata = abi.encode(account), same nonce).
        mandateCount++;
        conditions.allowedRole = 2; // Security Council
        conditions.needFulfilled = mandateCount - 1; // BlacklistAccount must be fulfilled first
        constitution.push(PowersTypes.MandateInitData({
            nameDescription: "Revoke Membership of Blacklisted Account: Security Council removes the Member role from a blacklisted account.",
            targetMandate: registry.getMandateAddress(MAJOR, MINOR, PATCH, "BespokeAction_Advanced"),
            config: abi.encode(
                address(powers),
                IPowers.revokeRole.selector,
                abi.encode(uint256(1)), // staticPrefix: roleId = 1 (Members)
                dynamicParams,
                abi.encode()
            ),
            conditions: conditions
        }));
        delete conditions;

        // Mandate: Remove the Blacklisted mark (revoke role 4).
        // Does NOT automatically restore membership — the account must go through Flow C again.
        mandateCount++;
        conditions.allowedRole = 2; // Security Council
        constitution.push(PowersTypes.MandateInitData({
            nameDescription: "De-Blacklist Account: Security Council removes the Blacklisted mark from an account.",
            targetMandate: registry.getMandateAddress(MAJOR, MINOR, PATCH, "BespokeAction_Advanced"),
            config: abi.encode(
                address(powers),
                IPowers.revokeRole.selector,
                abi.encode(uint256(BLACKLISTED_ROLE_ID)), // staticPrefix: roleId = 4 (Blacklisted)
                dynamicParams,
                abi.encode()
            ),
            conditions: conditions
        }));
        delete conditions;

        ////////////////////////////////////////////////////////////////////////
        //                   FLOW E: EMERGENCY CONTROLS                       //
        // Security Council can pause or restart Cast Vote, Execute Results,   //
        // and Add Slate — freezing the election machinery without touching     //
        // member management or the blacklist.                                  //
        ////////////////////////////////////////////////////////////////////////

        uint16[] memory flowE = new uint16[](1);
        flowE[0] = mandateCount + 1;
        flows.push(PowersTypes.Flow({
            mandateIds: flowE,
            nameDescription: "Emergency Controls: Security Council pauses or restarts critical election mandates."
        }));

        // PauseMandates targets:
        //   Flow 0 (Slate Elections) position 1 → Cast Vote        (mandateId 3)
        //   Flow 0 (Slate Elections) position 2 → Execute Results   (mandateId 4)
        //   Flow 1 (Slate Submission) position 0 → Add Slate        (mandateId 5)
        uint8[] memory indexFlow    = new uint8[](3);
        uint8[] memory indexMandate = new uint8[](3);
        indexFlow[0] = 0; indexMandate[0] = 1; // Cast Vote
        indexFlow[1] = 0; indexMandate[1] = 2; // Execute Results
        indexFlow[2] = 1; indexMandate[2] = 0; // Add Slate

        mandateCount++;
        conditions.allowedRole = 2; // Security Council
        constitution.push(PowersTypes.MandateInitData({
            nameDescription: "Pause or Restart Critical Mandates: Security Council pauses or restarts voting and execution mandates in an emergency.",
            targetMandate: registry.getMandateAddress(MAJOR, MINOR, PATCH, "PauseMandates"),
            config: abi.encode(indexFlow, indexMandate),
            conditions: conditions
        }));
        delete conditions;

        return constitution.length;
    }
}
