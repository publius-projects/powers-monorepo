// SPDX-License-Identifier: MIT

/// @title Mandate Interface - Contract Interface for Powers Protocol Mandates
/// @notice Interface for the Mandate contract, which provides core functionality for institutional mandates.
/// @dev Defines the interface for implementing role restricted conditional powers to transform input data into executable calldata.
/// @author 7Cedars
pragma solidity 0.8.26;

import { IERC165 } from "../../lib/openzeppelin-contracts/contracts/utils/introspection/IERC165.sol";

interface IMandate is IERC165 {
    //////////////////////////////////////////////////////////////
    //                        EVENTS                            //
    //////////////////////////////////////////////////////////////

    /// @notice Emitted when a mandate is deployed
    /// @param configParams Configurations parameters for the mandate
    event Mandate__Deployed(bytes configParams);

    /// @notice Emitted when a mandate is initialized
    /// @param powers Address of the Powers protocol
    /// @param index Index of the mandate
    /// @param nameDescription Name of the mandate
    /// @param inputParams Input parameters for the mandate
    event Mandate__Initialized(
        address indexed powers, uint16 indexed index, string nameDescription, bytes inputParams, bytes config
    );

    //////////////////////////////////////////////////////////////
    //                   LAW EXECUTION                          //
    //////////////////////////////////////////////////////////////
    /// @notice Initializes the mandate
    /// @param index Index of the mandate
    /// @param nameDescription Name of the mandate
    /// @param inputParams Input parameters for the mandate
    /// @param config Configurations parameters for the mandate
    function initializeMandate(
        uint16 index,
        string memory nameDescription,
        bytes memory inputParams,
        bytes memory config
    ) external;

    /// @notice Executes the mandate's logic after validation
    /// @dev Called by the Powers protocol during action execution
    /// @param caller Address that initiated the action
    /// @param mandateId The id of the mandate
    /// @param mandateCalldata Encoded function call data
    /// @param nonce The nonce for the action
    /// @return success True if execution succeeded
    function executeMandate(address caller, uint16 mandateId, bytes calldata mandateCalldata, uint256 nonce)
        external
        returns (bool success);

    /// @notice Simulates the mandate's execution logic
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
        external
        view
        returns (uint256 actionId, address[] memory targets, uint256[] memory values, bytes[] memory calldatas);
}
