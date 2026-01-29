// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

// Base contracts
import { Mandate } from "../../Mandate.sol";
import { MandateUtilities } from "../../libraries/MandateUtilities.sol";
import { IPowers } from "../../interfaces/IPowers.sol";
import { PowersTypes } from "../../interfaces/PowersTypes.sol";

import { Github_ClaimRoleWithSig } from "./Github_ClaimRoleWithSig.sol";

/**
 * @title Github_AssignRoleWithSig
 * @notice to do
 *
 */

contract Github_AssignRoleWithSig is Mandate {
    // --- Mem struct for handleRequest ---
    // (This is just to avoid "stack too deep" errors)

    struct Mem {
        bytes32 mandateHash;
        bytes32 mandateHashClaimRole;
        address addressClaimRole;
        bool active;
        bytes errorMessage;
        uint256 roleId;
    }

    // --- Constructor ---
    constructor() {
        // Define the parameters required to configure this mandate
        bytes memory configParams = abi.encode();
        emit Mandate__Deployed(configParams);
    }

    // --- Mandate Initialization ---
    function initializeMandate(
        uint16 index,
        string memory nameDescription,
        bytes memory inputParams,
        bytes memory config
    ) public override {
        // Set input parameters for UI: same as Github_ClaimRoleWithSig.
        inputParams = abi.encode("uint256 roleId", "string commitHash");
        super.initializeMandate(index, nameDescription, inputParams, config);
    }

    // --- Mandate Execution (Request) ---
    function handleRequest(
        address caller, // The user requesting the role
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

        (mem.roleId,) = abi.decode(mandateCalldata, (uint256, string));

        // Hash the action
        actionId = MandateUtilities.computeActionId(mandateId, mandateCalldata, nonce);

        PowersTypes.Conditions memory conditions = IPowers(payable(powers)).getConditions(mandateId);
        if (conditions.needFulfilled == 0) {
            revert("Need fulfilled condition not set");
        }
        // step 2: retrieve address of ClaimRoleByGitCommit
        (mem.addressClaimRole, mem.mandateHashClaimRole, mem.active) =
            IPowers(payable(powers)).getAdoptedMandate(conditions.needFulfilled);
        if (!mem.active) {
            revert("Claim role mandate not active");
        }

        // step 3: retrieve data from chainlink reply - and reset data in the process.
        (mem.errorMessage, mem.roleId) =
            Github_ClaimRoleWithSig(mem.addressClaimRole).getLatestReply(mem.mandateHashClaimRole, caller);
        if (mem.errorMessage.length > 0) {
            revert("error in claiming role.");
        }

        // Note: we reset the reply so it cannot be used twice. Then we assign the role.
        (targets, values, calldatas) = MandateUtilities.createEmptyArrays(2);
        targets[0] = mem.addressClaimRole;
        targets[1] = powers;
        calldatas[0] = abi.encodeWithSelector(Github_ClaimRoleWithSig.resetReply.selector, powers, mandateId, caller);
        calldatas[1] = abi.encodeWithSelector(IPowers.assignRole.selector, mem.roleId, caller);

        return (actionId, targets, values, calldatas);
    }
}
