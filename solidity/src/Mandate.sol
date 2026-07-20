// SPDX-License-Identifier: MIT
/*
  _____   ____  __          __ ______  _____    _____
 |  __ \ / __ \ \ \        / /|  ____||  __ \  / ____|
 | |__) | |  | | \ \  /\  / / | |__   | |__) || (___
 |  ___/| |  | |  \ \/  \/ /  |  __|  |  _  /  \___ \
 | |    | |__| |   \  /\  /   | |____ | | \ \  ____) |
 |_|     \____/     \/  \/    |______||_|  \_\|_____/

*/
/// @title Mandate - Base Implementation for Powers Protocol Mandates. v0.4.
/// @notice Base contract for implementing role-restricted governance actions
/// @dev Provides core functionality for creating institutional mandates in the Powers protocol
///
/// Mandates serve four key functions:
/// 1. Giving roles powers to transform input data into executable calldata.
/// 2. Validation of input and execution data.
/// 3. Calling external contracts and validating return data.
/// 4. Returning of data to the Powers protocol
///
/// Mandates can be customized through inheriting and implementing bespoke logic in the {handleRequest}
///
/// @author 7Cedars
pragma solidity ^0.8.26;

import { IPowers } from "./interfaces/IPowers.sol";
import { MandateUtilities } from "./libraries/MandateUtilities.sol";
import { IMandate } from "./interfaces/IMandate.sol";
import { IMandateRegistry } from "@src/core/helpers/MandateRegistry.sol";
import { ERC165 } from "@lib/openzeppelin-contracts/contracts/utils/introspection/ERC165.sol";
import { IERC165 } from "@lib/openzeppelin-contracts/contracts/utils/introspection/IERC165.sol";

// import { console2 } from "forge-std/console2.sol"; // remove before deploying

abstract contract Mandate is ERC165, IMandate {
    //////////////////////////////////////////////////////////////
    //                        STORAGE                           //
    //////////////////////////////////////////////////////////////
    struct MandateData {
        string nameDescription;
        bytes inputParams;
        bytes config;
        address powers;
    }
    mapping(bytes32 mandateHash => MandateData) public mandates;

    /// @notice Canonical MandateRegistry this mandate reports adoptions to (whitelist + paid-tier charge).
    address public immutable MANDATE_REGISTRY;

    /// @param registry_ Canonical MandateRegistry address. Adoption reverts if this mandate is not
    /// registered/active there; if priced, the adopting org is charged from its prepaid credits.
    constructor(address registry_) {
        MANDATE_REGISTRY = registry_;
    }

    //////////////////////////////////////////////////////////////
    //                   LAW EXECUTION                          //
    //////////////////////////////////////////////////////////////
    // note this is an unrestricted function. Anyone can initialize a mandate.
    function initializeMandate(
        uint16 index,
        string memory nameDescription,
        bytes memory inputParams,
        bytes memory config
    ) public virtual {
        // Enforce the whitelist and (if priced) charge the adopting org. msg.sender is the adopting Powers org.
        IMandateRegistry(MANDATE_REGISTRY).onAdopt(msg.sender);

        bytes32 mandateHash = MandateUtilities.hashMandate(msg.sender, index);
        MandateUtilities.checkStringLength(nameDescription, 1, 255);

        mandates[mandateHash] = MandateData({
            nameDescription: nameDescription, inputParams: inputParams, config: config, powers: msg.sender
        });

        emit Mandate__Initialized(msg.sender, index, nameDescription, inputParams, config);
    }

    /// @notice Executes the mandate's logic: validation -> handling request -> call external -> replying to Powers
    /// @dev Called by the Powers protocol during action execution
    /// @param caller Address that initiated the action
    /// @param mandateCalldata Encoded function call data
    /// @param nonce The nonce for the action
    /// @return success True if execution succeeded
    function executeMandate(address caller, uint16 mandateId, bytes calldata mandateCalldata, uint256 nonce)
        public
        returns (bool success)
    {
        bytes32 mandateHash = MandateUtilities.hashMandate(msg.sender, mandateId);
        if (mandates[mandateHash].powers != msg.sender) {
            revert OnlyPowers();
        }

        // Simulate and execute the mandate's logic. This might include additional conditional checks.
        (uint256 actionId, address[] memory targets, uint256[] memory values, bytes[] memory calldatas) =
            handleRequest(caller, payable(msg.sender), mandateId, mandateCalldata, nonce);

        IPowers(msg.sender).fulfill(mandateId, actionId, targets, values, calldatas);

        return true;
    }

    /// @notice Handles requests from the Powers protocol and returns data _replyPowers and _changeState can use.
    /// @dev Must be overridden by implementing contracts
    /// @param caller Address that initiated the action
    /// @param mandateId The id of the mandate
    /// @param mandateCalldata Encoded function call data
    /// @param nonce The nonce for the action
    /// @return actionId The action ID
    /// @return targets Target contract addresses for calls
    /// @return values ETH values to send with calls
    /// @return calldatas Encoded function calls
    function handleRequest(
        address caller,
        address powers,
        uint16 mandateId,
        bytes calldata mandateCalldata,
        uint256 nonce
    )
        public
        view
        virtual
        returns (uint256 actionId, address[] memory targets, uint256[] memory values, bytes[] memory calldatas)
    {
        // Empty implementation - must be overridden
    }

    //////////////////////////////////////////////////////////////
    //                      HELPER FUNCTIONS                    //
    //////////////////////////////////////////////////////////////
    function getNameDescription(address powers, uint16 mandateId) public view returns (string memory nameDescription) {
        return mandates[MandateUtilities.hashMandate(powers, mandateId)].nameDescription;
    }

    function getInputParams(address powers, uint16 mandateId) public view virtual returns (bytes memory inputParams) {
        return mandates[MandateUtilities.hashMandate(powers, mandateId)].inputParams;
    }

    function getConfig(address powers, uint16 mandateId) public view returns (bytes memory config) {
        return mandates[MandateUtilities.hashMandate(powers, mandateId)].config;
    }

    function version() public pure virtual returns (uint16 major, uint16 minor, uint16 patch) {
        return (0, 1, 9);
    }

    /// @notice Adoption price in credits. Default 0 (free); override to charge on adoption.
    /// @dev The registry reads this on adoption and converts credits -> wei via its weiPerCredit rate.
    ///      Declared view (not pure) so overrides may return a constant or a storage-backed value.
    function priceInCredits() public view virtual returns (uint256 price) {
        return 0;
    }

    /// @notice Developer payees for the paid portion of a priced adoption. Default empty (free mandates).
    /// @dev Must be non-empty when priceInCredits() > 0, or adoption reverts in the registry.
    function devs() public view virtual returns (address[] memory payees) {
        return new address[](0);
    }

    // can include here a getMetadata that returns a string uri from the config -- if there is one. This would be useful for frontends to easily retrieve metadata about the mandate.
    // this function would then be virtual, so that when not overridden, it returns an empty string or a default uri.

    //////////////////////////////////////////////////////////////
    //                      UTILITIES                           //
    //////////////////////////////////////////////////////////////
    function supportsInterface(bytes4 interfaceId) public view virtual override(ERC165, IERC165) returns (bool) {
        return interfaceId == type(IMandate).interfaceId || super.supportsInterface(interfaceId);
    }
}
