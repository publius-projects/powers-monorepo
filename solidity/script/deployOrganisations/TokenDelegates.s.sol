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
import { Nominees } from "@src/helpers/Nominees.sol";
import { SimpleErc20Votes } from "@mocks/SimpleErc20Votes.sol";

/// @title Token Delegates Deployment Script
contract TokenDelegates is DeploySetup {
    Configurations helperConfig;
    Configurations.NetworkConfig public config;
    PowersTypes.MandateInitData[] constitution;
    InitialisePowers initialisePowers;
    PowersTypes.Conditions conditions;
    Powers powers;
    Nominees nominees;
    SimpleErc20Votes simpleErc20Votes;

    address[] targets;
    uint256[] values;
    bytes[] calldatas;
    string[] dynamicParams;

    function run() external {
        // step 0, setup.
        initialisePowers = new InitialisePowers();
        initialisePowers.run();
        helperConfig = new Configurations();
        config = helperConfig.getConfig();

        // step 1: deploy Token Delegates Powers
        vm.startBroadcast();
        nominees = new Nominees();
        simpleErc20Votes = new SimpleErc20Votes();
        powers = new Powers(
            "Token Delegates", // name
            "https://aqua-famous-sailfish-288.mypinata.cloud/ipfs/bafkreicpqpipzetgtcbqdeehcg33ibipvrb3pnikes6oqixa7ntzaniinm", // uri
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

        // step 3: transfer ownership and run constitute.
        vm.startBroadcast();
        powers.constitute(constitution);
        powers.closeConstitute();
        vm.stopBroadcast();
        console2.log("Powers successfully constituted.");
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
                config: abi.encode(address(nominees)),
                conditions: conditions
            })
        );
        delete conditions;

        // Mandate 3: Elect Delegates
        conditions.allowedRole = type(uint256).max; // = Public Role
        conditions.throttleExecution = minutesToBlocks(10, config.BLOCKS_PER_HOUR); // = 10 minutes approx
        constitution.push(
            PowersTypes.MandateInitData({
                nameDescription: "Elect Delegates: Run the election for delegates. In this demo, the top 3 nominees by token delegation of token VOTES_TOKEN become Delegates.",
                targetMandate: initialisePowers.getInitialisedAddress("DelegateTokenSelect"),
                config: abi.encode(
                    address(simpleErc20Votes),
                    address(nominees),
                    2, // RoleId
                    3 // MaxRoleHolders
                ),
                conditions: conditions
            })
        );
        delete conditions;

        // Mandate 4: Admin assign role
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

        // Mandate 5: Delegate revoke role
        conditions.allowedRole = 2; // = Delegates
        conditions.needFulfilled = 4; // = Mandate 4 (Admin assign role)
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
