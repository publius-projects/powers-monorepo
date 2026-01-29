// SPDX-License-Identifier: MIT

/// @title Powers Protocol Interface
/// @notice Interface for Powers, a protocol implementing Institutional Governance.
/// @dev Derived from OpenZeppelin's Governor.sol contract and Haberdasher Labs Hats protocol.
/// @author 7Cedars
pragma solidity 0.8.26;

import { PowersErrors } from "./PowersErrors.sol";
import { PowersEvents } from "./PowersEvents.sol";
import { PowersTypes } from "./PowersTypes.sol";

interface IPowers is PowersErrors, PowersEvents, PowersTypes {
    //////////////////////////////////////////////////////////////
    //                  CONSTITUTE LOGIC                        //
    //////////////////////////////////////////////////////////////
    /// @notice Initializes the DAO by activating its founding mandates
    /// @dev Can only be called once by an admin account
    /// @param mandates The list of mandate contracts to activate
    function constitute(MandateInitData[] calldata mandates) external;

    /// @notice Initializes the DAO by activating its founding mandates and setting a new admin
    /// @dev Can only be called once by an admin account
    /// @param mandates The list of mandate contracts to activate
    /// @param newAdmin The address of the new admin
    function constitute(MandateInitData[] calldata mandates, address newAdmin) external;

    //////////////////////////////////////////////////////////////
    //                  GOVERNANCE FUNCTIONS                    //
    //////////////////////////////////////////////////////////////

    /// @notice Initiates an action to be executed through a mandate
    /// @dev This is the entry point for all actions in the protocol, whether they require voting or not
    /// @param mandateId The id of the mandate
    /// @param mandateCalldata The encoded function call data for the mandate
    /// @param uriDescription A human-readable description of the action
    /// @param nonce The nonce for the action
    function request(uint16 mandateId, bytes calldata mandateCalldata, uint256 nonce, string memory uriDescription)
        external
        returns (uint256 actionId);

    /// @notice Completes an action by executing the actual calls
    /// @dev Can only be called by an active mandate contract
    /// @param mandateId The id of the mandate
    /// @param actionId The unique identifier of the action
    /// @param targets The list of contract addresses to call
    /// @param values The list of ETH values to send with each call
    /// @param calldatas The list of encoded function calls
    function fulfill(
        uint16 mandateId,
        uint256 actionId,
        address[] calldata targets,
        uint256[] calldata values,
        bytes[] calldata calldatas
    ) external;

    /// @notice Creates a new proposal for an action that requires voting
    /// @dev Only callable if the mandate requires voting (quorum > 0)
    /// @dev note that no checks are run. If account has acces to mandate and it requires a vote - the account wil be able to create proposals.
    /// @param mandateId The id of the mandate
    /// @param mandateCalldata The encoded function call data for the mandate
    /// @param nonce The nonce for the action
    /// @param uriDescription A human-readable description of the proposal
    /// @return actionId The unique identifier of the created proposal
    function propose(uint16 mandateId, bytes calldata mandateCalldata, uint256 nonce, string memory uriDescription)
        external
        returns (uint256 actionId);

    /// @notice Cancels an existing proposal
    /// @dev Can only be called by the original proposer
    /// @param mandateId The id of the mandate
    /// @param mandateCalldata The original encoded function call data
    /// @param nonce The nonce for the action
    /// @return actionId The unique identifier of the cancelled proposal
    function cancel(uint16 mandateId, bytes calldata mandateCalldata, uint256 nonce) external returns (uint256 actionId);

    /// @notice Casts a vote on an active proposal
    /// @dev Vote types: 0=Against, 1=For, 2=Abstain
    /// @param actionId The unique identifier of the proposal
    /// @param support The type of vote to cast
    function castVote(uint256 actionId, uint8 support) external;

    /// @notice Casts a vote on an active proposal with an explanation
    /// @dev Same as castVote but includes a reason string
    /// @param actionId The unique identifier of the proposal
    /// @param support The type of vote to cast
    /// @param reason A human-readable explanation for the vote
    function castVoteWithReason(uint256 actionId, uint8 support, string calldata reason) external;

