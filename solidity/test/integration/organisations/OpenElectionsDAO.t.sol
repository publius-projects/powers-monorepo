// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.26;

import { Test, console, console2 } from "lib/forge-std/src/Test.sol";
import { Powers } from "@src/Powers.sol";
import { ElectionList } from "@src/helpers/ElectionList.sol";
import { TestSetupElectionListsDAO } from "../../TestSetup.t.sol";

// contract ElectionListsDAO_IntegrationTest is TestSetupElectionListsDAO {
//     // Mandate IDs from ElectionListsDAO.s.sol
//     // 1: Initial Setup (Revoked)
//     // 2: Nominate
//     // 3: Start Election
//     // 4: End Election
//     // 5: Admin Assign
//     // 6: Delegate Revoke
//     uint16 constant MANDATE_NOMINATE = 2;
//     uint16 constant MANDATE_START_ELECTION = 3;
//     uint16 constant MANDATE_END_ELECTION = 4;

//     // Vote mandate is created dynamically. It will be the next mandate ID.
//     // Initial setup (1), Nominate (2), Start (3), End (4), Admin (5), Revoke (6).
//     // So next mandate is 7.
//     uint16 constant VOTE_MANDATE_ID = 7;

//     function testElectionListsDAO_FullFlow() public {

//         // --- 1. NOMINATION FLOW ---
//         console2.log("--- Step 1: Nomination ---");

//         // Alice nominates
//         vm.prank(alice);
//         daoMock.request(
//             MANDATE_NOMINATE,
//             abi.encode(true), // shouldNominate = true
//             nonce++,
//             "Alice Nominates"
//         );
//         assertTrue(openElection.isNominee(alice), "Alice should be a nominee");

//         // Bob nominates
//         vm.prank(bob);
//         daoMock.request(
//             MANDATE_NOMINATE,
//             abi.encode(true),
//             nonce++,
//             "Bob Nominates"
//         );
//         assertTrue(openElection.isNominee(bob), "Bob should be a nominee");

//         // Frank nominates
//         vm.prank(frank);
//         daoMock.request(
//             MANDATE_NOMINATE,
//             abi.encode(true),
//             nonce++,
//             "Frank Nominates"
//         );
//         assertTrue(openElection.isNominee(frank), "Frank should be a nominee");

//         // Test Revoke Nomination (Frank revokes then renominates)
//         vm.prank(frank);
//         daoMock.request(
//             MANDATE_NOMINATE,
//             abi.encode(false), // shouldNominate = false
//             nonce++,
//             "Frank Revokes"
//         );
//         assertFalse(openElection.isNominee(frank), "Frank should not be a nominee");

//         vm.prank(frank);
//         daoMock.request(
//             MANDATE_NOMINATE,
//             abi.encode(true),
//             nonce++,
//             "Frank Renominates"
//         );
//         assertTrue(openElection.isNominee(frank), "Frank should be a nominee again");

//         // Verify nominees list order (Nominees contract uses push, so order is insertion order)
//         // Alice, Bob, Frank
//         address[] memory nominees = openElection.getNominees();
//         assertEq(nominees.length, 3, "Should be 3 nominees");
//         assertEq(nominees[0], alice, "First nominee should be Alice");
//         assertEq(nominees[1], bob, "Second nominee should be Bob");
//         assertEq(nominees[2], frank, "Third nominee should be Frank");

//         // --- 2. START ELECTION FLOW ---
//         console2.log("--- Step 2: Start Election ---");

//         assertFalse(openElection.isElectionOpen(), "Election should not be open yet");

//         // Alice starts election
//         uint256 electionNonce = nonce;
//         vm.prank(alice);
//         daoMock.request(
//             MANDATE_START_ELECTION,
//             abi.encode(), // No params
//             electionNonce,
//             "Start Election"
//         );

//         assertTrue(openElection.isElectionOpen(), "Election should be open");

//         // Verify Vote Mandate was adopted
//         (address voteMandateAddr,, bool active) = daoMock.getAdoptedMandate(VOTE_MANDATE_ID);
//         assertTrue(active, "Vote mandate should be active");
//         assertTrue(voteMandateAddr != address(0), "Vote mandate address should be set");

//         // --- 3. VOTING FLOW ---
//         console2.log("--- Step 3: Voting ---");

