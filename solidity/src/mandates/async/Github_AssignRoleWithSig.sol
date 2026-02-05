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
 * @notice Assigns a role to a user after verification of a GitHub signature via Github_ClaimRoleWithSig.
 *
 * This mandate works in tandem with Github_ClaimRoleWithSig.
 * 1. It checks if the `Github_ClaimRoleWithSig` mandate (linked via `needFulfilled` condition) has successfully verified a user's GitHub signature.
 * 2. If verified, it resets the verification status on `Github_ClaimRoleWithSig` (preventing replay) and assigns the role on `Powers`.
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
    /// @notice Constructor for Github_AssignRoleWithSig
    constructor() {
        // Define the parameters required to configure this mandate
        bytes memory configParams = abi.encode();
        emit Mandate__Deployed(configParams);
    }

    // --- Mandate Initialization ---
    /// @notice Initialize the mandate with configuration
    /// @param index The index of the mandate in the Powers contract
    /// @param nameDescription The name and description of the mandate
    /// @param inputParams The input parameters for the mandate (roleId, commitHash)
    /// @param config The configuration bytes (empty for this mandate)
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
    /// @notice Process a request to assign a role
    /// @param caller The user requesting the role
    /// @param powers The Powers contract address
    /// @param mandateId The mandate identifier
    /// @param mandateCalldata The calldata containing roleId and commitHash
    /// @param nonce The nonce for the action
    /// @return actionId The computed action ID
    /// @return targets The target addresses for execution
    /// @return values The ETH values for execution
    /// @return calldatas The calldata for execution
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
