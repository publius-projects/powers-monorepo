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
import { SafeProxyFactory } from "@lib/safe-smart-account/contracts/proxies/SafeProxyFactory.sol";
import { Safe } from "@lib/safe-smart-account/contracts/Safe.sol";
import { ModuleManager } from "@lib/safe-smart-account/contracts/base/ModuleManager.sol";

// powers contracts
import { PowersTypes } from "@src/interfaces/PowersTypes.sol";
import { Powers } from "@src/Powers.sol";
import { IPowers } from "@src/interfaces/IPowers.sol";

// helpers
import { PowersFactory } from "@src/core/helpers/PowersFactory.sol";
import { PowersDeployer } from "@src/core/helpers/PowersDeployer.sol";

/// @title Nested Governance Deployment Script
contract Deploy is DeployHelpers { 
    Configurations helperConfig; 
    IMandateRegistry registry;
    PowersTypes.Conditions conditions;

    PowersTypes.MandateInitData[] parentConstitution;
    PowersTypes.MandateInitData[] childConstitution;
    PowersTypes.Flow[] parentFlows;
    PowersTypes.Flow[] childFlows;

    Powers powersParent;    
    PowersFactory powersChildFactory;
    
    address treasury;
    address[] targets;
    uint256[] values;
    bytes[] calldatas;
    string[] inputParams;
    string[] dynamicParams;

    uint16 requestAllowanceMandateId; 
    address cedars = vm.envAddress("DEV2_ADDRESS");
    // Select version mandates to be used.
    uint16 constant MAJOR = 0;
    uint16 constant MINOR = 1;
    uint16 constant PATCH = 9;

    function run() external returns (Powers, PowersFactory) { 
        helperConfig = new Configurations();
        registry = IMandateRegistry(helperConfig.getMandateRegistry(block.chainid));

        // step 1: deploy Parent Powers
        vm.startBroadcast();
        powersParent = new Powers(
            "Nested Governance Parent", 
            "https://aqua-famous-sailfish-288.mypinata.cloud/ipfs/bafybeiecp4sftsohsmaqqnzojxu5qlhs44qzhfb3ym7qoyormx36v2a77q/nestedGovernance-parent.json",
            helperConfig.getMaxCallDataLength(block.chainid),
            helperConfig.getMaxReturnDataLength(block.chainid),
            helperConfig.getMaxExecutionsLength(block.chainid),
            address(registry)
        );
        vm.stopBroadcast();
        console2.log("Powers Parent deployed at:", address(powersParent));
        

        // step 2: deploy Child PowersFactory
        vm.startBroadcast();
        PowersDeployer powersDeployer = new PowersDeployer();
        powersChildFactory = new PowersFactory(
            "https://aqua-famous-sailfish-288.mypinata.cloud/ipfs/bafybeiecp4sftsohsmaqqnzojxu5qlhs44qzhfb3ym7qoyormx36v2a77q/nestedGovernance-child.json", 
            helperConfig.getMaxCallDataLength(block.chainid),
            helperConfig.getMaxReturnDataLength(block.chainid),
            helperConfig.getMaxExecutionsLength(block.chainid),
            address(powersDeployer),
            address(registry)
        );
        vm.stopBroadcast();
        console2.log("Powers Child Factory deployed at:", address(powersChildFactory));

        // step 3: setup Safe treasury for Parent
        address[] memory owners = new address[](1);
        owners[0] = address(powersParent);

        vm.startBroadcast();
        treasury = address(
            SafeProxyFactory(helperConfig.getSafeProxyFactory(block.chainid))
                .createProxyWithNonce(
                    helperConfig.getSafeL2Canonical(block.chainid),
                    abi.encodeWithSelector(
                        Safe.setup.selector,
                        owners,
                        1, // threshold
                        address(0), // to
                        "", // data
                        address(0), // fallbackHandler
                        address(0), // paymentToken
                        0, // payment
                        address(0) // paymentReceiver
                    ),
                    block.timestamp // nonce using timestamp to ensure uniqueness
                )
        );
        vm.stopBroadcast();
        console2.log("Safe treasury deployed at:", treasury);

        // step 4: create constitutions
        createParentConstitution();
        console2.log("Number of Mandates:", parentConstitution.length);
        createChildConstitution();
        console2.log("Number of Mandates in Child Factory:", childConstitution.length);

        // step 5: add mandates to factory
        vm.startBroadcast();
        powersChildFactory.addMandates(childConstitution);
        powersChildFactory.addFlows(childFlows);
        vm.stopBroadcast();

        // step 6: constitute Parent
        vm.startBroadcast();
        powersParent.constitute(parentConstitution);
        powersParent.closeConstitute(msg.sender, parentFlows);
        vm.stopBroadcast();
        console2.log("Parent Powers constituted.");

        // step 7: transfer ownership of factory to parent
        vm.startBroadcast();
        powersChildFactory.transferOwnership(address(powersParent));
        vm.stopBroadcast();
        console2.log("Child Factory ownership transferred to Parent.");

        return (powersParent, powersChildFactory);
    }

    function createParentConstitution() internal {
        uint16 mandateCount = 0;
        
        // signature for Safe module enabling call
        bytes memory signature = abi.encodePacked(
            uint256(uint160(address(powersParent))), // r = address of the signer (powers contract)
            uint256(0), // s = 0
            uint8(1) // v = 1 This is a type 1 call. See Safe.sol for details.
        );

        // Mandate 1: Setup
        targets = new address[](7);
        values = new uint256[](7);
        calldatas = new bytes[](7); 
        for (uint256 i = 0; i < targets.length; i++) {
            targets[i] = address(powersParent);
        }
        targets[5] = treasury; 

        calldatas[0] = abi.encodeWithSelector(IPowers.labelRole.selector, 0, "Admin", "");  
        calldatas[1] = abi.encodeWithSelector(IPowers.labelRole.selector, type(uint256).max, "Public", ""); 
        calldatas[2] = abi.encodeWithSelector(IPowers.labelRole.selector, 1, "Executive", "");
        calldatas[3] = abi.encodeWithSelector(IPowers.labelRole.selector, 2, "Child", "");
        calldatas[4] = abi.encodeWithSelector(IPowers.setTreasury.selector, treasury);
        calldatas[5] = abi.encodeWithSelector( 
            Safe.execTransaction.selector,
            treasury, 
            0, 
            abi.encodeWithSelector( 
                ModuleManager.enableModule.selector,
                helperConfig.getSafeAllowanceModule(block.chainid) 
            ),
            0, // operation = Call
            0, // safeTxGas
            0, // baseGas
            0, // gasPrice
            address(0), // gasToken
            address(0), // refundReceiver
            signature // the signature constructed above
        );
        calldatas[6] = abi.encodeWithSelector(IPowers.revokeMandate.selector, mandateCount + 1);

        mandateCount++;
        conditions.allowedRole = type(uint256).max; // anyone can execute this mandate. 
        parentConstitution.push(
            PowersTypes.MandateInitData({
                nameDescription: "Initial Setup: Assign role labels and revokes itself after execution",
                targetMandate: registry.getMandateAddress(MAJOR, MINOR, PATCH, "PresetActions"),
                config: abi.encode(targets, values, calldatas),
                conditions: conditions
            })
        );
        delete conditions;

        // CREATE NEW DAO FLOW // 
        uint16[] memory mandateIds = new uint16[](3); 
        mandateIds[0] = mandateCount + 1;
        mandateIds[1] = mandateCount + 2; 
        mandateIds[2] = mandateCount + 3;

        parentFlows.push(PowersTypes.Flow({
            mandateIds: mandateIds,
            nameDescription: "Create Child DAO: Executives can vote to create a new Child DAO. After its creation, any executive can assign a role Id to this new DAO and add it as a delegate to the treasury's Safe allowance module."
        }));

        // Initiate Child DAO Creation
        inputParams = new string[](2);
        inputParams[0] = "string name";
        inputParams[1] = "address Admin";
        

        // Create Child DAO
        mandateCount++;
        conditions.allowedRole = 1; // Executive
        conditions.quorum = 20; // 20% quorum for demo purposes
        conditions.succeedAt = 51; // >50% to pass
        conditions.votingPeriod = minutesToBlocks(10, helperConfig.getBlocksPerHour(block.chainid)); // 10 min voting period for demo
        parentConstitution.push(
            PowersTypes.MandateInitData({
                nameDescription: "Create Child DAO: Executive can execute creation of Child DAO.",
                targetMandate: registry.getMandateAddress(MAJOR, MINOR, PATCH, "BespokeAction_Simple"),
                config: abi.encode(
                    address(powersChildFactory), 
                    bytes4(0x62b9a9b5), // = keccak256("createPowers(address)")), 
                    inputParams
                ),
                conditions: conditions
            })
        );
        delete conditions;

        // Assign Child Role to new DAO
        mandateCount++;
        conditions.allowedRole = 1; // Executive
        conditions.needFulfilled = mandateCount - 1; // Need creation
        parentConstitution.push(
            PowersTypes.MandateInitData({
                nameDescription: "Assign Child Role: Assign Child role (2) to the new DAO.",
                targetMandate: registry.getMandateAddress(MAJOR, MINOR, PATCH, "BespokeAction_OnReturnValue"),
                config: abi.encode(
                    address(powersParent), 
                    IPowers.assignRole.selector, 
                    abi.encode(2), // roleId 2 (Child)
                    inputParams, 
                    mandateCount - 1, // parent mandate id (create child)
                    abi.encode() 
                ),
                conditions: conditions
            })
        );
        delete conditions;

        // Add Delegate to Allowance Module
        mandateCount++;
        conditions.allowedRole = 1; // Executive
        conditions.needFulfilled = mandateCount - 2; // Need creation (to get address)
        parentConstitution.push(
            PowersTypes.MandateInitData({
                nameDescription: "Add Delegate: Add new Child DAO as delegate to Allowance Module.",
                targetMandate: registry.getMandateAddress(MAJOR, MINOR, PATCH, "Safe_ExecTransaction_OnReturnValue"),
                config: abi.encode(
                    helperConfig.getSafeAllowanceModule(block.chainid), 
                    bytes4(0xe71bdf41), // == AllowanceModule.addDelegate.selector
                    abi.encode(), 
                    inputParams, 
                    mandateCount - 2, // parent mandate id (create child)
                    abi.encode() 
                ),
                conditions: conditions
            })
        );
        delete conditions;

        // REQUEST ALLOWANCE FLOW //
        mandateIds = new uint16[](2); 
        mandateIds[0] = mandateCount + 1;
        mandateIds[1] = mandateCount + 2; 

        parentFlows.push(PowersTypes.Flow({
            mandateIds: mandateIds,
            nameDescription: "Requesting an Allowance: A child DAO can request an allowance from the Safe treasury. Executives can vote to approve or reject the request."
        }));

        // Child can request allowance
        inputParams = new string[](5);
        inputParams[0] = "address Sub-DAO";
        inputParams[1] = "address Token";
        inputParams[2] = "uint96 allowanceAmount";
        inputParams[3] = "uint16 resetTimeMin";
        inputParams[4] = "uint32 resetBaseMin";

        mandateCount++;
        conditions.allowedRole = 2; // Child
        parentConstitution.push(
            PowersTypes.MandateInitData({
                nameDescription: "Request Allowance: Child DAO can request allowance.",
                targetMandate: registry.getMandateAddress(MAJOR, MINOR, PATCH, "StatementOfIntent"),
                config: abi.encode(inputParams),
                conditions: conditions
            })
        );
        delete conditions;
        requestAllowanceMandateId = mandateCount;

        // Executive can set allowance (fulfilling request)
        mandateCount++;
        conditions.allowedRole = 1; // Executive
        conditions.needFulfilled = mandateCount - 1; // Need request
        conditions.quorum = 20; // 50% quorum for voting on Parent to set allowance
        conditions.votingPeriod = minutesToBlocks(5, helperConfig.getBlocksPerHour(block.chainid));
        conditions.succeedAt = 51; // >50% to pass
        parentConstitution.push(
            PowersTypes.MandateInitData({
                nameDescription: "Set Allowance: Executive can set allowance for Child DAO.",
                targetMandate: registry.getMandateAddress(MAJOR, MINOR, PATCH, "SafeAllowance_Action"),
                config: abi.encode(
                    inputParams,
                    bytes4(0xbeaeb388), // == AllowanceModule.setAllowance.selector 
                    helperConfig.getSafeAllowanceModule(block.chainid)
                ),
                conditions: conditions
            })
        );
        delete conditions;

        // VETO TRANSFER AT CHILD DAO //
        mandateIds = new uint16[](1); 
        mandateIds[0] = mandateCount + 1; 

        parentFlows.push(PowersTypes.Flow({
            mandateIds: mandateIds,
            nameDescription: "Veto Child DAO's Token Transfer: Even after an allowance has been granted, a parent organisation can still veto specific token transfers at a child DAO."
        }));

        // Veto Transfer at Child DAO level  
        inputParams = new string[](3);
        inputParams[0] = "address Token";
        inputParams[1] = "uint96 Amount";
        inputParams[2] = "address PayableTo"; 

        mandateCount++;
        conditions.allowedRole = 1; // Members
        conditions.quorum = 20; // 50% quorum for voting on Parent to set allowance
        conditions.votingPeriod = minutesToBlocks(5, helperConfig.getBlocksPerHour(block.chainid));
        conditions.succeedAt = 51; // >50% to pass
        parentConstitution.push(
            PowersTypes.MandateInitData({
                nameDescription: "Veto Transfer at Child: A parent organisation can veto a transfer at a child.",
                targetMandate: registry.getMandateAddress(MAJOR, MINOR, PATCH, "ExternalAction_Flexible"),
                config: abi.encode(inputParams),
                conditions: conditions
            })  
        );
        delete conditions;
 
        /// ADMIN ASSIGN ANY ROLE FLOW ///
        mandateIds = new uint16[](2); 
        mandateIds[0] = mandateCount + 1;
        mandateIds[1] = mandateCount + 2; 

        parentFlows.push(PowersTypes.Flow({
            mandateIds: mandateIds,
            nameDescription: "Assign any role: For demo purposes, this flow allows the admin to assign any role and executives to revoke roles."
        }));

        // Admin can assign any role
        dynamicParams = new string[](2);
        dynamicParams[0] = "uint256 roleId";
        dynamicParams[1] = "address account";

        mandateCount++;
        conditions.allowedRole = 0; // Admin
        parentConstitution.push(
            PowersTypes.MandateInitData({
                nameDescription: "Admin can assign any role: The admin can assign any role to an account.",
                targetMandate: registry.getMandateAddress(MAJOR, MINOR, PATCH, "BespokeAction_Simple"),
                config: abi.encode(address(0), IPowers.assignRole.selector, dynamicParams),
                conditions: conditions
            })
        );
        delete conditions;

        // Executive can revoke role
        mandateCount++;
        conditions.allowedRole = 1; // Executive
        conditions.needFulfilled = mandateCount - 1; // Need admin assignment
        parentConstitution.push(
            PowersTypes.MandateInitData({
                nameDescription: "Executive can revoke role: Executive can revoke a role.",
                targetMandate: registry.getMandateAddress(MAJOR, MINOR, PATCH, "BespokeAction_Simple"),
                config: abi.encode(
                    address(0), // target is its own powers contract
                    IPowers.revokeRole.selector, 
                    dynamicParams
                    ),
                conditions: conditions
            })
        );
        delete conditions;

        // Admin: update uri 
        inputParams = new string[](1);
        inputParams[0] = "string newUri";

        mandateCount++;
        conditions.allowedRole = 0; // Admin
        parentConstitution.push(
            PowersTypes.MandateInitData({
                nameDescription: "Admin can update URI: Admin can update the URI of the contract.",
                targetMandate: registry.getMandateAddress(MAJOR, MINOR, PATCH, "BespokeAction_Simple"),
                config: abi.encode(address(0), IPowers.setUri.selector, inputParams),
                conditions: conditions
            })
        );
        delete conditions;
    }

    function createChildConstitution() internal {
        uint16 mandateCount = 0;

        // Initial Setup
        calldatas = new bytes[](6);
        calldatas[0] = abi.encodeWithSelector(IPowers.labelRole.selector, 0, "Admin", "");  
        calldatas[1] = abi.encodeWithSelector(IPowers.labelRole.selector, type(uint256).max, "Public", ""); 
        calldatas[2] = abi.encodeWithSelector(IPowers.labelRole.selector, 1, "Members", "");
        calldatas[3] = abi.encodeWithSelector(IPowers.labelRole.selector, 2, "Parent DAO", "");
        calldatas[4] = abi.encodeWithSelector(IPowers.assignRole.selector, 2, address(powersParent)); // No treasury for child, but could be set to own Safe if desired
        calldatas[5] = abi.encodeWithSelector(IPowers.revokeMandate.selector, mandateCount + 1);

        mandateCount++;
        conditions.allowedRole = 0; // Admin (Factory sets this)
        childConstitution.push(
            PowersTypes.MandateInitData({
                nameDescription: "Initial Setup: Assign role labels and revoke self.",
                targetMandate: registry.getMandateAddress(MAJOR, MINOR, PATCH, "PresetActions_OnOwnPowers"),
                config: abi.encode(calldatas),
                conditions: conditions
            })
        );
        delete conditions;

        /// TRANSFER TOKENS FLOW ///
        uint16[] memory mandateIds = new uint16[](3); 
        mandateIds[0] = mandateCount + 1;
        mandateIds[1] = mandateCount + 2; 
        mandateIds[2] = mandateCount + 3; 

        childFlows.push(PowersTypes.Flow({
            mandateIds: mandateIds,
            nameDescription: "Transfer tokens: Anyone can submit a request to transfer tokens, but members have to vote to execute the transfer. Meanwhile, the parent DAO retains veto power over any transfer."
        }));

        // Public Request Transfer
        inputParams = new string[](3);
        inputParams[0] = "address Token";
        inputParams[1] = "uint256 Amount";
        inputParams[2] = "address PayableTo";

        mandateCount++;
        conditions.allowedRole = type(uint256).max; // Public
        childConstitution.push(
            PowersTypes.MandateInitData({
                nameDescription: "Request Transfer: Public can request transfer of funds from Parent Treasury.",
                targetMandate: registry.getMandateAddress(MAJOR, MINOR, PATCH, "StatementOfIntent"),
                config: abi.encode(inputParams),
                conditions: conditions
            })
        );
        delete conditions;

        // Parent DAO Veto Transfer
        mandateCount++;
        conditions.allowedRole = 2; // Parent DAO
        conditions.needFulfilled = mandateCount - 1; // Need request
        childConstitution.push(
            PowersTypes.MandateInitData({
                nameDescription: "Veto Transfer: Parent DAO can veto transfer.",
                targetMandate: registry.getMandateAddress(MAJOR, MINOR, PATCH, "StatementOfIntent"),
                config: abi.encode(inputParams),
                conditions: conditions
            })
        );
        delete conditions;

        // Members Execute Transfer
        mandateCount++;
        conditions.allowedRole = 1; // Members
        conditions.quorum = 20; // 50% quorum for voting on Parent to set allowance
        conditions.votingPeriod = minutesToBlocks(5, helperConfig.getBlocksPerHour(block.chainid));
        conditions.succeedAt = 51; // >50% to pass
        conditions.needFulfilled = mandateCount - 2; // Need request (4)
        conditions.needNotFulfilled = mandateCount - 1; // Need NO veto (5)
        childConstitution.push(
            PowersTypes.MandateInitData({
                nameDescription: "Execute Transfer: Members vote to execute transfer from Parent Treasury.",
                targetMandate: registry.getMandateAddress(MAJOR, MINOR, PATCH, "SafeAllowance_Transfer"),
                config: abi.encode(helperConfig.getSafeAllowanceModule(block.chainid), treasury), // Treasury is Parent's treasury
                conditions: conditions
            })
        );
        delete conditions;

        /// REQUEST ADDITIONAL ALLOWANCE FLOW ///
        mandateIds = new uint16[](1); 
        mandateIds[0] = mandateCount + 1; 

        childFlows.push(PowersTypes.Flow({
            mandateIds: mandateIds,
            nameDescription: "Request Additional Allowance: A child DAO can request additional allowance from the Parent DAO. The Parent DAO can vote to approve the request, which if approved will trigger an execution at the Parent level to set the allowance for the child."
        }));

        // Request Additional Allowance from Parent
        inputParams = new string[](5);
        inputParams[0] = "address Sub-DAO";
        inputParams[1] = "address Token";
        inputParams[2] = "uint96 allowanceAmount";
        inputParams[3] = "uint16 resetTimeMin";
        inputParams[4] = "uint32 resetBaseMin";

        mandateCount++;
        conditions.allowedRole = 1; // Members
        childConstitution.push(
            PowersTypes.MandateInitData({
                nameDescription: "Request Additional Allowance: Members can request additional allowance from Parent.",
                targetMandate: registry.getMandateAddress(MAJOR, MINOR, PATCH, "ExternalAction_Simple"),
                config: abi.encode(
                    address(powersParent),
                    requestAllowanceMandateId, // ID from Parent Constitution
                    "Requesting allowance from Parent",
                    inputParams
                ),
                conditions: conditions
            })
        );
        delete conditions;
        
        /// ADMIN ASSIGN ANY ROLE FLOW ///
        mandateIds = new uint16[](2); 
        mandateIds[0] = mandateCount + 1;
        mandateIds[1] = mandateCount + 2; 

        childFlows.push(PowersTypes.Flow({
            mandateIds: mandateIds,
            nameDescription: "Assign any role: For demo purposes, this flow allows the admin to assign any role and executives to revoke roles."
        }));

        // Admin can assign any role
        dynamicParams = new string[](2);
        dynamicParams[0] = "uint256 roleId";
        dynamicParams[1] = "address account";

        mandateCount++;
        conditions.allowedRole = 0; // Admin
        childConstitution.push(
            PowersTypes.MandateInitData({
                nameDescription: "Admin can assign any role: The admin can assign any role to an account.",
                targetMandate: registry.getMandateAddress(MAJOR, MINOR, PATCH, "BespokeAction_Simple"),
                config: abi.encode(address(0), IPowers.assignRole.selector, dynamicParams),
                conditions: conditions
            })
        );
        delete conditions;

        // Members can revoke role
        mandateCount++;
        conditions.allowedRole = 1; // Members
        conditions.needFulfilled = mandateCount - 1; // Need admin assignment
        childConstitution.push(
            PowersTypes.MandateInitData({
                nameDescription: "Members can revoke role: Members can revoke a role.",
                targetMandate: registry.getMandateAddress(MAJOR, MINOR, PATCH, "BespokeAction_Simple"),
                config: abi.encode(address(0), IPowers.revokeRole.selector, dynamicParams),
                conditions: conditions
            })
        );
        delete conditions;

        /// ADMIN UPDATE URI: Note not assigned to any flow /// 
        inputParams = new string[](1);
        inputParams[0] = "string newUri";

        mandateCount++;
        conditions.allowedRole = 0; // Admin
        childConstitution.push(
            PowersTypes.MandateInitData({
                nameDescription: "Admin can update URI: Admin can update the URI of the contract.",
                targetMandate: registry.getMandateAddress(MAJOR, MINOR, PATCH, "BespokeAction_Simple"),
                config: abi.encode(address(0), IPowers.setUri.selector, inputParams),
                conditions: conditions
            })
        );
        delete conditions;

    }
}
