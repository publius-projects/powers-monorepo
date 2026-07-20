// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.26;

import { Test } from "forge-std/Test.sol";
import { Powers } from "@src/Powers.sol";
import { MandateUtilities } from "@src/libraries/MandateUtilities.sol";
import { Checks } from "@src/libraries/Checks.sol";
import { PowersTypes } from "@src/interfaces/PowersTypes.sol";
import { PowersErrors } from "@src/interfaces/PowersErrors.sol";
import { TestSetupPowers } from "../TestSetup.t.sol";
import { PowersMock } from "../mocks/PowersMock.sol";
import { OpenAction } from "@src/core/mandates/executive/OpenAction.sol";
import { AlwaysRevertMock, MismatchedArraysMandate, TooManyTargetsMandate } from "../mocks/MandateMocks.sol";
import { IERC721Receiver } from "@lib/openzeppelin-contracts/contracts/token/ERC721/IERC721Receiver.sol";
import { IERC1155Receiver } from "@lib/openzeppelin-contracts/contracts/token/ERC1155/IERC1155Receiver.sol";

/// @notice Unit tests for Powers.sol, organized following the contract's function order.

//////////////////////////////////////////////////////////////
//               CONSTRUCTOR & RECEIVE                      //
//////////////////////////////////////////////////////////////
contract ConstructorTest is Test {
    function testConstructorRevertsWithEmptyName() public {
        vm.expectRevert(PowersErrors.Powers__InvalidName.selector);
        new Powers("", "", 10_000, 10_000, 100_000, address(0));
    }

    function testConstructorRevertsWithZeroMaxCallDataLength() public {
        vm.expectRevert(PowersErrors.Powers__InvalidMaxCallDataLength.selector);
        new Powers("This is a name", "", 0, 10_000, 10_000, address(0));
    }

    function testConstructorRevertsWithZeroMaxReturnsDataLength() public {
        vm.expectRevert(PowersErrors.Powers__InvalidReturnCallDataLength.selector);
        new Powers("This is a name", "", 10_000, 0, 10_000, address(0));
    }

    function testConstructorRevertsWithZeroMaxExecutionsLength() public {
        vm.expectRevert(PowersErrors.Powers__InvalidMaxExecutionsLength.selector);
        new Powers("This is a name", "", 10_000, 10_000, 0, address(0));
    }
}

contract DeployTest is TestSetupPowers {
    function testDeployPowersMock() public view {
        assertEq(daoMock.name(), "This is a test DAO");
        assertEq(
            daoMock.uri(),
            "https://aqua-famous-sailfish-288.mypinata.cloud/ipfs/bafkreibd3qgeohyjeamqtfgk66lr427gpp4ify5q4civ2khcgkwyvz5hcq"
        );
        assertEq(daoMock.version(), "v0.6.1");
        assertNotEq(daoMock.mandateCounter(), 0);
        assertNotEq(daoMock.hasRoleSince(alice, ROLE_ONE), 0);
    }

    function testDeployProtocolEmitsEvent() public {
        vm.expectEmit(true, false, false, false);
        emit Powers__Initialized(address(daoMock), "PowersMock", "https://example.com");
        vm.prank(alice);
        daoMock = new PowersMock();
    }

    function testDeployProtocolSetsSenderToAdmin() public {
        vm.prank(alice);
        daoMock = new PowersMock();
        assertNotEq(daoMock.hasRoleSince(alice, ADMIN_ROLE), 0);
    }

    function testDeployProtocolSetsAdminRole() public {
        vm.prank(alice);
        daoMock = new PowersMock();
        assertEq(daoMock.getAmountRoleHolders(ADMIN_ROLE), 1);
    }

    function testReceiveEther() public {
        uint256 amount = 1 ether;
        vm.deal(alice, amount);
        vm.prank(alice);
        (bool ok,) = address(daoMock).call{ value: amount }("");
        assertTrue(ok);
        assertEq(address(daoMock).balance, amount);
    }
}

//////////////////////////////////////////////////////////////
//               CONSTITUTE LOGIC                           //
//////////////////////////////////////////////////////////////
contract ConstituteTest is TestSetupPowers {
    function testConstituteRevertsIfCallerNotAdmin() public {
        vm.prank(alice);
        PowersMock freshDao = new PowersMock();

        PowersTypes.MandateInitData[] memory emptyData = new PowersTypes.MandateInitData[](0);
        vm.expectRevert(PowersErrors.Powers__OnlyAdmin.selector);
        vm.prank(bob);
        freshDao.constitute(emptyData);
    }

    function testConstituteRevertsIfAlreadyClosed() public {
        vm.prank(alice);
        PowersMock freshDao = new PowersMock();

        PowersTypes.MandateInitData[] memory emptyData = new PowersTypes.MandateInitData[](0);
        vm.prank(alice);
        freshDao.closeConstitute();

        vm.expectRevert(PowersErrors.Powers__ConstituteClosed.selector);
        vm.prank(alice);
        freshDao.constitute(emptyData);
    }

    function testCloseConstituteWithNewAdminTransfersAdminRole() public {
        vm.prank(alice);
        PowersMock freshDao = new PowersMock();

        address newAdmin = makeAddr("newAdmin");

        vm.prank(alice);
        freshDao.closeConstitute(newAdmin);

        assertEq(freshDao.hasRoleSince(alice, ADMIN_ROLE), 0, "old admin should lose admin role");
        assertNotEq(freshDao.hasRoleSince(newAdmin, ADMIN_ROLE), 0, "new admin should gain admin role");
    }

    function testCloseConstituteWithSameAdminKeepsRole() public {
        vm.prank(alice);
        PowersMock freshDao = new PowersMock();

        vm.prank(alice);
        freshDao.closeConstitute(alice); // same address

        assertNotEq(freshDao.hasRoleSince(alice, ADMIN_ROLE), 0, "admin should retain role");
    }

    function testCloseConstituteWithFlowsAddsFlows() public {
        vm.prank(alice);
        PowersMock freshDao = new PowersMock();

        PowersTypes.Flow[] memory _flows = new PowersTypes.Flow[](1);
        _flows[0].mandateIds = new uint16[](2);
        _flows[0].mandateIds[0] = 1;
        _flows[0].mandateIds[1] = 2;
        _flows[0].nameDescription = "Test governance flow";

        vm.prank(alice);
        freshDao.closeConstitute(alice, _flows);

        assertEq(freshDao.getFlowCount(), 1);
        assertEq(freshDao.getFlowDescriptionAtIndex(0), "Test governance flow");
    }

    function testCloseConstituteRevertsIfCallerNotAdmin() public {
        vm.prank(alice);
        PowersMock freshDao = new PowersMock();

        vm.expectRevert(PowersErrors.Powers__OnlyAdmin.selector);
        vm.prank(bob);
        freshDao.closeConstitute();
    }
}

