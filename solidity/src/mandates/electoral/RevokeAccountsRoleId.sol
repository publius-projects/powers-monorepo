// SPDX-License-Identifier: MIT

/// @notice Revokes a specific role from all accounts that currently hold it.
/// @dev Takes a roleId as configuration. When executed, it finds all holders of that role
/// and queues revocation calls for all of them.
/// @author 7Cedars

pragma solidity 0.8.26;

import { Mandate } from "../../Mandate.sol";
import { IPowers } from "../../interfaces/IPowers.sol";
import { MandateUtilities } from "../../libraries/MandateUtilities.sol";

contract RevokeAccountsRoleId is Mandate {
    struct Mem {
        uint256 roleId;
        uint256 amountRoleHolders;
        address[] roleHolders;
        uint256 i;
    }

    /// @notice Constructor for RevokeAccountsRoleId mandate
    constructor() {
        bytes memory configParams = abi.encode("uint256 RoleId", "string[] InputParams");
        emit Mandate__Deployed(configParams);
    }

    /// @notice Initialize the mandate with the given parameters
    function initializeMandate(
        uint16 index,
        string memory nameDescription,
        bytes memory inputParams,
        bytes memory config
    ) public override {
        (, string[] memory inputParams_) = abi.decode(config, (uint256, string[]));
        super.initializeMandate(index, nameDescription, abi.encode(inputParams_), config);
    }

    /// @notice Handle the request to revoke roles
    function handleRequest(
        address, /* caller */
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
        
        // Decode configuration
        (mem.roleId, ) = abi.decode(getConfig(powers, mandateId), (uint256, string[]));
        
        // Compute action ID
        actionId = MandateUtilities.computeActionId(mandateId, mandateCalldata, nonce);

        // Get current role holders
        mem.amountRoleHolders = IPowers(payable(powers)).getAmountRoleHolders(mem.roleId);
        
        // If no role holders, return empty arrays
        if (mem.amountRoleHolders == 0) {
            (targets, values, calldatas) = MandateUtilities.createEmptyArrays(1);
            return (actionId, targets, values, calldatas);
        }

        mem.roleHolders = new address[](mem.amountRoleHolders);
        for (mem.i = 0; mem.i < mem.amountRoleHolders; mem.i++) {
            mem.roleHolders[mem.i] = IPowers(payable(powers)).getRoleHolderAtIndex(mem.roleId, mem.i);
        }

        // Prepare revocation calls
        (targets, values, calldatas) = MandateUtilities.createEmptyArrays(mem.amountRoleHolders);

        for (mem.i = 0; mem.i < mem.amountRoleHolders; mem.i++) {
            targets[mem.i] = powers;
            calldatas[mem.i] = abi.encodeWithSelector(
                IPowers.revokeRole.selector, 
                mem.roleId, 
                mem.roleHolders[mem.i]
            );
        }

        return (actionId, targets, values, calldatas);
    }
}
