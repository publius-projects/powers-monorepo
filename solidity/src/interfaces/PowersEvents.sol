// SPDX-License-Identifier: MIT

/// @notice Events used in the Powers protocol.
/// @author 7Cedars
pragma solidity 0.8.26;

interface PowersEvents {
    /// @notice Emitted when protocol is initialized.
    /// @param contractAddress the address of the contract
    /// @param name the name of the contract
    /// @param uri the uri of the contract
    event Powers__Initialized(address contractAddress, string name, string uri);

    /// @notice Emitted when protocol receives funds.
    /// @param value the amount of funds received
    /// @param sender the address of the sender
    event FundsReceived(uint256 value, address sender);

    /// @notice Emitted when executive action is requested.
    /// @param caller the address of the caller
    /// @param mandateId the id of the mandate
    /// @param mandateCalldata the calldata of the mandate
    /// @param description the description of the mandate action
    /// @param nonce the nonce of the action
    event ActionRequested(
        address indexed caller, uint16 indexed mandateId, bytes mandateCalldata, uint256 nonce, string description
    );

    /// @notice Emitted when an executive action has been executed.
    /// @param mandateId the id of the mandate
    /// @param actionId the id of the action
    /// @param targets the targets of the action
    /// @param values the values of the action
    /// @param calldatas the calldatas of the action
    event ActionFulfilled(
        uint16 indexed mandateId, uint256 indexed actionId, address[] targets, uint256[] values, bytes[] calldatas
    );

    /// @notice Emitted when a proposal is created.
    /// @param actionId the id of the proposal
    /// @param caller the address of the caller
    /// @param mandateId the id of the mandate
    /// @param signature the signature of the proposal
    /// @param executeCalldata the calldata to be passed to the mandate
    /// @param voteStart the start of the voting period
    /// @param voteEnd the end of the voting period
    /// @param description the description of the proposal
    event ProposedActionCreated(
        uint256 indexed actionId,
        address indexed caller,
        uint16 indexed mandateId,
        string signature,
        bytes executeCalldata,
        uint256 voteStart,
        uint256 voteEnd,
        uint256 nonce,
        string description
    );

    /// @notice Emitted when a proposal is cancelled.
    /// @param actionId the id of the proposal
    event ProposedActionCancelled(uint256 indexed actionId);

    /// @notice Emitted when a vote is cast.
    /// @param account the address of the account that cast the vote
    /// @param actionId the id of the proposal
    /// @param support support of the vote: Against, For or Abstain.
    /// @param reason the reason for the vote
    event VoteCast(address indexed account, uint256 indexed actionId, uint8 indexed support, string reason);

    /// @notice Emitted when a role is set.
    /// @param roleId the id of the role
    /// @param account the address of the account that has the role
    /// @param access whether the account has access to the role
    event RoleSet(uint256 indexed roleId, address indexed account, bool indexed access);

    /// @notice Emitted when a role is labelled.
    /// @param roleId the id of the role
    /// @param label the label assigned to the role
    event RoleLabel(uint256 indexed roleId, string label);

    /// @notice Emitted when a mandate is adopted.
    /// @param mandateId the id of the mandate
    event MandateAdopted(uint16 indexed mandateId);

    /// @notice Emitted when a mandate is revoked.
    /// @param mandateId the id of the mandate
    event MandateRevoked(uint16 indexed mandateId);

    /// @notice Emitted when a address is blacklisted.
    /// @param account the address of the account
    /// @param blacklisted the blacklisted status of the account
    event BlacklistSet(address indexed account, bool indexed blacklisted);
}
