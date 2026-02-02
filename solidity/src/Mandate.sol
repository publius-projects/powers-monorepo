// SPDX-License-Identifier: MIT

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
/// Mandates can be customized through:
/// - Inheriting and implementing bespoke logic in the {handleRequest} {_replyPowers} and {_externalCall} functions.
///
/// @author 7Cedars
pragma solidity 0.8.26;

import { IPowers } from "./interfaces/IPowers.sol";
import { MandateUtilities } from "./libraries/MandateUtilities.sol";
import { IMandate } from "./interfaces/IMandate.sol";
import { ERC165 } from "../lib/openzeppelin-contracts/contracts/utils/introspection/ERC165.sol";
import { IERC165 } from "../lib/openzeppelin-contracts/contracts/utils/introspection/IERC165.sol";

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
        virtual
        returns (bool success)
    {
        bytes32 mandateHash = MandateUtilities.hashMandate(msg.sender, mandateId);
        if (mandates[mandateHash].powers != msg.sender) {
            revert("Only Powers");
        }

        // Simulate and execute the mandate's logic. This might include additional conditional checks.
        (uint256 actionId, address[] memory targets, uint256[] memory values, bytes[] memory calldatas) =
            handleRequest(caller, msg.sender, mandateId, mandateCalldata, nonce);

        _externalCall(mandateId, actionId, targets, values, calldatas);

        _replyPowers(mandateId, actionId, targets, values, calldatas);

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
        bytes memory mandateCalldata,
        uint256 nonce
    )
        public
        view
        virtual
        returns (uint256 actionId, address[] memory targets, uint256[] memory values, bytes[] memory calldatas)
    {
        // Empty implementation - must be overridden
    }

    /// @notice Meant to be used to call an external contract. Especially usefull in the case of async mandates.
    /// @dev Can be overridden by implementing contracts.
    /// @param mandateId The id of the mandate
    /// @param actionId The action ID
    /// @param targets Target contract addresses for calls
    /// @param values ETH values to send with calls
    /// @param calldatas Encoded function calls
    function _externalCall(
        uint16 mandateId,
        uint256 actionId,
        address[] memory targets,
        uint256[] memory values,
        bytes[] memory calldatas
    ) internal virtual {
        // optional override by implementing contracts
    }

    /// @notice Meant to be used to reply to the Powers protocol. Can be overridden by implementing contracts.
    /// @dev Can be overridden by implementing contracts.
    /// @param mandateId The id of the mandate
    /// @param actionId The action ID
    /// @param targets Target contract addresses for calls
    /// @param values ETH values to send with calls
    /// @param calldatas Encoded function calls
    function _replyPowers(
        uint16 mandateId,
        uint256 actionId,
        address[] memory targets,
        uint256[] memory values,
        bytes[] memory calldatas
    ) internal virtual {
        // NB Important for async calls! Leave the targets array empty in the replyPowers function and thereby disallow _replyPowers returning data to Powers.
        // If data is send to Powers, the actionId will be set to fulfilled and the callback function will fail.
        if (targets.length > 0) {
            IPowers(msg.sender).fulfill(mandateId, actionId, targets, values, calldatas);
        }
    }

    //////////////////////////////////////////////////////////////
    //                      HELPER FUNCTIONS                    //
    //////////////////////////////////////////////////////////////
    function getNameDescription(address powers, uint16 mandateId) public view returns (string memory nameDescription) {
        return mandates[MandateUtilities.hashMandate(powers, mandateId)].nameDescription;
    }

    function getInputParams(address powers, uint16 mandateId) public view returns (bytes memory inputParams) {
        return mandates[MandateUtilities.hashMandate(powers, mandateId)].inputParams;
    }

    function getConfig(address powers, uint16 mandateId) public view returns (bytes memory config) {
        return mandates[MandateUtilities.hashMandate(powers, mandateId)].config;
    }

    //////////////////////////////////////////////////////////////
    //                      UTILITIES                           //
    //////////////////////////////////////////////////////////////
    function supportsInterface(bytes4 interfaceId) public view virtual override(ERC165, IERC165) returns (bool) {
        return interfaceId == type(IMandate).interfaceId || super.supportsInterface(interfaceId);
    }
}
