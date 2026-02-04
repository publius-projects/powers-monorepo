// SPDX-License-Identifier: MIT
/*
  _____   ____  __          __ ______  _____    _____ 
 |  __ \ / __ \ \ \        / /|  ____||  __ \  / ____|
 | |__) | |  | | \ \  /\  / / | |__   | |__) || (___  
 |  ___/| |  | |  \ \/  \/ /  |  __|  |  _  /  \___ \ 
 | |    | |__| |   \  /\  /   | |____ | | \ \  ____) |
 |_|     \____/     \/  \/    |______||_|  \_\|_____/ 
                                                      
*/
/// @title Powers Protocol v.0.4
/// @notice Powers is a Role Based Governance Protocol. It provides a modular, flexible,  DAOs.
///
/// @dev This contract is the core engine of the protocol. It is meant to be used in combination with implementations of {Mandate.sol}. The contract should be used as is, making changes to this contract should be avoided.
/// @dev Code is derived from OpenZeppelin's Governor.sol and AccessManager contracts, in addition to Haberdasher Labs Hats protocol.
/// @dev note that Powers prefers to save as much data as possible on-chain. This reduces reliance on off-chain data that needs to be indexed and (often centrally) stored.
///
/// Note several key differences from openzeppelin's {Governor.sol}.
/// 1 - Any DAO action needs to be encoded in role restricted external contracts, or mandates, that follow the {IMandate} interface.
/// 2 - Proposing, voting, cancelling and executing actions are role restricted along the target mandate that is called.
/// 3 - All DAO actions need to run through the governance flow provided by Powers.sol. Calls to mandates that do not need a proposedAction vote, FOR instance, still need to be executed through the {execute} function.
/// 4 - The core protocol uses a non-weighted voting mechanism: one account has one vote. Accounts vote with their roles, not with their tokens.
/// 5 - The core protocol is intentionally minimalistic. Any complexities (multi-chain governance, oracle based governance, timelocks, delayed execution, guardian roles, weighted votes, staking, etc.) has to be integrated through mandates.
///
/// For example organisational implementations, see testConstitutions.sol in the /test folder.
///
/// Note This protocol is a work in progress. A number of features are planned to be added in the future.
/// - Gas efficiency improvements.
/// - Integration with new ENS standards to log organisational data on-chain.
/// - And more.
///
/// @author 7Cedars

pragma solidity 0.8.26;

import { Mandate } from "./Mandate.sol";
import { IMandate } from "./interfaces/IMandate.sol";
import { IPowers } from "./interfaces/IPowers.sol";
import { Checks } from "./libraries/Checks.sol";
import { ERC165Checker } from "../lib/openzeppelin-contracts/contracts/utils/introspection/ERC165Checker.sol";
import { Address } from "../lib/openzeppelin-contracts/contracts/utils/Address.sol";
import { EIP712 } from "../lib/openzeppelin-contracts/contracts/utils/cryptography/EIP712.sol";
import { Context } from "../lib/openzeppelin-contracts/contracts/utils/Context.sol";

// import { console2 } from "forge-std/console2.sol"; // remove before deploying.

