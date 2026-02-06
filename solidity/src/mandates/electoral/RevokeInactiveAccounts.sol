// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import { Mandate } from "../../Mandate.sol";
import { MandateUtilities } from "../../libraries/MandateUtilities.sol";
import { IPowers } from "../../interfaces/IPowers.sol";
import { PowersTypes } from "../../interfaces/PowersTypes.sol";

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
    }

    /// @notice Constructor
    constructor() {
        bytes memory configParams = abi.encode("uint256 RoleId", "uint256 minimumActionsNeeded", "uint256 numberActionsToCheck");
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
        bytes memory mandateCalldata,
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
        for (uint256 i = 0; i < mem.amountRoleHolders; i++) {
            mem.roleHolders[i] = IPowers(payable(powers)).getRoleHolderAtIndex(mem.roleId, i);
        }

        // 2. Find relevant mandates
        mem.mandateCounter = IPowers(payable(powers)).getMandateCounter();
        
        // Oversize array to max possible mandates, then track actual count
        uint16[] memory tempMandates = new uint16[](mem.mandateCounter);
        mem.relevantMandatesCount = 0;
        
        // Loop through all mandates to find those with the matching role
        for (uint16 i = 1; i < mem.mandateCounter; i++) {
            PowersTypes.Conditions memory conditions = IPowers(payable(powers)).getConditions(i);
            if (conditions.allowedRole == mem.roleId) {
                tempMandates[mem.relevantMandatesCount] = i;
                mem.relevantMandatesCount++;
            }
        }

        // 3 & 4. Get action counts and calculate total available actions
        mem.totalAvailableActions = 0;
        mem.mandateActionCounts = new uint256[](mem.relevantMandatesCount);
        
        for (uint256 i = 0; i < mem.relevantMandatesCount; i++) {
            uint16 mId = tempMandates[i];
            uint256 count = IPowers(payable(powers)).getQuantityMandateActions(mId);
            mem.mandateActionCounts[i] = count;
            mem.totalAvailableActions += count;
        }

        // 5. Make list of actionIds to check
        uint256 actualCheckCount = mem.numberActionsToCheck;
        if (actualCheckCount > mem.totalAvailableActions) {
            actualCheckCount = mem.totalAvailableActions;
        }
        
        mem.actionIdsToCheck = new uint256[](actualCheckCount); 
        mem.actionIdsToCheckCount = 0;

        if (mem.totalAvailableActions > 0) {
             for (uint256 i = 0; i < mem.relevantMandatesCount; i++) {
                uint16 mId = tempMandates[i];
                uint256 available = mem.mandateActionCounts[i];
                if (available == 0) continue;

                // Calculate relative number of actions to check from this mandate
                uint256 toCheckForMandate = (available * actualCheckCount) / mem.totalAvailableActions;
                if (toCheckForMandate > available) toCheckForMandate = available;

                // Retrieve the latest action IDs
                for (uint256 k = 0; k < toCheckForMandate; k++) {
                    if (mem.actionIdsToCheckCount < actualCheckCount) {
                        mem.actionIdsToCheck[mem.actionIdsToCheckCount] = IPowers(payable(powers)).getMandateActionAtIndex(mId, available - 1 - k);
                        mem.actionIdsToCheckCount++;
                    }
                }
            }
        }
        
        // 6. Check actions
        mem.observedActions = new uint256[](mem.amountRoleHolders);
        
        for (uint256 i = 0; i < mem.actionIdsToCheckCount; i++) {
            uint256 aId = mem.actionIdsToCheck[i];
            (,,,,, address actionCaller,) = IPowers(payable(powers)).getActionData(aId);
            
            for (uint256 h = 0; h < mem.amountRoleHolders; h++) {
                address holder = mem.roleHolders[h];
                
                // 6b: Check if address was caller
                if (holder == actionCaller) {
                    mem.observedActions[h]++;
                }
                
                // 6c: Check if address voted
                if (IPowers(payable(powers)).hasVoted(aId, holder)) {
                    mem.observedActions[h]++;
                }
            }
        }

        // 7. Revoke list
        mem.toRevoke = new address[](mem.amountRoleHolders);
        mem.revokeCount = 0;
        
        for (uint256 h = 0; h < mem.amountRoleHolders; h++) {
            if (mem.observedActions[h] < mem.minimumActionsNeeded) {
                mem.toRevoke[mem.revokeCount] = mem.roleHolders[h];
                mem.revokeCount++;
            }
        }
        
        if (mem.revokeCount == 0) {
            (targets, values, calldatas) = MandateUtilities.createEmptyArrays(1);
            return (actionId, targets, values, calldatas);
        }

        (targets, values, calldatas) = MandateUtilities.createEmptyArrays(mem.revokeCount);
        
        for (uint256 i = 0; i < mem.revokeCount; i++) {
            targets[i] = powers;
            calldatas[i] = abi.encodeWithSelector(IPowers.revokeRole.selector, mem.roleId, mem.toRevoke[i]);
        }

        return (actionId, targets, values, calldatas);
    }
}
