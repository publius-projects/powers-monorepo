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

// helpers
import { ElectionList } from "@src/helpers/ElectionList.sol";

/// @title Open Elections Deployment Script
contract ElectionListsDAO is DeploySetup {
    Configurations helperConfig;
    Configurations.NetworkConfig public config;
    PowersTypes.MandateInitData[] constitution;
    InitialisePowers initialisePowers;
    PowersTypes.Conditions conditions;
    Powers powers;

    ElectionList openElection;

    address[] targets;
    uint256[] values;
    bytes[] calldatas;
    string[] dynamicParams;

    function run() external returns (Powers, ElectionList) {
        // step 0, setup.
        initialisePowers = new InitialisePowers();
        initialisePowers.run();
        helperConfig = new Configurations();
        config = helperConfig.getConfig();

        // step 1: deploy Open Elections Powers
        vm.startBroadcast();
        openElection = new ElectionList();
        powers = new Powers(
            "Open Elections", // name
            "https://aqua-famous-sailfish-288.mypinata.cloud/ipfs/bafkreiaaprfqxtgyxa5v2dnf7edfbc3mxewdh4axf4qtkurpz66jh2f2ve", // uri
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

        return (powers, openElection);
    }

    function createConstitution() internal returns (uint256 constitutionLength) {
        // Mandate 1: Initial Setup
        targets = new address[](3);
        values = new uint256[](3);
        calldatas = new bytes[](3);
        for (uint256 i = 0; i < targets.length; i++) {
            targets[i] = address(powers);
        }
        calldatas[0] = abi.encodeWithSelector(IPowers.labelRole.selector, 1, "Voters");
        calldatas[1] = abi.encodeWithSelector(IPowers.labelRole.selector, 2, "Delegates");
        calldatas[2] = abi.encodeWithSelector(IPowers.revokeMandate.selector, 1); // revoke mandate 1 after use.

        conditions.allowedRole = 0; // = admin.
        constitution.push(
            PowersTypes.MandateInitData({
                nameDescription: "Initial Setup: Assign role labels (Delegates, Funders) and revokes itself after execution",
                targetMandate: initialisePowers.getInitialisedAddress("PresetActions_Single"),
                config: abi.encode(targets, values, calldatas),
                conditions: conditions
            })
        );
        delete conditions;

        // Mandate 2: Nominate for Delegates
        conditions.allowedRole = 1; // = Voters
        constitution.push(
            PowersTypes.MandateInitData({
                nameDescription: "Nominate for Delegates: Members can nominate themselves for the Token Delegate role.",
                targetMandate: initialisePowers.getInitialisedAddress("Nominate"),
                config: abi.encode(address(openElection)),
                conditions: conditions
            })
        );
        delete conditions;

        // Mandate 3: Start an election
        conditions.allowedRole = 1; // = Voters
        constitution.push(
            PowersTypes.MandateInitData({
                nameDescription: "Start an election: an election can be initiated be voters once every 2 hours. The election will last 10 minutes.",
                targetMandate: initialisePowers.getInitialisedAddress("ElectionList_Create"),
                config: abi.encode(
                    address(openElection),
                    initialisePowers.getInitialisedAddress("ElectionList_Vote"), // Vote mandate address
                    minutesToBlocks(10, config.BLOCKS_PER_HOUR), // 10 minutes in blocks (approx)
                    1 // Voter role id
                ),
                conditions: conditions
            })
        );
        delete conditions;

        // Mandate 4: End and Tally elections
        conditions.allowedRole = 1; // = Voters
        conditions.needFulfilled = 3; // = Mandate 3 (Start election)
        constitution.push(
            PowersTypes.MandateInitData({
                nameDescription: "End and Tally elections: After an election has finished, assign the Delegate role to the winners.",
                targetMandate: initialisePowers.getInitialisedAddress("ElectionList_Tally"),
                config: abi.encode(
                    address(openElection),
                    2, // RoleId for Delegates
                    5 // Max role holders
                ),
                conditions: conditions
            })
        );
        delete conditions;

        // Mandate 5: Admin assign role
        dynamicParams = new string[](2);
        dynamicParams[0] = "uint256 roleId";
        dynamicParams[1] = "address account";

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

        // Mandate 6: Delegate revoke role
        conditions.allowedRole = 2; // = Delegates
        conditions.needFulfilled = 5; // = Mandate 5 (Admin assign role)
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
