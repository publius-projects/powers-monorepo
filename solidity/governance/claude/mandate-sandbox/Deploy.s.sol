// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

// Run with: forge script governance/mandate-sandbox/Deploy.s.sol --rpc-url $ARB_SEPOLIA_RPC_URL --broadcast

// scripts
import { Script } from "forge-std/Script.sol";
import { console2 } from "forge-std/console2.sol";
import { Configurations } from "@script/Configurations.s.sol";
import { DeployHelpers } from "../../DeployHelpers.s.sol";
import { IMandateRegistry } from "@src/core/helpers/MandateRegistry.sol";

// powers contracts
import { PowersTypes } from "@src/interfaces/PowersTypes.sol";
import { Powers } from "@src/Powers.sol";
import { IPowers } from "@src/interfaces/IPowers.sol";

// account abstraction
import { PowersPaymaster } from "@src/core/helpers/PowersPaymaster.sol";
import { IEntryPoint } from "@lib/account-abstraction/contracts/interfaces/IEntryPoint.sol";

// helpers
import { ReturnDataMock } from "../../../test/mocks/ReturnDataMock.sol";

/// @title Mandate Sandbox — Deploy Script
/// @notice Exercises every `Conditions` field (allowedRole, votingPeriod, quorum, succeedAt,
///         timelock, throttleExecution, needFulfilled, needNotFulfilled) using only five
///         familiar mandate types. See Spec.md for the full design rationale.
///
/// Roles:
///   0 = Admin   (deployer; vetoes proposed actions, governs the paymaster)
///   1 = Member  (open join; proposes actions)
///   2 = Council (trusted executor; assigned to the deployer at setup)
contract Deploy is DeployHelpers {
    Configurations helperConfig;
    PowersTypes.MandateInitData[] constitution;
    PowersTypes.Conditions conditions;
    PowersTypes.Flow[] flows;
    Powers powers;
    IMandateRegistry registry;

    ReturnDataMock returnDataMock;
    PowersPaymaster powersPaymaster;

    address[] targets;
    uint256[] values;
    bytes[] calldatas;
    string[] inputParams;

    // Select version mandates to be used.
    uint16 constant MAJOR = 0;
    uint16 constant MINOR = 1;
    uint16 constant PATCH = 9;

    address constant ENTRY_POINT = 0x0000000071727De22E5E9d8BAf0edAc6f37da032;
    address constant HANNAH = 0xc9ce1DC547C42F66464f5a7f0E3cd60EBf1C5Bd2;

    function run() external returns (Powers) {
        // step 0: setup.
        helperConfig = new Configurations();
        registry = IMandateRegistry(helperConfig.getMandateRegistry(block.chainid));

        // step 1: deploy helper contracts and Powers.
        vm.startBroadcast();
        returnDataMock = new ReturnDataMock();

        powers = new Powers(
            "Mandate Sandbox", // name
            "https://aqua-famous-sailfish-288.mypinata.cloud/ipfs/bafkreicqstgxzdv2edfuaadxkz76ijtjedgmq2ovvkececchnfdkj77jeq", 
            helperConfig.getMaxCallDataLength(block.chainid),
            helperConfig.getMaxReturnDataLength(block.chainid),
            helperConfig.getMaxExecutionsLength(block.chainid),
            address(registry)
        );

        powersPaymaster = new PowersPaymaster(IEntryPoint(ENTRY_POINT), address(powers));
        powersPaymaster.deposit{ value: 0.05 ether }();
        vm.stopBroadcast();

        console2.log("Powers deployed at:", address(powers));
        console2.log("PowersPaymaster deployed at:", address(powersPaymaster));
        console2.log("ReturnDataMock deployed at:", address(returnDataMock));

        // step 2: create constitution
        uint256 constitutionLength = createConstitution();
        console2.log("Constitution created with length:");
        console2.logUint(constitutionLength);

        // step 3: constitute and close.
        vm.startBroadcast();
        powers.constitute(constitution);
        powers.closeConstitute(msg.sender, flows);
        vm.stopBroadcast();
        console2.log("Powers successfully constituted.");

        return powers;
    }

    function createConstitution() internal returns (uint256 constitutionLength) {
        uint16 mandateCount = 0;

        ////////////////////////////////////////////////////////////////////////
        //                         SETUP (mandateId = 1)                      //
        // Labels roles, assigns Council to the deployer, wires the paymaster, //
        // and revokes itself after execution.                                 //
        ////////////////////////////////////////////////////////////////////////
        targets = new address[](10);
        values = new uint256[](10);
        calldatas = new bytes[](10);
        for (uint256 i = 0; i < targets.length; i++) {
            targets[i] = address(powers);
        }

        calldatas[0] = abi.encodeWithSelector(IPowers.labelRole.selector, 0, "Admin", "");
        calldatas[1] = abi.encodeWithSelector(IPowers.labelRole.selector, type(uint256).max, "Public", "");
        calldatas[2] = abi.encodeWithSelector(IPowers.labelRole.selector, 1, "Member", "");
        calldatas[3] = abi.encodeWithSelector(IPowers.labelRole.selector, 2, "Council", "");
        calldatas[4] = abi.encodeWithSelector(IPowers.setTreasury.selector, address(powers));
        calldatas[5] = abi.encodeWithSelector(IPowers.assignRole.selector, 2, msg.sender);
        calldatas[6] = abi.encodeWithSelector(IPowers.setPaymaster.selector, address(powersPaymaster));
        targets[7] = address(powersPaymaster);
        calldatas[7] = abi.encodeWithSelector(PowersPaymaster.addSponsoredTarget.selector, address(powers));
        calldatas[8] = abi.encodeWithSelector(IPowers.revokeMandate.selector, mandateCount + 1); // revoke itself after use.
        // adding Hannah to council
        calldatas[9] = abi.encodeWithSelector(IPowers.assignRole.selector, 2, HANNAH);

        mandateCount++;
        conditions.allowedRole = type(uint256).max; // = public role
        constitution.push(
            PowersTypes.MandateInitData({
                nameDescription: "Initial Setup: Assign role labels and revokes itself after execution",
                targetMandate: registry.getMandateAddress(MAJOR, MINOR, PATCH, "PresetActions"),
                config: abi.encode(targets, values, calldatas),
                conditions: conditions
            })
        );
        delete conditions;

        ////////////////////////////////////////////////////////////////////////
        //                       FLOW 1: Membership                          //
        // Exercises `allowedRole` alone — no vote, no timelock, no           //
        // dependency on any other mandate.                                   //
        ////////////////////////////////////////////////////////////////////////
        {
            uint16[] memory flow1Ids = new uint16[](2);
            flow1Ids[0] = mandateCount + 1;
            flow1Ids[1] = mandateCount + 2;
            flows.push(
                PowersTypes.Flow({
                    mandateIds: flow1Ids,
                    nameDescription: "Flow 1: Membership. Anyone can self-select as a Member; Members can renounce their role."
                })
            );
        }

        mandateCount++;
        conditions.allowedRole = type(uint256).max; // = public role
        constitution.push(
            PowersTypes.MandateInitData({
                nameDescription: "Join as Member: Self-select as a Member of Mandate Sandbox.",
                targetMandate: registry.getMandateAddress(MAJOR, MINOR, PATCH, "SelfSelect"),
                config: abi.encode(uint256(1)), // roleId = 1 (Member)
                conditions: conditions
            })
        );
        delete conditions;

        // Allow current Members to voluntarily leave by renouncing their Member role.
        {
            uint256[] memory renounceableRoles = new uint256[](1);
            renounceableRoles[0] = 1; // Member role
            mandateCount++;
            conditions.allowedRole = 1; // = Member
            constitution.push(
                PowersTypes.MandateInitData({
                    nameDescription: "Leave as Member: A Member renounces their Member role in Mandate Sandbox.",
                    targetMandate: registry.getMandateAddress(MAJOR, MINOR, PATCH, "RenounceRole"),
                    config: abi.encode(renounceableRoles),
                    conditions: conditions
                })
            );
            delete conditions;
        }

        ////////////////////////////////////////////////////////////////////////
        //                  FLOW 2: Optimistic Execution                      //
        // propose (votingPeriod + quorum + succeedAt) -> veto (needFulfilled  //
        // alone) -> execute (needFulfilled + needNotFulfilled + timelock).    //
        ////////////////////////////////////////////////////////////////////////
        {
            uint16[] memory flow2Ids = new uint16[](3);
            flow2Ids[0] = mandateCount + 1;
            flow2Ids[1] = mandateCount + 2;
            flow2Ids[2] = mandateCount + 3;
            flows.push(
                PowersTypes.Flow({
                    mandateIds: flow2Ids,
                    nameDescription: "Flow 2: Optimistic Execution. Members propose, Admin can veto, Council executes."
                })
            );
        }

        inputParams = new string[](3);
        inputParams[0] = "address[] targets";
        inputParams[1] = "uint256[] values";
        inputParams[2] = "bytes[] calldatas";

        // Propose (isolated: allowedRole, votingPeriod, quorum, succeedAt)
        mandateCount++;
        conditions.allowedRole = 1; // = Member
        conditions.votingPeriod = minutesToBlocks(10, helperConfig.getBlocksPerHour(block.chainid));
        conditions.quorum = 20;
        conditions.succeedAt = 51;
        constitution.push(
            PowersTypes.MandateInitData({
                nameDescription: "Propose Action: A Member proposes an action for the optimistic execution flow.",
                targetMandate: registry.getMandateAddress(MAJOR, MINOR, PATCH, "StatementOfIntent"),
                config: abi.encode(inputParams),
                conditions: conditions
            })
        );
        delete conditions;
        uint16 proposeActionId = mandateCount;

        // Veto (isolated: needFulfilled only)
        mandateCount++;
        conditions.allowedRole = 0; // = Admin
        conditions.needFulfilled = proposeActionId;
        constitution.push(
            PowersTypes.MandateInitData({
                nameDescription: "Veto Action: Admin vetoes a proposed action before the timelock expires.",
                targetMandate: registry.getMandateAddress(MAJOR, MINOR, PATCH, "StatementOfIntent"),
                config: abi.encode(inputParams),
                conditions: conditions
            })
        );
        delete conditions;
        uint16 vetoActionId = mandateCount;

        // Execute (needFulfilled + needNotFulfilled + timelock; timelock > propose's votingPeriod)
        mandateCount++;
        conditions.allowedRole = 2; // = Council
        conditions.needFulfilled = proposeActionId;
        conditions.needNotFulfilled = vetoActionId;
        conditions.timelock = minutesToBlocks(20, helperConfig.getBlocksPerHour(block.chainid));
        constitution.push(
            PowersTypes.MandateInitData({
                nameDescription: "Execute Action: Council executes an action that was proposed and not vetoed.",
                targetMandate: registry.getMandateAddress(MAJOR, MINOR, PATCH, "OpenAction"),
                config: abi.encode(), // empty config — OpenAction takes targets/values/calldatas directly
                conditions: conditions
            })
        );
        delete conditions;

        ////////////////////////////////////////////////////////////////////////
        //                     FLOW 3: Throttled Action                       //
        // Exercises `throttleExecution` alone — public, no vote, no          //
        // dependency on any other mandate.                                   //
        ////////////////////////////////////////////////////////////////////////
        {
            uint16[] memory flow3Ids = new uint16[](1);
            flow3Ids[0] = mandateCount + 1;
            flows.push(
                PowersTypes.Flow({
                    mandateIds: flow3Ids,
                    nameDescription: "Flow 3: Throttled Action. Anyone can call it, but only once per cooldown window."
                })
            );
        }

        inputParams = new string[](1);
        inputParams[0] = "uint256 Value";

        mandateCount++;
        conditions.allowedRole = type(uint256).max; // = public role
        conditions.throttleExecution = minutesToBlocks(10, helperConfig.getBlocksPerHour(block.chainid));
        constitution.push(
            PowersTypes.MandateInitData({
                nameDescription: "Throttled Call: Anyone can call this, but only once per 10-minute cooldown window.",
                targetMandate: registry.getMandateAddress(MAJOR, MINOR, PATCH, "BespokeAction_Simple"),
                config: abi.encode(address(returnDataMock), ReturnDataMock.consume.selector, inputParams),
                conditions: conditions
            })
        );
        delete conditions;

        ////////////////////////////////////////////////////////////////////////
        //                   FLOW 4: Account Abstraction                      //
        // Reuses StatementOfIntent / PresetActions / BespokeAction_Simple —  //
        // no new mandate type or condition field, just the gasless UX.       //
        ////////////////////////////////////////////////////////////////////////
        {
            uint16[] memory flow4Ids = new uint16[](4);
            flow4Ids[0] = mandateCount + 1;
            flow4Ids[1] = mandateCount + 2;
            flow4Ids[2] = mandateCount + 3;
            flow4Ids[3] = mandateCount + 4;
            flows.push(
                PowersTypes.Flow({
                    mandateIds: flow4Ids,
                    nameDescription: "Flow 4: Account Abstraction. Admin proposes and executes funding/withdrawal of the PowersPaymaster."
                })
            );
        }

        // Propose to fund paymaster
        mandateCount++;
        conditions.allowedRole = 0; // = Admin
        conditions.votingPeriod = minutesToBlocks(5, helperConfig.getBlocksPerHour(block.chainid));
        conditions.quorum = 20;
        conditions.succeedAt = 51;
        constitution.push(
            PowersTypes.MandateInitData({
                nameDescription: "Propose to Fund Paymaster: Admin proposes an ETH top-up of the PowersPaymaster.",
                targetMandate: registry.getMandateAddress(MAJOR, MINOR, PATCH, "StatementOfIntent"),
                config: abi.encode(),
                conditions: conditions
            })
        );
        delete conditions;
        uint16 proposeFundId = mandateCount;

        // Execute fund paymaster
        targets = new address[](1);
        values = new uint256[](1);
        calldatas = new bytes[](1);
        targets[0] = address(powersPaymaster);
        values[0] = 0.05 ether;
        calldatas[0] = abi.encodeWithSignature("deposit()");

        mandateCount++;
        conditions.allowedRole = 0; // = Admin
        conditions.needFulfilled = proposeFundId;
        constitution.push(
            PowersTypes.MandateInitData({
                nameDescription: "Execute Fund Paymaster: Send 0.05 ETH to the paymaster.",
                targetMandate: registry.getMandateAddress(MAJOR, MINOR, PATCH, "PresetActions"),
                config: abi.encode(targets, values, calldatas),
                conditions: conditions
            })
        );
        delete conditions;

        // Propose to withdraw from paymaster
        string[] memory withdrawParams = new string[](2);
        withdrawParams[0] = "address withdrawAddress";
        withdrawParams[1] = "uint256 amount";

        mandateCount++;
        conditions.allowedRole = 0; // = Admin
        conditions.votingPeriod = minutesToBlocks(5, helperConfig.getBlocksPerHour(block.chainid));
        conditions.quorum = 20;
        conditions.succeedAt = 51;
        constitution.push(
            PowersTypes.MandateInitData({
                nameDescription: "Propose to Withdraw from Paymaster: Admin proposes withdrawing ETH from the paymaster.",
                targetMandate: registry.getMandateAddress(MAJOR, MINOR, PATCH, "StatementOfIntent"),
                config: abi.encode(withdrawParams),
                conditions: conditions
            })
        );
        delete conditions;
        uint16 proposeWithdrawId = mandateCount;

        // Execute withdraw from paymaster
        mandateCount++;
        conditions.allowedRole = 0; // = Admin
        conditions.needFulfilled = proposeWithdrawId;
        constitution.push(
            PowersTypes.MandateInitData({
                nameDescription: "Execute Withdraw from Paymaster: Withdraw approved ETH amount from the paymaster.",
                targetMandate: registry.getMandateAddress(MAJOR, MINOR, PATCH, "BespokeAction_Simple"),
                config: abi.encode(
                    address(powersPaymaster), bytes4(keccak256("withdrawTo(address,uint256)")), withdrawParams
                ),
                conditions: conditions
            })
        );
        delete conditions;

        return constitution.length;
    }
}
