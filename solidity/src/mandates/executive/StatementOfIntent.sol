// SPDX-License-Identifier: MIT

/// @notice A base contract that takes an input but does not execute any logic.
///
/// The logic:
/// - the mandateCalldata includes targets[], values[], calldatas[] - that are sent straight to the Powers protocol without any checks.
/// - the mandateCalldata is not executed.
///
/// @author 7Cedars,

pragma solidity 0.8.26;

import { Mandate } from "../../Mandate.sol";
import { MandateUtilities } from "../../libraries/MandateUtilities.sol";

contract StatementOfIntent is Mandate {
    /// @notice Constructor function for StatementOfIntent mandate
    constructor() {
        // This mandate does not require config; it forwards user-provided calls.
        // Expose expected input parameters for UIs.
        bytes memory configParams = abi.encode("string[] inputParams");
        emit Mandate__Deployed(configParams);
    }

    function initializeMandate(
        uint16 index,
        string memory nameDescription,
        bytes memory inputParams,
        bytes memory config
    ) public override {
        inputParams = config;

        super.initializeMandate(index, nameDescription, inputParams, config);
    }

    /// @notice Return calls provided by the user without modification
    /// @param mandateCalldata The calldata containing targets, values, and calldatas arrays
    /// @return actionId The unique action identifier
    /// @return targets Array of target contract addresses
    /// @return values Array of ETH values to send
    /// @return calldatas Array of calldata for each call
    function handleRequest(
        address, /*caller*/
        address, /*powers*/
        uint16 mandateId,
        bytes memory mandateCalldata,
        uint256 nonce
    )
        public
        pure
        override
        returns (uint256 actionId, address[] memory targets, uint256[] memory values, bytes[] memory calldatas)
    {
        actionId = MandateUtilities.computeActionId(mandateId, mandateCalldata, nonce);
        (targets, values, calldatas) = MandateUtilities.createEmptyArrays(1);
        return (actionId, targets, values, calldatas);
    }
}
