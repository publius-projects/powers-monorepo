// SPDX-License-Identifier: MIT

/// @notice Revoke a set of mandates configured at initialization.
/// @dev Builds calls to `IPowers.revokeMandate` for each configured mandate. No self-destruction occurs.
///
/// @author 7Cedars,

pragma solidity 0.8.26;

import { Mandate } from "../../Mandate.sol";
import { MandateUtilities } from "../../libraries/MandateUtilities.sol";
import { IPowers } from "../../interfaces/IPowers.sol";

contract Mandates_Revoke is Mandate {
    constructor() {
        bytes memory configParams = abi.encode();
        emit Mandate__Deployed(configParams);
    }

    function initializeMandate(
        uint16 index,
        string memory nameDescription,
        bytes memory inputParams,
        bytes memory config
    ) public override {
        inputParams = abi.encode("uint16[] mandateIds");
        super.initializeMandate(index, nameDescription, inputParams, config);
    }

    /// @notice Build calls to revoke the configured mandates
    /// @param mandateCalldata Unused for this mandate
    function handleRequest(
        address,
        /*caller*/
        address powers,
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

        (uint16[] memory mandateIds_) = abi.decode(mandateCalldata, (uint16[]));

        // Create arrays for the calls to revokeMandate
        uint256 length = mandateIds_.length;
        (targets, values, calldatas) = MandateUtilities.createEmptyArrays(length);
        for (uint256 i; i < length; i++) {
            targets[i] = powers;
            calldatas[i] = abi.encodeWithSelector(IPowers.revokeMandate.selector, mandateIds_[i]);
        }
        return (actionId, targets, values, calldatas);
    }
}
