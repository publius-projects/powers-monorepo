// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

// scripts
import { Script } from "forge-std/Script.sol";
import { console2 } from "forge-std/console2.sol";
import { Configurations } from "@script/Configurations.s.sol"; 
import { DeployHelpers } from "../DeployHelpers.s.sol";
import { IMandateRegistry } from "@src/core/helpers/MandateRegistry.sol";

// powers contracts
import { PowersTypes } from "@src/interfaces/PowersTypes.sol";
import { Powers } from "@src/Powers.sol";
import { IPowers } from "@src/interfaces/IPowers.sol";

// Account Abstraction Integrations
import { PowersPaymaster } from "@src/core/helpers/PowersPaymaster.sol"; 
import { IEntryPoint } from "@lib/account-abstraction/contracts/interfaces/IEntryPoint.sol";

// helpers
import { SimpleErc20Votes } from "../../test/mocks/SimpleErc20Votes.sol";
import { Strings } from "@lib/openzeppelin-contracts/contracts/utils/Strings.sol";

/// @title Account Abstraction Deployment Script
contract Deploy is DeployHelpers {
    using Strings for address;

    Configurations helperConfig;
    PowersTypes.MandateInitData[] constitution;
    PowersTypes.Conditions conditions;
    PowersTypes.Flow[] flows;
    Powers powers;
    IMandateRegistry registry;

    SimpleErc20Votes simpleErc20Votes;
    PowersPaymaster powersPaymaster; 

    address[] targets;
    uint256[] values;
    bytes[] calldatas;
    string[] dynamicParams;

    // Select version mandates to be used.
    uint16 constant MAJOR = 0;
    uint16 constant MINOR = 1;
    uint16 constant PATCH = 9;

    address constant ENTRY_POINT = 0x0000000071727De22E5E9d8BAf0edAc6f37da032;
    address public cedars = 0x328735d26e5Ada93610F0006c32abE2278c46211; 

    function run() external returns (Powers) {
        // step 0, setup. 
        helperConfig = new Configurations();
        registry = IMandateRegistry(helperConfig.getMandateRegistry(block.chainid));

        // step 1: deploy Contracts
        vm.startBroadcast();
        simpleErc20Votes = new SimpleErc20Votes(); 

        powers = new Powers(
            "Account Abstracted Powers", // name
            "https://aqua-famous-sailfish-288.mypinata.cloud/ipfs/bafkreibt7jfbckh7pudo32u5n3fje2defkafopiw2np55zij7u3vrtyxqy",  
            helperConfig.getMaxCallDataLength(block.chainid), // max call data length
            helperConfig.getMaxReturnDataLength(block.chainid), // max return data length
            helperConfig.getMaxExecutionsLength(block.chainid), // max executions length
            address(registry)
        );

        powersPaymaster = new PowersPaymaster(
            IEntryPoint(ENTRY_POINT),
            address(powers)
        );
        powersPaymaster.deposit{value: 0.05 ether}();
        vm.stopBroadcast();
        
        console2.log("Powers deployed at:", address(powers));
        console2.log("PowersPaymaster deployed at:", address(powersPaymaster));

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

        return powers;
    }

    function createConstitution() internal returns (uint256 constitutionLength) {
        uint16 mandateCount = 0;
        
        //////////////////////////////////////////////////////////////////////
        //                              SETUP                               //
        //////////////////////////////////////////////////////////////////////
        targets = new address[](8);
        values = new uint256[](8);
        calldatas = new bytes[](8);
        for (uint256 i = 0; i < targets.length; i++) {
            targets[i] = address(powers);
        }
        calldatas[0] = abi.encodeWithSelector(IPowers.labelRole.selector, 0, "Admin", "");
        calldatas[1] = abi.encodeWithSelector(IPowers.labelRole.selector, type(uint256).max, "Public", "");
        calldatas[2] = abi.encodeWithSelector(IPowers.labelRole.selector, 1, "Delegate", "");
        calldatas[3] = abi.encodeWithSelector(IPowers.assignRole.selector, 1, cedars);
        calldatas[4] = abi.encodeWithSelector(IPowers.setTreasury.selector, address(powers));
        calldatas[5] = abi.encodeWithSelector(IPowers.setPaymaster.selector, address(powersPaymaster));
        targets[6] = address(powersPaymaster);
        calldatas[6] = abi.encodeWithSelector(PowersPaymaster.addSponsoredTarget.selector, address(powers));
        calldatas[7] = abi.encodeWithSelector(IPowers.revokeMandate.selector, mandateCount + 1); // revoke mandate after use.

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

        //////////////////////////////////////////////////////////////////////
        //                   FUND PAYMASTER FLOW                            //
        //////////////////////////////////////////////////////////////////////
        uint16[] memory mandateIds = new uint16[](2); 
        mandateIds[0] = mandateCount + 1;
        mandateIds[1] = mandateCount + 2; 

        flows.push(PowersTypes.Flow({
            mandateIds: mandateIds,
            nameDescription: "Fund Paymaster Flow: A delegate proposes to fund the PowersPaymaster with ETH, and another delegate can execute it."
        }));

        // Propose to fund paymaster
        mandateCount++;
        conditions.allowedRole = 1; // Delegate
        constitution.push(
            PowersTypes.MandateInitData({
                nameDescription: "Propose to Fund Paymaster: Propose an ETH transfer to the paymaster.",
                targetMandate: registry.getMandateAddress(MAJOR, MINOR, PATCH, "StatementOfIntent"),
                config: abi.encode(),
                conditions: conditions
            })
        ); 
        delete conditions;

        // Execute fund paymaster
        targets = new address[](1);
        values = new uint256[](1);
        calldatas = new bytes[](1);
        targets[0] = address(powersPaymaster);
        values[0] = 100000000000000000; // 0.1 ETH
        calldatas[0] = abi.encodeWithSignature("deposit()");

        mandateCount++;
        conditions.allowedRole = 1; // Delegate
        conditions.votingPeriod = minutesToBlocks(5, helperConfig.getBlocksPerHour(block.chainid));
        conditions.succeedAt = 51; 
        conditions.quorum = 20; 
        conditions.needFulfilled = mandateCount - 1; 
        constitution.push(
            PowersTypes.MandateInitData({
                nameDescription: "Execute Fund Paymaster: Send 0.1 ETH to the paymaster.",
                targetMandate: registry.getMandateAddress(MAJOR, MINOR, PATCH, "PresetActions"),
                config: abi.encode(targets, values, calldatas), 
                conditions: conditions
            })
        );
        delete conditions;

        //////////////////////////////////////////////////////////////////////
        //                 WITHDRAW FROM PAYMASTER FLOW                     //
        //////////////////////////////////////////////////////////////////////
        mandateIds = new uint16[](2); 
        mandateIds[0] = mandateCount + 1;
        mandateIds[1] = mandateCount + 2; 

        flows.push(PowersTypes.Flow({
            mandateIds: mandateIds,
            nameDescription: "Withdraw From Paymaster Flow: A delegate proposes to withdraw ETH from the PowersPaymaster, and another delegate can execute it."
        }));

        string[] memory withdrawParams = new string[](2); 
        withdrawParams[0] = "address withdrawAddress";
        withdrawParams[1] = "uint256 amount";

        // Propose to withdraw from paymaster
        mandateCount++;
        conditions.allowedRole = 1; // Delegate
        constitution.push(
            PowersTypes.MandateInitData({
                nameDescription: "Propose to Withdraw from Paymaster: Propose withdrawing ETH from the paymaster back to the treasury.",
                targetMandate: registry.getMandateAddress(MAJOR, MINOR, PATCH, "StatementOfIntent"),
                config: abi.encode(withdrawParams),
                conditions: conditions
            })
        );
        delete conditions;

        // Execute withdraw from paymaster
        mandateCount++;
        conditions.allowedRole = 1; // Delegate
        conditions.votingPeriod = minutesToBlocks(5, helperConfig.getBlocksPerHour(block.chainid));
        conditions.succeedAt = 51; 
        conditions.quorum = 20; 
        conditions.needFulfilled = mandateCount - 1; 
        constitution.push(
            PowersTypes.MandateInitData({
                nameDescription: "Execute Withdraw from Paymaster: Execute the proposed ETH withdrawal from the paymaster.",
                targetMandate: registry.getMandateAddress(MAJOR, MINOR, PATCH, "BespokeAction_Simple"),
                config: abi.encode(
                    address(powersPaymaster),
                    bytes4(keccak256("withdrawTo(address,uint256)")),
                    withdrawParams
                    ),  
                conditions: conditions
            })
        );
        delete conditions;

        //////////////////////////////////////////////////////////////////////
        //                      MINT TOKENS FLOW                            //
        //////////////////////////////////////////////////////////////////////
        
        mandateIds = new uint16[](3); 
        mandateIds[0] = mandateCount + 1;
        mandateIds[1] = mandateCount + 2;
        mandateIds[2] = mandateCount + 3;

        flows.push(PowersTypes.Flow({
            mandateIds: mandateIds,
            nameDescription: "Minting Flow: Propose a mint, veto a mint, execute a mint."
        }));

        string[] memory mintParams = new string[](2);
        mintParams[0] = "address To";
        mintParams[1] = "uint256 Quantity";

        // Propose
        mandateCount++;
        conditions.allowedRole = type(uint256).max; // anyone can call this mandate
        constitution.push(
            PowersTypes.MandateInitData({
                nameDescription: string(abi.encodePacked("Propose to Mint: Propose to mint tokens at ", address(simpleErc20Votes).toHexString(), ".")),
                targetMandate: registry.getMandateAddress(MAJOR, MINOR, PATCH, "StatementOfIntent"),
                config: abi.encode(mintParams),
                conditions: conditions
            })
        );
        delete conditions;

        // Veto
        mandateCount++;
        conditions.allowedRole = 0; // Admin
        conditions.needFulfilled = mandateCount - 1; 
        constitution.push(
            PowersTypes.MandateInitData({
                nameDescription: string(abi.encodePacked("Veto a mint: Veto a proposed token mint at ", address(simpleErc20Votes).toHexString(), ".")),
                targetMandate: registry.getMandateAddress(MAJOR, MINOR, PATCH, "StatementOfIntent"),
                config: abi.encode(mintParams),
                conditions: conditions
            })
        );
        delete conditions;

        // Execute
        mandateCount++;
        conditions.allowedRole = 1; // Delegate
        conditions.votingPeriod = minutesToBlocks(5, helperConfig.getBlocksPerHour(block.chainid)); 
        conditions.succeedAt = 66; 
        conditions.quorum = 20; 
        conditions.needFulfilled = mandateCount - 2; 
        conditions.needNotFulfilled = mandateCount - 1; 
        constitution.push(
            PowersTypes.MandateInitData({
                nameDescription: string(abi.encodePacked("Execute a mint: Execute a mint at ", address(simpleErc20Votes).toHexString(), ". it has to be proposed first by the community and should not have been vetoed by an admin.")),
                targetMandate: registry.getMandateAddress(MAJOR, MINOR, PATCH, "BespokeAction_Simple"),
                config: abi.encode(
                    address(simpleErc20Votes), 
                    bytes4(keccak256("mint(address,uint256)")), 
                    mintParams
                ), 
                conditions: conditions
            })
        );
        delete conditions;

        //////////////////////////////////////////////////////////////////////
        //                 ADMIN ROLE ASSIGNMENT FLOW                       //
        //////////////////////////////////////////////////////////////////////
        mandateIds = new uint16[](2); 
        mandateIds[0] = mandateCount + 1;
        mandateIds[1] = mandateCount + 2; 

        flows.push(PowersTypes.Flow({
            mandateIds: mandateIds,
            nameDescription: "Assign any role: For demo purposes, this flow allows the admin to assign any role and delegates to revoke roles."
        }));

        dynamicParams = new string[](2);
        dynamicParams[0] = "uint256 roleId";
        dynamicParams[1] = "address account";

        // Admin assign role
        mandateCount++;
        conditions.allowedRole = 0; // Admin
        constitution.push(
            PowersTypes.MandateInitData({
                nameDescription: "Admin can assign any role: For this demo, the admin can assign any role to an account.",
                targetMandate: registry.getMandateAddress(MAJOR, MINOR, PATCH, "BespokeAction_Simple"),
                config: abi.encode(address(powers), IPowers.assignRole.selector, dynamicParams),
                conditions: conditions
            })
        );
        delete conditions;

        // Delegate revoke role
        mandateCount++;
        conditions.allowedRole = 1; // Delegate
        conditions.needFulfilled = mandateCount - 1; 
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