//////////////////////////////////////////////////////////////
//               GOVERNANCE: PROPOSE                        //
//////////////////////////////////////////////////////////////
contract ProposeTest is TestSetupPowers {
    function testProposePassesWithCorrectCredentials() public {
        mandateId = 3; // StatementOfIntent — needs ROLE_ONE
        mandateCalldata = abi.encode(true);
        assertTrue(daoMock.canCallMandate(bob, mandateId));

        vm.prank(bob);
        actionId = daoMock.propose(mandateId, mandateCalldata, nonce, description);

        assertEq(uint8(daoMock.getActionState(actionId)), uint8(ActionState.Active));
    }

    function testProposeRevertsWhenAccountLacksCredentials() public {
        mandateId = 3; // StatementOfIntent — needs ROLE_ONE
        mandateCalldata = abi.encode(true);
        account = makeAddr("mock");
        assertFalse(daoMock.canCallMandate(account, mandateId));

        vm.expectRevert(Powers__CannotCallMandate.selector);
        vm.prank(account);
        daoMock.propose(mandateId, mandateCalldata, nonce, description);
    }

    function testProposeRevertsIfMandateNotActive() public {
        mandateId = 3; // StatementOfIntent
        mandateCalldata = abi.encode(true);

        vm.prank(address(daoMock));
        daoMock.revokeMandate(mandateId);

        vm.expectRevert(Powers__MandateNotActive.selector);
        vm.prank(bob);
        daoMock.propose(mandateId, mandateCalldata, nonce, description);
    }

    function testProposeRevertsIfAlreadyExist() public {
        mandateId = 3;
        mandateCalldata = abi.encode(true);
        vm.prank(bob);
        daoMock.propose(mandateId, mandateCalldata, nonce, description);

        vm.expectRevert(Powers__ActionAlreadyInitiated.selector);
        vm.prank(bob);
        daoMock.propose(mandateId, mandateCalldata, nonce, description);
    }

    function testProposeRevertsIfConstituteOpen() public {
        vm.prank(alice);
        PowersMock freshDao = new PowersMock();

        vm.expectRevert(Powers__ConstituteOpen.selector);
        vm.prank(alice);
        freshDao.propose(1, abi.encode(true), nonce, description);
    }

    function testProposeRevertsWithBlacklistedCaller() public {
        mandateId = 3;
        mandateCalldata = abi.encode(true);

        vm.prank(address(daoMock));
        daoMock.blacklistAddress(bob, true);

        vm.expectRevert(PowersErrors.Powers__AddressBlacklisted.selector);
        vm.prank(bob);
        daoMock.propose(mandateId, mandateCalldata, nonce, "Test proposal");
    }

    function testProposeRevertsWithCalldataTooLong() public {
        mandateId = 3;
        mandateCalldata = new bytes(daoMock.MAX_CALLDATA_LENGTH() + 1);

        vm.expectRevert(PowersErrors.Powers__CalldataTooLong.selector);
        vm.prank(bob);
        daoMock.propose(mandateId, mandateCalldata, nonce, "Test proposal");
    }

    function testProposeEmitsEvent() public {
        mandateId = 3;
        mandateCalldata = abi.encode(true);
        actionId = MandateUtilities.computeActionId(mandateId, mandateCalldata, nonce);
        conditions = daoMock.getConditions(mandateId);

        vm.expectEmit(true, false, false, false);
        emit ProposedActionCreated(
            actionId,
            bob,
            mandateId,
            "",
            mandateCalldata,
            block.number,
            block.number + conditions.votingPeriod,
            nonce,
            description
        );
        vm.prank(bob);
        daoMock.propose(mandateId, mandateCalldata, nonce, description);
    }

    function testProposeSetsCorrectVotingDeadline() public {
        mandateId = 3;
        mandateCalldata = abi.encode(true);
        conditions = daoMock.getConditions(mandateId);

        vm.prank(bob);
        actionId = daoMock.propose(mandateId, mandateCalldata, nonce, description);

        (,, uint256 deadline,,,,) = daoMock.getActionVoteData(actionId);
        assertEq(deadline, block.number + conditions.votingPeriod);
    }
}

