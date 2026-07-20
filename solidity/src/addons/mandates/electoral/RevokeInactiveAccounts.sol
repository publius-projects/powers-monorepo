// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import { Mandate } from "@src/Mandate.sol";
import { MandateUtilities } from "@src/libraries/MandateUtilities.sol";
import { IPowers } from "@src/interfaces/IPowers.sol";
import { PowersTypes } from "@src/interfaces/PowersTypes.sol";

/**
 * @title RevokeInactiveAccounts
 * @notice Revokes a specific role from accounts that have not participated in enough governance actions.
 *
 * Logic:
 * 1. Identifies all mandates that restrict actions to the specified role.
 * 2. Samples recent actions from these mandates.
 * 3. Checks if each role holder participated in these actions (either as the caller or a voter).
 * 4. Revokes the role from any account whose participation count is below the minimum threshold.
 */
contract RevokeInactiveAccounts is Mandate {
    struct Mem {
        uint256 roleId;
        uint256 minimumActionsNeeded;
        uint256 numberActionsToCheck;

        address[] roleHolders;
        uint256 amountRoleHolders;

        uint16 mandateCounter;
        uint16[] relevantMandates;
        uint256 relevantMandatesCount;

        uint256 totalAvailableActions;
        uint256[] mandateActionCounts;

        uint256[] actionIdsToCheck;
        uint256 actionIdsToCheckCount;

        uint256[] observedActions;

        uint256 revokeCount;
        address[] toRevoke;

        // Stack too deep mitigation: Loop variables and temps
        uint256 i;
        uint256 k;
        uint256 h;
        uint16 mId;
        uint256 count;
        uint16[] tempMandates;
        uint256 actualCheckCount;
        uint256 available;
        uint256 toCheckForMandate;
        uint256 aId;
        address actionCaller;
        address holder;
    }

    /// @notice Constructor
    constructor(address registry_) Mandate(registry_) {
        bytes memory configParams =
            abi.encode("uint256 RoleId", "uint256 minimumActionsNeeded", "uint256 numberActionsToCheck");
        emit Mandate__Deployed(configParams);
    }

    /// @notice Initialize the mandate
    function initializeMandate(uint16 index, string memory nameDescription, bytes memory, bytes memory config)
        public
        override
    {
        // No input params required by user
        bytes memory inputParams = "";
        super.initializeMandate(index, nameDescription, inputParams, config);
    }

    /// @notice Process a request to revoke inactive accounts
    /// @param powers The Powers contract address
    /// @param mandateId The mandate identifier
    /// @param mandateCalldata Unused (no input params)
    /// @param nonce The nonce for the action
    /// @return actionId The computed action ID
    /// @return targets The target addresses for execution
    /// @return values The ETH values for execution
    /// @return calldatas The calldata for execution
    function handleRequest(
        address, /*caller*/
        address powers,
        uint16 mandateId,
        bytes calldata mandateCalldata,
        uint256 nonce
    )
        public
        view
        override
        returns (uint256 actionId, address[] memory targets, uint256[] memory values, bytes[] memory calldatas)
    {
        Mem memory mem;

        // Config decoding
        (mem.roleId, mem.minimumActionsNeeded, mem.numberActionsToCheck) =
            abi.decode(getConfig(powers, mandateId), (uint256, uint256, uint256));

        actionId = MandateUtilities.computeActionId(mandateId, mandateCalldata, nonce);

        // 1. Retrieve role holders
        mem.amountRoleHolders = IPowers(payable(powers)).getAmountRoleHolders(mem.roleId);
        if (mem.amountRoleHolders == 0) {
            (targets, values, calldatas) = MandateUtilities.createEmptyArrays(1);
            return (actionId, targets, values, calldatas);
        }

        mem.roleHolders = new address[](mem.amountRoleHolders);
        for (mem.i = 0; mem.i < mem.amountRoleHolders; mem.i++) {
            mem.roleHolders[mem.i] = IPowers(payable(powers)).getRoleHolderAtIndex(mem.roleId, mem.i);
        }

        // 2. Find relevant mandates
        mem.mandateCounter = IPowers(payable(powers)).getMandateCounter();

        // Oversize array to max possible mandates, then track actual count
        mem.tempMandates = new uint16[](mem.mandateCounter);
        mem.relevantMandatesCount = 0;

        // Loop through all mandates to find those with the matching role
        // Note: mem.i reused here, assuming safe because type matches (uint16 cast to uint256 fine, wait i is uint256 in struct)
        // Mandate index is uint16. We can loop with uint16 but store in uint256 mem.i? Or just use mem.i
        for (uint16 mIdx = 1; mIdx < mem.mandateCounter; mIdx++) {
            PowersTypes.Conditions memory conditions = IPowers(payable(powers)).getConditions(mIdx);
            if (conditions.allowedRole == mem.roleId) {
                mem.tempMandates[mem.relevantMandatesCount] = mIdx;
                mem.relevantMandatesCount++;
            }
        }

        // 3 & 4. Get action counts and calculate total available actions
        mem.totalAvailableActions = 0;
        mem.mandateActionCounts = new uint256[](mem.relevantMandatesCount);

        for (mem.i = 0; mem.i < mem.relevantMandatesCount; mem.i++) {
            mem.mId = mem.tempMandates[mem.i];
            mem.count = IPowers(payable(powers)).getQuantityMandateActions(mem.mId);
            mem.mandateActionCounts[mem.i] = mem.count;
            mem.totalAvailableActions += mem.count;
        }

        // 5. Make list of actionIds to check
        mem.actualCheckCount = mem.numberActionsToCheck;
        if (mem.actualCheckCount > mem.totalAvailableActions) {
            mem.actualCheckCount = mem.totalAvailableActions;
        }

        mem.actionIdsToCheck = new uint256[](mem.actualCheckCount);
        mem.actionIdsToCheckCount = 0;

        if (mem.totalAvailableActions > 0) {
            for (mem.i = 0; mem.i < mem.relevantMandatesCount; mem.i++) {
                mem.mId = mem.tempMandates[mem.i];
                mem.available = mem.mandateActionCounts[mem.i];
                if (mem.available == 0) continue;

                // Calculate relative number of actions to check from this mandate
                mem.toCheckForMandate = (mem.available * mem.actualCheckCount) / mem.totalAvailableActions;
                if (mem.toCheckForMandate > mem.available) mem.toCheckForMandate = mem.available;

                // Retrieve the latest action IDs
                for (mem.k = 0; mem.k < mem.toCheckForMandate; mem.k++) {
                    if (mem.actionIdsToCheckCount < mem.actualCheckCount) {
                        mem.actionIdsToCheck[mem.actionIdsToCheckCount] =
                            IPowers(payable(powers)).getMandateActionAtIndex(mem.mId, mem.available - 1 - mem.k);
                        mem.actionIdsToCheckCount++;
                    }
                }
            }
        }

        // 6. Check actions
        mem.observedActions = new uint256[](mem.amountRoleHolders);

        for (mem.i = 0; mem.i < mem.actionIdsToCheckCount; mem.i++) {
            mem.aId = mem.actionIdsToCheck[mem.i];
            (,,,,, mem.actionCaller,) = IPowers(payable(powers)).getActionData(mem.aId);

            for (mem.h = 0; mem.h < mem.amountRoleHolders; mem.h++) {
                mem.holder = mem.roleHolders[mem.h];

                // 6b: Check if address was caller
                if (mem.holder == mem.actionCaller) {
                    mem.observedActions[mem.h]++;
                }

                // 6c: Check if address voted
                if (IPowers(payable(powers)).hasVoted(mem.aId, mem.holder)) {
                    mem.observedActions[mem.h]++;
                }
            }
        }

        // 7. Revoke list
        mem.toRevoke = new address[](mem.amountRoleHolders);
        mem.revokeCount = 0;

        for (mem.h = 0; mem.h < mem.amountRoleHolders; mem.h++) {
            if (mem.observedActions[mem.h] < mem.minimumActionsNeeded) {
                mem.toRevoke[mem.revokeCount] = mem.roleHolders[mem.h];
                mem.revokeCount++;
            }
        }

        if (mem.revokeCount == 0) {
            (targets, values, calldatas) = MandateUtilities.createEmptyArrays(1);
            return (actionId, targets, values, calldatas);
        }

        (targets, values, calldatas) = MandateUtilities.createEmptyArrays(mem.revokeCount);

        for (mem.i = 0; mem.i < mem.revokeCount; mem.i++) {
            targets[mem.i] = powers;
            calldatas[mem.i] = abi.encodeWithSelector(IPowers.revokeRole.selector, mem.roleId, mem.toRevoke[mem.i]);
        }

        return (actionId, targets, values, calldatas);
    }
}
