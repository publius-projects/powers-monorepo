// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

// Run with: forge script governance/claude/project-orange/Deploy.s.sol:Deploy --rpc-url $ARB_SEPOLIA_RPC_URL --broadcast

import { Script } from "forge-std/Script.sol";
import { console2 } from "forge-std/console2.sol";
import { Configurations } from "@script/Configurations.s.sol";
import { DeployHelpers } from "../../DeployHelpers.s.sol";
import { IMandateRegistry } from "@src/core/helpers/MandateRegistry.sol";

import { PowersTypes } from "@src/interfaces/PowersTypes.sol";
import { Powers } from "@src/Powers.sol";
import { IPowers } from "@src/interfaces/IPowers.sol";

import { PowersPaymaster } from "@src/core/helpers/PowersPaymaster.sol";
import { IEntryPoint } from "@lib/account-abstraction/contracts/interfaces/IEntryPoint.sol";

/// @title Project Orange — Deploy Script
///
/// Roles:
///   0 = Admin    (deployer; emergency veto authority)
///   1 = Member   (3 pre-assigned addresses; unanimous vote required)
///   max = Public (anyone may submit funding proposals)
///
/// Flows:
///   1 — Fund a Project:       Public submits → Members vote unanimously → Admin may veto → Member executes
///   2 — Governance Reform:    Members vote unanimously → Member executes after timelock
///   3 — Fund Paymaster:       Admin signals → Admin executes fixed 0.05 ETH deposit
///   4 — Withdraw Paymaster:   Admin signals → Admin executes withdrawal
contract Deploy is DeployHelpers {
    Configurations helperConfig;
    IMandateRegistry registry;

    PowersTypes.MandateInitData[] constitution;
    PowersTypes.Conditions conditions;
    PowersTypes.Flow[] flows;

    Powers powers;
    PowersPaymaster powersPaymaster;

    address[] targets;
    uint256[] values;
    bytes[] calldatas;
    string[] inputParams;

    uint16 constant MAJOR = 0;
    uint16 constant MINOR = 1;
    uint16 constant PATCH = 9;

    address constant ENTRY_POINT = 0x0000000071727De22E5E9d8BAf0edAc6f37da032;

    address constant MEMBER_1 = 0x3F46F636F78929a4336de0a435E3930092900f06;
    address constant MEMBER_2 = 0xa221eB405d87B624be08fAbf949F05D19C765f68;
    address constant MEMBER_3 = 0x3cc18745C907979BdF19e6F2B5f243416eeaBba1;

    function run() external returns (Powers) {
        helperConfig = new Configurations();
        registry = IMandateRegistry(helperConfig.getMandateRegistry(block.chainid));

        vm.startBroadcast();
        powers = new Powers(
            "Project Orange",
            "https://aqua-famous-sailfish-288.mypinata.cloud/ipfs/bafkreidsrfntlufrkdbfgiwnutjhzo6e4a4qf4faba4zjfajrcn6rpbpvm",
            helperConfig.getMaxCallDataLength(block.chainid),
            helperConfig.getMaxReturnDataLength(block.chainid),
            helperConfig.getMaxExecutionsLength(block.chainid),
            address(registry)
        );
        powersPaymaster = new PowersPaymaster(IEntryPoint(ENTRY_POINT), address(powers));
        powersPaymaster.deposit{value: 0.05 ether}();
        vm.stopBroadcast();
        console2.log("Powers deployed at:", address(powers));
        console2.log("PowersPaymaster deployed at:", address(powersPaymaster));

        uint256 constitutionLength = createConstitution();
        console2.log("Constitution length:", constitutionLength);

        vm.startBroadcast();
        powers.constitute(constitution);
        powers.closeConstitute(msg.sender, flows);
        vm.stopBroadcast();
        console2.log("Powers successfully constituted.");

        return powers;
    }

    function createConstitution() internal returns (uint256) {
        uint16 mandateCount = 0;

        ////////////////////////////////////////////////////////////////////////
        //                        SETUP (mandateId = 1)                       //
        ////////////////////////////////////////////////////////////////////////
        // Labels all roles, assigns three Member addresses, sets treasury and paymaster,
        // registers Powers as a sponsored target, then revokes itself.

        targets = new address[](10);
        values = new uint256[](10);
        calldatas = new bytes[](10);
        for (uint256 i = 0; i < 10; i++) targets[i] = address(powers);

        calldatas[0] = abi.encodeWithSelector(IPowers.labelRole.selector, 0, "Admin", "");
        calldatas[1] = abi.encodeWithSelector(IPowers.labelRole.selector, type(uint256).max, "Public", "");
        calldatas[2] = abi.encodeWithSelector(IPowers.labelRole.selector, 1, "Member", "");
        calldatas[3] = abi.encodeWithSelector(IPowers.assignRole.selector, uint256(1), MEMBER_1);
        calldatas[4] = abi.encodeWithSelector(IPowers.assignRole.selector, uint256(1), MEMBER_2);
        calldatas[5] = abi.encodeWithSelector(IPowers.assignRole.selector, uint256(1), MEMBER_3);
        calldatas[6] = abi.encodeWithSelector(IPowers.setTreasury.selector, address(powers));
        calldatas[7] = abi.encodeWithSelector(IPowers.setPaymaster.selector, address(powersPaymaster));
        targets[8] = address(powersPaymaster); // addSponsoredTarget is called ON the paymaster
        calldatas[8] = abi.encodeWithSelector(PowersPaymaster.addSponsoredTarget.selector, address(powers));
        calldatas[9] = abi.encodeWithSelector(IPowers.revokeMandate.selector, mandateCount + 1);

        mandateCount++;
        conditions.allowedRole = type(uint256).max;
        constitution.push(PowersTypes.MandateInitData({
            nameDescription: "Initial Setup: Assign role labels and revokes itself after execution",
            targetMandate: registry.getMandateAddress(MAJOR, MINOR, PATCH, "PresetActions"),
            config: abi.encode(targets, values, calldatas),
            conditions: conditions
        }));
        delete conditions;

        ////////////////////////////////////////////////////////////////////////
        //                    FLOW 1: FUND A PROJECT                          //
        ////////////////////////////////////////////////////////////////////////
        // Public submits a funding request. All three Members must vote unanimously
        // to approve it. Admin has a veto window after approval. After timelock,
        // a Member executes the ETH transfer to the recipient.
        //
        // All four steps share the same inputParams so the actionId chain holds:
        //   [address[] Targets, uint256[] Values, bytes[] Calldatas, string ProposalDescription]
        // OpenAction (step 4) decodes only (address[], uint256[], bytes[]) at execution time;
        // the trailing string is part of the on-chain record and is ignored by the EVM decoder.

        uint16[] memory flow1MandateIds = new uint16[](4);
        flow1MandateIds[0] = mandateCount + 1;
        flow1MandateIds[1] = mandateCount + 2;
        flow1MandateIds[2] = mandateCount + 3;
        flow1MandateIds[3] = mandateCount + 4;
        flows.push(PowersTypes.Flow({
            mandateIds: flow1MandateIds,
            nameDescription: "Fund a Project: Public submits a funding request; Members vote unanimously; Admin may veto; Member executes after timelock."
        }));

        inputParams = new string[](4);
        inputParams[0] = "address[] Targets";
        inputParams[1] = "uint256[] Values";
        inputParams[2] = "bytes[] Calldatas";
        inputParams[3] = "string ProposalDescription";

        // Step 1 — Anyone submits a funding request. Recorded immediately; no vote.
        mandateCount++;
        conditions.allowedRole = type(uint256).max;
        constitution.push(PowersTypes.MandateInitData({
            nameDescription: "Propose Funding: Anyone can submit a funding request for an orange project. Provide recipient, amount, calldata, and a description.",
            targetMandate: registry.getMandateAddress(MAJOR, MINOR, PATCH, "StatementOfIntent"),
            config: abi.encode(inputParams),
            conditions: conditions
        }));
        delete conditions;

        // Step 2 — All three Members must vote FOR. A single AGAINST or absent vote kills the proposal.
        // Demo: 5-minute voting window. Production: replace with 3-day window.
        mandateCount++;
        conditions.allowedRole = 1; // Member
        conditions.votingPeriod = minutesToBlocks(5, helperConfig.getBlocksPerHour(block.chainid));
        conditions.quorum = 100;     // all Members must vote
        conditions.succeedAt = 100;  // all votes must be FOR (unanimity)
        conditions.needFulfilled = mandateCount - 1;
        constitution.push(PowersTypes.MandateInitData({
            nameDescription: "Vote to Approve Funding: Members vote unanimously to approve a submitted funding proposal.",
            targetMandate: registry.getMandateAddress(MAJOR, MINOR, PATCH, "StatementOfIntent"),
            config: abi.encode(inputParams),
            conditions: conditions
        }));
        delete conditions;

        // Step 3 — Admin may veto within the timelock window after the vote passes.
        // Casting this veto permanently blocks the corresponding execute (step 4).
        mandateCount++;
        conditions.allowedRole = 0; // Admin
        conditions.needFulfilled = mandateCount - 1;
        constitution.push(PowersTypes.MandateInitData({
            nameDescription: "Admin Veto Funding: Admin blocks execution of an approved funding proposal.",
            targetMandate: registry.getMandateAddress(MAJOR, MINOR, PATCH, "StatementOfIntent"),
            config: abi.encode(inputParams),
            conditions: conditions
        }));
        delete conditions;

        // Step 4 — Any Member executes the ETH transfer after the timelock, provided no veto was cast.
        // Timelock (10 min demo / 4 days production) gives Admin time to veto after vote passes.
        // OpenAction executes (Targets, Values, Calldatas) decoded from the 4-field calldata.
        mandateCount++;
        conditions.allowedRole = 1; // Member
        conditions.needFulfilled = mandateCount - 2;    // vote (step 2) must be completed
        conditions.needNotFulfilled = mandateCount - 1; // veto (step 3) must NOT be completed
        conditions.timelock = minutesToBlocks(10, helperConfig.getBlocksPerHour(block.chainid));
        constitution.push(PowersTypes.MandateInitData({
            nameDescription: "Execute Funding: Transfer approved funds from the treasury to the nominated recipient.",
            targetMandate: registry.getMandateAddress(MAJOR, MINOR, PATCH, "OpenAction"),
            config: abi.encode(inputParams),
            conditions: conditions
        }));
        delete conditions;

        ////////////////////////////////////////////////////////////////////////
        //                    FLOW 2: GOVERNANCE REFORM                       //
        ////////////////////////////////////////////////////////////////////////
        // Members unanimously vote to adopt new governance mandates.
        // Same unanimity threshold as funding; timelock gives Admin a window.

        uint16[] memory flow2MandateIds = new uint16[](2);
        flow2MandateIds[0] = mandateCount + 1;
        flow2MandateIds[1] = mandateCount + 2;
        flows.push(PowersTypes.Flow({
            mandateIds: flow2MandateIds,
            nameDescription: "Governance Reform: Members unanimously vote to adopt new governance mandates."
        }));

        // Adopt_Mandates v0.2.0 takes one full MandateInitData[]. The propose step is matched to
        // the execute step by hashing the *same* mandateCalldata, so this must mirror the executor
        // exactly or an approved proposal cannot be executed. (The old two-array shape needed a
        // lowercase-name workaround to match v0.1.9's hardcoded params; that is no longer relevant.)
        string[] memory reformParams = new string[](1);
        reformParams[0] =
            "(string,address,bytes,(uint256,uint32,uint32,uint32,uint16,uint16,uint8,uint8,uint32))[] mandateInitData";

        // Step 1 — All Members must unanimously agree to adopt new mandates.
        mandateCount++;
        conditions.allowedRole = 1; // Member
        conditions.votingPeriod = minutesToBlocks(5, helperConfig.getBlocksPerHour(block.chainid));
        conditions.quorum = 100;
        conditions.succeedAt = 100;
        constitution.push(PowersTypes.MandateInitData({
            nameDescription: "Propose Governance Reform: Members vote unanimously to adopt new governance mandates.",
            targetMandate: registry.getMandateAddress(MAJOR, MINOR, PATCH, "StatementOfIntent"),
            config: abi.encode(reformParams),
            conditions: conditions
        }));
        delete conditions;

        // Step 2 — Any Member triggers the reform after the timelock.
        mandateCount++;
        conditions.allowedRole = 1; // Member
        conditions.needFulfilled = mandateCount - 1;
        conditions.timelock = minutesToBlocks(10, helperConfig.getBlocksPerHour(block.chainid));
        constitution.push(PowersTypes.MandateInitData({
            nameDescription: "Execute Governance Reform: Adopt new mandates after unanimous member approval.",
            targetMandate: _latestAdoptMandates(),
            config: abi.encode(),
            conditions: conditions
        }));
        delete conditions;

        ////////////////////////////////////////////////////////////////////////
        //                    FLOW 3: FUND PAYMASTER                          //
        ////////////////////////////////////////////////////////////////////////
        // Admin tops up the PowersPaymaster so Members and the public can interact
        // without holding ETH. Fixed deposit of 0.05 ETH per top-up.

        uint16[] memory flow3MandateIds = new uint16[](2);
        flow3MandateIds[0] = mandateCount + 1;
        flow3MandateIds[1] = mandateCount + 2;
        flows.push(PowersTypes.Flow({
            mandateIds: flow3MandateIds,
            nameDescription: "Fund Paymaster: Admin tops up the PowersPaymaster with 0.05 ETH."
        }));

        // Step 1 — Admin signals intent to fund the paymaster (no params needed).
        mandateCount++;
        conditions.allowedRole = 0; // Admin
        constitution.push(PowersTypes.MandateInitData({
            nameDescription: "Propose to Fund Paymaster: Admin signals intent to top up the gasless paymaster.",
            targetMandate: registry.getMandateAddress(MAJOR, MINOR, PATCH, "StatementOfIntent"),
            config: abi.encode(),
            conditions: conditions
        }));
        delete conditions;

        // Step 2 — Admin deposits a fixed 0.05 ETH into the paymaster.
        targets = new address[](1);
        values = new uint256[](1);
        calldatas = new bytes[](1);
        targets[0] = address(powersPaymaster);
        values[0] = 0.05 ether;
        calldatas[0] = abi.encodeWithSignature("deposit()");

        mandateCount++;
        conditions.allowedRole = 0; // Admin
        conditions.needFulfilled = mandateCount - 1;
        constitution.push(PowersTypes.MandateInitData({
            nameDescription: "Execute Fund Paymaster: Send 0.05 ETH to the paymaster deposit.",
            targetMandate: registry.getMandateAddress(MAJOR, MINOR, PATCH, "PresetActions"),
            config: abi.encode(targets, values, calldatas),
            conditions: conditions
        }));
        delete conditions;

        ////////////////////////////////////////////////////////////////////////
        //                  FLOW 4: WITHDRAW FROM PAYMASTER                   //
        ////////////////////////////////////////////////////////////////////////
        // Admin recovers ETH from the paymaster if needed.

        uint16[] memory flow4MandateIds = new uint16[](2);
        flow4MandateIds[0] = mandateCount + 1;
        flow4MandateIds[1] = mandateCount + 2;
        flows.push(PowersTypes.Flow({
            mandateIds: flow4MandateIds,
            nameDescription: "Withdraw from Paymaster: Admin withdraws ETH from the PowersPaymaster."
        }));

        string[] memory withdrawParams = new string[](2);
        withdrawParams[0] = "address WithdrawAddress";
        withdrawParams[1] = "uint256 Amount";

        // Step 1 — Admin specifies where to send the withdrawal and how much.
        mandateCount++;
        conditions.allowedRole = 0; // Admin
        constitution.push(PowersTypes.MandateInitData({
            nameDescription: "Propose to Withdraw from Paymaster: Admin signals intent to withdraw ETH from the paymaster.",
            targetMandate: registry.getMandateAddress(MAJOR, MINOR, PATCH, "StatementOfIntent"),
            config: abi.encode(withdrawParams),
            conditions: conditions
        }));
        delete conditions;

        // Step 2 — Admin executes the withdrawal.
        mandateCount++;
        conditions.allowedRole = 0; // Admin
        conditions.needFulfilled = mandateCount - 1;
        constitution.push(PowersTypes.MandateInitData({
            nameDescription: "Execute Withdraw from Paymaster: Withdraw ETH from the paymaster to the specified address.",
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
