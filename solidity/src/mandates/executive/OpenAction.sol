// SPDX-License-Identifier: MIT

/// @notice A base contract that executes a open action.
///
/// Note As the contract allows for any action to be executed, it severely limits the functionality of the Powers protocol.
/// - any role that has access to this mandate, can execute any function. It has full power of the DAO.
/// - if this mandate is restricted by PUBLIC_ROLE, it means that anyone has access to it. Which means that anyone is given the right to do anything through the DAO.
/// - The contract should always be used in combination with modifiers from {PowerModiifiers}.
///
/// The logic:
/// - the mandateCalldata includes targets[], values[], calldatas[] - that are sent straight to the Powers protocol without any checks.
///
/// @author 7Cedars,

pragma solidity 0.8.26;

import { Mandate } from "../../Mandate.sol";
import { MandateUtilities } from "../../libraries/MandateUtilities.sol";

// import { console2 } from "forge-std/console2.sol"; // remove before deploying

contract OpenAction is Mandate {
    /// @notice Constructor function for OpenAction contract.
    constructor() {
        emit Mandate__Deployed("");
    }

    function initializeMandate(
        uint16 index,
        string memory nameDescription,
        bytes memory inputParams,
        bytes memory config
    ) public override {
        // Set UI-exposed input parameters: targets, values, calldatas
        inputParams = abi.encode("address[] targets", "uint256[] values", "bytes[] calldatas");
        super.initializeMandate(index, nameDescription, inputParams, config);
    }

    /// @notice Execute the open action.
    /// @param mandateCalldata the calldata of the mandate
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
        // note: no check on decoded call data. If needed, this can be added.
        (targets, values, calldatas) = abi.decode(mandateCalldata, (address[], uint256[], bytes[]));
        return (actionId, targets, values, calldatas);
    }
}