//////////////////////////////////////////////////////////////
//               GOVERNANCE: VOTE                           //
//////////////////////////////////////////////////////////////
contract VoteTest is TestSetupPowers {
    function testVotingRevertsIfAccountNotAuthorised() public {
        mandateId = 3;
        mandateCalldata = abi.encode(true);
        vm.prank(bob);
        actionId = daoMock.propose(mandateId, mandateCalldata, nonce, description);

        account = makeAddr("mock");
        assertFalse(daoMock.canCallMandate(account, mandateId));

        vm.expectRevert(Powers__CannotCallMandate.selector);
        vm.prank(account);
        daoMock.castVote(actionId, FOR);
    }

    function testProposalDefeatedIfQuorumNotReachedInTime() public {
        mandateId = 3;
        mandateCalldata = abi.encode(true);
        vm.prank(bob);
        actionId = daoMock.propose(mandateId, mandateCalldata, nonce, description);

        conditions = daoMock.getConditions(mandateId);
        vm.roll(block.number + conditions.votingPeriod + 1);

        assertEq(uint8(daoMock.getActionState(actionId)), uint8(ActionState.Defeated));
    }

    function testVotingIsNotPossibleForDefeatedProposals() public {
        mandateId = 3;
        mandateCalldata = abi.encode(true);
        vm.prank(bob);
        actionId = daoMock.propose(mandateId, mandateCalldata, nonce, description);

        conditions = daoMock.getConditions(mandateId);
        vm.roll(block.number + conditions.votingPeriod + 1);

        vm.expectRevert(Powers__ProposedActionNotActive.selector);
        vm.prank(charlotte);
        daoMock.castVote(actionId, FOR);
    }

    function testProposalSucceededIfQuorumReachedInTime() public {
        mandateId = 3;
        mandateCalldata = abi.encode(true);
        vm.prank(bob);
        actionId = daoMock.propose(mandateId, mandateCalldata, nonce, description);

        conditions = daoMock.getConditions(mandateId);
        for (i = 0; i < users.length; i++) {
            if (daoMock.hasRoleSince(users[i], conditions.allowedRole) != 0) {
                vm.prank(users[i]);
                daoMock.castVote(actionId, FOR);
            }
        }
        vm.roll(block.number + conditions.votingPeriod + 1);

        assertEq(uint8(daoMock.getActionState(actionId)), uint8(ActionState.Succeeded));
    }

    function testVoteRevertsWithInvalidVote() public {
        mandateId = 3;
        mandateCalldata = abi.encode(true);
        vm.prank(bob);
        actionId = daoMock.propose(mandateId, mandateCalldata, nonce, description);

        vm.expectRevert(Powers__InvalidVoteType.selector);
        vm.prank(alice);
        daoMock.castVote(actionId, 4);
    }

    function testVoteRevertsIfAlreadyCastVote() public {
        mandateId = 3;
        mandateCalldata = abi.encode(true);
        vm.prank(bob);
        actionId = daoMock.propose(mandateId, mandateCalldata, nonce, description);

        vm.prank(alice);
        daoMock.castVote(actionId, FOR);

        vm.expectRevert(Powers__AlreadyCastVote.selector);
        vm.prank(alice);
        daoMock.castVote(actionId, FOR);
    }

    function testVotesWithReasonsWorks() public {
        mandateId = 3;
        mandateCalldata = abi.encode(true);
        vm.prank(bob);
        actionId = daoMock.propose(mandateId, mandateCalldata, nonce, description);

        conditions = daoMock.getConditions(mandateId);
        for (i = 0; i < users.length; i++) {
            if (daoMock.hasRoleSince(users[i], conditions.allowedRole) != 0) {
                vm.prank(users[i]);
                daoMock.castVoteWithReason(actionId, FOR, "This is a test");
            }
        }
        vm.roll(block.number + conditions.votingPeriod + 1);

        assertEq(uint8(daoMock.getActionState(actionId)), uint8(ActionState.Succeeded));
    }

    function testProposalOutcomeVoteCounts() public {
        mandateId = 3;
        mandateCalldata = abi.encode(true);
        vm.prank(bob);
        actionId = daoMock.propose(mandateId, mandateCalldata, nonce, description);

        conditions = daoMock.getConditions(mandateId);
        againstVote = 0;
        forVote = 0;
        abstainVote = 0;

        for (i = 0; i < users.length; i++) {
            if (daoMock.hasRoleSince(users[i], conditions.allowedRole) != 0) {
                uint256 r = uint256(uint160(users[i])) % 3;
                if (r == 0) {
                    vm.prank(users[i]);
                    daoMock.castVote(actionId, AGAINST);
                    againstVote++;
                } else if (r == 1) {
                    vm.prank(users[i]);
                    daoMock.castVote(actionId, FOR);
                    forVote++;
                } else {
                    vm.prank(users[i]);
                    daoMock.castVote(actionId, ABSTAIN);
                    abstainVote++;
                }
            }
        }

        (,,, uint32 againstVotes, uint32 forVotes, uint32 abstainVotes,) = daoMock.getActionVoteData(actionId);
        assertEq(againstVotes, uint32(againstVote));
        assertEq(forVotes, uint32(forVote));
        assertEq(abstainVotes, uint32(abstainVote));
    }

    function testHasVotedReturnsTrueAfterVoting() public {
        mandateId = 3;
        mandateCalldata = abi.encode(true);
        vm.prank(bob);
        actionId = daoMock.propose(mandateId, mandateCalldata, nonce, description);

        vm.prank(alice);
        daoMock.castVote(actionId, ABSTAIN);

        assertTrue(daoMock.hasVoted(actionId, alice));
        assertFalse(daoMock.hasVoted(actionId, bob));
    }

    // C-01 regression: a concluded vote must not be flippable by mutating role membership before
    // request(). The eligible-voter count is snapshotted at voteStart and used as the denominator.
    function testVoteOutcomeNotDefeatedByMembershipInflation() public {
        mandateId = 3; // StatementOfIntent — needs ROLE_ONE (alice, bob → snapshot of 2)
        mandateCalldata = abi.encode(true);
        vm.prank(bob);
        actionId = daoMock.propose(mandateId, mandateCalldata, nonce, description);
        conditions = daoMock.getConditions(mandateId);

        // Both ROLE_ONE members vote FOR → passes the 66% threshold against the 2-member snapshot.
        vm.prank(alice);
        daoMock.castVote(actionId, FOR);
        vm.prank(bob);
        daoMock.castVote(actionId, FOR);

        // Inflate ROLE_ONE membership after the vote (the C-01 "defeat a passing proposal" attack).
        address[6] memory newMembers = [charlotte, david, eve, frank, gary, helen];
        vm.startPrank(address(daoMock));
        for (i = 0; i < newMembers.length; i++) {
            daoMock.assignRole(ROLE_ONE, newMembers[i]);
        }
        vm.stopPrank();

        vm.roll(block.number + conditions.votingPeriod + 1);

        // Frozen denominator (2) keeps this Succeeded; a live count (8) would flip it to Defeated.
        assertEq(uint8(daoMock.getActionState(actionId)), uint8(ActionState.Succeeded));
    }

    function testVoteOutcomeNotPassedByMembershipDeflation() public {
        mandateId = 3;
        mandateCalldata = abi.encode(true);
        vm.prank(bob);
        actionId = daoMock.propose(mandateId, mandateCalldata, nonce, description);
        conditions = daoMock.getConditions(mandateId);

        // Only a minority (1 of 2) votes FOR → fails the 66% threshold against the snapshot.
        vm.prank(alice);
        daoMock.castVote(actionId, FOR);

        // Shrink ROLE_ONE so a live count would turn alice's single FOR into a passing majority.
        vm.prank(address(daoMock));
        daoMock.revokeRole(ROLE_ONE, bob);

        vm.roll(block.number + conditions.votingPeriod + 1);

        // Frozen denominator (2) keeps this Defeated; a live count (1) would flip it to Succeeded.
        assertEq(uint8(daoMock.getActionState(actionId)), uint8(ActionState.Defeated));
    }

    function testVoteRevertsForMemberJoinedAfterVoteStart() public {
        mandateId = 3;
        mandateCalldata = abi.encode(true);
        vm.prank(bob);
        actionId = daoMock.propose(mandateId, mandateCalldata, nonce, description);

        // helen joins ROLE_ONE one block after voteStart (vote-stuffing attempt).
        vm.roll(block.number + 1);
        vm.prank(address(daoMock));
        daoMock.assignRole(ROLE_ONE, helen);

        // She can call the mandate, but joined after voteStart → not part of the snapshot, cannot vote.
        assertNotEq(daoMock.hasRoleSince(helen, ROLE_ONE), 0);
        vm.expectRevert(Powers__JoinedAfterVoteStart.selector);
        vm.prank(helen);
        daoMock.castVote(actionId, FOR);
    }

    function testVoterCountSnapshotEqualsMemberCountAtVoteStart() public {
        mandateId = 3;
        mandateCalldata = abi.encode(true);
        uint256 expectedCount = daoMock.getAmountRoleHolders(ROLE_ONE);

        vm.prank(bob);
        actionId = daoMock.propose(mandateId, mandateCalldata, nonce, description);

        (,,,,,, uint32 voterCountSnapshot) = daoMock.getActionVoteData(actionId);
        assertEq(uint256(voterCountSnapshot), expectedCount);
        assertEq(uint256(voterCountSnapshot), 2);
    }
}

