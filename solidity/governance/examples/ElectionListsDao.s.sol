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

// helpers
import { ElectionRegistry } from "@src/core/helpers/ElectionRegistry.sol";

/// @title Open Elections Deployment Script
contract Deploy is DeployHelpers {
    Configurations helperConfig; 
    IMandateRegistry registry;
    PowersTypes.MandateInitData[] constitution;
    PowersTypes.Flow[] flows; 
    PowersTypes.Conditions conditions;
    Powers powers;

    ElectionRegistry openElection;

    address[] targets;
    uint256[] values;
    bytes[] calldatas;
    string[] dynamicParams;

    // Select version mandates to be used.
    uint16 constant MAJOR = 0;
    uint16 constant MINOR = 1;
    uint16 constant PATCH = 9;

    function run() external returns (Powers, ElectionRegistry) { 
        helperConfig = new Configurations(); 
        registry = IMandateRegistry(helperConfig.getMandateRegistry(block.chainid));

        // step 1: deploy Open Elections Powers
        vm.startBroadcast();
        openElection = new ElectionRegistry(minutesToBlocks(5, helperConfig.getBlocksPerHour(block.chainid)), minutesToBlocks(5, helperConfig.getBlocksPerHour(block.chainid))); // nomination duration: 1 hour, vote duration: 2 hours
        powers = new Powers(
            "Open Election", // name
            "https://aqua-famous-sailfish-288.mypinata.cloud/ipfs/bafybeiecp4sftsohsmaqqnzojxu5qlhs44qzhfb3ym7qoyormx36v2a77q/electionListDao.json", // uri
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

        return (powers, openElection);
    }

    function createConstitution() internal returns (uint256 constitutionLength) {
        uint16 mandateCount = 0;
        // Mandate 1: Initial Setup
        targets = new address[](5);
        values = new uint256[](5);
        calldatas = new bytes[](5);
        for (uint256 i = 0; i < targets.length; i++) {
            targets[i] = address(powers);
        }
        calldatas[0] = abi.encodeWithSelector(IPowers.labelRole.selector, 0, "Admin", "");  
        calldatas[1] = abi.encodeWithSelector(IPowers.labelRole.selector, type(uint256).max, "Public", ""); 
        calldatas[2] = abi.encodeWithSelector(IPowers.labelRole.selector, 1, "Voters", ""); 
        calldatas[3] = abi.encodeWithSelector(IPowers.labelRole.selector, 2, "Delegates", ""); // .
        calldatas[4] = abi.encodeWithSelector(IPowers.revokeMandate.selector, mandateCount + 1); // revoke mandate 1 after use.

        mandateCount++;
        conditions.allowedRole = 0; // = admin.
        constitution.push(
            PowersTypes.MandateInitData({
                nameDescription: "Initial Setup: Assign role labels and revokes itself after execution",
                targetMandate: registry.getMandateAddress(MAJOR, MINOR, PATCH, "PresetActions"),
                config: abi.encode(targets, values, calldatas),
                conditions: conditions
            })
        );
        delete conditions;

        // ELECTION FLOW //
        uint16[] memory mandateIds = new uint16[](4); 
        mandateIds[0] = mandateCount + 1;
        mandateIds[1] = mandateCount + 2;
        mandateIds[2] = mandateCount + 3;
        mandateIds[3] = mandateCount + 4; 

        flows.push(PowersTypes.Flow({
            mandateIds: mandateIds,
            nameDescription: "Election flow: A flow that allows voters to create elections, open votes and tally results."
        }));
        
        // Members: create election
        string[] memory inputParams = new string[](3);
        inputParams[0] = "string Title";
        inputParams[1] = "uint48 StartBlock";
        inputParams[2] = "uint48 EndBlock";

        mandateCount++;
        conditions.allowedRole = 1; // = Voters
        conditions.throttleExecution = minutesToBlocks(120, helperConfig.getBlocksPerHour(block.chainid)); // = once every 2 hours
        constitution.push(
            PowersTypes.MandateInitData({
                nameDescription: "Create an election: an election can be initiated be any voter.",
                targetMandate: registry.getMandateAddress(MAJOR, MINOR, PATCH, "BespokeAction_Simple"),
                config: abi.encode(
                    address(openElection), // election list contract
                    ElectionRegistry.createElection.selector, // selector
                    inputParams
                ),
                conditions: conditions
            })
        );
        delete conditions;

        // Members: Open Vote for election
        mandateCount++;
        conditions.allowedRole = 1; // = Voters
        conditions.needFulfilled = mandateCount - 1; // = Create election
        constitution.push(
            PowersTypes.MandateInitData({
                nameDescription: "Open voting for election: Voters can open the vote for an election. This will create a dedicated vote mandate.",
                targetMandate: registry.getMandateAddress(MAJOR, MINOR, PATCH, "ElectionRegistry_CreateVoteMandate"),
                config: abi.encode(
                    address(openElection), // election list contract
                    registry.getMandateAddress(MAJOR, MINOR, PATCH, "ElectionRegistry_Vote"), // the vote mandate address
                    1, // the max number of votes a voter can cast
                    1 // the role Id allowed to vote (Voters)
                ),
                conditions: conditions
            })
        );
        delete conditions;

        // Members: Tally election
        mandateCount++;
        conditions.allowedRole = 1; // = Voters
        conditions.needFulfilled = mandateCount - 1; // = Open Vote election
        constitution.push(
            PowersTypes.MandateInitData({
                nameDescription: "Tally elections: After an election has finished, assign the Delegate role to the winners.",
                targetMandate: registry.getMandateAddress(MAJOR, MINOR, PATCH, "ElectionRegistry_Tally"),
                config: abi.encode(
                    address(openElection),
                    2, // RoleId for Delegates
                    5 // Max role holders
                ),
                conditions: conditions
            })
        );
        delete conditions;

        // Members: clean up election
        mandateCount++;
        conditions.allowedRole = 1; // = Voters
        conditions.needFulfilled = mandateCount - 1; // = Tally election
        constitution.push(
            PowersTypes.MandateInitData({
                nameDescription: "Clean up election: After an election has finished, clean up related mandates.",
                targetMandate: registry.getMandateAddress(MAJOR, MINOR, PATCH, "BespokeAction_OnReturnValue"),
                config: abi.encode(
                    address(powers), // target contract
                    IPowers.revokeMandate.selector, // function selector to call
                    abi.encode(), // params before
                    inputParams, // dynamic params (the input params of the parent mandate)
                    mandateCount - 2, // parent mandate id (the open vote mandate)
                    abi.encode() // no params after
                ),
                conditions: conditions
            })
        );
        delete conditions;

        // NOMINATION FLOW //
        mandateIds = new uint16[](2);
        mandateIds[0] = mandateCount + 1;
        mandateIds[1] = mandateCount + 2;
        
        flows.push(PowersTypes.Flow({
            mandateIds: mandateIds,
            nameDescription: "Nomination flow: A flow that allows voters to nominate themselves for an election and revoke their nomination."
        }));

        // Members: Nominate for Delegate election
        mandateCount++;
        conditions.allowedRole = 1; // = Voters
        constitution.push(
            PowersTypes.MandateInitData({
                nameDescription: "Nominate for election: any voter can nominate for an election.",
                targetMandate: registry.getMandateAddress(MAJOR, MINOR, PATCH, "ElectionRegistry_Nominate"),
                config: abi.encode(
                    address(openElection), // election list contract
                    true // nominate as candidate
                ),
                conditions: conditions
            })
        );
        delete conditions;

        // Members revoke nomination for Delegate election.
        mandateCount++;
        conditions.allowedRole = 1; // = Voters
        constitution.push(
            PowersTypes.MandateInitData({
                nameDescription: "Revoke nomination for election: any voter can revoke their nomination for an election.",
                targetMandate: registry.getMandateAddress(MAJOR, MINOR, PATCH, "ElectionRegistry_Nominate"),
                config: abi.encode(
                    address(openElection), // election list contract
                    false // revoke nomination
                ),
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
        
        // Mandate: Admin assign role
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

        // Mandate: Delegate revoke role
        mandateCount++;
        conditions.allowedRole = 2; // = Delegates
        conditions.needFulfilled = mandateCount - 1; // = Mandate Admin assign role
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