contract Powers is EIP712, IPowers, Context {
    //////////////////////////////////////////////////////////////
    //                           STORAGE                        //
    /////////////////////////////////////////////////////////////
    /// @dev Mapping from actionId to Action struct
    mapping(uint256 actionId => Action) internal _actions;
    /// @dev Mapping from mandateId to AdoptedMandate struct
    mapping(uint16 mandateId => AdoptedMandate) internal mandates;
    /// @dev Mapping from roleId to Role struct
    mapping(uint256 roleId => Role) internal roles;
    /// @dev Mapping from account to blacklisted status
    mapping(address account => bool blacklisted) internal _blacklist;

    // two roles are preset: ADMIN_ROLE == 0 and PUBLIC_ROLE == type(uint256).max.
    /// @notice Role identifier for the admin role
    uint256 public constant ADMIN_ROLE = type(uint256).min;
    /// @notice Role identifier for the public role (everyone)
    uint256 public constant PUBLIC_ROLE = type(uint256).max;
    /// @notice Denominator used for percentage calculations (100%)
    uint256 public constant DENOMINATOR = 100;

    /// @notice Maximum length of calldata for a mandate action
    uint256 public immutable MAX_CALLDATA_LENGTH;
    /// @notice Maximum length of return data stored from execution
    uint256 public immutable MAX_RETURN_DATA_LENGTH;
    /// @notice Maximum number of execution targets per action
    uint256 public immutable MAX_EXECUTIONS_LENGTH;

    // NB! this is a gotcha: mandates start counting a 1, NOT 0!. 0 is used as a default 'false' value.
    /// @notice Number of mandates that have been initiated throughout the life of the organisation
    uint16 public mandateCounter = 1;
    /// @notice Name of the DAO
    string public name;
    /// @notice URI to metadata of the DAO
    /// @dev Can be altered
    string public uri;
    /// @notice Address to the treasury of the organisation
    address payable private treasury;
    /// @dev Is the constitute phase closed? Note: no actions can be started when the constitute phase is open.
    bool private _constituteClosed;

    //////////////////////////////////////////////////////////////
    //                          MODIFIERS                       //
    //////////////////////////////////////////////////////////////
    /// @notice A modifier that sets a function to only be callable by the {Powers} contract.
    modifier onlyPowers() {
        _onlyPowers();
        _;
    }

    /// @dev Internal check for onlyPowers modifier.
    function _onlyPowers() internal view {
        if (_msgSender() != address(this)) revert Powers__OnlyPowers();
    }

    /// @notice Modifier to restrict access to the admin role.
    modifier onlyAdmin() {
        _onlyAdmin();
        _;
    }

    /// @dev Internal check for onlyAdmin modifier.
    function _onlyAdmin() internal view {
        if (_msgSender() != getRoleHolderAtIndex(ADMIN_ROLE, 0)) revert Powers__OnlyAdmin();
    }

    /// @notice A modifier that sets a function to only be callable by an active mandate.
    modifier onlyAdoptedMandate(uint16 mandateId) {
        _onlyAdoptedMandate(mandateId);
        _;
    }

    /// @dev Internal check for onlyAdoptedMandate modifier.
    function _onlyAdoptedMandate(uint16 mandateId) internal view {
        if (mandates[mandateId].active == false) revert Powers__MandateNotActive();
    }

    //////////////////////////////////////////////////////////////
    //              CONSTRUCTOR & RECEIVE                       //
    //////////////////////////////////////////////////////////////
    /// @notice  Sets the value for {name} at the time of construction.
    ///
    /// @param name_ name of the contract
    /// @param uri_ uri of the contract
    /// @param maxCallDataLength_ maximum length of calldata for a mandate
    /// @param maxReturnDataLength_ maximum length of return data for a mandate
    /// @param maxExecutionsLength_ maximum length of executions for a mandate
    constructor(
        string memory name_,
        string memory uri_,
        uint256 maxCallDataLength_,
        uint256 maxReturnDataLength_,
        uint256 maxExecutionsLength_
        // add here the init data for initial mandates?
    ) EIP712(name_, version()) {
        if (bytes(name_).length == 0) revert Powers__InvalidName();
        if (maxCallDataLength_ == 0) revert Powers__InvalidMaxCallDataLength();
        if (maxReturnDataLength_ == 0) revert Powers__InvalidReturnCallDataLength();
        if (maxExecutionsLength_ == 0) revert Powers__InvalidMaxExecutionsLength();

        _setRole(ADMIN_ROLE, _msgSender(), true); // the account that initiates a Powerscontract is set to its admin.
        name = name_;
        uri = uri_;
        MAX_CALLDATA_LENGTH = maxCallDataLength_;
        MAX_RETURN_DATA_LENGTH = maxReturnDataLength_;
        MAX_EXECUTIONS_LENGTH = maxExecutionsLength_;

        emit Powers__Initialized(address(this), name, uri);
    }

    //////////////////////////////////////////////////////////////
    //                  CONSTITUTE LOGIC                        //
    //////////////////////////////////////////////////////////////
    /// @inheritdoc IPowers
    function constitute(MandateInitData[] memory constituentMandates) external onlyAdmin {
        if (_constituteClosed) revert Powers__ConstituteClosed();
        
        //  set mandates as active.
        for (uint256 i = 0; i < constituentMandates.length; i++) {
            // note: ignore empty slots in MandateInitData array.
            if (constituentMandates[i].targetMandate != address(0)) {
                _adoptMandate(constituentMandates[i]);
            }
        }
    }

    /// @inheritdoc IPowers
    function closeConstitute() external onlyAdmin() { 
        _closeConstitute(_msgSender());
    }

    /// @inheritdoc IPowers
    function closeConstitute(address newAdmin) external onlyAdmin() { 
        _closeConstitute(newAdmin);
    }

    /// @dev Internal function to close constitution phase.
    /// @param newAdmin Address of the new admin.
    function _closeConstitute(address newAdmin) internal {
        // if newAdmin is different from current admin, set new admin...
        if (_msgSender() != newAdmin) {
            _setRole(ADMIN_ROLE, _msgSender(), false);
            _setRole(ADMIN_ROLE, newAdmin, true);
        }

        _constituteClosed = true;
    }

    //////////////////////////////////////////////////////////////
    //                  GOVERNANCE LOGIC                        //
    //////////////////////////////////////////////////////////////
    /// @inheritdoc IPowers
    /// @dev The request -> fulfill functions follow a call-and-return mechanism. This allows for async execution of mandates.
    function request(uint16 mandateId, bytes calldata mandateCalldata, uint256 nonce, string memory uriAction)
        external
        onlyAdoptedMandate(mandateId)
        returns (uint256 actionId)
    {
        if (!_constituteClosed) revert Powers__ConstituteOpen();

        actionId = Checks.computeActionId(mandateId, mandateCalldata, nonce);
        AdoptedMandate memory mandate = mandates[mandateId];

        // check 0 is calldata length is too long
        if (mandateCalldata.length > MAX_CALLDATA_LENGTH) revert Powers__CalldataTooLong();

        // check 1: is _msgSender() blacklisted?
        if (isBlacklisted(_msgSender())) revert Powers__AddressBlacklisted();

        // check 2: does caller have access to mandate being executed?
        if (!canCallMandate(_msgSender(), mandateId)) revert Powers__CannotCallMandate();

        // check 3: has action already been set as requested?
        if (_hasBeenRequested(actionId)) revert Powers__ActionAlreadyInitiated();

        // check 4: is proposedAction cancelled?
        if (_actions[actionId].cancelledAt > 0) revert Powers__ActionCancelled();

        // check 5: do checks pass?
        Checks.check(mandateId, mandateCalldata, address(this), nonce, mandate.latestFulfillment);

        // if not registered yet, register actionId at mandate.
        if (_actions[actionId].mandateId == 0) mandates[mandateId].actionIds.push(actionId);

        // If everything passed, set action as requested.
        Action storage action = _actions[actionId];
        action.caller = _msgSender(); // note if caller had been set during proposedAction, it will be overwritten.
        action.mandateId = mandateId;
        action.requestedAt = uint48(block.number);
        action.mandateCalldata = mandateCalldata;
        action.uri = uriAction;
        action.nonce = nonce;

        // execute mandate.
        (bool success) = IMandate(mandate.targetMandate).executeMandate(_msgSender(), mandateId, mandateCalldata, nonce);
        if (!success) revert Powers__MandateRequestFailed();

        // emit event.
        emit ActionRequested(_msgSender(), mandateId, mandateCalldata, nonce, uriAction);

        return actionId;
    }

    /// @inheritdoc IPowers
    function fulfill(
        uint16 mandateId,
        uint256 actionId,
        address[] calldata targets,
        uint256[] calldata values,
        bytes[] calldata calldatas
    ) external onlyAdoptedMandate(mandateId) {
        AdoptedMandate memory mandate = mandates[mandateId];

        // check 1: is mandate active?
        if (!mandate.active) revert Powers__MandateNotActive();

        // check 2: is _msgSender() the targetMandate?
        if (mandate.targetMandate != _msgSender()) revert Powers__CallerNotTargetMandate();

        // check 3: has action already been set as requested?
        if (!_hasBeenRequested(actionId)) revert Powers__ActionNotRequested();

        // check 4: has action already been fulfilled?
        if (_actions[actionId].fulfilledAt > 0) revert Powers__ActionAlreadyFulfilled();

        // check 5: are the lengths of targets, values and calldatas equal?
        if (targets.length != values.length || targets.length != calldatas.length) revert Powers__InvalidCallData();

        // check 6: check array length is too long
        if (targets.length > MAX_EXECUTIONS_LENGTH) revert Powers__ExecutionArrayTooLong();

        // check 7: for each target, check if calldata does not exceed MAX_CALLDATA_LENGTH + targets have not been blacklisted.
        for (uint256 i = 0; i < targets.length; ++i) {
            if (calldatas[i].length > MAX_CALLDATA_LENGTH) revert Powers__CalldataTooLong();
            if (isBlacklisted(targets[i])) revert Powers__AddressBlacklisted();
        }

        // set action as fulfilled
        _actions[actionId].fulfilledAt = uint48(block.number);

        // execute targets[], values[], calldatas[] received from mandate.
        for (uint256 i = 0; i < targets.length; ++i) {
            (bool success, bytes memory returndata) = targets[i].call{ value: values[i] }(calldatas[i]);
            if (!success) {
                revert Powers__MandateFulfillCallFailed();
            }
            if (returndata.length <= MAX_RETURN_DATA_LENGTH) {
                _actions[actionId].returnDatas.push(returndata);
            } else {
                _actions[actionId].returnDatas.push(abi.encode(0));
            }
        }

        // emit event. -- commented out to save gas, can be re-enabled if needed.
        // emit ActionFulfilled(mandateId, actionId, targets, values, calldatas);

        // register latestFulfillment at mandate. -- is there anyway to do this more efficiently?
        mandates[mandateId].latestFulfillment = uint48(block.number);
    }

    /// @inheritdoc IPowers
    function propose(uint16 mandateId, bytes calldata mandateCalldata, uint256 nonce, string memory uriAction)
        external
        onlyAdoptedMandate(mandateId)
        returns (uint256 actionId)
    {
        if (!_constituteClosed) revert Powers__ConstituteOpen();
        
        AdoptedMandate memory mandate = mandates[mandateId];

        // check 1: is targetMandate is an active mandate?
        if (!mandate.active) revert Powers__MandateNotActive();

        // check 2: does _msgSender() have access to targetMandate?
        if (!canCallMandate(_msgSender(), mandateId)) revert Powers__CannotCallMandate();

        // check 3: is caller blacklisted?
        if (isBlacklisted(_msgSender())) revert Powers__AddressBlacklisted();

        // check 4: is caller too long?
        if (mandateCalldata.length > MAX_CALLDATA_LENGTH) revert Powers__CalldataTooLong();

        // if checks pass: propose.
        actionId = _propose(_msgSender(), mandateId, mandateCalldata, nonce, uriAction);

        return actionId;
    }

    /// @notice Internal propose mechanism.
    /// @dev The mechanism checks for the length of targets and calldatas.
    /// @param caller The address of the caller proposing the action.
    /// @param mandateId The ID of the mandate being proposed for.
    /// @param mandateCalldata The calldata for the mandate execution.
    /// @param nonce A unique nonce for the proposal.
    /// @param uriAction URI with metadata about the action.
    /// @return actionId The generated ID of the proposed action.
    ///
    /// Emits a {PowersEvents::ProposedActionCreated} event.
    function _propose(
        address caller,
        uint16 mandateId,
        bytes calldata mandateCalldata,
        uint256 nonce,
        string memory uriAction
    ) internal virtual returns (uint256 actionId) {
        // (uint8 quorum,, uint32 votingPeriod,,,,,) = Mandate(targetMandate).conditions();
        Conditions memory conditions = getConditions(mandateId);
        actionId = Checks.computeActionId(mandateId, mandateCalldata, nonce);

        // check 1: does target mandate need proposal vote to pass?
        if (conditions.quorum == 0) revert Powers__NoVoteNeeded();

        // check 2: do we have a proposal with the same targetMandate and mandateCalldata?
        if (_actions[actionId].voteStart != 0) revert Powers__UnexpectedActionState();

        // register actionId at mandate.
        // £check: is this necessary?
        mandates[mandateId].actionIds.push(actionId);

        // if checks pass: create proposedAction
        Action storage action = _actions[actionId];
        action.mandateCalldata = mandateCalldata;
        action.proposedAt = uint48(block.number);
        action.mandateId = mandateId;
        action.voteStart = uint48(block.number); // note that the moment proposedAction is made, voting start. Delay functionality has to be implemeted at the mandate level.
        action.voteDuration = conditions.votingPeriod;
        action.caller = caller;
        action.uri = uriAction;
        action.nonce = nonce;

        emit ProposedActionCreated(
            actionId,
            caller,
            mandateId,
            "",
            mandateCalldata,
            block.number,
            block.number + conditions.votingPeriod,
            nonce,
            uriAction
        );
    }

    /// @inheritdoc IPowers
    /// @dev the account to cancel must be the account that created the proposedAction.
    function cancel(uint16 mandateId, bytes calldata mandateCalldata, uint256 nonce)
        external
        onlyAdoptedMandate(mandateId)
        returns (uint256)
    {
        uint256 actionId = Checks.computeActionId(mandateId, mandateCalldata, nonce);

        // check: is caller the caller of the proposedAction?
        if (_msgSender() != _actions[actionId].caller) revert Powers__NotProposerAction();

        return _cancel(mandateId, mandateCalldata, nonce);
    }

    /// @notice Internal cancel mechanism with minimal restrictions.
    /// @dev A proposal can be cancelled in any state other than Cancelled or Executed.
    /// Once cancelled a proposal cannot be re-submitted.
    /// @param mandateId The ID of the mandate.
    /// @param mandateCalldata The calldata of the action.
    /// @param nonce The nonce of the action.
    /// @return actionId The ID of the cancelled action.
    ///
    /// Emits a {PowersEvents::ProposedActionCancelled} event.
    function _cancel(uint16 mandateId, bytes calldata mandateCalldata, uint256 nonce)
        internal
        virtual
        returns (uint256)
    {
        uint256 actionId = Checks.computeActionId(mandateId, mandateCalldata, nonce);

        // check 1: does action exist?
        if (_actions[actionId].proposedAt == 0) revert Powers__ActionNotProposed();

        // check 2: is action already fulfilled or cancelled?
        if (_actions[actionId].fulfilledAt > 0 || _actions[actionId].cancelledAt > 0) {
            revert Powers__UnexpectedActionState();
        }

        // set action as cancelled.
        _actions[actionId].cancelledAt = uint48(block.number);

        // emit event.
        emit ProposedActionCancelled(actionId);

        return actionId;
    }

    /// @inheritdoc IPowers
    function castVote(uint256 actionId, uint8 support) external {
        return _castVote(actionId, _msgSender(), support, "");
    }

    /// @inheritdoc IPowers
    function castVoteWithReason(uint256 actionId, uint8 support, string calldata reason) external {
        return _castVote(actionId, _msgSender(), support, reason);
    }

    /// @notice Internal vote casting mechanism.
    /// @dev Check that the proposal is active, and that account has access to targetMandate.
    /// @param actionId The ID of the action being voted on.
    /// @param account The address casting the vote.
    /// @param support The support value (0=Against, 1=For, 2=Abstain).
    /// @param reason The reason for the vote.
    ///
    /// Emits a {PowersEvents::VoteCast} event.
    function _castVote(uint256 actionId, address account, uint8 support, string memory reason) internal virtual {
        // Check that the proposal is active, that it has not been paused, cancelled or ended yet.
        if (getActionState(actionId) != ActionState.Active) {
            revert Powers__ProposedActionNotActive();
        }
        Action storage proposedAction = _actions[actionId];

        // Note that we check if account has access to the mandate targetted in the proposedAction.
        uint16 mandateId = proposedAction.mandateId;
        if (!canCallMandate(account, mandateId)) revert Powers__CannotCallMandate();
        // check 2: has account already voted?
        if (proposedAction.hasVoted[account]) revert Powers__AlreadyCastVote();

        // if all this passes: cast vote.
        _countVote(actionId, account, support);

        emit VoteCast(account, actionId, support, reason);
    }

    //////////////////////////////////////////////////////////////
    //                  ROLE AND LAW ADMIN                      //
    //////////////////////////////////////////////////////////////
    /// @inheritdoc IPowers
    function adoptMandate(MandateInitData memory mandateInitData) external onlyPowers returns (uint16 mandateId) {
        mandateId = _adoptMandate(mandateInitData);
        // emit event.
        emit MandateAdopted(mandateCounter - 1);

        return mandateId;
    }

    /// @inheritdoc IPowers
    function revokeMandate(uint16 mandateId) external onlyPowers {
        if (mandates[mandateId].active == false) revert Powers__MandateNotActive();

        mandates[mandateId].active = false;
        emit MandateRevoked(mandateId);
    }

    /// @notice Internal function to set a mandate or revoke it.
    /// @param mandateInitData Data of the mandate to adopt.
    /// @return mandateId The ID of the newly adopted mandate.
    ///
    /// Emits a {PowersEvents::MandateAdopted} event.
    function _adoptMandate(MandateInitData memory mandateInitData) internal virtual returns (uint16 mandateId) {
        // check if added address is indeed a mandate. Note that this will also revert with address(0).
        if (!ERC165Checker.supportsInterface(mandateInitData.targetMandate, type(IMandate).interfaceId)) {
            revert Powers__IncorrectInterface(mandateInitData.targetMandate);
        }

        // check if targetMandate is blacklisted
        if (isBlacklisted(mandateInitData.targetMandate)) revert Powers__AddressBlacklisted();

        // check if conditions combine PUBLIC_ROLE with a vote - which is impossible due to PUBLIC_ROLE having an infinite number of members.
        if (mandateInitData.conditions.allowedRole == PUBLIC_ROLE && mandateInitData.conditions.quorum > 0) {
            revert Powers__VoteWithPublicRoleDisallowed();
        }

        // if checks pass, set mandate as active.
        mandates[mandateCounter].active = true;
        mandates[mandateCounter].targetMandate = mandateInitData.targetMandate;
        mandates[mandateCounter].conditions = mandateInitData.conditions;
        mandateCounter++;

        Mandate(mandateInitData.targetMandate)
            .initializeMandate(mandateCounter - 1, mandateInitData.nameDescription, "", mandateInitData.config);

        return mandateCounter - 1;
    }

    /// @inheritdoc IPowers
    function assignRole(uint256 roleId, address account) external onlyPowers {
        if (isBlacklisted(account)) revert Powers__AddressBlacklisted();

        _setRole(roleId, account, true);
    }

    /// @inheritdoc IPowers
    function revokeRole(uint256 roleId, address account) external onlyPowers {
        _setRole(roleId, account, false);
    }

    /// @inheritdoc IPowers
    function labelRole(uint256 roleId, string memory label) external onlyPowers {
        if (roleId == ADMIN_ROLE || roleId == PUBLIC_ROLE) revert Powers__LockedRole();
        if (bytes(label).length == 0) revert Powers__InvalidLabel();
        if (bytes(label).length > 255) revert Powers__LabelTooLong();

        roles[roleId].label = label;
        emit RoleLabel(roleId, label);
    }

    /// @notice Internal version of {setRole} without access control.
    /// @dev This function is used to set a role for a given account. Public role is locked as everyone has it.
    /// Note that it does allow Admin role to be assigned and revoked.
    /// Note that the function does not revert if trying to remove a role someone does not have, or add a role someone already has.
    /// @param roleId The ID of the role to set.
    /// @param account The address to assign/revoke the role for.
    /// @param access True to grant role, false to revoke.
    ///
    /// Emits a {PowersEvents::RoleSet} event.
    function _setRole(uint256 roleId, address account, bool access) internal virtual {
        // check 1: Public role is locked.
        if (roleId == PUBLIC_ROLE) revert Powers__CannotSetPublicRole();
        // check 2: Zero address is not allowed.
        if (account == address(0)) revert Powers__CannotAddZeroAddress();

        bool newMember = roles[roleId].members[account] == 0;
        // add role if role requested and account does not already have role.
        if (access && newMember) {
            roles[roleId].members[account] = roles[roleId].membersArray.length + 1; // 'index of new member is length of array + 1. index = 0 is used a 'undefined' value..
            roles[roleId].membersArray.push(Member({ account: account, since: uint48(block.number) }));
            // remove role if access set to false and account has role.
        } else if (!access && !newMember) {
            uint256 indexEnd = roles[roleId].membersArray.length - 1;
            Member memory memberEnd = roles[roleId].membersArray[indexEnd];
            uint256 indexAccount = roles[roleId].members[account];

            // updating array. Note that 1 is added to the index to avoid 0 index of first member in array. We here have to subtract it.
            roles[roleId].membersArray[indexAccount - 1] = memberEnd; // replace account with last member account.
            roles[roleId].membersArray.pop(); // remove last member.

            // updating indices in mapping.
            roles[roleId].members[memberEnd.account] = indexAccount; // update index of last member in list
            roles[roleId].members[account] = 0; // 'index of removed member is set to 0.
        }
        // note: nothing happens when 1: access is requested and not a new member 2: access is false and account does not have role. No revert.

        emit RoleSet(roleId, account, access);
    }

    /// @inheritdoc IPowers
    function blacklistAddress(address account, bool blacklisted) public onlyPowers {
        _blacklist[account] = blacklisted;
        emit BlacklistSet(account, blacklisted);
    }

    /// @inheritdoc IPowers
    function setUri(string memory newUri) public onlyPowers {
        uri = newUri;
    }

    /// @inheritdoc IPowers
    function setTreasury(address payable newTreasury) public onlyPowers {
        if (newTreasury == address(0)) revert Powers__CannotSetZeroAddress();
        treasury = newTreasury;
    }

    //////////////////////////////////////////////////////////////
    //               INTERNAL HELPER FUNCTIONS                  //
    //////////////////////////////////////////////////////////////
    /// @notice Internal function to check if the quorum for a given proposal has been reached.
    /// @param actionId The ID of the proposal.
    /// @return True if quorum is reached, false otherwise.
    function _quorumReached(uint256 actionId) internal view virtual returns (bool) {
        // retrieve quorum and allowedRole from mandate.
        Action storage proposedAction = _actions[actionId];
        Conditions memory conditions = getConditions(proposedAction.mandateId);
        uint256 amountMembers = _countMembersRole(conditions.allowedRole);

        // check if quorum is set to 0 in a Mandate, it will automatically return true. Otherwise, check if quorum has been reached.
        return (conditions.quorum == 0
                || amountMembers * conditions.quorum
                    <= (proposedAction.forVotes + proposedAction.abstainVotes) * DENOMINATOR);
    }

    /// @notice Internal function to check if a given action has been requested.
    /// @param actionId The ID of the action.
    /// @return True if the action has been requested or fulfilled, false otherwise.
    function _hasBeenRequested(uint256 actionId) internal view virtual returns (bool) {
        ActionState state = getActionState(actionId);
        if (state == ActionState.Requested || state == ActionState.Fulfilled) {
            return true;
        }
        return false;
    }

    /// @notice Internal function to check if a vote for a given proposal has succeeded.
    /// @param actionId The ID of the proposal.
    /// @return True if the vote succeeded, false otherwise.
    function _voteSucceeded(uint256 actionId) internal view virtual returns (bool) {
        // retrieve quorum and success threshold from mandate.
        Action storage proposedAction = _actions[actionId];
        Conditions memory conditions = getConditions(proposedAction.mandateId);
        uint256 amountMembers = _countMembersRole(conditions.allowedRole);

        // note if quorum is set to 0 in a Mandate, it will automatically return true. Otherwise, check if success threshold has been reached.
        return conditions.quorum == 0 || amountMembers * conditions.succeedAt <= proposedAction.forVotes * DENOMINATOR;
    }

    /// @notice Internal function to count against, for, and abstain votes for a given proposal.
    /// @dev In this module, the support follows the `VoteType` enum (from Governor Bravo).
    /// It does not check if account has roleId referenced in actionId. This has to be done by {Powers.castVote} function.
    /// @param actionId The ID of the proposal.
    /// @param account The address casting the vote.
    /// @param support The support value (0=Against, 1=For, 2=Abstain).
    function _countVote(uint256 actionId, address account, uint8 support) internal virtual {
        Action storage proposedAction = _actions[actionId];

        // set account as voted.
        proposedAction.hasVoted[account] = true;

        // add vote to tally.
        if (support == uint8(VoteType.Against)) {
            proposedAction.againstVotes++;
        } else if (support == uint8(VoteType.For)) {
            proposedAction.forVotes++;
        } else if (support == uint8(VoteType.Abstain)) {
            proposedAction.abstainVotes++;
        } else {
            revert Powers__InvalidVoteType();
        }
    }

    /// @notice Internal function that counts the number of members in a given role.
    /// @dev If needed, this function can be overridden with bespoke logic.
    /// @param roleId The ID of the role.
    /// @return amountMembers Number of members in the role.
    function _countMembersRole(uint256 roleId) internal view virtual returns (uint256 amountMembers) {
        return roles[roleId].membersArray.length;
    }

    //////////////////////////////////////////////////////////////
    //                 VIEW / GETTER FUNCTIONS                  //
    //////////////////////////////////////////////////////////////
    /// @inheritdoc IPowers
    function version() public pure returns (string memory) {
        return "0.5";
    }

    /// @inheritdoc IPowers
    function canCallMandate(address caller, uint16 mandateId) public view virtual returns (bool) {
        uint256 allowedRole = getConditions(mandateId).allowedRole;
        uint48 since = hasRoleSince(caller, allowedRole);

        return since != 0 || allowedRole == PUBLIC_ROLE;
    }

    /// @inheritdoc IPowers
    function hasRoleSince(address account, uint256 roleId) public view returns (uint48 since) {
        uint256 index = roles[roleId].members[account];
        if (index == 0) {
            return 0;
        }
        return roles[roleId].membersArray[index - 1].since;
    }

    /// @inheritdoc IPowers
    function getAmountRoleHolders(uint256 roleId) public view returns (uint256 amountMembers) {
        return roles[roleId].membersArray.length;
    }

    /// @inheritdoc IPowers
    function getRoleHolderAtIndex(uint256 roleId, uint256 index) public view returns (address account) {
        if (index >= getAmountRoleHolders(roleId)) {
            revert Powers__InvalidIndex();
        }
        return roles[roleId].membersArray[index].account;
    }

    /// @inheritdoc IPowers
    function getRoleLabel(uint256 roleId) public view returns (string memory label) {
        return roles[roleId].label;
    }

    /// @inheritdoc IPowers
    function getActionState(uint256 actionId) public view virtual returns (ActionState) {
        // We read the struct fields into the stack at once so Solidity emits a single SLOAD
        Action storage action = _actions[actionId];

        if (action.proposedAt == 0 && action.requestedAt == 0 && action.fulfilledAt == 0 && action.cancelledAt == 0) {
            return ActionState.NonExistent;
        }
        if (action.fulfilledAt > 0) {
            return ActionState.Fulfilled;
        }
        if (action.cancelledAt > 0) {
            return ActionState.Cancelled;
        }
        if (action.requestedAt > 0) {
            return ActionState.Requested;
        }

        uint256 deadline = action.voteStart + action.voteDuration;

        if (deadline >= block.number) {
            return ActionState.Active;
        } else if (!_quorumReached(actionId) || !_voteSucceeded(actionId)) {
            return ActionState.Defeated;
        } else {
            return ActionState.Succeeded;
        }
    }

    /// @inheritdoc IPowers
    function getActionData(uint256 actionId)
        public
        view
        virtual
        returns (
            uint16 mandateId,
            uint48 proposedAt,
            uint48 requestedAt,
            uint48 fulfilledAt,
            uint48 cancelledAt,
            address caller,
            uint256 nonce
        )
    {
        Action storage action = _actions[actionId];

        return (
            action.mandateId,
            action.proposedAt,
            action.requestedAt,
            action.fulfilledAt,
            action.cancelledAt,
            action.caller,
            action.nonce
        );
    }

    /// @inheritdoc IPowers
    function getActionVoteData(uint256 actionId)
        public
        view
        virtual
        returns (
            uint48 voteStart,
            uint32 voteDuration,
            uint256 voteEnd,
            uint32 againstVotes,
            uint32 forVotes,
            uint32 abstainVotes
        )
    {
        Action storage action = _actions[actionId];

        return (
            action.voteStart,
            action.voteDuration,
            action.voteStart + action.voteDuration,
            action.againstVotes,
            action.forVotes,
            action.abstainVotes
        );
    }

    /// @inheritdoc IPowers
    function getActionCalldata(uint256 actionId) public view virtual returns (bytes memory callData) {
        return _actions[actionId].mandateCalldata;
    }

    /// @inheritdoc IPowers
    function getActionReturnData(uint256 actionId, uint256 index)
        public
        view
        virtual
        returns (bytes memory returnData)
    {
        return _actions[actionId].returnDatas[index];
    }

    /// @inheritdoc IPowers
    function getActionUri(uint256 actionId) public view virtual returns (string memory _uri) {
        _uri = _actions[actionId].uri;
    }

    /// @inheritdoc IPowers
    function hasVoted(uint256 actionId, address account) public view virtual returns (bool) {
        return _actions[actionId].hasVoted[account];
    }

    /// @inheritdoc IPowers
    function getAdoptedMandate(uint16 mandateId)
        external
        view
        returns (address mandate, bytes32 mandateHash, bool active)
    {
        mandate = mandates[mandateId].targetMandate;
        active = mandates[mandateId].active;
        mandateHash = keccak256(abi.encode(address(this), mandateId));

        return (mandate, mandateHash, active);
    }

    /// @inheritdoc IPowers
    function getMandateCounter() external view returns (uint16) {
        return mandateCounter;
    }

    /// @inheritdoc IPowers
    function getLatestFulfillment(uint16 mandateId) external view returns (uint48 latestFulfillment) {
        return mandates[mandateId].latestFulfillment;
    }

    /// @inheritdoc IPowers
    function getQuantityMandateActions(uint16 mandateId) external view returns (uint256 quantityMandateActions) {
        return mandates[mandateId].actionIds.length;
    }

    /// @inheritdoc IPowers
    function getMandateActionAtIndex(uint16 mandateId, uint256 index) external view returns (uint256 actionId) {
        if (index >= mandates[mandateId].actionIds.length) {
            revert Powers__InvalidIndex();
        }
        return mandates[mandateId].actionIds[index];
    }

    /// @inheritdoc IPowers
    function getConditions(uint16 mandateId) public view returns (Conditions memory conditions) {
        return mandates[mandateId].conditions;
    }

    /// @inheritdoc IPowers
    function getTreasury() external view returns (address payable) {
        return treasury;
    }

    /// @inheritdoc IPowers
    function isBlacklisted(address account) public view returns (bool) {
        return _blacklist[account];
    }
}