//////////////////////////////////////////////////////////////
//               GOVERNANCE: CANCEL                         //
//////////////////////////////////////////////////////////////
contract CancelTest is TestSetupPowers {
    function testCancellingProposalsSetsStateToCancelled() public {
        mandateId = 3;
        mandateCalldata = abi.encode(true);
        vm.prank(bob);
        actionId = daoMock.propose(mandateId, mandateCalldata, nonce, description);

        vm.prank(bob);
        daoMock.cancel(mandateId, mandateCalldata, nonce);

        assertEq(uint8(daoMock.getActionState(actionId)), uint8(ActionState.Cancelled));
    }

    function testCancellingProposalsEmitsCorrectEvent() public {
        mandateId = 3;
        mandateCalldata = abi.encode(true);
        vm.prank(bob);
        actionId = daoMock.propose(mandateId, mandateCalldata, nonce, description);

        vm.expectEmit(true, false, false, false);
        emit ProposedActionCancelled(actionId);
        vm.prank(bob);
        daoMock.cancel(mandateId, mandateCalldata, nonce);
    }

    function testCancelRevertsWhenAccountDidNotCreateProposal() public {
        mandateId = 3;
        mandateCalldata = abi.encode(true);
        vm.prank(bob);
        daoMock.propose(mandateId, mandateCalldata, nonce, description);

        vm.expectRevert(Powers__NotProposerAction.selector);
        vm.prank(helen);
        daoMock.cancel(mandateId, mandateCalldata, nonce);
    }

    function testCancelledProposalsCannotBeCancelledAgain() public {
        mandateId = 3;
        mandateCalldata = abi.encode(true);
        vm.prank(bob);
        actionId = daoMock.propose(mandateId, mandateCalldata, nonce, description);

        vm.prank(bob);
        daoMock.cancel(mandateId, mandateCalldata, nonce);

        vm.expectRevert(Powers__UnexpectedActionState.selector);
        vm.prank(bob);
        daoMock.cancel(mandateId, mandateCalldata, nonce);
    }

    function testCancelRevertsIfActionAlreadyExecuted() public {
        mandateId = 3;
        mandateCalldata = abi.encode(true);
        vm.prank(bob);
        actionId = daoMock.propose(mandateId, mandateCalldata, nonce, description);

        conditions = daoMock.getConditions(mandateId);
        for (i = 0; i < users.length; i++) {
            if (daoMock.hasRoleSince(users[i], conditions.allowedRole) != 0) {
                vm.prank(users[i]);
                daoMock.castVote(actionId, FOR);
            }
        }
        vm.roll(block.number + conditions.votingPeriod + conditions.timelock + 1);
        vm.prank(bob);
        daoMock.request(mandateId, mandateCalldata, nonce, description);

        vm.expectRevert(Powers__UnexpectedActionState.selector);
        vm.prank(bob);
        daoMock.cancel(mandateId, mandateCalldata, nonce);
    }

    function testCancelRevertsIfMandateNotActive() public {
        mandateId = 3;
        mandateCalldata = abi.encode(true);
        vm.prank(bob);
        actionId = daoMock.propose(mandateId, mandateCalldata, nonce, description);

        vm.prank(address(daoMock));
        daoMock.revokeMandate(mandateId);

        vm.expectRevert(Powers__MandateNotActive.selector);
        vm.prank(bob);
        daoMock.cancel(mandateId, mandateCalldata, nonce);
    }

    function testCancelRevertsIfActionNotProposedOrRequested() public {
        // an actionId that was never propose()'d nor request()'d does not exist at all;
        // action.caller defaults to address(0), so prank as address(0) to pass the caller check
        // and isolate the existence check (proposedAt == 0 && requestedAt == 0).
        mandateId = 1;
        mandateCalldata = abi.encode(helen);

        vm.expectRevert(Powers__ActionNotProposed.selector);
        vm.prank(address(0));
        daoMock.cancel(mandateId, mandateCalldata, nonce);
    }

    function testCancelRevertsIfDirectRequestActionAlreadyFulfilled() public {
        // Execute mandate 1 (SelfSelect, PUBLIC_ROLE) directly via request — this sets requestedAt
        // (not proposedAt), and since SelfSelect is synchronous, fulfilledAt is also set in the same tx.
        // cancel() now recognizes the action via requestedAt, but rejects it as already-fulfilled
        // rather than reporting it as never having existed.
        mandateId = 1;
        mandateCalldata = abi.encode(helen);
        vm.prank(helen);
        daoMock.request(mandateId, mandateCalldata, nonce, description);

        vm.expectRevert(Powers__UnexpectedActionState.selector);
        vm.prank(helen);
        daoMock.cancel(mandateId, mandateCalldata, nonce);
    }
}

//////////////////////////////////////////////////////////////
//               GOVERNANCE: REQUEST (EXECUTE)              //
//////////////////////////////////////////////////////////////
contract RequestTest is TestSetupPowers {
    function testRequestCanChangeState() public {
        mandateId = 6; // PresetActions — PUBLIC_ROLE, no voting, assigns role labels
        mandateCalldata = abi.encode(true);
        assertEq(daoMock.getRoleLabel(ROLE_ONE), "");

        vm.prank(alice);
        daoMock.request(mandateId, mandateCalldata, nonce, description);

        assertEq(daoMock.getRoleLabel(ROLE_ONE), "Member");
        assertEq(daoMock.getRoleLabel(ROLE_TWO), "Delegate");
    }

    function testRequestSuccessSetsStateToFulfilled() public {
        mandateId = 6;
        mandateCalldata = abi.encode(true);

        vm.prank(alice);
        daoMock.request(mandateId, mandateCalldata, nonce, description);

        actionId = MandateUtilities.computeActionId(mandateId, mandateCalldata, nonce);
        assertEq(uint8(daoMock.getActionState(actionId)), uint8(ActionState.Fulfilled));
    }

    function testRequestRevertsIfNotAuthorised() public {
        mandateId = 3;
        mandateCalldata = abi.encode(true);
        account = makeAddr("mock");
        assertFalse(daoMock.canCallMandate(account, mandateId));

        vm.expectRevert(Powers__CannotCallMandate.selector);
        vm.prank(account);
        daoMock.request(mandateId, mandateCalldata, nonce, description);
    }

    function testRequestRevertsIfActionAlreadyExecuted() public {
        mandateId = 3;
        mandateCalldata = abi.encode(true);
        vm.prank(bob);
        actionId = daoMock.propose(mandateId, mandateCalldata, nonce, description);

        conditions = daoMock.getConditions(mandateId);
        for (i = 0; i < users.length; i++) {
            if (daoMock.hasRoleSince(users[i], conditions.allowedRole) != 0) {
                vm.prank(users[i]);
                daoMock.castVote(actionId, FOR);
            }
        }
        vm.roll(block.number + conditions.votingPeriod + conditions.timelock + 1);
        vm.prank(alice);
        daoMock.request(mandateId, mandateCalldata, nonce, description);

        vm.expectRevert(Powers__ActionAlreadyInitiated.selector);
        vm.prank(alice);
        daoMock.request(mandateId, mandateCalldata, nonce, description);
    }

    function testRequestRevertsIfMandateNotActive() public {
        mandateId = 6;
        mandateCalldata = abi.encode(true);

        vm.prank(address(daoMock));
        daoMock.revokeMandate(mandateId);

        vm.expectRevert(Powers__MandateNotActive.selector);
        vm.prank(alice);
        daoMock.request(mandateId, mandateCalldata, nonce, description);
    }

    function testRequestRevertsIfProposalNeeded() public {
        mandateId = 5; // Execute — needs mandate 3 fulfilled first
        mandateCalldata = abi.encode(true);

        vm.expectRevert(Checks.Checks__ParentMandateNotFulfilled.selector);
        vm.prank(charlotte);
        daoMock.request(mandateId, mandateCalldata, nonce, description);
    }

    function testRequestRevertsIfProposalDefeated() public {
        mandateId = 3;
        mandateCalldata = abi.encode(true);
        vm.prank(bob);
        actionId = daoMock.propose(mandateId, mandateCalldata, nonce, description);

        conditions = daoMock.getConditions(mandateId);
        for (i = 0; i < users.length; i++) {
            if (daoMock.hasRoleSince(users[i], conditions.allowedRole) != 0) {
                vm.prank(users[i]);
                daoMock.castVote(actionId, AGAINST);
            }
        }
        vm.roll(block.number + conditions.votingPeriod + 1);
        assertEq(uint8(daoMock.getActionState(actionId)), uint8(ActionState.Defeated));

        vm.expectRevert(Checks.Checks__ProposalNotSucceeded.selector);
        vm.prank(alice);
        daoMock.request(mandateId, mandateCalldata, nonce, description);
    }

    function testRequestRevertsIfProposalCancelled() public {
        mandateId = 3;
        mandateCalldata = abi.encode(true);
        vm.prank(bob);
        actionId = daoMock.propose(mandateId, mandateCalldata, nonce, description);

        vm.prank(bob);
        daoMock.cancel(mandateId, mandateCalldata, nonce);

        vm.expectRevert(Powers__ActionCancelled.selector);
        vm.prank(bob);
        daoMock.request(mandateId, mandateCalldata, nonce, description);
    }

    function testRequestRevertsIfConstituteOpen() public {
        vm.prank(alice);
        PowersMock freshDao = new PowersMock();

        vm.expectRevert(Powers__ConstituteOpen.selector);
        vm.prank(alice);
        freshDao.request(1, abi.encode(true), nonce, description);
    }
}

