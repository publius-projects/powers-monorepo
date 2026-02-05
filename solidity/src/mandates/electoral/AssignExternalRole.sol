// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import { Mandate } from "../../Mandate.sol";
import { MandateUtilities } from "../../libraries/MandateUtilities.sol";
import { IPowers } from "../../interfaces/IPowers.sol";

/**
 * @title AssignExternalRole
 * @notice Synchronizes a role assignment from an external (Parent) Powers contract to this (Child) Powers contract.
 *
 * Logic:
 * - Checks if an account has a specific role in an external Powers contract ("Parent").
 * - Checks if the account has the same role in the current Powers contract ("Child").
 * - If Parent=Yes and Child=No: Assigns role in Child.
 * - If Parent=No and Child=Yes: Revokes role in Child.
 * - If statuses match, it reverts (no action needed).
 */
contract AssignExternalRole is Mandate {
    struct Mem {
        address account;
        address externalPowersAddress;
        uint256 roleId;
        uint48 hasRoleInChild;
        uint48 hasRoleInParent;
        bool A;
        bool B;
    }

    /// @notice Constructor
    constructor() {
        bytes memory configParams = abi.encode("address externalPowers", "uint256 roleId");
        emit Mandate__Deployed(configParams);
    }

    /// @notice Initialize the mandate
    /// @param index The index of the mandate in the Powers contract
    /// @param nameDescription Name and description
    /// @param config Configuration bytes (externalPowers, roleId)
    function initializeMandate(uint16 index, string memory nameDescription, bytes memory, bytes memory config)
        public
        override
    {
        // Define the input parameters for the UI
        bytes memory inputParams = abi.encode("address account");
        super.initializeMandate(index, nameDescription, inputParams, config);
    }

    /// @notice Process a request to synchronize a role
    /// @param powers The Powers contract address
    /// @param mandateId The mandate identifier
    /// @param mandateCalldata The calldata containing the account to check
    /// @param nonce The nonce for the action
    /// @return actionId The computed action ID
    /// @return targets The target addresses for execution
    /// @return values The ETH values for execution
    /// @return calldatas The calldata for execution
    function handleRequest(
        address, /*caller*/
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
        Mem memory mem;
        (mem.account) = abi.decode(mandateCalldata, (address));
        (mem.externalPowersAddress, mem.roleId) = abi.decode(getConfig(powers, mandateId), (address, uint256));

        // A: Check if the account has the role in the Child contract (current Powers contract)
        mem.hasRoleInChild = IPowers(powers).hasRoleSince(mem.account, mem.roleId);
        mem.A = mem.hasRoleInChild > 0;

        // B: Check if the account has the role in the Parent contract (external Powers contract)
        mem.hasRoleInParent = IPowers(mem.externalPowersAddress).hasRoleSince(mem.account, mem.roleId);
        mem.B = mem.hasRoleInParent > 0;

        // Prepare the action ID
        actionId = MandateUtilities.computeActionId(mandateId, mandateCalldata, nonce);

        // Handle the four scenarios
        if (mem.A && !mem.B) {
            // A == true and B == false: revoke role in child contract
            (targets, values, calldatas) = MandateUtilities.createEmptyArrays(1);
            targets[0] = powers;
            calldatas[0] = abi.encodeWithSelector(IPowers.revokeRole.selector, mem.roleId, mem.account);
        } else if (!mem.A && mem.B) {
            // B == true and A == false: assign role in child contract
            (targets, values, calldatas) = MandateUtilities.createEmptyArrays(1);
            targets[0] = powers;
            calldatas[0] = abi.encodeWithSelector(IPowers.assignRole.selector, mem.roleId, mem.account);
        } else if (!mem.A && !mem.B) {
            // A == false and B == false: revert
            revert("Account does not have role at parent");
        } else {
            // A == true and B == true: revert
            revert("Account already has role at parent");
        }

        return (actionId, targets, values, calldatas);
    }
}
