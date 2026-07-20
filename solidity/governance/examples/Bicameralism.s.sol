// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

// scripts
import { Script } from "forge-std/Script.sol";
import { console2 } from "forge-std/console2.sol";
import { Configurations } from "@script/Configurations.s.sol"; 
import { DeployHelpers } from "../DeployHelpers.s.sol";
import { IMandateRegistry } from "@src/core/helpers/MandateRegistry.sol";

// external protocols
import { Create2 } from "@lib/openzeppelin-contracts/contracts/utils/Create2.sol";

// powers contracts
import { PowersTypes } from "@src/interfaces/PowersTypes.sol";
import { Powers } from "@src/Powers.sol";
import { IPowers } from "@src/interfaces/IPowers.sol";

/// @title Bicameralism Deployment Script
contract Deploy is DeployHelpers {
    Configurations helperConfig;
    PowersTypes.MandateInitData[] constitution;
    PowersTypes.Conditions conditions;
    PowersTypes.Flow[] flows;
    Powers powers;
    IMandateRegistry registry;

    address[] targets;
    uint256[] values;
    bytes[] calldatas;
    string[] inputParams;
    string[] dynamicParams;

    // Select version mandates to be used.
    uint16 constant MAJOR = 0;
    uint16 constant MINOR = 1;
    uint16 constant PATCH = 9;

    function run() external returns (Powers) {
        // step 0, setup. 
        helperConfig = new Configurations();
        registry = IMandateRegistry(helperConfig.getMandateRegistry(block.chainid));

        // step 1: deploy Bicameralism Powers
        vm.startBroadcast();
        powers = new Powers(
            "Bicameralism", // name 
            "https://aqua-famous-sailfish-288.mypinata.cloud/ipfs/bafybeiecp4sftsohsmaqqnzojxu5qlhs44qzhfb3ym7qoyormx36v2a77q/bicameralism.json", // uri
            helperConfig.getMaxCallDataLength(block.chainid), // max call data length
            helperConfig.getMaxReturnDataLength(block.chainid), // max return data length
            helperConfig.getMaxExecutionsLength(block.chainid), // max executions length
            address(registry)
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
        powers.closeConstitute(msg.sender, flows);
        vm.stopBroadcast();
        console2.log("Powers successfully constituted.");

        return powers;
    }

    function createConstitution() internal returns (uint256 constitutionLength) {
        uint16 mandateCount = 0;
        // Initial Setup
        targets = new address[](5);
        values = new uint256[](5);
        calldatas = new bytes[](5);
        for (uint256 i = 0; i < targets.length; i++) {
            targets[i] = address(powers);
        }
        calldatas[0] = abi.encodeWithSelector(IPowers.labelRole.selector, 0, "Admin", "");  
        calldatas[1] = abi.encodeWithSelector(IPowers.labelRole.selector, type(uint256).max, "Public", ""); 
        calldatas[2] = abi.encodeWithSelector(IPowers.labelRole.selector, 1, "Delegates", "");  
        calldatas[3] = abi.encodeWithSelector(IPowers.labelRole.selector, 2, "Funders", ""); 
        calldatas[4] = abi.encodeWithSelector(IPowers.revokeMandate.selector, mandateCount + 1); // revoke mandate 1 after use.

        mandateCount++;
        conditions.allowedRole = type(uint256).max; // = public.
        constitution.push(
            PowersTypes.MandateInitData({
                nameDescription: "Initial Setup: Assign role labels and revokes itself after execution",
                targetMandate: registry.getMandateAddress(MAJOR, MINOR, PATCH, "PresetActions"),
                config: abi.encode(targets, values, calldatas),
                conditions: conditions
            })
        );
        delete conditions;

        // BICAMERALISM FLOW // 
        uint16[] memory mandateIds = new uint16[](2);
        mandateIds[0] = mandateCount + 1;
        mandateIds[1] = mandateCount + 2;

        flows.push(PowersTypes.Flow({
            nameDescription: "Bicameralism flow: Delegates can propose actions, but Funders have veto power. Both Delegates and Funders must approve for an action to be executed.",
            mandateIds: mandateIds
        }));

        // Initiate action (StatementOfIntent)
        inputParams = new string[](3);
        inputParams[0] = "address[] targets";
        inputParams[1] = "uint256[] values";
        inputParams[2] = "bytes[] calldatas";

        mandateCount++;
        conditions.allowedRole = 1; // = Delegates
        conditions.votingPeriod = minutesToBlocks(5, helperConfig.getBlocksPerHour(block.chainid)); // = 5 minutes approx (depends on block time, 300 is ~5 mins on 1s chain, 1h on 12s)
        conditions.succeedAt = 51; // = 51% majority
        conditions.quorum = 33; // = 33% quorum
        constitution.push(
            PowersTypes.MandateInitData({
                nameDescription: "Initiate action: Delegates can initiate an action",
                targetMandate: registry.getMandateAddress(MAJOR, MINOR, PATCH, "StatementOfIntent"),
                config: abi.encode(inputParams),
                conditions: conditions
            })
        );
        delete conditions;

        // Execute action (OpenAction)
        mandateCount++;
        conditions.allowedRole = 2; // = Funders
        conditions.votingPeriod = minutesToBlocks(5, helperConfig.getBlocksPerHour(block.chainid));
        conditions.succeedAt = 51;
        conditions.needFulfilled = mandateCount - 1; // = Mandate 2 (Initiate action)
        conditions.quorum = 33;
        constitution.push(
            PowersTypes.MandateInitData({
                nameDescription: "Execute an action: Funders can execute an action.",
                targetMandate: registry.getMandateAddress(MAJOR, MINOR, PATCH, "OpenAction"),
                config: abi.encode(), // empty config
                conditions: conditions
            })
        );
        delete conditions;

        /// DEMO ONLY: ADMIN ASSIGNS ANY ROLE FLOW ///
        mandateIds = new uint16[](2); 
        mandateIds[0] = mandateCount + 1;
        mandateIds[1] = mandateCount + 2; 

        flows.push(PowersTypes.Flow({
            mandateIds: mandateIds,
            nameDescription: "Assign any role: For demo purposes, this flow allows the admin to assign any role and delegates to revoke roles."
        }));

        // Admin assign role (BespokeAction_Simple)
        dynamicParams = new string[](2);
        dynamicParams[0] = "uint256 roleId";
        dynamicParams[1] = "address account";

        mandateCount++;
        conditions.allowedRole = 0; // = Admin
        constitution.push(
            PowersTypes.MandateInitData({
                nameDescription: "Admin can assign any role: For this demo, the admin can assign any role to an account.",
                targetMandate: registry.getMandateAddress(MAJOR, MINOR, PATCH, "BespokeAction_Simple"),
                config: abi.encode(address(0), IPowers.assignRole.selector, dynamicParams),
                conditions: conditions
            })
        );
        delete conditions;

        // Delegate revoke role (BespokeAction_Simple) 
        mandateCount++;
        conditions.allowedRole = 1; // = Delegates
        conditions.needFulfilled = mandateCount - 1; // = Mandate 4 (Admin assign role)
        constitution.push(
            PowersTypes.MandateInitData({
                nameDescription: "A delegate can revoke a role: For this demo, any delegate can revoke previously assigned roles.",
                targetMandate: registry.getMandateAddress(MAJOR, MINOR, PATCH, "BespokeAction_Simple"),
                config: abi.encode(address(0), IPowers.revokeRole.selector, dynamicParams),
                conditions: conditions
            })
        );
        delete conditions;

        return constitution.length;
    }
}