//////////////////////////////////////////////////////////////
//               GOVERNANCE: FULFILL                        //
//////////////////////////////////////////////////////////////
contract FulfillTest is TestSetupPowers {
    function testFulfillRevertsIfMandateNotActive() public {
        // Revoke mandate 1 so it is no longer active
        vm.prank(address(daoMock));
        daoMock.revokeMandate(1);

        vm.expectRevert(Powers__MandateNotActive.selector);
        vm.prank(alice);
        daoMock.fulfill(1, 0, new address[](0), new uint256[](0), new bytes[](0));
    }

    function testFulfillRevertsIfCallerNotTargetMandate() public {
        // Mandate 1 is active; alice is not the target mandate contract
        vm.expectRevert(Powers__CallerNotTargetMandate.selector);
        vm.prank(alice);
        daoMock.fulfill(1, 0, new address[](0), new uint256[](0), new bytes[](0));
    }

    function testFulfillRevertsIfActionNotRequested() public {
        // Propose creates proposedAt but not requestedAt
        mandateId = 3;
        mandateCalldata = abi.encode(true);
        vm.prank(bob);
        actionId = daoMock.propose(mandateId, mandateCalldata, nonce, description);

        (mandateAddress,,) = daoMock.getAdoptedMandate(mandateId);
        vm.expectRevert(Powers__ActionNotRequested.selector);
        vm.prank(mandateAddress);
        daoMock.fulfill(mandateId, actionId, new address[](0), new uint256[](0), new bytes[](0));
    }

    function testFulfillRevertsIfAlreadyFulfilled() public {
        // Execute mandate 3 (StatementOfIntent) via propose → vote → request; mandate stays active after execution
        mandateId = 3;
        mandateCalldata = abi.encode(true);
        vm.prank(bob);
        actionId = daoMock.propose(mandateId, mandateCalldata, nonce, description);

        conditions = daoMock.getConditions(mandateId);
        for (i = 0; i < users.length; i++) {
            if (daoMock.hasRoleSince(users[i], conditions.allowedRole) != 0) {
                vm.prank(users[i]);
                daoMock.castVote(actionId, FOR);
            }
        }
        vm.roll(block.number + conditions.votingPeriod + conditions.timelock + 1);
        vm.prank(alice);
        daoMock.request(mandateId, mandateCalldata, nonce, description);
        assertEq(uint8(daoMock.getActionState(actionId)), uint8(ActionState.Fulfilled));

        // Mandate 3 is still active; try to fulfill the already-fulfilled action
        (mandateAddress,,) = daoMock.getAdoptedMandate(mandateId);
        vm.expectRevert(Powers__ActionAlreadyFulfilled.selector);
        vm.prank(mandateAddress);
        daoMock.fulfill(mandateId, actionId, new address[](0), new uint256[](0), new bytes[](0));
    }

    function testFulfillRevertsIfMismatchedArrays() public {
        // Adopt a mandate whose handleRequest returns mismatched arrays
        MismatchedArraysMandate mismatchMandate =
            MismatchedArraysMandate(registerTestMandate(address(new MismatchedArraysMandate(address(registry)))));
        PowersTypes.MandateInitData memory initData = PowersTypes.MandateInitData({
            nameDescription: "Test mismatched: triggers Powers__InvalidCallData",
            targetMandate: address(mismatchMandate),
            config: abi.encode(),
            conditions: conditions // ADMIN_ROLE, no voting
        });
        vm.prank(address(daoMock));
        mandateId = daoMock.adoptMandate(initData);

        vm.expectRevert(PowersErrors.Powers__InvalidCallData.selector);
        vm.prank(alice);
        daoMock.request(mandateId, abi.encode(), nonce, description);
    }

    function testFulfillRevertsIfExecutionArrayTooLong() public {
        // Adopt a mandate whose handleRequest returns 26 targets (> MAX_EXECUTIONS_LENGTH=25)
        TooManyTargetsMandate tooManyMandate =
            TooManyTargetsMandate(registerTestMandate(address(new TooManyTargetsMandate(address(registry)))));
        PowersTypes.MandateInitData memory initData = PowersTypes.MandateInitData({
            nameDescription: "Test too many: triggers Powers__ExecutionArrayTooLong",
            targetMandate: address(tooManyMandate),
            config: abi.encode(),
            conditions: conditions // ADMIN_ROLE, no voting
        });
        vm.prank(address(daoMock));
        mandateId = daoMock.adoptMandate(initData);

        vm.expectRevert(PowersErrors.Powers__ExecutionArrayTooLong.selector);
        vm.prank(alice);
        daoMock.request(mandateId, abi.encode(), nonce, description);
    }

    function testFulfillRevertsIfCallFailsWithNoData() public {
        // OpenAction passes targets directly to fulfill; AlwaysRevertMock.revertNoData() fails with no returndata
        AlwaysRevertMock revertMock = new AlwaysRevertMock();
        OpenAction openAction = OpenAction(registerTestMandate(address(new OpenAction(address(registry)))));

        PowersTypes.Conditions memory openConditions;
        openConditions.allowedRole = PUBLIC_ROLE; // anyone can call
        PowersTypes.MandateInitData memory initData = PowersTypes.MandateInitData({
            nameDescription: "OpenAction test: for fulfill no-data fail",
            targetMandate: address(openAction),
            config: abi.encode(),
            conditions: openConditions
        });
        vm.prank(address(daoMock));
        mandateId = daoMock.adoptMandate(initData);

        targets = new address[](1);
        targets[0] = address(revertMock);
        values = new uint256[](1);
        values[0] = 0;
        calldatas = new bytes[](1);
        calldatas[0] = abi.encodeWithSelector(AlwaysRevertMock.revertNoData.selector);
        mandateCalldata = abi.encode(targets, values, calldatas);

        vm.expectRevert(PowersErrors.Powers__MandateFulfillCallFailed.selector);
        vm.prank(alice);
        daoMock.request(mandateId, mandateCalldata, nonce, description);
    }

    function testFulfillBubblesUpRevertData() public {
        // OpenAction passes targets directly to fulfill; AlwaysRevertMock.revertWithData() bubbles up the error
        AlwaysRevertMock revertMock = new AlwaysRevertMock();
        OpenAction openAction = OpenAction(registerTestMandate(address(new OpenAction(address(registry)))));

        PowersTypes.Conditions memory openConditions;
        openConditions.allowedRole = PUBLIC_ROLE;
        PowersTypes.MandateInitData memory initData = PowersTypes.MandateInitData({
            nameDescription: "OpenAction test: for fulfill bubbled revert",
            targetMandate: address(openAction),
            config: abi.encode(),
            conditions: openConditions
        });
        vm.prank(address(daoMock));
        mandateId = daoMock.adoptMandate(initData);

        targets = new address[](1);
        targets[0] = address(revertMock);
        values = new uint256[](1);
        values[0] = 0;
        calldatas = new bytes[](1);
        calldatas[0] = abi.encodeWithSelector(AlwaysRevertMock.revertWithData.selector);
        mandateCalldata = abi.encode(targets, values, calldatas);

        vm.expectRevert(AlwaysRevertMock.AlwaysRevertMock__Reverted.selector);
        vm.prank(alice);
        daoMock.request(mandateId, mandateCalldata, nonce, description);
    }
}