    //////////////////////////////////////////////////////////////
    //                  ROLE AND LAW ADMIN                       //
    //////////////////////////////////////////////////////////////
    /// @notice Activates a new mandate in the protocol
    /// @dev Can only be called through the protocol itself
    /// @param mandateInitData The data of the mandate
    function adoptMandate(MandateInitData calldata mandateInitData) external returns (uint16 mandateId);

    /// @notice Deactivates an existing mandate
    /// @dev Can only be called through the protocol itself
    /// @param mandateId The id of the mandate
    function revokeMandate(uint16 mandateId) external;

    /// @notice Grants a role to an account
    /// @dev Can only be called through the protocol itself
    /// @param roleId The identifier of the role to assign
    /// @param account The address to grant the role to
    function assignRole(uint256 roleId, address account) external;

    /// @notice Removes a role from an account
    /// @dev Can only be called through the protocol itself
    /// @param roleId The identifier of the role to remove
    /// @param account The address to remove the role from
    function revokeRole(uint256 roleId, address account) external;

    /// @notice Assigns a human-readable label to a role
    /// @dev Optional. Can only be called through the protocol itself
    /// @param roleId The identifier of the role to label
    /// @param label The human-readable label for the role
    function labelRole(uint256 roleId, string calldata label) external;

    /// @notice Updates the protocol's metadata URI
    /// @dev Can only be called through the protocol itself
    /// @param newUri The new URI string
    function setUri(string memory newUri) external;

    /// @notice Sets the treasury address
    /// @dev Can only be called through the protocol itself
    /// @param newTreasury The new treasury address
    function setTreasury(address payable newTreasury) external;

    /// @notice Blacklists an account
    /// @dev Can only be called through the protocol itself
    /// @param account The address to blacklist
    /// @param blacklisted The blacklisted status of the account
    function blacklistAddress(address account, bool blacklisted) external;

    //////////////////////////////////////////////////////////////
    //                      VIEW FUNCTIONS                       //
    //////////////////////////////////////////////////////////////
    /// @notice Gets the quantity of actions of a mandate
    /// @param mandateId The id of the mandate
    /// @return quantityMandateActions The quantity of actions of the mandate
    function getQuantityMandateActions(uint16 mandateId) external view returns (uint256 quantityMandateActions);

    /// @notice Gets the current state of a proposal
    /// @param actionId The unique identifier of the proposal
    /// @return state the current state of the proposal
    function getActionState(uint256 actionId) external view returns (ActionState state);

    /// @notice Checks if an account has voted on a specific proposal
    /// @param actionId The unique identifier of the proposal
    /// @param account The address to check
    /// @return hasVoted True if the account has voted, false otherwise
    function hasVoted(uint256 actionId, address account) external view returns (bool hasVoted);

    /// @notice gets the data of an actionId that are not an array.
    /// @param actionId The unique identifier of the proposal
    /// @return mandateId - the id of the mandate that the action is associated with
    /// @return proposedAt - the block number at which the action was proposed
    /// @return requestedAt - the block number at which the action was requested
    /// @return fulfilledAt - the block number at which the action was fulfilled
    /// @return cancelledAt - the block number at which the action was cancelled
    /// @return caller - the address of the caller
    /// @return nonce - the nonce of the action
    function getActionData(uint256 actionId)
        external
        view
        returns (
            uint16 mandateId,
            uint48 proposedAt,
            uint48 requestedAt,
            uint48 fulfilledAt,
            uint48 cancelledAt,
            address caller,
            uint256 nonce
        );

    /// @notice gets the vote data of an actionId that are not an array.
    /// @param actionId The unique identifier of the proposal
    /// @return voteStart - the block number at which voting starts
    /// @return voteDuration - the duration of the voting period
    /// @return voteEnd - the block number at which voting ends
    /// @return againstVotes - the number of votes against the action
    /// @return forVotes - the number of votes for the action
    /// @return abstainVotes - the number of abstain votes
    function getActionVoteData(uint256 actionId)
        external
        view
        returns (
            uint48 voteStart,
            uint32 voteDuration,
            uint256 voteEnd,
            uint32 againstVotes,
            uint32 forVotes,
            uint32 abstainVotes
        );

