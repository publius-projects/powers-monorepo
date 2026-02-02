// SPDX-License-Identifier: MIT

/// @notice Adopt a set of mandates configured at initialization.
/// RoleIds are dynamic. 
/// @dev Builds calls to `IPowers.adoptMandate` for each configured mandate. No self-destruction occurs.
///
/// @author 7Cedars

pragma solidity 0.8.26;

import { Mandate } from "../../Mandate.sol";
import { MandateUtilities } from "../../libraries/MandateUtilities.sol";
import { IPowers } from "../../interfaces/IPowers.sol";
import { PowersTypes } from "../../interfaces/PowersTypes.sol";

contract Mandates_Prepackaged is Mandate {
    constructor() {
        bytes memory configParams = abi.encode("MandateInitData[] MandatesToAdopt");
        emit Mandate__Deployed("");
    }

    function initializeMandate(
        uint16 index,
        string memory nameDescription,
        bytes memory inputParams,
        bytes memory config
    ) public override {
        inputParams = abi.encode("uint256[] roleIds");
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
        view
        override
        returns (uint256 actionId, address[] memory targets, uint256[] memory values, bytes[] memory calldatas)
    {
        actionId = MandateUtilities.computeActionId(mandateId, mandateCalldata, nonce);
        PowersTypes.MandateInitData[] memory initData = abi.decode(getConfig(powers, mandateId), (PowersTypes.MandateInitData[])); 
        uint256 mandateCount = IPowers(powers).getMandateCounter();

        (uint256[] memory roleIds) = abi.decode(mandateCalldata, (uint256[]));

        for (uint256 i = 0; i < initData.length; i++) {
            // this will give an ugly revert if the roleId index is out of bounds
            initData[i].conditions.allowedRole = roleIds[initData[i].conditions.allowedRole]; // replaces placeholder with actual roleId
            // Let's see if this is going to work.. 
            if (initData[i].conditions.needFulfilled != 0)  {
                initData[i].conditions.needFulfilled = uint16(initData[i].conditions.needFulfilled + mandateCount); // adjust needFulfilled to current mandate count
            } 
            if (initData[i].conditions.needNotFulfilled != 0) {
                initData[i].conditions.needNotFulfilled = uint16(initData[i].conditions.needNotFulfilled + mandateCount); // adjust needNotFulfilled to current mandate count
            }
        }

        // Create arrays for the calls to adoptMandate
        (targets, values, calldatas) = MandateUtilities.createEmptyArrays(initData.length);

        for (uint256 i; i < initData.length; i++) {
            targets[i] = powers;
            calldatas[i] = abi.encodeWithSelector(IPowers.adoptMandate.selector, initData[i]);
        }
        return (actionId, targets, values, calldatas);
    }
}
