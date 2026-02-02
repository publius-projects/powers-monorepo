// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import { Mandate } from "../../Mandate.sol";
import { MandateUtilities } from "../../libraries/MandateUtilities.sol";
import { IPowers } from "../../interfaces/IPowers.sol";

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

    constructor() {
        bytes memory configParams = abi.encode("address externalPowers", "uint256 roleId");
        emit Mandate__Deployed(configParams);
    }

    function initializeMandate(uint16 index, string memory nameDescription, bytes memory, bytes memory config)
        public
        override
    {
        // Define the input parameters for the UI
        bytes memory inputParams = abi.encode("address account");
        super.initializeMandate(index, nameDescription, inputParams, config);
    }

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