//         // Nominees: [Alice, Bob, Frank]
//         // Votes are bool[]

//         // Alice votes for Alice
//         bool[] memory votesForAlice = new bool[](3);
//         votesForAlice[0] = true; // Alice

//         vm.prank(alice);
//         daoMock.request(
//             VOTE_MANDATE_ID,
//             abi.encode(votesForAlice),
//             nonce++,
//             "Alice votes for Alice"
//         );

//         // Bob votes for Bob
//         bool[] memory votesForBob = new bool[](3);
//         votesForBob[1] = true; // Bob

//         vm.prank(bob);
//         daoMock.request(
//             VOTE_MANDATE_ID,
//             abi.encode(votesForBob),
//             nonce++,
//             "Bob votes for Bob"
//         );

//         // Frank votes for Alice
//         vm.prank(frank);
//         daoMock.request(
//             VOTE_MANDATE_ID,
//             abi.encode(votesForAlice),
//             nonce++,
//             "Frank votes for Alice"
//         );

//         // Gary votes for Bob
//         vm.prank(gary);
//         daoMock.request(
//             VOTE_MANDATE_ID,
//             abi.encode(votesForBob),
//             nonce++,
//             "Gary votes for Bob"
//         );

//         // Helen votes for Alice
//         vm.prank(helen);
//         daoMock.request(
//             VOTE_MANDATE_ID,
//             abi.encode(votesForAlice),
//             nonce++,
//             "Helen votes for Alice"
//         );

//         // Verify intermediate vote counts (Election ID matches VOTE_MANDATE_ID = 7)
//         uint256 electionId = openElection.currentElectionId();
//         assertEq(electionId, VOTE_MANDATE_ID, "Election ID should match Vote Mandate ID");

//         assertEq(openElection.getVoteCount(alice, electionId), 3, "Alice should have 3 votes");
//         assertEq(openElection.getVoteCount(bob, electionId), 2, "Bob should have 2 votes");
//         assertEq(openElection.getVoteCount(frank, electionId), 0, "Frank should have 0 votes");

//         // Test Double Voting (Alice tries to vote again)
//         vm.expectRevert(); // ElectionList already voted check or Mandate check
//         vm.prank(alice);
//         daoMock.request(
//             VOTE_MANDATE_ID,
//             abi.encode(votesForAlice),
//             nonce++,
//             "Alice votes again"
//         );

//         // --- 4. END ELECTION FLOW ---
//         console2.log("--- Step 4: End Election ---");

//         // Attempt early end
//         vm.expectRevert("Election is still open");
//         vm.prank(alice);
//         daoMock.request(
//             MANDATE_END_ELECTION,
//             abi.encode(),
//             electionNonce,
//             "End Election Early"
//         );

//         // Fast forward 10 mins (600 blocks)
//         vm.roll(block.number + 601);
//         assertFalse(openElection.isElectionOpen(), "Election should be closed by time");

//         // Execute End Election
//         vm.prank(alice);
//         daoMock.request(
//             MANDATE_END_ELECTION,
//             abi.encode(),
//             electionNonce,
//             "End Election"
//         );

//         // Verification
//         // 1. Vote Mandate Revoked
//         (,, active) = daoMock.getAdoptedMandate(VOTE_MANDATE_ID);
//         assertFalse(active, "Vote mandate should be revoked");

//         // 2. Roles Updated
//         // Old Role 2: Charlotte, David -> Should be removed
//         assertFalse(daoMock.hasRoleSince(charlotte, ROLE_TWO) > 0, "Charlotte should lose Role 2");
//         assertFalse(daoMock.hasRoleSince(david, ROLE_TWO) > 0, "David should lose Role 2");

//         // New Role 2: Alice (3 votes), Bob (2 votes), Frank (0 votes).
//         // Max holders = 5. All 3 should be elected.
//         assertTrue(daoMock.hasRoleSince(alice, ROLE_TWO) > 0, "Alice should have Role 2");
//         assertTrue(daoMock.hasRoleSince(bob, ROLE_TWO) > 0, "Bob should have Role 2");
//         assertTrue(daoMock.hasRoleSince(frank, ROLE_TWO) > 0, "Frank should have Role 2");

//         assertEq(daoMock.getAmountRoleHolders(ROLE_TWO), 3, "Should be exactly 3 delegates");
//     }
// }
