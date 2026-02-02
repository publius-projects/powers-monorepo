// SPDX-License-Identifier: MIT

/// @notice Allows a caller to renounce specific roles they currently hold.
/// @dev The deployer configures which roleIds are allowed to be renounced. The mandate validates
/// the caller holds the role and that it is eligible for renouncement, then emits a revoke call.
/// @author 7Cedars

pragma solidity 0.8.26;

import { Mandate } from "../../Mandate.sol";
import { IPowers } from "../../interfaces/IPowers.sol";
import { MandateUtilities } from "../../libraries/MandateUtilities.sol";

contract RenounceRole is Mandate {
    struct Mem {
        uint256 roleId;
        uint256 i;
        bool allowed;
        uint256[] allowedRoleIds;
    }

    /// @notice Constructor for RenounceRole mandate
    constructor() {
        bytes memory configParams = abi.encode("uint256[] allowedRoleIds");
        emit Mandate__Deployed(configParams);
    }

    function initializeMandate(
        uint16 index,
        string memory nameDescription,
        bytes memory inputParams,
        bytes memory config
    ) public override {
        inputParams = abi.encode("uint256 roleId");
        super.initializeMandate(index, nameDescription, inputParams, config);
    }

    function handleRequest(
        address caller,
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
        // step 1: decode the calldata
        mem.roleId = abi.decode(mandateCalldata, (uint256));
        mem.allowedRoleIds = abi.decode(getConfig(powers, mandateId), (uint256[]));

        // step 2: check if the account has the role
        if (IPowers(payable(powers)).hasRoleSince(caller, mem.roleId) == 0) {
            revert("Account does not have role.");
        }

        // step 3: check if the role is allowed to be renounced
        mem.allowed = false;
        for (mem.i = 0; mem.i < mem.allowedRoleIds.length; mem.i++) {
            if (mem.roleId == mem.allowedRoleIds[mem.i]) {
                mem.allowed = true;
                break;
            }
        }
        if (!mem.allowed) {
            revert("Role not allowed to be renounced.");
        }

        // step 4: create & send return calldata (revoke action)
        (targets, values, calldatas) = MandateUtilities.createEmptyArrays(1);
        actionId = MandateUtilities.computeActionId(mandateId, mandateCalldata, nonce);
        targets[0] = powers;
        calldatas[0] = abi.encodeWithSelector(IPowers.revokeRole.selector, mem.roleId, caller); // selector = revokeRole

        return (actionId, targets, values, calldatas);
    }

    function getAllowedRoleIds(bytes32 mandateHash) public view returns (uint256[] memory) {
        bytes memory configBytes = mandates[mandateHash].config;
        return abi.decode(configBytes, (uint256[]));
    }
}
