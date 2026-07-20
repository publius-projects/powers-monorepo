// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

// --- Forge/OpenZeppelin Imports ---
import { Script } from "forge-std/Script.sol";
import { console2 } from "forge-std/console2.sol";
import { Configurations } from "./Configurations.s.sol";

// --- Interfaces ---
import { MandateRegistry } from "@src/core/helpers/MandateRegistry.sol";
import { IMandate } from "@src/interfaces/IMandate.sol";

// ELECTORAL MANDATES
import { PeerSelect } from "@src/core/mandates/electoral/PeerSelect.sol";
import { RoleByRoles } from "@src/addons/mandates/electoral/RoleByRoles.sol";
import { SelfSelect } from "@src/core/mandates/electoral/SelfSelect.sol";
import { RenounceRole } from "@src/core/mandates/electoral/RenounceRole.sol";
import { AssignExternalRole } from "@src/addons/mandates/electoral/AssignExternalRole.sol";
import { DelegateTokenSelect } from "@src/core/mandates/electoral/DelegateTokenSelect.sol";
import { Nominate } from "@src/core/mandates/electoral/Nominate.sol";
import { RevokeInactiveAccounts } from "@src/addons/mandates/electoral/RevokeInactiveAccounts.sol";
import { RevokeAccountsRoleId } from "@src/addons/mandates/electoral/RevokeAccountsRoleId.sol";

// EXECUTIVE MANDATES
import { PresetActions } from "@src/core/mandates/executive/PresetActions.sol";
import { OpenAction } from "@src/core/mandates/executive/OpenAction.sol";
import { StatementOfIntent } from "@src/core/mandates/executive/StatementOfIntent.sol";

import { CheckExternalActionState } from "@src/addons/mandates/executive/CheckExternalActionState.sol";
import { BespokeAction_OnReturnValue } from "@src/core/mandates/executive/BespokeAction_OnReturnValue.sol";
import { BespokeAction_Advanced } from "@src/core/mandates/executive/BespokeAction_Advanced.sol";
import { BespokeAction_Simple } from "@src/core/mandates/executive/BespokeAction_Simple.sol";
import { ExternalAction_Simple } from "@src/core/mandates/executive/ExternalAction_Simple.sol";
import { ExternalAction_OnReturnValue } from "@src/addons/mandates/executive/ExternalAction_OnReturnValue.sol";
import { ExternalAction_Flexible } from "@src/core/mandates/executive/ExternalAction_Flexible.sol";
import { PresetActions_OnOwnPowers } from "@src/addons/mandates/executive/PresetActions_OnOwnPowers.sol";

// INTEGRATION MANDATES
// Election List
import {
    ElectionRegistry_Nominate
} from "@src/core/mandates/integrations/ElectionRegistry/ElectionRegistry_Nominate.sol";
import { ElectionRegistry_Tally } from "@src/core/mandates/integrations/ElectionRegistry/ElectionRegistry_Tally.sol";
import { ElectionRegistry_Vote } from "@src/core/mandates/integrations/ElectionRegistry/ElectionRegistry_Vote.sol";
import {
    ElectionRegistry_CreateVoteMandate
} from "@src/core/mandates/integrations/ElectionRegistry/ElectionRegistry_CreateVoteMandate.sol";
import {
    ElectionRegistry_CleanUpVoteMandate
} from "@src/core/mandates/integrations/ElectionRegistry/ElectionRegistry_CleanUpVoteMandate.sol";

// ERC721
import { ERC721_GatedAccess } from "@src/addons/mandates/integrations/ERC721/ERC721_GatedAccess.sol";

// GitHub -> Chainlink Functions
import {
    ChainlinkFunctions_Open
} from "@src/addons/mandates/integrations/ChainlinkFunctions/ChainlinkFunctions_Open.sol";

// GovernedToken
import {
    GovernedToken_GatedAccess
} from "@src/addons/mandates/integrations/GovernedToken/GovernedToken_GatedAccess.sol";
import {
    GovernedToken_MintEncodedToken
} from "@src/addons/mandates/integrations/GovernedToken/GovernedToken_MintEncodedToken.sol";
import {
    GovernedToken_CollectSplitPayment
} from "@src/addons/mandates/integrations/GovernedToken/GovernedToken_CollectSplitPayment.sol";
import {
    GovernedToken_BurnToAccess
} from "@src/addons/mandates/integrations/GovernedToken/GovernedToken_BurnToAccess.sol";

