// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

// scripts
import { Script } from "forge-std/Script.sol";
import { console2 } from "forge-std/console2.sol";
import { Configurations } from "@script/Configurations.s.sol";
import { InitialisePowers } from "@script/InitialisePowers.s.sol";
import { DeploySetup } from "./DeploySetup.s.sol";

// external protocols
import { Create2 } from "@openzeppelin/contracts/utils/Create2.sol";

// powers contracts
import { PowersTypes } from "@src/interfaces/PowersTypes.sol";
import { Powers } from "@src/Powers.sol";
import { IPowers } from "@src/interfaces/IPowers.sol";

/// @title Optimistic Execution Deployment Script
contract OptimisticExecution is DeploySetup {
    Configurations helperConfig;
    Configurations.NetworkConfig public config;
    PowersTypes.MandateInitData[] constitution;
    InitialisePowers initialisePowers;
    PowersTypes.Conditions conditions;
    Powers powers;

    address[] targets;
    uint256[] values;
    bytes[] calldatas;
    string[] inputParams;
    string[] dynamicParams;

    function run() external {
        // step 0, setup.
        initialisePowers = new InitialisePowers();
        initialisePowers.run();
        helperConfig = new Configurations();
        config = helperConfig.getConfig();

        // step 1: deploy Optimistic Execution Powers

        vm.startBroadcast();
        powers = new Powers(
            "Optimistic Execution", // name
            "https://aqua-famous-sailfish-288.mypinata.cloud/ipfs/bafkreibzf5td4orxnfknmrz5giiifw4ltsbzciaam7izm6dok5pkm6aqqa", // uri
            config.maxCallDataLength, // max call data length
            config.maxReturnDataLength, // max return data length
            config.maxExecutionsLength // max executions length
        );
        vm.stopBroadcast();
        console2.log("Powers deployed at:", address(powers));

        // step 2: create constitution
        uint256 constitutionLength = createConstitution();
        console2.log("Constitution created with length:");
        console2.logUint(constitutionLength);

        // step 3: run constitute.
        vm.startBroadcast();
        powers.constitute(constitution);
        powers.closeConstitute();
        vm.stopBroadcast();
        console2.log("Powers successfully constituted.");
    }

    function createConstitution() internal returns (uint256 constitutionLength) {
        uint16 mandateCount = 0;
        // Mandate 1: Initial Setup
        targets = new address[](3);
        values = new uint256[](3);
        calldatas = new bytes[](3);
        for (uint256 i = 0; i < targets.length; i++) {
            targets[i] = address(powers);
        }
        calldatas[0] = abi.encodeWithSelector(IPowers.labelRole.selector, 1, "Members");
        calldatas[1] = abi.encodeWithSelector(IPowers.labelRole.selector, 2, "Executives");
        calldatas[2] = abi.encodeWithSelector(IPowers.revokeMandate.selector, mandateCount + 1); // revoke mandate 1 after use.

        mandateCount++;
        conditions.allowedRole = 0; // = admin.
        constitution.push(
            PowersTypes.MandateInitData({
                nameDescription: "Initial Setup: Assign role labels (Members, Executives) and revokes itself after execution",
                targetMandate: initialisePowers.getInitialisedAddress("PresetActions_Single"),
                config: abi.encode(targets, values, calldatas),
                conditions: conditions
            })
        );
        delete conditions;

        // Mandate 2: Veto Actions (StatementOfIntent)
        inputParams = new string[](3);
        inputParams[0] = "address[] targets";
        inputParams[1] = "uint256[] values";
        inputParams[2] = "bytes[] calldatas";

        mandateCount++;
        conditions.allowedRole = 1; // = Members
        conditions.votingPeriod = minutesToBlocks(5, config.BLOCKS_PER_HOUR); // = 5 minutes approx
        conditions.succeedAt = 66; // = 66% majority (high threshold)
        conditions.quorum = 66; // = 66% quorum (high quorum)
        constitution.push(
            PowersTypes.MandateInitData({
                nameDescription: "Veto Actions: Funders can veto actions",
                targetMandate: initialisePowers.getInitialisedAddress("StatementOfIntent"),
                config: abi.encode(inputParams),
                conditions: conditions
            })
        );
        delete conditions;

        // Mandate 3: Execute an action (OpenAction)
        mandateCount++;
        conditions.allowedRole = 2; // = Executives
        conditions.votingPeriod = minutesToBlocks(5, config.BLOCKS_PER_HOUR);
        conditions.succeedAt = 51;
        conditions.needNotFulfilled = mandateCount - 1; // = Mandate 2 (Veto Actions)
        conditions.quorum = 33;
        constitution.push(
            PowersTypes.MandateInitData({
                nameDescription: "Execute an action: Members propose adopting new mandates",
                targetMandate: initialisePowers.getInitialisedAddress("OpenAction"),
                config: abi.encode(), // empty config
                conditions: conditions
            })
        );
        delete conditions;

        // Mandate 4: Admin assign role (BespokeAction_Simple)
        dynamicParams = new string[](2);
        dynamicParams[0] = "uint256 roleId";
        dynamicParams[1] = "address account";

        mandateCount++;
        conditions.allowedRole = 0; // = Admin
        constitution.push(
            PowersTypes.MandateInitData({
                nameDescription: "Admin can assign any role: For this demo, the admin can assign any role to an account.",
                targetMandate: initialisePowers.getInitialisedAddress("BespokeAction_Simple"),
                config: abi.encode(address(powers), IPowers.assignRole.selector, dynamicParams),
                conditions: conditions
            })
        );
        delete conditions;

        // Mandate 5: Delegate revoke role (BespokeAction_Simple)
        mandateCount++;
        conditions.allowedRole = 2; // = Executives
        conditions.needFulfilled = mandateCount - 1; // = Mandate 4 (Admin assign role)
        constitution.push(
            PowersTypes.MandateInitData({
                nameDescription: "A delegate can revoke a role: For this demo, any delegate can revoke previously assigned roles.",
                targetMandate: initialisePowers.getInitialisedAddress("BespokeAction_Simple"),
                config: abi.encode(address(powers), IPowers.revokeRole.selector, dynamicParams),
                conditions: conditions
            })
        );
        delete conditions;

        return constitution.length;
    }
}
