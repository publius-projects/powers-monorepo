// SPDX-License-Identifier: MIT

/// @title Checks - Checks for Powers Protocol
/// @notice A library of helper functions used across Powers contracts
/// @dev Provides common functionality for Powers implementation and validation
/// @author 7Cedars

pragma solidity 0.8.26;

import { Powers } from "../Powers.sol";
import { PowersTypes } from "../interfaces/PowersTypes.sol";

// import "forge-std/Test.sol"; // for testing only. remove before deployment.

library Checks {
    ////////////////////////////////////////////////////////////
    //                 ERRORS                                 //
    ////////////////////////////////////////////////////////////
    error Checks__ParentMandateNotFulfilled();
    error Checks__ParentMandateBlocksFulfillment();
    error Checks__ExecutionGapTooSmall();
    error Checks__ProposalNotSucceeded();
    error Checks__DeadlineNotPassed();

    /////////////////////////////////////////////////////////////
    //                  CHECKS                                 //
    /////////////////////////////////////////////////////////////
    /// @notice Runs checks before executing a mandate
    /// @param mandateId The id of the mandate
    /// @param mandateCalldata The calldata of the mandate
    /// @param powers The address of the Powers contract
    /// @param nonce The nonce of the mandate
    /// @param latestFulfillment The latest fulfillment of the mandate
    function check(
        uint16 mandateId,
        bytes memory mandateCalldata,
        address powers,
        uint256 nonce,
        uint48 latestFulfillment
    ) external view {
        PowersTypes.Conditions memory conditions = getConditions(powers, mandateId);
        // Check if parent mandate completion is required
        if (conditions.needFulfilled != 0) {
            PowersTypes.ActionState stateLog = Powers(payable(powers))
                .getActionState(computeActionId(conditions.needFulfilled, mandateCalldata, nonce));
            if (stateLog != PowersTypes.ActionState.Fulfilled) {
                revert Checks__ParentMandateNotFulfilled();
            }
        }

        // Check if parent mandate must not be completed
        if (conditions.needNotFulfilled != 0) {
            PowersTypes.ActionState stateLog = Powers(payable(powers))
                .getActionState(computeActionId(conditions.needNotFulfilled, mandateCalldata, nonce));
            if (stateLog == PowersTypes.ActionState.Fulfilled) {
                revert Checks__ParentMandateBlocksFulfillment();
            }
        }

        // Check execution throttling
        if (conditions.throttleExecution != 0) {
            if (latestFulfillment > 0 && block.number - latestFulfillment < conditions.throttleExecution) {
                revert Checks__ExecutionGapTooSmall();
            }
        }

        // Check if proposal vote succeeded
        if (conditions.quorum != 0) {
            if (
                Powers(payable(powers)).getActionState(computeActionId(mandateId, mandateCalldata, nonce))
                    != PowersTypes.ActionState.Succeeded
            ) {
                revert Checks__ProposalNotSucceeded();
            }
        }

        // Check execution delay after proposal
        if (conditions.timelock != 0) {
            (,, uint256 deadline,,,) =
                Powers(payable(powers)).getActionVoteData(computeActionId(mandateId, mandateCalldata, nonce));
            if (deadline + conditions.timelock > block.number) {
                revert Checks__DeadlineNotPassed();
            }
        }
    }

    /////////////////////////////////////////////////////////////
    //                  SIGNATURE VALIDATION                   //
    /////////////////////////////////////////////////////////////

    /////////////////////////////////////////////////////////////
    //                  HELPER FUNCTIONS                        //
    /////////////////////////////////////////////////////////////
    /// @notice Creates a unique identifier for an action
    /// @dev Hashes the combination of mandate address, calldata, and nonce
    /// @param mandateId Address of the mandate contract being called
    /// @param mandateCalldata Encoded function call data
    /// @param nonce The nonce for the action
    /// @return actionId Unique identifier for the action
    function computeActionId(uint16 mandateId, bytes memory mandateCalldata, uint256 nonce)
        public
        pure
        returns (uint256 actionId)
    {
        actionId = uint256(keccak256(abi.encode(mandateId, mandateCalldata, nonce)));
    }

    function getConditions(address powers, uint16 mandateId)
        public
        view
        returns (PowersTypes.Conditions memory conditions)
    {
        return Powers(payable(powers)).getConditions(mandateId);
    }
}
