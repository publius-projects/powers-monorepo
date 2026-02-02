// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.26;

import { Test } from "forge-std/Test.sol";
import { Powers } from "../../src/Powers.sol";
import { Mandate } from "../../src/Mandate.sol";
import { MandateUtilities } from "../../src/libraries/MandateUtilities.sol";
import { Checks } from "../../src/libraries/Checks.sol";
import { IMandate } from "../../src/interfaces/IMandate.sol";
import { PowersTypes } from "../../src/interfaces/PowersTypes.sol";
import { PowersErrors } from "../../src/interfaces/PowersErrors.sol";
import { TestSetupPowers } from "../TestSetup.t.sol";
import { PowersMock } from "../mocks/PowersMock.sol";
import { OpenAction } from "../../src/mandates/executive/OpenAction.sol";

import { SimpleErc1155 } from "@mocks/SimpleErc1155.sol";

/// @notice Unit tests for the core Powers protocol (updated v0.4)

//////////////////////////////////////////////////////////////
//               CONSTRUCTOR & RECEIVE                      //
//////////////////////////////////////////////////////////////
contract DeployTest is TestSetupPowers {
    function testDeployPowersMock() public view {
        assertEq(daoMock.name(), "This is a test DAO");
        assertEq(
            daoMock.uri(),
            "https://aqua-famous-sailfish-288.mypinata.cloud/ipfs/bafkreibd3qgeohyjeamqtfgk66lr427gpp4ify5q4civ2khcgkwyvz5hcq"
        );
        assertEq(daoMock.version(), "0.5");
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
}

//////////////////////////////////////////////////////////////
//                  GOVERNANCE LOGIC                        //
//////////////////////////////////////////////////////////////
contract ProposeTest is TestSetupPowers {
    function testProposeRevertsWhenAccountLacksCredentials() public {
        mandateId = 3; // StatementOfIntent - needs ROLE_ONE
        description = "Creating a proposal";
        mandateCalldata = abi.encode(true);
        account = makeAddr("mock");
        assertFalse(daoMock.canCallMandate(account, mandateId));

        vm.expectRevert(Powers__CannotCallMandate.selector);
        vm.prank(account);
        daoMock.propose(mandateId, mandateCalldata, nonce, description);
    }

    function testProposeRevertsIfMandateNotActive() public {
        mandateId = 3; // StatementOfIntent - needs ROLE_ONE
        description = "Creating a proposal";
        mandateCalldata = abi.encode(true);
        assertTrue(daoMock.canCallMandate(bob, mandateId), "bob should be able to call mandate 4");

        vm.prank(address(daoMock));
        daoMock.revokeMandate(mandateId);

        vm.expectRevert(Powers__MandateNotActive.selector);
        vm.prank(charlotte);
        daoMock.propose(mandateId, mandateCalldata, nonce, description);
    }

    function testProposeRevertsIfMandateDoesNotNeedVote() public {
        mandateId = 2; // self select  - does not need vote
        description = "Creating a proposal";
        mandateCalldata = abi.encode(true);
        assertTrue(daoMock.canCallMandate(david, mandateId), "david should be able to call mandate 2");

        vm.prank(david);
        vm.expectRevert(Powers__NoVoteNeeded.selector);
        daoMock.propose(mandateId, mandateCalldata, nonce, description);
    }

    function testProposePassesWithCorrectCredentials() public {
        mandateId = 3; // StatementOfIntent - needs ROLE_ONE
        description = "Creating a proposal";
        mandateCalldata = abi.encode(true);
        assertTrue(daoMock.canCallMandate(bob, mandateId));

        vm.prank(bob);
        actionId = daoMock.propose(mandateId, mandateCalldata, nonce, description);

        ActionState actionState = daoMock.getActionState(actionId);
        assertEq(uint8(actionState), uint8(ActionState.Active));
    }

    function testProposeEmitsEvents() public {
        mandateId = 3; // StatementOfIntent - needs ROLE_ONE
        description = "Creating a proposal";
        mandateCalldata = abi.encode(true);
        assertTrue(daoMock.hasRoleSince(bob, ROLE_ONE) != 0, "bob should have role 1");
        assertTrue(daoMock.canCallMandate(bob, mandateId), "bob should be able to call mandate 4");

        actionId = MandateUtilities.computeActionId(mandateId, mandateCalldata, nonce);

        (mandateAddress, mandateHash, active) = daoMock.getAdoptedMandate(mandateId);
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

    function testProposeRevertsIfAlreadyExist() public {
        mandateId = 3; // StatementOfIntent - needs ROLE_ONE
        description = "Creating a proposal";
        mandateCalldata = abi.encode(true);
        assertTrue(daoMock.canCallMandate(bob, mandateId));

        vm.prank(bob);
        daoMock.propose(mandateId, mandateCalldata, nonce, description);

        vm.expectRevert(Powers__UnexpectedActionState.selector);
        vm.prank(bob);
        daoMock.propose(mandateId, mandateCalldata, nonce, description);
    }

    function testProposeSetsCorrectVoteStartAndDuration() public {
        mandateId = 3; // StatementOfIntent - needs ROLE_ONE
        description = "Creating a proposal";
        mandateCalldata = abi.encode(true);

        vm.prank(bob);
        actionId = daoMock.propose(mandateId, mandateCalldata, nonce, description);
        (mandateAddress, mandateHash, active) = daoMock.getAdoptedMandate(mandateId);
        conditions = daoMock.getConditions(mandateId);

        (,, uint256 deadline,,,) = daoMock.getActionVoteData(actionId);

        assertEq(deadline, block.number + conditions.votingPeriod);
    }
}

contract CancelTest is TestSetupPowers {
    function testCancellingProposalsEmitsCorrectEvent() public {
        mandateId = 3; // StatementOfIntent - needs ROLE_ONE
        mandateCalldata = abi.encode(true);
        vm.prank(bob);
        actionId = daoMock.propose(mandateId, mandateCalldata, nonce, description);

        vm.expectEmit(true, false, false, false);
        emit ProposedActionCancelled(actionId);
        vm.prank(bob);
        daoMock.cancel(mandateId, mandateCalldata, nonce);
    }

    function testCancellingProposalsSetsStateToCancelled() public {
        mandateId = 3; // StatementOfIntent - needs ROLE_ONE
        mandateCalldata = abi.encode(true);
        vm.prank(bob);
        actionId = daoMock.propose(mandateId, mandateCalldata, nonce, description);

        vm.prank(bob);
        daoMock.cancel(mandateId, mandateCalldata, nonce);

        ActionState actionState = daoMock.getActionState(actionId);
        assertEq(uint8(actionState), uint8(ActionState.Cancelled));
    }

    function testCancelRevertsWhenAccountDidNotCreateProposal() public {
        mandateId = 3; // StatementOfIntent - needs ROLE_ONE
        mandateCalldata = abi.encode(true);
        vm.prank(bob);
        daoMock.propose(mandateId, mandateCalldata, nonce, description);

        vm.expectRevert(Powers__NotProposerAction.selector);
        vm.prank(helen);
        daoMock.cancel(mandateId, mandateCalldata, nonce);
    }

    function testCancelledProposalsCannotBeCancelledAgain() public {
        mandateId = 3; // StatementOfIntent - needs ROLE_ONE
        mandateCalldata = abi.encode(true);
        vm.prank(bob);
        actionId = daoMock.propose(mandateId, mandateCalldata, nonce, description);

        vm.prank(bob);
        daoMock.cancel(mandateId, mandateCalldata, nonce);

        vm.expectRevert(Powers__UnexpectedActionState.selector);
        vm.prank(bob);
        daoMock.cancel(mandateId, mandateCalldata, nonce);
    }

    function testCancelRevertsIfProposalAlreadyExecuted() public {
        mandateId = 3; // StatementOfIntent - needs ROLE_ONE
        targets = new address[](1);
        targets[0] = address(123);
        values = new uint256[](1);
        values[0] = 0;
        calldatas = new bytes[](1);
        calldatas[0] = abi.encode("mockCall");

        mandateCalldata = abi.encode(targets, values, calldatas);
        vm.prank(bob);
        actionId = daoMock.propose(mandateId, mandateCalldata, nonce, description);
        (mandateAddress, mandateHash, active) = daoMock.getAdoptedMandate(mandateId);
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
        mandateId = 3; // StatementOfIntent - needs ROLE_ONE
        mandateCalldata = abi.encode(true);
        vm.prank(bob);
        actionId = daoMock.propose(mandateId, mandateCalldata, nonce, description);

        vm.prank(address(daoMock));
        daoMock.revokeMandate(mandateId);

        vm.expectRevert(Powers__MandateNotActive.selector);
        vm.prank(bob);
        daoMock.cancel(mandateId, mandateCalldata, nonce);
    }
}

contract VoteTest is TestSetupPowers {
    function testVotingRevertsIfAccountNotAuthorised() public {
        mandateId = 3; // StatementOfIntent - needs ROLE_ONE
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
        mandateId = 3; // StatementOfIntent - needs ROLE_ONE
        mandateCalldata = abi.encode(true);
        vm.prank(bob);
        actionId = daoMock.propose(mandateId, mandateCalldata, nonce, description);

        (mandateAddress, mandateHash, active) = daoMock.getAdoptedMandate(mandateId);
        conditions = daoMock.getConditions(mandateId);

        vm.roll(block.number + conditions.votingPeriod + 1);

        ActionState actionState = daoMock.getActionState(actionId);
        assertEq(uint8(actionState), uint8(ActionState.Defeated));
    }

    function testVotingIsNotPossibleForDefeatedProposals() public {
        mandateId = 3; // StatementOfIntent - needs ROLE_ONE
        mandateCalldata = abi.encode(true);
        vm.prank(bob);
        actionId = daoMock.propose(mandateId, mandateCalldata, nonce, description);

        (mandateAddress, mandateHash, active) = daoMock.getAdoptedMandate(mandateId);
        conditions = daoMock.getConditions(mandateId);

        vm.roll(block.number + conditions.votingPeriod + 1);

        vm.expectRevert(Powers__ProposedActionNotActive.selector);
        vm.prank(charlotte);
        daoMock.castVote(actionId, FOR);
    }

    function testProposalSucceededIfQuorumReachedInTime() public {
        mandateId = 3; // StatementOfIntent - needs ROLE_ONE
        mandateCalldata = abi.encode(true);
        vm.prank(bob);
        actionId = daoMock.propose(mandateId, mandateCalldata, nonce, description);

        (mandateAddress, mandateHash, active) = daoMock.getAdoptedMandate(mandateId);
        conditions = daoMock.getConditions(mandateId);

        for (i = 0; i < users.length; i++) {
            if (daoMock.hasRoleSince(users[i], conditions.allowedRole) != 0) {
                vm.prank(users[i]);
                daoMock.castVote(actionId, FOR);
            }
        }
        vm.roll(block.number + conditions.votingPeriod + 1);

        ActionState actionState = daoMock.getActionState(actionId);
        assertEq(uint8(actionState), uint8(ActionState.Succeeded));
    }

    function testVotesWithReasonsWorks() public {
        mandateId = 3; // StatementOfIntent - needs ROLE_ONE
        mandateCalldata = abi.encode(true);
        vm.prank(bob);
        actionId = daoMock.propose(mandateId, mandateCalldata, nonce, description);

        (mandateAddress, mandateHash, active) = daoMock.getAdoptedMandate(mandateId);
        conditions = daoMock.getConditions(mandateId);

        for (i = 0; i < users.length; i++) {
            if (daoMock.hasRoleSince(users[i], conditions.allowedRole) != 0) {
                vm.prank(users[i]);
                daoMock.castVoteWithReason(actionId, FOR, "This is a test");
            }
        }
        vm.roll(block.number + conditions.votingPeriod + 1);

        ActionState actionState = daoMock.getActionState(actionId);
        assertEq(uint8(actionState), uint8(ActionState.Succeeded));
    }

    function testProposalOutcomeVoteCounts() public {
        mandateId = 3; // StatementOfIntent - needs ROLE_ONE
        mandateCalldata = abi.encode(true);
        vm.prank(bob);
        actionId = daoMock.propose(mandateId, mandateCalldata, nonce, description);

        (mandateAddress, mandateHash, active) = daoMock.getAdoptedMandate(mandateId);
        conditions = daoMock.getConditions(mandateId);

        // Reset votes
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

        (,,, uint32 againstVotes, uint32 forVotes, uint32 abstainVotes) = daoMock.getActionVoteData(actionId);
        assertEq(againstVotes, uint32(againstVote));
        assertEq(forVotes, uint32(forVote));
        assertEq(abstainVotes, uint32(abstainVote));
    }

    function testVoteRevertsWithInvalidVote() public {
        mandateId = 3; // StatementOfIntent - needs ROLE_ONE
        mandateCalldata = abi.encode(true);
        vm.prank(bob);
        actionId = daoMock.propose(mandateId, mandateCalldata, nonce, description);

        vm.prank(alice);
        vm.expectRevert(Powers__InvalidVoteType.selector);
        daoMock.castVote(actionId, 4);

        (,,, uint32 againstVotes, uint32 forVotes, uint32 abstainVotes) = daoMock.getActionVoteData(actionId);
        assertEq(againstVotes, 0);
        assertEq(forVotes, 0);
        assertEq(abstainVotes, 0);
    }

    function testHasVotedReturnCorrectData() public {
        mandateId = 3; // StatementOfIntent - needs ROLE_ONE
        mandateCalldata = abi.encode(true);
        vm.prank(bob);
        actionId = daoMock.propose(mandateId, mandateCalldata, nonce, description);

        vm.prank(alice);
        daoMock.castVote(actionId, ABSTAIN);

        assertTrue(daoMock.hasVoted(actionId, alice));
    }
}

contract ExecuteTest is TestSetupPowers {
    function testExecuteCanChangeState() public {
        mandateId = 6; // A Single Action: to assign labels to roles. It self-destructs after execution.
        mandateCalldata = abi.encode(true); // PresetActions_Single doesn't use this parameter, but we need to provide something

        // Check initial state - role labels should be empty
        assertEq(daoMock.getRoleLabel(ROLE_ONE), "");
        assertEq(daoMock.getRoleLabel(ROLE_TWO), "");
        assertTrue(daoMock.canCallMandate(alice, mandateId)); // Alice is admin and can call mandate 6

        vm.prank(alice);
        daoMock.request(mandateId, mandateCalldata, nonce, description);

        // Check that role labels were assigned
        assertEq(daoMock.getRoleLabel(ROLE_ONE), "Member");
        assertEq(daoMock.getRoleLabel(ROLE_TWO), "Delegate");
    }

    function testExecuteSuccessSetsStateToFulfilled() public {
        mandateId = 6; // A Single Action: to assign labels to roles. It self-destructs after execution.
        mandateCalldata = abi.encode(true); // PresetActions_Single doesn't use this parameter, but we need to provide something

        vm.prank(alice);
        daoMock.request(mandateId, mandateCalldata, nonce, description);

        actionId = MandateUtilities.computeActionId(mandateId, mandateCalldata, nonce);
        ActionState actionState = daoMock.getActionState(actionId);
        assertEq(uint8(actionState), uint8(ActionState.Fulfilled));
    }

    function testExecuteRevertsIfNotAuthorised() public {
        mandateId = 3; // Delegate Election - needs ROLE_ONE
        accounts = new address[](1);
        accounts[0] = makeAddr("mock");
        mandateCalldata = abi.encode(accounts);

        assertFalse(daoMock.canCallMandate(accounts[0], mandateId));

        vm.expectRevert(Powers__CannotCallMandate.selector);
        vm.prank(accounts[0]);
        daoMock.request(mandateId, mandateCalldata, nonce, description);
    }

    function testExecuteRevertsIfActionAlreadyExecuted() public {
        mandateId = 3; // = ROle ONE
        targets = new address[](1);
        values = new uint256[](1);
        calldatas = new bytes[](1);
        targets[0] = address(daoMock);
        values[0] = 0;
        calldatas[0] = abi.encodeWithSelector(daoMock.labelRole.selector, ROLE_ONE, "Member");

        (mandateAddress, mandateHash, active) = daoMock.getAdoptedMandate(mandateId);
        conditions = daoMock.getConditions(mandateId);

        mandateCalldata = abi.encode(targets, values, calldatas);
        vm.prank(alice);
        actionId = daoMock.propose(mandateId, mandateCalldata, nonce, description);
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

    function testExecuteRevertsIfMandateNotActive() public {
        mandateId = 6; // A Single Action: to assign labels to roles. It self-destructs after execution.
        mandateCalldata = abi.encode(true); // PresetActions_Single doesn't use this parameter, but we need to provide something

        vm.prank(address(daoMock));
        daoMock.revokeMandate(mandateId);

        vm.expectRevert(Powers__MandateNotActive.selector);
        vm.prank(alice);
        daoMock.request(mandateId, mandateCalldata, nonce, description);
    }

    function testExecuteRevertsIfProposalNeeded() public {
        mandateId = 5; // Execute action - needs mandate 4 completed
        mandateCalldata = abi.encode(true);

        vm.expectRevert(Checks.Checks__ParentMandateNotFulfilled.selector);
        vm.prank(charlotte);
        daoMock.request(mandateId, mandateCalldata, nonce, description);
    }

    function testExecuteRevertsIfProposalDefeated() public {
        mandateId = 3; // = ROLE ONE
        mandateCalldata = abi.encode(true);
        vm.prank(bob);
        actionId = daoMock.propose(mandateId, mandateCalldata, nonce, description);

        (mandateAddress, mandateHash, active) = daoMock.getAdoptedMandate(mandateId);
        conditions = daoMock.getConditions(mandateId);

        for (i = 0; i < users.length; i++) {
            if (daoMock.hasRoleSince(users[i], conditions.allowedRole) != 0) {
                vm.prank(users[i]);
                daoMock.castVote(actionId, AGAINST);
            }
        }

        vm.roll(block.number + conditions.votingPeriod + 1);
        ActionState actionState = daoMock.getActionState(actionId);
        assertEq(uint8(actionState), uint8(ActionState.Defeated));

        vm.expectRevert(Checks.Checks__ProposalNotSucceeded.selector);
        vm.prank(alice);
        daoMock.request(mandateId, mandateCalldata, nonce, description);
    }

    function testExecuteRevertsIfProposalCancelled() public {
        mandateId = 3; // StatementOfIntent - needs ROLE_ONE
        mandateCalldata = abi.encode(true);
        vm.prank(bob);
        actionId = daoMock.propose(mandateId, mandateCalldata, nonce, description);

        vm.prank(bob);
        daoMock.cancel(mandateId, mandateCalldata, nonce);

        ActionState actionState = daoMock.getActionState(actionId);
        assertEq(uint8(actionState), uint8(ActionState.Cancelled));

        vm.expectRevert(Powers__ActionCancelled.selector);
        vm.prank(bob);
        daoMock.request(mandateId, mandateCalldata, nonce, description);
    }
}

//////////////////////////////////////////////////////////////
//                  ROLE AND LAW ADMIN                      //
//////////////////////////////////////////////////////////////
contract ConstituteTest is TestSetupPowers {
    function testConstituteSetsMandatesToActive() public {
        vm.prank(alice);
        PowersMock daoMockTest = new PowersMock();

        MandateInitData[] memory mandateInitData = new MandateInitData[](1);

        mandateInitData[0] = MandateInitData({
            nameDescription: "Test mandate: Test mandate description",
            targetMandate: initialisePowers.getInitialisedAddress("OpenAction"), // = openAction
            config: abi.encode(),
            conditions: conditions
        });

        vm.prank(alice);
        daoMockTest.constitute(mandateInitData);

        for (i = 1; i <= mandateInitData.length; i++) {
            daoMockTest.getAdoptedMandate(uint16(i));
        }
    }

    function testConstituteRevertsWhenClosed() public {
        vm.prank(alice);
        PowersMock daoMockTest = new PowersMock();

        MandateInitData[] memory mandateInitData = new MandateInitData[](1);
        mandateInitData[0] = MandateInitData({
            nameDescription: "Test mandate: Test mandate description",
            targetMandate: initialisePowers.getInitialisedAddress("OpenAction"), // = openAction
            config: abi.encode(),
            conditions: conditions
        });

        vm.prank(alice);
        daoMockTest.constitute(mandateInitData);
        daoMockTest.closeConstitute();

        vm.expectRevert(Powers__ConstituteClosed.selector);
        vm.prank(alice);
        daoMockTest.constitute(mandateInitData);
    }

    function testConstituteCannotBeCalledByNonAdmin() public {
        vm.prank(alice);
        PowersMock daoMockTest = new PowersMock();

        MandateInitData[] memory mandateInitData = new MandateInitData[](1);
        mandateInitData[0] = MandateInitData({
            nameDescription: "Test mandate: Test mandate description",
            targetMandate: initialisePowers.getInitialisedAddress("OpenAction"), // mandateAddresses[3],
            config: abi.encode(),
            conditions: conditions
        });

        vm.expectRevert(Powers__OnlyAdmin.selector);
        vm.prank(bob);
        daoMockTest.constitute(mandateInitData);
    }
}

contract SetMandateTest is TestSetupPowers {
    function testSetMandateSetsNewMandate() public {
        mandateCounter = daoMock.mandateCounter();
        newMandate = address(new OpenAction());

        MandateInitData memory mandateInitData = MandateInitData({
            nameDescription: "Test mandate: Test mandate description",
            targetMandate: newMandate,
            config: abi.encode(),
            conditions: conditions
        });

        vm.prank(address(daoMock));
        daoMock.adoptMandate(mandateInitData);

        (address mandate,,) = daoMock.getAdoptedMandate(mandateCounter);
        assertEq(mandate, newMandate, "New mandate should be active after adoption");
    }

    function testSetMandateEmitsEvent() public {
        mandateCounter = daoMock.mandateCounter();
        newMandate = address(new OpenAction());

        MandateInitData memory mandateInitData = MandateInitData({
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

    function testSetMandateRevertsIfNotCalledFromPowers() public {
        newMandate = address(new OpenAction());

        MandateInitData memory mandateInitData = MandateInitData({
            nameDescription: "Test mandate: Test mandate description",
            targetMandate: newMandate,
            config: abi.encode(),
            conditions: conditions
        });

        vm.expectRevert(Powers__OnlyPowers.selector);
        vm.prank(alice);
        daoMock.adoptMandate(mandateInitData);
    }

    function testSetMandateRevertsIfAddressNotAMandate() public {
        newMandate = address(3333);

        MandateInitData memory mandateInitData = MandateInitData({
            nameDescription: "Test mandate: Test mandate description",
            targetMandate: newMandate,
            config: abi.encode(),
            conditions: conditions
        });

        vm.expectRevert(abi.encodeWithSelector(Powers__IncorrectInterface.selector, newMandate));
        vm.prank(address(daoMock));
        daoMock.adoptMandate(mandateInitData);
    }

    function testAdoptingSameMandateTwice() public {
        newMandate = address(new OpenAction());

        vm.prank(alice);
        PowersMock daoMockTest = new PowersMock();

        MandateInitData memory mandateInitData = MandateInitData({
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
            assertEq(mandate, newMandate, "New mandate should be active after adoption");
        }
    }

    function testRevokeMandateRevertsIfAddressNotActive() public {
        newMandate = address(new OpenAction());

        vm.prank(address(daoMock));
        daoMock.revokeMandate(1);

        vm.expectRevert(Powers__MandateNotActive.selector);
        vm.prank(address(daoMock));
        daoMock.revokeMandate(1);
    }
}

contract SetRoleTest is TestSetupPowers {
    function testSetRoleSetsNewRole() public {
        assertEq(daoMock.hasRoleSince(helen, ROLE_THREE), 0);

        vm.prank(address(daoMock));
        daoMock.assignRole(ROLE_THREE, helen);

        assertNotEq(daoMock.hasRoleSince(helen, ROLE_THREE), 0, "Role should be assigned");
    }

    function testSetRoleRevertsWhenCalledFromOutsideProtocol() public {
        vm.prank(alice);
        vm.expectRevert(Powers__OnlyPowers.selector);
        daoMock.assignRole(ROLE_THREE, bob);
    }

    function testSetRoleEmitsCorrectEventIfAccountAlreadyHasRole() public {
        assertNotEq(daoMock.hasRoleSince(bob, ROLE_ONE), 0);

        vm.prank(address(daoMock));
        vm.expectEmit(true, false, false, false);
        emit RoleSet(ROLE_ONE, bob, false);
        daoMock.assignRole(ROLE_ONE, bob);
    }

    function testAddingRoleAddsOneToAmountMembers() public {
        balanceBefore = daoMock.getAmountRoleHolders(ROLE_THREE);
        assertEq(daoMock.hasRoleSince(helen, ROLE_THREE), 0);

        vm.prank(address(daoMock));
        daoMock.assignRole(ROLE_THREE, helen);

        balanceAfter = daoMock.getAmountRoleHolders(ROLE_THREE);
        assertNotEq(daoMock.hasRoleSince(helen, ROLE_THREE), 0, "Role should be assigned");
        assertEq(balanceAfter, balanceBefore + 1, "Member count should increase by 1");
    }

    function testRemovingRoleSubtractsOneFromAmountMembers() public {
        balanceBefore = daoMock.getAmountRoleHolders(ROLE_ONE);
        assertNotEq(daoMock.hasRoleSince(bob, ROLE_ONE), 0);

        vm.prank(address(daoMock));
        daoMock.revokeRole(ROLE_ONE, bob);

        balanceAfter = daoMock.getAmountRoleHolders(ROLE_ONE);
        assertEq(daoMock.hasRoleSince(bob, ROLE_ONE), 0, "Role should be revoked");
        assertEq(balanceAfter, balanceBefore - 1, "Member count should decrease by 1");
    }

    function testSetRoleSetsEmitsEvent() public {
        vm.expectEmit(true, false, false, false);
        emit RoleSet(ROLE_THREE, helen, true);
        vm.prank(address(daoMock));
        daoMock.assignRole(ROLE_THREE, helen);
    }

    function testLabelRoleEmitsCorrectEvent() public {
        vm.expectEmit(true, false, false, false);
        emit RoleLabel(ROLE_THREE, "This is role three");
        vm.prank(address(daoMock));
        daoMock.labelRole(ROLE_THREE, "This is role three");
    }

    function testLabelRoleRevertsForLockedRoles() public {
        vm.expectRevert(Powers__LockedRole.selector);
        vm.prank(address(daoMock));
        daoMock.labelRole(ADMIN_ROLE, "Admin role");
    }
}

//////////////////////////////////////////////////////////////
//                  PROPOSE FUNCTION TESTS                  //
//////////////////////////////////////////////////////////////
contract ProposeAdvancedTest is TestSetupPowers {
    function testProposeRevertsWithBlacklistedCaller() public {
        mandateId = 3; // StatementOfIntent
        mandateCalldata = abi.encode(true);

        // Blacklist the caller
        vm.prank(address(daoMock));
        daoMock.blacklistAddress(bob, true);

        vm.expectRevert(PowersErrors.Powers__AddressBlacklisted.selector);
        vm.prank(bob);
        daoMock.propose(mandateId, mandateCalldata, nonce, "Test proposal");
    }

    function testProposeRevertsWithCalldataTooLong() public {
        mandateId = 3; // StatementOfIntent
        // Create calldata longer than MAX_CALLDATA_LENGTH
        mandateCalldata = new bytes(daoMock.MAX_CALLDATA_LENGTH() + 1);

        vm.expectRevert(PowersErrors.Powers__CalldataTooLong.selector);
        vm.prank(bob);
        daoMock.propose(mandateId, mandateCalldata, nonce, "Test proposal");
    }
}

//////////////////////////////////////////////////////////////
//                  LAW ADOPTION TESTS                      //
//////////////////////////////////////////////////////////////
contract MandateAdoptionTest is TestSetupPowers {
    function testAdoptMandateRevertsWithBlacklistedTarget() public {
        mandateAddress = mandateAddresses[2];

        // Blacklist the target mandate
        vm.prank(address(daoMock));
        daoMock.blacklistAddress(mandateAddress, true);

        MandateInitData memory mandateInitData = MandateInitData({
            nameDescription: "Test mandate", targetMandate: mandateAddress, config: abi.encode(), conditions: conditions
        });

        vm.expectRevert(PowersErrors.Powers__AddressBlacklisted.selector);
        vm.prank(address(daoMock));
        daoMock.adoptMandate(mandateInitData);
    }

    function testAdoptMandateRevertsWithPublicRoleAndQuorum() public {
        newMandate = address(new OpenAction());

        // Create conditions with PUBLIC_ROLE and quorum > 0
        PowersTypes.Conditions memory invalidConditions = PowersTypes.Conditions({
            allowedRole: PUBLIC_ROLE,
            quorum: 50, // > 0
            succeedAt: 0,
            votingPeriod: 0,
            timelock: 0,
            throttleExecution: 0,
            needFulfilled: 0,
            needNotFulfilled: 0
        });

        MandateInitData memory mandateInitData = MandateInitData({
            nameDescription: "Test mandate",
            targetMandate: newMandate,
            config: abi.encode(),
            conditions: invalidConditions
        });

        vm.expectRevert(PowersErrors.Powers__VoteWithPublicRoleDisallowed.selector);
        vm.prank(address(daoMock));
        daoMock.adoptMandate(mandateInitData);
    }
}

//////////////////////////////////////////////////////////////
//                  ROLE MANAGEMENT TESTS                   //
//////////////////////////////////////////////////////////////
contract RoleManagementTest is TestSetupPowers {
    function testAssignRoleRevertsWithBlacklistedAccount() public {
        account = makeAddr("blacklisted");

        // Blacklist the account
        vm.prank(address(daoMock));
        daoMock.blacklistAddress(account, true);

        vm.expectRevert(PowersErrors.Powers__AddressBlacklisted.selector);
        vm.prank(address(daoMock));
        daoMock.assignRole(ROLE_THREE, account);
    }

    function testLabelRoleRevertsWithEmptyLabel() public {
        vm.expectRevert(PowersErrors.Powers__InvalidLabel.selector);
        vm.prank(address(daoMock));
        daoMock.labelRole(ROLE_THREE, "");
    }

    function testLabelRoleRevertsWithLabelTooLong() public {
        // Create a label longer than 255 characters
        string memory longLabel =
            "This is a very long label that exceeds the maximum allowed length of 255 characters and should cause the function to revert when trying to set it as a role label in the Powers protocol governance system which has strict validation rules to prevent abuse and ensure proper formatting of role labels";

        vm.expectRevert(PowersErrors.Powers__LabelTooLong.selector);
        vm.prank(address(daoMock));
        daoMock.labelRole(ROLE_THREE, longLabel);
    }

    function testSetRoleRevertsWithPublicRole() public {
        // Try to set PUBLIC_ROLE (should revert)
        vm.expectRevert(PowersErrors.Powers__CannotSetPublicRole.selector);
        vm.prank(address(daoMock));
        daoMock.assignRole(PUBLIC_ROLE, alice);
    }

    function testSetRoleRevertsWithZeroAddress() public {
        vm.expectRevert(PowersErrors.Powers__CannotAddZeroAddress.selector);
        vm.prank(address(daoMock));
        daoMock.assignRole(ROLE_THREE, address(0));
    }

    function testSetRoleRemovesRoleCorrectly() public {
        // First assign a role
        vm.prank(address(daoMock));
        daoMock.assignRole(ROLE_THREE, alice);

        balanceBefore = daoMock.getAmountRoleHolders(ROLE_THREE);
        assertEq(balanceBefore, 1);

        // Now remove the role
        vm.prank(address(daoMock));
        daoMock.revokeRole(ROLE_THREE, alice);

        balanceAfter = daoMock.getAmountRoleHolders(ROLE_THREE);
        assertEq(balanceAfter, 0);
        assertEq(daoMock.hasRoleSince(alice, ROLE_THREE), 0);
    }

    function testGetRoleHoldersWithEmptyArray() public view {
        // Test with a role that has no members
        uint256 amountRoleHolders = daoMock.getAmountRoleHolders(ROLE_THREE);
        assertEq(amountRoleHolders, 0);
    }

    function testGetActionStateNonExistent() public view {
        // Test with a non-existent action ID
        uint256 nonExistentActionId = 999_999;
        ActionState state = daoMock.getActionState(nonExistentActionId);
        assertEq(uint8(state), uint8(ActionState.NonExistent));
    }
}

//////////////////////////////////////////////////////////////
//                  CONSTRUCTOR TESTS                       //
//////////////////////////////////////////////////////////////
contract ConstructorTest is Test {
    function testConstructorRevertsWithEmptyName() public {
        vm.expectRevert(PowersErrors.Powers__InvalidName.selector);
        new Powers("", "", 10_000, 10_000, 100_000);
    }

    function testConstructorRevertsWithZeroMaxCallDataLength() public {
        vm.expectRevert(PowersErrors.Powers__InvalidMaxCallDataLength.selector);
        new Powers("This is a name", "", 0, 10_000, 10_000);
    }

    function testConstructorRevertsWithZeroMaxReturnsDataLength() public {
        vm.expectRevert(PowersErrors.Powers__InvalidReturnCallDataLength.selector);
        new Powers("This is a name", "", 10_000, 0, 10_000);
    }

    function testConstructorRevertsWithZeroMaxExecutionsLength() public {
        vm.expectRevert(PowersErrors.Powers__InvalidMaxExecutionsLength.selector);
        new Powers("This is a name", "", 10_000, 10_000, 0);
    }
}