    /// @notice Gets the calldata for a specific action
    /// @param actionId The unique identifier of the action
    /// @return callData The calldata for the action
    function getActionCalldata(uint256 actionId) external view returns (bytes memory callData);

    /// @notice Gets the return data for a specific action
    /// @param actionId The unique identifier of the action
    /// @param index The index of the return data
    /// @return returnData The return data for the action
    function getActionReturnData(uint256 actionId, uint256 index) external view returns (bytes memory returnData);

    /// @notice Gets the URI for a specific action
    /// @param actionId The unique identifier of the action
    /// @return _uri The URI for the action
    function getActionUri(uint256 actionId) external view returns (string memory _uri);

    /// @notice Gets the block number since which an account has held a role
    /// @param account The address to check
    /// @param roleId The identifier of the role
    /// @return since the block number since holding the role, 0 if never held
    function hasRoleSince(address account, uint256 roleId) external view returns (uint48 since);

    /// @notice Gets the total number of accounts holding a specific role
    /// @param roleId The identifier of the role
    /// @return amountMembers the number of role holders
    function getAmountRoleHolders(uint256 roleId) external view returns (uint256 amountMembers);

    /// @notice Gets the holder of a role at a specific index
    /// @param roleId The identifier of the role
    /// @param index The index of the role holder
    /// @return account The address of the role holder
    function getRoleHolderAtIndex(uint256 roleId, uint256 index) external view returns (address account);

    /// @notice Gets the label of a role
    /// @param roleId The identifier of the role
    /// @return label The label of the role
    function getRoleLabel(uint256 roleId) external view returns (string memory label);

    /// @notice Checks if a mandate is currently active
    /// @param mandateId The id of the mandate
    /// @return mandate The address of the mandate
    /// @return mandateHash The hash of the mandate
    /// @return active The active status of the mandate
    function getAdoptedMandate(uint16 mandateId)
        external
        view
        returns (address mandate, bytes32 mandateHash, bool active);

    /// @notice Gets the total number of adopted mandates
    /// @return mandateCounter The total number of adopted mandates
    /// @dev Added this function to expose mandateCounter at IPowers interface level.
    function getMandateCounter() external view returns (uint16 mandateCounter);

    /// @notice Gets the latest fulfillment of a mandate
    /// @param mandateId The id of the mandate
    /// @return latestFulfillment The latest fulfillment of the mandate
    function getLatestFulfillment(uint16 mandateId) external view returns (uint48 latestFulfillment);

    /// @notice Gets the actions of a mandate
    /// @param mandateId The id of the mandate
    /// @param index The index of the action
    /// @return actionId The action at the index
    function getMandateActionAtIndex(uint16 mandateId, uint256 index) external view returns (uint256 actionId);

    /// @notice Gets the conditions of a mandate
    /// @param mandateId The id of the mandate
    /// @return conditions The conditions of the mandate
    function getConditions(uint16 mandateId) external view returns (Conditions memory conditions);

    /// @notice Getter for treasury address.
    /// @return The treasury address
    function getTreasury() external view returns (address payable);

    /// @notice Checks if an account has permission to call a mandate
    /// @param caller The address attempting to call the mandate
    /// @param mandateId The mandate id to check
    /// @return canCall True if the caller has permission, false otherwise
    function canCallMandate(address caller, uint16 mandateId) external view returns (bool canCall);

    /// @notice Gets the protocol version
    /// @return version the version string
    function version() external pure returns (string memory version);

    /// @notice Checks if an account is blacklisted
    /// @param account The address to check
    /// @return blacklisted The blacklisted status of the account
    function isBlacklisted(address account) external view returns (bool blacklisted);
}