//////////////////////////////////////////////////////////////
//               MANDATE ADMIN                              //
//////////////////////////////////////////////////////////////
contract MandateAdminTest is TestSetupPowers {
    function testAdoptMandateSetsNewMandate() public {
        mandateCounter = daoMock.mandateCounter();
        newMandate = registerTestMandate(address(new OpenAction(address(registry))));

        PowersTypes.MandateInitData memory mandateInitData = PowersTypes.MandateInitData({
            nameDescription: "Test mandate: Test mandate description",
            targetMandate: newMandate,
            config: abi.encode(),
            conditions: conditions
        });

        vm.prank(address(daoMock));
        daoMock.adoptMandate(mandateInitData);

        (address mandate,,) = daoMock.getAdoptedMandate(mandateCounter);
        assertEq(mandate, newMandate);
    }

    function testAdoptMandateEmitsEvent() public {
        mandateCounter = daoMock.mandateCounter();
        newMandate = registerTestMandate(address(new OpenAction(address(registry))));

        PowersTypes.MandateInitData memory mandateInitData = PowersTypes.MandateInitData({
            nameDescription: "Test mandate: Test mandate description",
            targetMandate: newMandate,
            config: abi.encode(),
            conditions: conditions
        });

        vm.expectEmit(true, false, false, false);
        emit MandateAdopted(uint16(mandateCounter));
        vm.prank(address(daoMock));
        daoMock.adoptMandate(mandateInitData);
    }

    function testAdoptMandateRevertsIfNotCalledFromPowers() public {
        newMandate = registerTestMandate(address(new OpenAction(address(registry))));

        PowersTypes.MandateInitData memory mandateInitData = PowersTypes.MandateInitData({
            nameDescription: "Test mandate: Test mandate description",
            targetMandate: newMandate,
            config: abi.encode(),
            conditions: conditions
        });

        vm.expectRevert(Powers__OnlyPowers.selector);
        vm.prank(alice);
        daoMock.adoptMandate(mandateInitData);
    }

    function testAdoptMandateRevertsIfAddressNotAMandate() public {
        newMandate = address(3333);

        PowersTypes.MandateInitData memory mandateInitData = PowersTypes.MandateInitData({
            nameDescription: "Test mandate: Test mandate description",
            targetMandate: newMandate,
            config: abi.encode(),
            conditions: conditions
        });

        vm.expectRevert(abi.encodeWithSelector(Powers__IncorrectInterface.selector, newMandate));
        vm.prank(address(daoMock));
        daoMock.adoptMandate(mandateInitData);
    }

    function testAdoptMandateRevertsWithBlacklistedTarget() public {
        (mandateAddress,,) = daoMock.getAdoptedMandate(3);

        vm.prank(address(daoMock));
        daoMock.blacklistAddress(mandateAddress, true);

        PowersTypes.MandateInitData memory mandateInitData = PowersTypes.MandateInitData({
            nameDescription: "Test mandate", targetMandate: mandateAddress, config: abi.encode(), conditions: conditions
        });

        vm.expectRevert(PowersErrors.Powers__AddressBlacklisted.selector);
        vm.prank(address(daoMock));
        daoMock.adoptMandate(mandateInitData);
    }

    function testAdoptMandateRevertsWithPublicRoleAndQuorum() public {
        newMandate = registerTestMandate(address(new OpenAction(address(registry))));

        PowersTypes.Conditions memory invalidConditions = PowersTypes.Conditions({
            allowedRole: PUBLIC_ROLE,
            quorum: 50,
            succeedAt: 0,
            votingPeriod: 0,
            timelock: 0,
            throttleExecution: 0,
            needFulfilled: 0,
            needNotFulfilled: 0,
            maxExecutionDelay: 0
        });

        PowersTypes.MandateInitData memory mandateInitData = PowersTypes.MandateInitData({
            nameDescription: "Test mandate",
            targetMandate: newMandate,
            config: abi.encode(),
            conditions: invalidConditions
        });

        vm.expectRevert(PowersErrors.Powers__VoteWithPublicRoleDisallowed.selector);
        vm.prank(address(daoMock));
        daoMock.adoptMandate(mandateInitData);
    }

    function testAdoptingSameMandateTwice() public {
        newMandate = registerTestMandate(address(new OpenAction(address(registry))));

        vm.prank(alice);
        PowersMock daoMockTest = new PowersMock();

        PowersTypes.MandateInitData memory mandateInitData = PowersTypes.MandateInitData({
            nameDescription: "Test mandate: Test mandate description",
            targetMandate: newMandate,
            config: abi.encode(),
            conditions: conditions
        });

        vm.prank(address(daoMockTest));
        daoMockTest.adoptMandate(mandateInitData);

        vm.prank(address(daoMockTest));
        daoMockTest.adoptMandate(mandateInitData);

        for (i = 1; i <= 2; i++) {
            (address mandate,,) = daoMockTest.getAdoptedMandate(uint16(i));
            assertEq(mandate, newMandate);
        }
    }

    function testRevokeMandateRevertsIfAddressNotActive() public {
        vm.prank(address(daoMock));
        daoMock.revokeMandate(1);

        vm.expectRevert(Powers__MandateNotActive.selector);
        vm.prank(address(daoMock));
        daoMock.revokeMandate(1);
    }
}

//////////////////////////////////////////////////////////////
//               ROLE ADMIN                                 //
//////////////////////////////////////////////////////////////
contract RoleAdminTest is TestSetupPowers {
    function testAssignRoleSetsNewRole() public {
        assertEq(daoMock.hasRoleSince(helen, ROLE_THREE), 0);

        vm.prank(address(daoMock));
        daoMock.assignRole(ROLE_THREE, helen);

        assertNotEq(daoMock.hasRoleSince(helen, ROLE_THREE), 0);
    }

    function testAssignRoleRevertsWhenCalledFromOutsideProtocol() public {
        vm.expectRevert(Powers__OnlyPowers.selector);
        vm.prank(alice);
        daoMock.assignRole(ROLE_THREE, bob);
    }

    function testAssignRoleEmitsCorrectEventIfAccountAlreadyHasRole() public {
        assertNotEq(daoMock.hasRoleSince(bob, ROLE_ONE), 0);

        vm.expectEmit(true, false, false, false);
        emit RoleSet(ROLE_ONE, bob, false);
        vm.prank(address(daoMock));
        daoMock.assignRole(ROLE_ONE, bob);
    }

    function testAssignRoleAddsOneToAmountMembers() public {
        balanceBefore = daoMock.getAmountRoleHolders(ROLE_THREE);
        assertEq(daoMock.hasRoleSince(helen, ROLE_THREE), 0);

        vm.prank(address(daoMock));
        daoMock.assignRole(ROLE_THREE, helen);

        balanceAfter = daoMock.getAmountRoleHolders(ROLE_THREE);
        assertNotEq(daoMock.hasRoleSince(helen, ROLE_THREE), 0);
        assertEq(balanceAfter, balanceBefore + 1);
    }

    function testRevokeRoleSubtractsOneFromAmountMembers() public {
        balanceBefore = daoMock.getAmountRoleHolders(ROLE_ONE);
        assertNotEq(daoMock.hasRoleSince(bob, ROLE_ONE), 0);

        vm.prank(address(daoMock));
        daoMock.revokeRole(ROLE_ONE, bob);

        balanceAfter = daoMock.getAmountRoleHolders(ROLE_ONE);
        assertEq(daoMock.hasRoleSince(bob, ROLE_ONE), 0);
        assertEq(balanceAfter, balanceBefore - 1);
    }

    function testAssignRoleEmitsEvent() public {
        vm.expectEmit(true, false, false, false);
        emit RoleSet(ROLE_THREE, helen, true);
        vm.prank(address(daoMock));
        daoMock.assignRole(ROLE_THREE, helen);
    }

    function testAssignRoleRevertsWithBlacklistedAccount() public {
        account = makeAddr("blacklisted");
        vm.prank(address(daoMock));
        daoMock.blacklistAddress(account, true);

        vm.expectRevert(PowersErrors.Powers__AddressBlacklisted.selector);
        vm.prank(address(daoMock));
        daoMock.assignRole(ROLE_THREE, account);
    }

    function testAssignRoleRevertsWithPublicRole() public {
        vm.expectRevert(PowersErrors.Powers__CannotSetPublicRole.selector);
        vm.prank(address(daoMock));
        daoMock.assignRole(PUBLIC_ROLE, alice);
    }

    function testAssignRoleRevertsWithZeroAddress() public {
        vm.expectRevert(PowersErrors.Powers__CannotAddZeroAddress.selector);
        vm.prank(address(daoMock));
        daoMock.assignRole(ROLE_THREE, address(0));
    }

    function testRevokeRoleRemovesRoleCorrectly() public {
        vm.prank(address(daoMock));
        daoMock.assignRole(ROLE_THREE, alice);

        balanceBefore = daoMock.getAmountRoleHolders(ROLE_THREE);
        assertEq(balanceBefore, 1);

        vm.prank(address(daoMock));
        daoMock.revokeRole(ROLE_THREE, alice);

        assertEq(daoMock.getAmountRoleHolders(ROLE_THREE), 0);
        assertEq(daoMock.hasRoleSince(alice, ROLE_THREE), 0);
    }

    function testLabelRoleEmitsCorrectEvent() public {
        vm.expectEmit(true, false, false, false);
        emit RoleLabel(ROLE_THREE, "This is role three");
        vm.prank(address(daoMock));
        daoMock.labelRole(ROLE_THREE, "This is role three", "");
    }

    function testLabelRoleRevertsWithEmptyLabel() public {
        vm.expectRevert(PowersErrors.Powers__InvalidLabel.selector);
        vm.prank(address(daoMock));
        daoMock.labelRole(ROLE_THREE, "", "");
    }

    function testLabelRoleRevertsWithLabelTooLong() public {
        string memory longLabel =
            "This is a very long label that exceeds the maximum allowed length of 255 characters and should cause the function to revert when trying to set it as a role label in the Powers protocol governance system which has strict validation rules to prevent abuse and ensure proper formatting of role labels";

        vm.expectRevert(PowersErrors.Powers__LabelTooLong.selector);
        vm.prank(address(daoMock));
        daoMock.labelRole(ROLE_THREE, longLabel, "");
    }

    function testGetAmountRoleHoldersEmptyRole() public view {
        assertEq(daoMock.getAmountRoleHolders(ROLE_THREE), 0);
    }
}

