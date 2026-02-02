// SPDX-License-Identifier: MIT

/// @notice Adopt a set of mandates configured at initialization.
/// @dev Builds calls to `IPowers.adoptMandate` for each configured mandate. No self-destruction occurs.
///
/// @author 7Cedars,

pragma solidity 0.8.26;

import { Mandate } from "../../Mandate.sol";
import { MandateUtilities } from "../../libraries/MandateUtilities.sol";
import { IPowers } from "../../interfaces/IPowers.sol";
import { PowersTypes } from "../../interfaces/PowersTypes.sol";

contract Mandates_Adopt is Mandate {
    constructor() {
        emit Mandate__Deployed("");
    }

    function initializeMandate(
        uint16 index,
        string memory nameDescription,
        bytes memory inputParams,
        bytes memory config
    ) public override {
        inputParams = abi.encode("address[] mandateAddress", "uint256[] roleIds");
        super.initializeMandate(index, nameDescription, inputParams, config);
    }

    /// @notice Build calls to adopt the configured mandates
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

        (address[] memory mandates_, uint256[] memory roleIds_) = abi.decode(mandateCalldata, (address[], uint256[]));

        // Create arrays for the calls to adoptMandate
        uint256 length = mandates_.length;
        (targets, values, calldatas) = MandateUtilities.createEmptyArrays(length);
        PowersTypes.Conditions memory conditions;

        for (uint256 i; i < length; i++) {
            conditions.allowedRole = roleIds_[i];
            PowersTypes.MandateInitData memory mandateInitData = PowersTypes.MandateInitData({
                nameDescription: "Reform mandate",
                targetMandate: mandates_[i],
                config: abi.encode(),
                conditions: conditions
            });
            targets[i] = powers;
            calldatas[i] = abi.encodeWithSelector(IPowers.adoptMandate.selector, mandateInitData);
        }
        return (actionId, targets, values, calldatas);
    }
}