// Governor
import { Governor_CreateProposal } from "@src/addons/mandates/integrations/Governor/Governor_CreateProposal.sol";
import { Governor_ExecuteProposal } from "@src/addons/mandates/integrations/Governor/Governor_ExecuteProposal.sol";

// PowersFactory
import { PowersFactory_AssignRole } from "@src/addons/mandates/integrations/PowersFactory/PowersFactory_AssignRole.sol";
import {
    PowersFactory_AddSafeDelegate
} from "@src/addons/mandates/integrations/PowersFactory/PowersFactory_AddSafeDelegate.sol";

// Safe
import { Safe_ExecTransaction } from "@src/core/mandates/integrations/Safe/Safe_ExecTransaction.sol";
import { Safe_RecoverTokens } from "@src/core/mandates/integrations/Safe/Safe_RecoverTokens.sol";
import {
    Safe_ExecTransaction_OnReturnValue
} from "@src/core/mandates/integrations/Safe/Safe_ExecTransaction_OnReturnValue.sol";
import { SafeAllowance_Transfer } from "@src/core/mandates/integrations/Safe/SafeAllowance_Transfer.sol";
import { SafeAllowance_PresetTransfer } from "@src/core/mandates/integrations/Safe/SafeAllowance_PresetTransfer.sol";
import { SafeAllowance_Action } from "@src/core/mandates/integrations/Safe/SafeAllowance_Action.sol";

// Slate Registry
import { SlateRegistry_AddSlate } from "@src/core/mandates/integrations/SlateRegistry/SlateRegistry_AddSlate.sol";
import { SlateRegistry_RemoveSlate } from "@src/core/mandates/integrations/SlateRegistry/SlateRegistry_RemoveSlate.sol";
import {
    SlateRegistry_ExecuteResult
} from "@src/core/mandates/integrations/SlateRegistry/SlateRegistry_ExecuteResult.sol";

// Snapshot
// Will be reintegrated soon.

// ZKPassport
import { ZKPassport_Check } from "@src/addons/mandates/integrations/ZKPassport/ZKPassport_Check.sol";

// REFORM MANDATES
import { Adopt_Mandates } from "@src/core/mandates/reform/Adopt_Mandates.sol";
import { Revoke_Mandates } from "@src/core/mandates/reform/Revoke_Mandates.sol";
import { PauseMandates } from "@src/core/mandates/reform/PauseMandates.sol";

