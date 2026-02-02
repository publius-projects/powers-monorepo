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

/// @title TestRig Deployment Script
contract TestRig is DeploySetup {
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

        // step 1: deploy TestRig Powers
        vm.startBroadcast();
        powers = new Powers(
            "TestRig", // name
            "https://aqua-famous-sailfish-288.mypinata.cloud/ipfs/bafkreidlcgxe2mnwghrk4o5xenybljieurrxhtio6gq5fq5u6lxduyyl6e", // uri
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
        // Mandate 1: Statement of Intent with one boolean 
        inputParams = new string[](1);
        inputParams[0] = "bool SingleBoolean";

        conditions.allowedRole = type(uint256).max; // = Public role (Anyone)
        constitution.push(
            PowersTypes.MandateInitData({
                nameDescription: "Single Bool: Testing Statement of Intent with a single boolean parameter.",
                targetMandate: initialisePowers.getInitialisedAddress("StatementOfIntent"),
                config: abi.encode(inputParams),
                conditions: conditions
            })
        );
        delete conditions;

        // Mandate 2: Statement of Intent with three singles booleans
        inputParams = new string[](3);
        inputParams[0] = "bool BooleanOne";
        inputParams[1] = "bool BooleanTwo";
        inputParams[2] = "bool BooleanThree";

        conditions.allowedRole = type(uint256).max; // = Public role (Anyone)
        constitution.push(
            PowersTypes.MandateInitData({
                nameDescription: "Multiple Bools: Testing Statement of Intent with three boolean parameters.",
                targetMandate: initialisePowers.getInitialisedAddress("StatementOfIntent"),
                config: abi.encode(inputParams),
                conditions: conditions
            })
        );
        delete conditions;

        // Mandate 3: Statement of Intent with an array of booleans
        inputParams = new string[](1);
        inputParams[0] = "bool[] BooleanArray";

        conditions.allowedRole = type(uint256).max; // = Public role (Anyone)
        constitution.push(
            PowersTypes.MandateInitData({
                nameDescription: "Boolean Array: Testing Statement of Intent with an array of boolean parameters.",
                targetMandate: initialisePowers.getInitialisedAddress("StatementOfIntent"),
                config: abi.encode(inputParams),
                conditions: conditions
            })
        );
        delete conditions;

        return constitution.length;
    }
}