//////////////////////////////////////////////////////////////
//               FLOW ADMIN                                 //
//////////////////////////////////////////////////////////////
contract FlowAdminTest is TestSetupPowers {
    function testAddFlowAddsToFlows() public {
        uint256 countBefore = daoMock.getFlowCount();

        PowersTypes.Flow memory flow;
        flow.mandateIds = new uint16[](2);
        flow.mandateIds[0] = 1;
        flow.mandateIds[1] = 2;
        flow.nameDescription = "Test governance flow";

        vm.prank(address(daoMock));
        daoMock.addFlow(flow);

        assertEq(daoMock.getFlowCount(), countBefore + 1);
    }

    function testAddFlowRevertsIfNotCalledFromPowers() public {
        PowersTypes.Flow memory flow;
        flow.mandateIds = new uint16[](0);
        flow.nameDescription = "Test flow";

        vm.expectRevert(Powers__OnlyPowers.selector);
        vm.prank(alice);
        daoMock.addFlow(flow);
    }

    function testRemoveFlowDeletesFlow() public {
        PowersTypes.Flow memory flow;
        flow.mandateIds = new uint16[](1);
        flow.mandateIds[0] = 1;
        flow.nameDescription = "To be removed";

        vm.prank(address(daoMock));
        daoMock.addFlow(flow);

        uint256 countBefore = daoMock.getFlowCount();

        // delete clears the slot but does not remove it from the array
        vm.prank(address(daoMock));
        daoMock.removeFlow(0);

        // flow at index 0 should now be empty
        assertEq(daoMock.getFlowMandatesAtIndex(0).length, 0);
        assertEq(daoMock.getFlowCount(), countBefore);
    }

    function testRemoveFlowRevertsIfInvalidIndex() public {
        // flows array is empty initially in TestSetupPowers
        vm.expectRevert(Powers__InvalidFlowIndex.selector);
        vm.prank(address(daoMock));
        daoMock.removeFlow(0);
    }

    function testEditFlowByIndexChangesMandate() public {
        PowersTypes.Flow memory flow;
        flow.mandateIds = new uint16[](2);
        flow.mandateIds[0] = 1;
        flow.mandateIds[1] = 2;
        flow.nameDescription = "Editable flow";

        vm.prank(address(daoMock));
        daoMock.addFlow(flow);

        vm.prank(address(daoMock));
        daoMock.editFlowByIndex(0, 1, 3); // set mandateIds[1] = 3

        uint16[] memory ids = daoMock.getFlowMandatesAtIndex(0);
        assertEq(ids[1], 3);
    }

    function testEditFlowByIndexRevertsIfInvalidFlowIndex() public {
        vm.expectRevert(Powers__InvalidFlowIndex.selector);
        vm.prank(address(daoMock));
        daoMock.editFlowByIndex(99, 0, 1);
    }

    function testEditFlowByIndexRevertsIfInvalidMandateIndex() public {
        PowersTypes.Flow memory flow;
        flow.mandateIds = new uint16[](1);
        flow.mandateIds[0] = 1;
        flow.nameDescription = "Single mandate flow";

        vm.prank(address(daoMock));
        daoMock.addFlow(flow);

        vm.expectRevert(Powers__InvalidMandateIndex.selector);
        vm.prank(address(daoMock));
        daoMock.editFlowByIndex(0, 5, 1); // index 5 is out of bounds for 1-element array
    }

    function testEditFlowByIndexRevertsIfMandateIdTooHigh() public {
        PowersTypes.Flow memory flow;
        flow.mandateIds = new uint16[](1);
        flow.mandateIds[0] = 1;
        flow.nameDescription = "Single mandate flow";

        vm.prank(address(daoMock));
        daoMock.addFlow(flow);

        uint16 tooHighId = daoMock.mandateCounter() + 2;
        vm.expectRevert(Powers__InvalidMandateId.selector);
        vm.prank(address(daoMock));
        daoMock.editFlowByIndex(0, 0, tooHighId);
    }

    function testGetFlowCount() public {
        assertEq(daoMock.getFlowCount(), 0);

        PowersTypes.Flow memory flow;
        flow.mandateIds = new uint16[](0);
        flow.nameDescription = "Flow one";
        vm.prank(address(daoMock));
        daoMock.addFlow(flow);

        assertEq(daoMock.getFlowCount(), 1);
    }

    function testGetFlowMandatesAtIndex() public {
        PowersTypes.Flow memory flow;
        flow.mandateIds = new uint16[](2);
        flow.mandateIds[0] = 1;
        flow.mandateIds[1] = 3;
        flow.nameDescription = "Multi mandate flow";

        vm.prank(address(daoMock));
        daoMock.addFlow(flow);

        uint16[] memory ids = daoMock.getFlowMandatesAtIndex(0);
        assertEq(ids.length, 2);
        assertEq(ids[0], 1);
        assertEq(ids[1], 3);
    }

    function testGetFlowDescriptionAtIndex() public {
        PowersTypes.Flow memory flow;
        flow.mandateIds = new uint16[](0);
        flow.nameDescription = "Describable flow";

        vm.prank(address(daoMock));
        daoMock.addFlow(flow);

        assertEq(daoMock.getFlowDescriptionAtIndex(0), "Describable flow");
    }

    function testGetFlowMandatesAtIndexRevertsIfInvalidIndex() public {
        vm.expectRevert(Powers__InvalidIndex.selector);
        daoMock.getFlowMandatesAtIndex(99);
    }

    function testGetFlowDescriptionAtIndexRevertsIfInvalidIndex() public {
        vm.expectRevert(Powers__InvalidIndex.selector);
        daoMock.getFlowDescriptionAtIndex(99);
    }
}