/// @title DeployMandates
/// @notice Deploys all library and mandate contracts
/// and registers them to the MandateRegistry via the Powers protocol.
contract DeployMandates is Script {
    Configurations helperConfig;
    MandateRegistry registry;
    string[] names;
    bytes[] creationCodes;
    bytes[] constructorArgs;
    uint48[] versions;
    address[] addresses;

    function run() external returns (address) {
        helperConfig = new Configurations();

        address registryAddr = helperConfig.getMandateRegistry(block.chainid);
        if (registryAddr != address(0)) {
            registry = MandateRegistry(registryAddr);
        } else {
            console2.log("No existing MandateRegistry found for this network. Deploying new MandateRegistry...");
            vm.startBroadcast();
            registry = new MandateRegistry{ salt: keccak256("MandateRegistry2") }(msg.sender);
            vm.stopBroadcast();
            // Seed the credit -> wei exchange rate so priced mandates work out of the box (owner-gated).
            vm.startBroadcast(registry.owner());
            registry.setWeiPerCredit(helperConfig.getWeiPerCredit(block.chainid));
            vm.stopBroadcast();
        }
        // MandateRegistry registry = MandateRegistry(registryAddr);
        // IPowers powers = IPowers(registry.owner());
        // uint16 submitMandateId = helperConfig.getSubmitMandateId(block.chainid);

        _recordMandates();

        string[] memory regNames = new string[](names.length);
        address[] memory regAddresses = new address[](names.length);
        bytes32[] memory regCreationCodeHashes = new bytes32[](names.length);
        uint256 regCount = 0;

        for (uint256 i = 0; i < names.length; i++) {
            bool isRegistered = registry.isMandateRegistered(bytes32(keccak256(creationCodes[i])));
            if (isRegistered) {
                console2.log("Mandate already registered, skipping:", names[i]);
                continue;
            }
            address mandateAddr = deploy(creationCodes[i], constructorArgs[i]);
            addresses.push(mandateAddr);

            // Skip if name+version already registered (bytecode may differ without version bump)
            (uint16 maj, uint16 min, uint16 pat) = IMandate(mandateAddr).version();
            if (registry.isVersionActive(maj, min, pat, names[i])) {
                console2.log("Mandate name+version already active, skipping:", names[i]);
                continue;
            }

            regNames[regCount] = names[i];
            regAddresses[regCount] = mandateAddr;
            regCreationCodeHashes[regCount] = bytes32(keccak256(creationCodes[i]));
            regCount++;
        }

        console2.log("Deployment complete. Registering mandates to MandateRegistry...");
        console2.log("Total mandates to register:", regCount);
        console2.log("Total mandates deployed:", names.length);

        // Create exactly-sized arrays for the registration payload
        if (regCount > 0) {
            // Create properly-sized arrays with only regCount elements
            string[] memory finalNames = new string[](regCount);
            address[] memory finalAddresses = new address[](regCount);
            bytes32[] memory finalCreationCodeHashes = new bytes32[](regCount);

            for (uint256 i = 0; i < regCount; i++) {
                finalNames[i] = regNames[i];
                finalAddresses[i] = regAddresses[i];
                finalCreationCodeHashes[i] = regCreationCodeHashes[i];
            }

            console2.log("Registering the following mandates:");
            for (uint256 i = 0; i < regCount; i++) {
                console2.log(" - ", finalNames[i], " at ", finalAddresses[i]);
            }

            vm.startBroadcast(registry.owner());
            registry.batchRegisterMandates(finalNames, finalAddresses, finalCreationCodeHashes);
            vm.stopBroadcast();

            console2.log("Successfully registered mandates to MandateRegistry.");
        } else {
            console2.log("No mandates for registration.");
        }

        console2.log("-----------------------------------------");
        console2.log("Registry Address:", address(registry));
        console2.log("Total contracts deployed:", names.length);
        console2.log("Total mandates registered:", regCount);
        console2.log("-----------------------------------------");

        return address(registry);
    }

    /// @dev Deploys a mandate normally (no CREATE2).
    function deploy(bytes memory creationCode, bytes memory constructorArg) internal returns (address) {
        bytes memory deploymentData = abi.encodePacked(creationCode, constructorArg);
        address deployedAddress;

        vm.startBroadcast();
        assembly {
            deployedAddress := create(0, add(deploymentData, 0x20), mload(deploymentData))
        }
        vm.stopBroadcast();

        require(deployedAddress != address(0), "Error: Deployment failed.");
        return deployedAddress;
    }

    function _packVersion(uint16 major, uint16 minor, uint16 patch) public pure returns (uint48) {
        return (uint48(major) << 32) | (uint48(minor) << 16) | uint48(patch);
    }

    function _recordMandates() internal {
        //////////////////////////////////////////////////////////////////////////
        //                      Electoral Mandates                              //
        //////////////////////////////////////////////////////////////////////////
        names.push("PeerSelect");
        creationCodes.push(type(PeerSelect).creationCode);
        constructorArgs.push(abi.encode(address(registry)));

        names.push("RoleByRoles");
        creationCodes.push(type(RoleByRoles).creationCode);
        constructorArgs.push(abi.encode(address(registry)));

        names.push("SelfSelect");
        creationCodes.push(type(SelfSelect).creationCode);
        constructorArgs.push(abi.encode(address(registry)));

        names.push("RenounceRole");
        creationCodes.push(type(RenounceRole).creationCode);
        constructorArgs.push(abi.encode(address(registry)));

        names.push("AssignExternalRole");
        creationCodes.push(type(AssignExternalRole).creationCode);
        constructorArgs.push(abi.encode(address(registry)));

        names.push("DelegateTokenSelect");
        creationCodes.push(type(DelegateTokenSelect).creationCode);
        constructorArgs.push(abi.encode(address(registry)));

        names.push("Nominate");
        creationCodes.push(type(Nominate).creationCode);
        constructorArgs.push(abi.encode(address(registry)));

        names.push("RevokeInactiveAccounts");
        creationCodes.push(type(RevokeInactiveAccounts).creationCode);
        constructorArgs.push(abi.encode(address(registry)));

        names.push("RevokeAccountsRoleId");
        creationCodes.push(type(RevokeAccountsRoleId).creationCode);
        constructorArgs.push(abi.encode(address(registry)));

        //////////////////////////////////////////////////////////////////////////
        //                       Executive Mandates                             //
        //////////////////////////////////////////////////////////////////////////
        names.push("PresetActions");
        creationCodes.push(type(PresetActions).creationCode);
        constructorArgs.push(abi.encode(address(registry)));

        names.push("PresetActions_OnOwnPowers");
        creationCodes.push(type(PresetActions_OnOwnPowers).creationCode);
        constructorArgs.push(abi.encode(address(registry)));

        names.push("OpenAction");
        creationCodes.push(type(OpenAction).creationCode);
        constructorArgs.push(abi.encode(address(registry)));

        names.push("StatementOfIntent");
        creationCodes.push(type(StatementOfIntent).creationCode);
        constructorArgs.push(abi.encode(address(registry)));

        names.push("BespokeAction_Advanced");
        creationCodes.push(type(BespokeAction_Advanced).creationCode);
        constructorArgs.push(abi.encode(address(registry)));

        names.push("BespokeAction_OnReturnValue");
        creationCodes.push(type(BespokeAction_OnReturnValue).creationCode);
        constructorArgs.push(abi.encode(address(registry)));

        names.push("BespokeAction_Simple");
        creationCodes.push(type(BespokeAction_Simple).creationCode);
        constructorArgs.push(abi.encode(address(registry)));

        names.push("CheckExternalActionState");
        creationCodes.push(type(CheckExternalActionState).creationCode);
        constructorArgs.push(abi.encode(address(registry)));

        names.push("ExternalAction_Simple");
        creationCodes.push(type(ExternalAction_Simple).creationCode);
        constructorArgs.push(abi.encode(address(registry)));

        names.push("ExternalAction_OnReturnValue");
        creationCodes.push(type(ExternalAction_OnReturnValue).creationCode);
        constructorArgs.push(abi.encode(address(registry)));

        names.push("ExternalAction_Flexible");
        creationCodes.push(type(ExternalAction_Flexible).creationCode);
        constructorArgs.push(abi.encode(address(registry)));

        //////////////////////////////////////////////////////////////////////////
        //                      Integrations Mandates                           //
        //////////////////////////////////////////////////////////////////////////
        names.push("Governor_CreateProposal");
        creationCodes.push(type(Governor_CreateProposal).creationCode);
        constructorArgs.push(abi.encode(address(registry)));

        names.push("Governor_ExecuteProposal");
        creationCodes.push(type(Governor_ExecuteProposal).creationCode);
        constructorArgs.push(abi.encode(address(registry)));

        names.push("Safe_ExecTransaction");
        creationCodes.push(type(Safe_ExecTransaction).creationCode);
        constructorArgs.push(abi.encode(address(registry)));

        names.push("Safe_ExecTransaction_OnReturnValue");
        creationCodes.push(type(Safe_ExecTransaction_OnReturnValue).creationCode);
        constructorArgs.push(abi.encode(address(registry)));

        names.push("Safe_RecoverTokens");
        creationCodes.push(type(Safe_RecoverTokens).creationCode);
        constructorArgs.push(abi.encode(address(registry)));

        names.push("SafeAllowance_Transfer");
        creationCodes.push(type(SafeAllowance_Transfer).creationCode);
        constructorArgs.push(abi.encode(address(registry)));

        names.push("SafeAllowance_PresetTransfer");
        creationCodes.push(type(SafeAllowance_PresetTransfer).creationCode);
        constructorArgs.push(abi.encode(address(registry)));

        names.push("SafeAllowance_Action");
        creationCodes.push(type(SafeAllowance_Action).creationCode);
        constructorArgs.push(abi.encode(address(registry)));

        names.push("PowersFactory_AssignRole");
        creationCodes.push(type(PowersFactory_AssignRole).creationCode);
        constructorArgs.push(abi.encode(address(registry)));

        names.push("PowersFactory_AddSafeDelegate");
        creationCodes.push(type(PowersFactory_AddSafeDelegate).creationCode);
        constructorArgs.push(abi.encode(address(registry)));

        names.push("GovernedToken_GatedAccess");
        creationCodes.push(type(GovernedToken_GatedAccess).creationCode);
        constructorArgs.push(abi.encode(address(registry)));

        names.push("ERC721_GatedAccess");
        creationCodes.push(type(ERC721_GatedAccess).creationCode);
        constructorArgs.push(abi.encode(address(registry)));

        names.push("GovernedToken_MintEncodedToken");
        creationCodes.push(type(GovernedToken_MintEncodedToken).creationCode);
        constructorArgs.push(abi.encode(address(registry)));

        names.push("GovernedToken_BurnToAccess");
        creationCodes.push(type(GovernedToken_BurnToAccess).creationCode);
        constructorArgs.push(abi.encode(address(registry)));

        names.push("ElectionRegistry_Vote");
        creationCodes.push(type(ElectionRegistry_Vote).creationCode);
        constructorArgs.push(abi.encode(address(registry)));

        names.push("ElectionRegistry_Nominate");
        creationCodes.push(type(ElectionRegistry_Nominate).creationCode);
        constructorArgs.push(abi.encode(address(registry)));

        names.push("ElectionRegistry_CreateVoteMandate");
        creationCodes.push(type(ElectionRegistry_CreateVoteMandate).creationCode);
        constructorArgs.push(abi.encode(address(registry)));

        names.push("ElectionRegistry_Tally");
        creationCodes.push(type(ElectionRegistry_Tally).creationCode);
        constructorArgs.push(abi.encode(address(registry)));

        names.push("ElectionRegistry_CleanUpVoteMandate");
        creationCodes.push(type(ElectionRegistry_CleanUpVoteMandate).creationCode);
        constructorArgs.push(abi.encode(address(registry)));

        names.push("SlateRegistry_AddSlate");
        creationCodes.push(type(SlateRegistry_AddSlate).creationCode);
        constructorArgs.push(abi.encode(address(registry)));

        names.push("SlateRegistry_RemoveSlate");
        creationCodes.push(type(SlateRegistry_RemoveSlate).creationCode);
        constructorArgs.push(abi.encode(address(registry)));

        names.push("SlateRegistry_ExecuteResult");
        creationCodes.push(type(SlateRegistry_ExecuteResult).creationCode);
        constructorArgs.push(abi.encode(address(registry)));

        names.push("GovernedToken_CollectSplitPayment");
        creationCodes.push(type(GovernedToken_CollectSplitPayment).creationCode);
        constructorArgs.push(abi.encode(address(registry)));

        names.push("ZKPassport_Check");
        creationCodes.push(type(ZKPassport_Check).creationCode);
        constructorArgs.push(abi.encode(address(registry)));

        names.push("ChainlinkFunctions_Open");
        creationCodes.push(type(ChainlinkFunctions_Open).creationCode);
        // router placeholder (not configured in this script) + canonical registry
        constructorArgs.push(abi.encode(address(0), address(registry)));

        //////////////////////////////////////////////////////////////////////////
        //                          Reform Mandates                             //
        //////////////////////////////////////////////////////////////////////////
        names.push("Adopt_Mandates");
        creationCodes.push(type(Adopt_Mandates).creationCode);
        constructorArgs.push(abi.encode(address(registry)));

        names.push("PauseMandates");
        creationCodes.push(type(PauseMandates).creationCode);
        constructorArgs.push(abi.encode(address(registry)));

        names.push("Revoke_Mandates");
        creationCodes.push(type(Revoke_Mandates).creationCode);
        constructorArgs.push(abi.encode(address(registry)));
    }
}
