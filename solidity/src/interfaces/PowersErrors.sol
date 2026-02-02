// SPDX-License-Identifier: MIT

/// @notice Errors used in the Powers protocol.
/// @author 7Cedars
pragma solidity 0.8.26;

interface PowersErrors {
    /// @notice Emitted when an action has already been initiated.
    error Powers__ActionAlreadyInitiated();

    /// @notice Emitted when the constitute phase is closed.
    error Powers__ConstituteClosed();

    /// @notice Emitted when the constitute phase is still open.
    error Powers__ConstituteOpen();

    /// @notice Emitted when an action has been cancelled.
    error Powers__ActionCancelled();

    /// @notice Emitted when an action has not been initiated yet.
    error Powers__ActionNotRequested();

    /// @notice Emitted when a callData is invalid.
    error Powers__InvalidCallData();

    /// @notice Emitted when an invalid address is used.
    error Powers__InvalidAddress();

    /// @notice Emitted when a mandate is not active.
    error Powers__MandateNotActive();

    /// @notice Emitted when a function is called that does not need a vote.
    error Powers__NoVoteNeeded();

    /// @notice Emitted when a function is called from a contract that is not Powers.
    error Powers__OnlyPowers();

    /// @notice Emitted when an action is in an unexpected state.
    error Powers__UnexpectedActionState();

    /// @notice Emitted when a role is locked.
    error Powers__LockedRole();

    /// @notice Emitted when an incorrect interface is called.
    error Powers__IncorrectInterface(address targetMandate);

    /// @notice Emitted when a proposed action is not active.
    error Powers__ProposedActionNotActive();

    /// @notice Emitted when a constitution has already been executed.
    error Powers__ConstitutionAlreadyExecuted();

    /// @notice Emitted when a mandate is not adopted.
    error Powers__AlreadyCastVote();

    /// @notice Emitted when a vote type is invalid.
    error Powers__InvalidVoteType();

    /// @notice Emitted when a role is locked.
    error Powers__CannotSetPublicRole();

    /// @notice Emitted when a zero address is added.
    error Powers__CannotAddZeroAddress();

    /// @notice Emitted when a name is invalid.
    error Powers__InvalidName();

    /// @notice Emitted when a role has no members.
    error Powers__NoMembersInRole();

    /// @notice Emitted when an action is already fulfilled.
    error Powers__ActionAlreadyFulfilled();

    /// @notice Emitted when a mandate request fails.
    error Powers__MandateRequestFailed();

    /// @notice Emitted when a calldata is too long.
    error Powers__CalldataTooLong();

    /// @notice Emitted when an address is blacklisted.
    error Powers__AddressBlacklisted();

    /// @notice Emitted when an array is too long.
    error Powers__ExecutionArrayTooLong();

    /// @notice Emitted when a mandate fulfill call fails.
    error Powers__MandateFulfillCallFailed();

    /// @notice Emitted when an action does not exist.
    error Powers__ActionNotProposed();

    /// @notice Emitted when payable is not enabled.
    error Powers__PayableNotEnabled();

    /// @notice Emitted when an account cannot call a mandate.
    error Powers__CannotCallMandate();

    /// @notice Emitted when the caller is not the target mandate.
    error Powers__CallerNotTargetMandate();

    /// @notice Emitted when the caller is not the proposer of the action.
    error Powers__NotProposerAction();

    /// @notice Emitted when the caller is not the admin.
    error Powers__OnlyAdmin();

    /// @notice Emitted when an external contract is blacklisted.
    error Powers__ExternalContractBlacklisted();

    /// @notice Emitted when an external contract is not a contract.
    error Powers__NotAContract();

    /// @notice Emitted when a label is invalid.
    error Powers__InvalidLabel();

    /// @notice Emitted when a label is too long.
    error Powers__LabelTooLong();

    /// @notice Emitted when a vote with public role is attempted.
    error Powers__VoteWithPublicRoleDisallowed();

    /// @notice Emitted when a max call data length is invalid.
    error Powers__InvalidMaxCallDataLength();

    /// @notice Emitted when a max call data length is invalid.
    error Powers__InvalidReturnCallDataLength();

    /// @notice Emitted when a max executions length is invalid.
    error Powers__InvalidMaxExecutionsLength();

    /// @notice Emitted when an index is invalid.
    error Powers__InvalidIndex();

    /// notice Emitted when trying to set the treasury to the zero address.
    error Powers__CannotSetZeroAddress();
}
