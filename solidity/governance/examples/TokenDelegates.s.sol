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
import { Nominees } from "@src/core/helpers/Nominees.sol";
import { SimpleErc20Votes } from "../../test/mocks/SimpleErc20Votes.sol";

/// @title Token Delegates Deployment Script
contract Deploy is DeployHelpers {
    Configurations helperConfig; 
    PowersTypes.MandateInitData[] constitution;
    PowersTypes.Conditions conditions;
    Powers powers;
    PowersTypes.Flow[] flows;
    Nominees nominees;
    SimpleErc20Votes simpleErc20Votes;
    IMandateRegistry registry;

    address[] targets;
    uint256[] values;
    bytes[] calldatas;
    string[] dynamicParams;

    // Select version mandates to be used.
    uint16 constant MAJOR = 0;
    uint16 constant MINOR = 1;
    uint16 constant PATCH = 9;

    function run() external {
        // step 0, setup.  
        helperConfig = new Configurations(); 
        registry = IMandateRegistry(helperConfig.getMandateRegistry(block.chainid));

        // step 1: deploy Token Delegates Powers
        vm.startBroadcast();
        nominees = new Nominees();
        simpleErc20Votes = new SimpleErc20Votes();
        powers = new Powers(
            "Token Delegates", // name
            "https://aqua-famous-sailfish-288.mypinata.cloud/ipfs/bafybeiecp4sftsohsmaqqnzojxu5qlhs44qzhfb3ym7qoyormx36v2a77q/tokenDelegates.json", // uri
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

        // step 3: transfer ownership and run constitute.
        vm.startBroadcast();
        powers.constitute(constitution);
        powers.closeConstitute(msg.sender, flows);
        vm.stopBroadcast();
        console2.log("Powers successfully constituted.");
    }

    function createConstitution() internal returns (uint256 constitutionLength) {
        uint16 mandateCount = 0;
        // Mandate 1: Initial Setup
        targets = new address[](6);
        values = new uint256[](6);
        calldatas = new bytes[](6);
        for (uint256 i = 0; i < targets.length; i++) {
            targets[i] = address(powers);
        }
        calldatas[0] = abi.encodeWithSelector(IPowers.labelRole.selector, 0, "Admin", "");  
        calldatas[1] = abi.encodeWithSelector(IPowers.labelRole.selector, type(uint256).max, "Public", ""); 
        calldatas[2] = abi.encodeWithSelector(IPowers.labelRole.selector, 1, "Voters", ""); 
        calldatas[3] = abi.encodeWithSelector(IPowers.labelRole.selector, 2, "Delegates", ""); 
        calldatas[4] = abi.encodeWithSelector(IPowers.setTreasury.selector, address(powers));
        calldatas[5] = abi.encodeWithSelector(IPowers.revokeMandate.selector, mandateCount + 1); // revoke mandate 1 after use.

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
        
        /// FLOW: Electing Delegates /// 
        uint16[] memory mandateIds = new uint16[](2); 
        mandateIds[0] = mandateCount + 1;
        mandateIds[1] = mandateCount + 2; 

        flows.push(PowersTypes.Flow({
            mandateIds: mandateIds,
            nameDescription: "Electing Delegates: A governance flow that allows anyone to nominate themselves for a delegate role and to call a delegate election."
        }));

        // Mandate 2: Nominate for Delegates
        mandateCount++;
        conditions.allowedRole = 1; // = Voters
        constitution.push(
            PowersTypes.MandateInitData({
                nameDescription: "Nominate for Delegates: Members can nominate themselves for the Token Delegate role.",
                targetMandate: registry.getMandateAddress(MAJOR, MINOR, PATCH, "Nominate"),
                config: abi.encode(address(nominees)),
                conditions: conditions
            })
        );
        delete conditions;

        // Mandate 3: Elect Delegates
        mandateCount++;
        conditions.allowedRole = type(uint256).max; // = Public Role
        conditions.throttleExecution = minutesToBlocks(10, helperConfig.getBlocksPerHour(block.chainid)); // = 10 minutes approx
        constitution.push(
            PowersTypes.MandateInitData({
                nameDescription: "Elect Delegates: Run the election for delegates. In this demo, the top 3 nominees by token delegation of token VOTES_TOKEN become Delegates.",
                targetMandate: registry.getMandateAddress(MAJOR, MINOR, PATCH, "DelegateTokenSelect"),
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

        /// DEMO ONLY: ADMIN ASSIGNS ANY ROLE FLOW ///
        mandateIds = new uint16[](2); 
        mandateIds[0] = mandateCount + 1;
        mandateIds[1] = mandateCount + 2; 

        flows.push(PowersTypes.Flow({
            mandateIds: mandateIds,
            nameDescription: "Assign any role: For demo purposes, this flow allows the admin to assign any role and delegates to revoke roles."
        }));

        // Mandate 4: Admin assign role
        dynamicParams = new string[](2);
        dynamicParams[0] = "uint256 roleId";
        dynamicParams[1] = "address account";

        mandateCount++;
        conditions.allowedRole = 0; // = Admin
        constitution.push(
            PowersTypes.MandateInitData({
                nameDescription: "Admin can assign any role: For this demo, the admin can assign any role to an account.",
                targetMandate: registry.getMandateAddress(MAJOR, MINOR, PATCH, "BespokeAction_Simple"),
                config: abi.encode(address(powers), IPowers.assignRole.selector, dynamicParams),
                conditions: conditions
            })
        );
        delete conditions;

        // Mandate 5: Delegate revoke role
        mandateCount++;
        conditions.allowedRole = 2; // = Delegates
        conditions.needFulfilled = mandateCount - 1; // = Mandate 4 (Admin assign role)
        constitution.push(
            PowersTypes.MandateInitData({
                nameDescription: "A delegate can revoke a role: For this demo, any delegate can revoke previously assigned roles.",
                targetMandate: registry.getMandateAddress(MAJOR, MINOR, PATCH, "BespokeAction_Simple"),
                config: abi.encode(address(powers), IPowers.revokeRole.selector, dynamicParams),
                conditions: conditions
            })
        );
        delete conditions;

        return constitution.length;
    }
}
