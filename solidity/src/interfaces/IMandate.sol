// SPDX-License-Identifier: MIT

/// @title Mandate Interface - Contract Interface for Powers Protocol Mandates
/// @notice Interface for the Mandate contract, which provides core functionality for institutional mandates.
/// @dev Defines the interface for implementing role restricted conditional powers to transform input data into executable calldata.
/// @author 7Cedars
pragma solidity ^0.8.26;

import { IERC165 } from "@lib/openzeppelin-contracts/contracts/utils/introspection/IERC165.sol";

interface IMandate is IERC165 {
    //////////////////////////////////////////////////////////////
    //                        ERRORS                            //
    //////////////////////////////////////////////////////////////

    error OnlyPowers();

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
    /// @param config Configurations parameters for the mandate
    event Mandate__Initialized(
        address indexed powers, uint16 indexed index, string nameDescription, bytes inputParams, bytes config
    );

    /// @notice Emitted when an async mandate is initialized
    /// @param powers Address of the Powers protocol
    /// @param index Index of the mandate
    /// @param nameDescription Name of the mandate
    /// @param inputParams Input parameters for the mandate
    /// @param config Configurations parameters for the mandate
    /// @param oracle Address of the oracle for the async mandate
    event AsyncMandate__Initialized(
        address indexed powers,
        uint16 indexed index,
        string nameDescription,
        bytes inputParams,
        bytes config,
        address oracle
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
        bytes calldata mandateCalldata,
        uint256 nonce
    )
        external
        view
        returns (uint256 actionId, address[] memory targets, uint256[] memory values, bytes[] memory calldatas);

    //////////////////////////////////////////////////////////////
    //                       GETTERS                            //
    //////////////////////////////////////////////////////////////

    /// @notice Retrieves the name and description for a specific mandate
    /// @param powers Address of the Powers protocol
    /// @param mandateId The id of the mandate
    /// @return nameDescription The name and description of the mandate
    function getNameDescription(address powers, uint16 mandateId) external view returns (string memory nameDescription);

    /// @notice Retrieves the input parameters for a specific mandate
    /// @param powers Address of the Powers protocol
    /// @param mandateId The id of the mandate
    /// @return inputParams The input parameters for the mandate
    function getInputParams(address powers, uint16 mandateId) external view returns (bytes memory inputParams);

    /// @notice Retrieves the configuration for a specific mandate
    /// @param powers Address of the Powers protocol
    /// @param mandateId The id of the mandate
    /// @return config The configuration data for the mandate
    function getConfig(address powers, uint16 mandateId) external view returns (bytes memory config);

    /// @notice Retrieves the version of the mandate contract
    /// @return major The major version number
    /// @return minor The minor version number
    /// @return patch The patch version number
    function version() external pure returns (uint16 major, uint16 minor, uint16 patch);

    /// @notice The developer-set adoption price of this mandate, denominated in credits (0 = free).
    /// @dev Declared by the mandate itself (like version()), so the registry owner cannot alter it.
    ///      The registry converts credits to wei at adoption time via its owner-set weiPerCredit rate.
    /// @return price The adoption price in credits.
    function priceInCredits() external view returns (uint256 price);

    /// @notice The developer payees that receive the paid portion of a priced adoption.
    /// @dev Declared by the mandate itself. The paid portion (after protocol fee) is split equally,
    ///      with any indivisible remainder wei going to the first payee. Must be non-empty if priced.
    /// @return payees The developer payee addresses.
    function devs() external view returns (address[] memory payees);
}
