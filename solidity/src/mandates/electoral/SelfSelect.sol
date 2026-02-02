// SPDX-License-Identifier: MIT

/// @notice Allows a caller to claim a specific role if they do not already hold it.
/// @dev The deployer configures a single roleId that can be self-assigned. Intended for
/// open onboarding flows where a base role can be freely claimed.
/// @author 7Cedars

pragma solidity 0.8.26;

import { Mandate } from "../../Mandate.sol";
import { IPowers } from "../../interfaces/IPowers.sol";
import { MandateUtilities } from "../../libraries/MandateUtilities.sol";

contract SelfSelect is Mandate {
    /// @notice Constructor for SelfSelect mandate
    constructor() {
        bytes memory configParams = abi.encode("uint256 RoleId");
        emit Mandate__Deployed(configParams);
    }

    /// @notice Build a call to assign the configured role to the caller if not already held
    /// @param caller The transaction originator (forwarded to assignment)
    /// @param powers The Powers contract address
    /// @param mandateId The mandate identifier
    /// @param mandateCalldata Not used for this mandate
    /// @param nonce Unique nonce to build the action id
    function handleRequest(
        address caller,
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
        (targets, values, calldatas) = MandateUtilities.createEmptyArrays(1);
        actionId = MandateUtilities.computeActionId(mandateId, mandateCalldata, nonce);
        uint256 roleId = abi.decode(getConfig(powers, mandateId), (uint256));

        if (IPowers(payable(powers)).hasRoleSince(caller, roleId) != 0) {
            revert("Account already has role.");
        }

        targets[0] = powers;
        calldatas[0] = abi.encodeWithSelector(IPowers.assignRole.selector, roleId, caller); // selector = assignRole

        return (actionId, targets, values, calldatas);
    }
}
