// SPDX-License-Identifier: MIT

/// @notice Revoke roles from all accounts when the number of flagged actions exceeds a threshold.
///
/// The logic:
/// - Counts flagged actions for a specific roleId from FlagActions contract.
/// - If the count exceeds numberOfStrikes, revokes the role from all current holders.
/// - Resets the flagged actions after revocation.
///
/// @author 7Cedars

pragma solidity 0.8.26;

import { Mandate } from "../../Mandate.sol";
import { IPowers } from "../../interfaces/IPowers.sol";
import { MandateUtilities } from "../../libraries/MandateUtilities.sol";
import { FlagActions } from "../../helpers/FlagActions.sol";

// import "forge-std/console2.sol"; // only for testing purposes. Comment out for production.

contract NStrikesRevokesRoles is Mandate {
    struct Mem {
        bytes32 mandateHash;
        uint256[] flaggedActionIds;
        address[] roleHolders;
        uint256 i;
        uint256 j;
        uint256 flaggedCount;
        uint256 amountRoleHolders;
        uint256 roleId;
        uint256 numberOfStrikes;
        address flagActionsAddress;
    }

    /// @notice Constructor for NStrikesRevokesRoles mandate
    constructor() {
        bytes memory configParams =
            abi.encode("uint256 roleId", "uint256 numberOfStrikes", "address flagActionsAddress");
        emit Mandate__Deployed(configParams);
    }

    /// @notice Build calls to revoke roles from all holders if strike threshold met
    /// @param powers The Powers contract address
    /// @param mandateId The mandate identifier
    /// @param mandateCalldata Not used for this mandate
    /// @param nonce Unique nonce to build the action id
    function handleRequest(
        address,
        /* caller */
        address powers,
        uint16 mandateId,
        bytes memory mandateCalldata,
        uint256 nonce
    )
        public
        view
        virtual
        override
        returns (uint256 actionId, address[] memory targets, uint256[] memory values, bytes[] memory calldatas)
    {
        Mem memory mem;
        actionId = MandateUtilities.computeActionId(mandateId, mandateCalldata, nonce);
        (mem.roleId, mem.numberOfStrikes, mem.flagActionsAddress) =
            abi.decode(getConfig(powers, mandateId), (uint256, uint256, address)); // just to silence compiler warning

        // Get flagged actions for the specific roleId from FlagActions contract
        mem.flaggedActionIds = FlagActions(mem.flagActionsAddress).getFlaggedActionsByRole(uint16(mem.roleId));
        // Check if we have enough strikes
        if (mem.flaggedActionIds.length < mem.numberOfStrikes) {
            revert("Not enough strikes to revoke roles.");
        }

        // Get all current role holders
        mem.amountRoleHolders = IPowers(payable(powers)).getAmountRoleHolders(mem.roleId);
        mem.roleHolders = new address[](mem.amountRoleHolders);
        for (uint256 i = 0; i < mem.amountRoleHolders; i++) {
            mem.roleHolders[i] = IPowers(payable(powers)).getRoleHolderAtIndex(mem.roleId, i);
        }

        // Set up calls to revoke roles from all holders
        (targets, values, calldatas) = MandateUtilities.createEmptyArrays(mem.amountRoleHolders);

        for (mem.i = 0; mem.i < mem.amountRoleHolders; mem.i++) {
            targets[mem.i] = powers;
            calldatas[mem.i] = abi.encodeWithSelector(IPowers.revokeRole.selector, mem.roleId, mem.roleHolders[mem.i]);
            mem.i++;
        }
        mem.i = 0;

        return (actionId, targets, values, calldatas);
    }

    /// @notice Check if the role should be revoked based on current flagged actions
    /// @param powers The Powers contract address
    /// @param mandateId The mandate identifier
    /// @return shouldRevoke True if the role should be revoked (enough strikes)
    function shouldRevokeRole(address powers, uint16 mandateId) external view returns (bool shouldRevoke) {
        Mem memory mem;
        (mem.roleId, mem.numberOfStrikes, mem.flagActionsAddress) =
            abi.decode(getConfig(powers, mandateId), (uint256, uint256, address)); // just to silence compiler warning

        uint256 flaggedCount = FlagActions(mem.flagActionsAddress).getFlaggedActionsCountByRole(uint16(mem.roleId));
        return flaggedCount >= mem.numberOfStrikes;
    }
}