//////////////////////////////////////////////////////////////
//               PROTOCOL SETTINGS                          //
//////////////////////////////////////////////////////////////
contract ProtocolSettingsTest is TestSetupPowers {
    function testSetUriChangesUri() public {
        string memory newUri = "https://new-uri.example.com";
        vm.prank(address(daoMock));
        daoMock.setUri(newUri);
        assertEq(daoMock.uri(), newUri);
    }

    function testSetUriRevertsIfNotCalledFromPowers() public {
        vm.expectRevert(Powers__OnlyPowers.selector);
        vm.prank(alice);
        daoMock.setUri("https://new-uri.example.com");
    }

    function testSetTreasurySetsTreasury() public {
        address payable newTreasury = payable(makeAddr("treasury"));
        vm.prank(address(daoMock));
        daoMock.setTreasury(newTreasury);
        assertEq(daoMock.getTreasury(), newTreasury);
    }

    function testSetTreasuryRevertsWithZeroAddress() public {
        vm.expectRevert(Powers__CannotSetZeroAddress.selector);
        vm.prank(address(daoMock));
        daoMock.setTreasury(payable(address(0)));
    }

    function testSetPaymasterSetsPaymaster() public {
        address newPaymaster = makeAddr("paymaster");
        vm.prank(address(daoMock));
        daoMock.setPaymaster(newPaymaster);
        assertEq(daoMock.paymaster(), newPaymaster);
    }

    function testSetPaymasterRevertsWithZeroAddress() public {
        vm.expectRevert(Powers__CannotSetZeroAddress.selector);
        vm.prank(address(daoMock));
        daoMock.setPaymaster(address(0));
    }

    function testSetPaymasterEmitsEvent() public {
        address newPaymaster = makeAddr("paymaster");
        vm.expectEmit(true, false, false, false);
        emit PaymasterSet(newPaymaster);
        vm.prank(address(daoMock));
        daoMock.setPaymaster(newPaymaster);
    }
}

//////////////////////////////////////////////////////////////
//               TOKEN RECEIVERS                            //
//////////////////////////////////////////////////////////////
contract TokenReceiverTest is TestSetupPowers {
    function testOnERC721ReceivedReturnsSelector() public {
        bytes4 result = daoMock.onERC721Received(address(0), address(0), 0, "");
        assertEq(result, IERC721Receiver.onERC721Received.selector);
    }

    function testOnERC1155ReceivedReturnsSelector() public {
        bytes4 result = daoMock.onERC1155Received(address(0), address(0), 0, 0, "");
        assertEq(result, IERC1155Receiver.onERC1155Received.selector);
    }

    function testOnERC1155BatchReceivedReturnsSelector() public {
        bytes4 result = daoMock.onERC1155BatchReceived(address(0), address(0), new uint256[](0), new uint256[](0), "");
        assertEq(result, IERC1155Receiver.onERC1155BatchReceived.selector);
    }

    function testSupportsInterfaceERC721Receiver() public view {
        assertTrue(daoMock.supportsInterface(type(IERC721Receiver).interfaceId));
    }

    function testSupportsInterfaceERC1155Receiver() public view {
        assertTrue(daoMock.supportsInterface(type(IERC1155Receiver).interfaceId));
    }
}

//////////////////////////////////////////////////////////////
//               VIEW / GETTER FUNCTIONS                    //
//////////////////////////////////////////////////////////////
contract ViewFunctionsTest is TestSetupPowers {
    function testGetActionCalldataReturnsCorrectData() public {
        mandateId = 3;
        mandateCalldata = abi.encode(true);
        vm.prank(bob);
        actionId = daoMock.propose(mandateId, mandateCalldata, nonce, description);

        assertEq(daoMock.getActionCalldata(actionId), mandateCalldata);
    }

    function testGetActionUriReturnsCorrectData() public {
        mandateId = 6;
        mandateCalldata = abi.encode(true);
        string memory testUri = "https://action-uri.example.com";

        vm.prank(alice);
        daoMock.request(mandateId, mandateCalldata, nonce, testUri);

        actionId = MandateUtilities.computeActionId(mandateId, mandateCalldata, nonce);
        assertEq(daoMock.getActionUri(actionId), testUri);
    }

    function testGetActionStateNonExistent() public view {
        assertEq(uint8(daoMock.getActionState(999_999)), uint8(ActionState.NonExistent));
    }

    function testGetLatestFulfillmentAfterExecution() public {
        mandateId = 6;
        mandateCalldata = abi.encode(true);

        assertEq(daoMock.getLatestFulfillment(mandateId), 0);

        vm.prank(alice);
        daoMock.request(mandateId, mandateCalldata, nonce, description);

        assertEq(daoMock.getLatestFulfillment(mandateId), block.number);
    }

    function testGetQuantityMandateActionsAfterRequests() public {
        assertEq(daoMock.getQuantityMandateActions(6), 0);

        mandateId = 6;
        mandateCalldata = abi.encode(true);
        vm.prank(alice);
        daoMock.request(mandateId, mandateCalldata, nonce, description);

        assertEq(daoMock.getQuantityMandateActions(mandateId), 1);
    }

    function testGetMandateActionAtIndex() public {
        mandateId = 6;
        mandateCalldata = abi.encode(true);
        vm.prank(alice);
        daoMock.request(mandateId, mandateCalldata, nonce, description);

        actionId = MandateUtilities.computeActionId(mandateId, mandateCalldata, nonce);
        assertEq(daoMock.getMandateActionAtIndex(mandateId, 0), actionId);
    }

    function testGetMandateActionAtIndexRevertsIfInvalidIndex() public {
        vm.expectRevert(Powers__InvalidIndex.selector);
        daoMock.getMandateActionAtIndex(6, 99);
    }

    function testGetMandateCounterReturnsCorrectValue() public view {
        assertEq(daoMock.getMandateCounter(), daoMock.mandateCounter());
    }

    function testGetRoleMetadata() public {
        vm.prank(address(daoMock));
        daoMock.labelRole(ROLE_ONE, "Member", "ipfs://role-one-metadata");

        assertEq(daoMock.getRoleMetadata(ROLE_ONE), "ipfs://role-one-metadata");
    }

    function testGetRoleHolderAtIndexRevertsIfInvalidIndex() public {
        // ROLE_THREE has no members
        vm.expectRevert(Powers__InvalidIndex.selector);
        daoMock.getRoleHolderAtIndex(ROLE_THREE, 0);
    }

    function testGetActionReturnData() public {
        mandateId = 6; // PresetActions returns empty returndata for each call
        mandateCalldata = abi.encode(true);
        vm.prank(alice);
        daoMock.request(mandateId, mandateCalldata, nonce, description);

        actionId = MandateUtilities.computeActionId(mandateId, mandateCalldata, nonce);
        // First call (labelRole) returns empty bytes
        bytes memory returnData = daoMock.getActionReturnData(actionId, 0);
        assertEq(returnData.length, 0);
    }
}
