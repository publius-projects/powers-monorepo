// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import { Test, console, console2 } from "lib/forge-std/src/Test.sol";
import { Powers } from "@src/Powers.sol";
import { Mandate } from "@src/Mandate.sol";
import { Nominees } from "@src/helpers/Nominees.sol";
import { ElectionList } from "@src/helpers/ElectionList.sol";
import {
    TestSetupDelegateTokenFlow,
    TestSetupElectionListFlow,
    TestSetupAssignExternalRoleParentFlow
} from "../../TestSetup.t.sol";

import { Nominees } from "@src/helpers/Nominees.sol";
import { SimpleErc20Votes } from "@mocks/SimpleErc20Votes.sol";

contract DelegateTokenFlow_IntegrationTest is TestSetupDelegateTokenFlow {
    uint16 constant MANDATE_NOMINATE = 1;
    uint16 constant MANDATE_ELECT = 2;

    function setUp() public override {
        super.setUp();

        // Identify helpers from the setup
        vm.startPrank(address(daoMock));
        // Give Frank Role 1 so he can nominate (as per constitution allowedRole=1 for Nominate)
        // Alice and Bob already have Role 1 from TestSetup
        daoMock.assignRole(ROLE_ONE, frank);
        vm.stopPrank();
    }

    function testDelegateTokenFlow_FullInteraction() public {
        // --- 1. NOMINATION FLOW ---
        console2.log("--- Step 1: Nomination ---");
        console2.log("owner of nominees:", nominees.owner());

        // Alice nominates
        vm.prank(alice);
        daoMock.request(
            MANDATE_NOMINATE,
            abi.encode(true), // shouldNominate = true
            nonce++,
            "Alice Nominates"
        );
        assertTrue(nominees.isNominee(alice), "Alice should be a nominee");

        // Bob nominates
        vm.prank(bob);
        daoMock.request(MANDATE_NOMINATE, abi.encode(true), nonce++, "Bob Nominates");
        assertTrue(nominees.isNominee(bob), "Bob should be a nominee");

        // Frank nominates
        vm.prank(frank);
        daoMock.request(MANDATE_NOMINATE, abi.encode(true), nonce++, "Frank Nominates");
        assertTrue(nominees.isNominee(frank), "Frank should be a nominee");

        // Test Revoke Nomination (Alice revokes then renominates)
        vm.prank(alice);
        daoMock.request(
            MANDATE_NOMINATE,
            abi.encode(false), // shouldNominate = false
            nonce++,
            "Alice Revokes"
        );
        assertFalse(nominees.isNominee(alice), "Alice should not be a nominee");

        vm.prank(alice);
        daoMock.request(MANDATE_NOMINATE, abi.encode(true), nonce++, "Alice Renominates");
        assertTrue(nominees.isNominee(alice), "Alice should be a nominee again");

        // --- 2. VOTE DISTRIBUTION ---
        console2.log("--- Step 2: Vote Distribution ---");
        // Mint votes: Frank > Bob > Alice
        // Frank: 90, Bob: 60, Alice: 30

        vm.prank(frank);
        simpleErc20Votes.mint(90 ether);
        vm.prank(frank);
        simpleErc20Votes.delegate(frank); // Delegate to self

        vm.prank(bob);
        simpleErc20Votes.mint(60 ether);
        vm.prank(bob);
        simpleErc20Votes.delegate(bob);

        vm.prank(alice);
        simpleErc20Votes.mint(30 ether);
        vm.prank(alice);
        simpleErc20Votes.delegate(alice);

        assertEq(simpleErc20Votes.getVotes(frank), 90 ether, "Frank vote balance wrong");
        assertEq(simpleErc20Votes.getVotes(bob), 60 ether, "Bob vote balance wrong");
        assertEq(simpleErc20Votes.getVotes(alice), 30 ether, "Alice vote balance wrong");

        // --- 3. ELECTION FLOW ---
        console2.log("--- Step 3: Election ---");

        // Current Role 2 holders (from setup): Charlotte, David
        assertTrue(daoMock.hasRoleSince(charlotte, ROLE_TWO) > 0, "Charlotte should have Role 2");
        assertTrue(daoMock.hasRoleSince(david, ROLE_TWO) > 0, "David should have Role 2");
        assertFalse(daoMock.hasRoleSince(frank, ROLE_TWO) > 0, "Frank should not have Role 2");

        // Execute Election (anyone can call, public role)
        // Note: The mandate has throttleExecution, but this is the first call.
        vm.prank(eve); // Eve is just a random user
        daoMock.request(
            MANDATE_ELECT,
            abi.encode(), // No params
            nonce++,
            "Run Election"
        );

        // Verification
        // Expected: Charlotte/David removed. Frank, Bob, Alice assigned.
        // MaxRoleHolders is 3. We have 3 nominees. All should be elected.

        assertFalse(daoMock.hasRoleSince(charlotte, ROLE_TWO) > 0, "Charlotte should have lost Role 2");
        assertFalse(daoMock.hasRoleSince(david, ROLE_TWO) > 0, "David should have lost Role 2");

        assertTrue(daoMock.hasRoleSince(frank, ROLE_TWO) > 0, "Frank should have Role 2");
        assertTrue(daoMock.hasRoleSince(bob, ROLE_TWO) > 0, "Bob should have Role 2");
        assertTrue(daoMock.hasRoleSince(alice, ROLE_TWO) > 0, "Alice should have Role 2");

        assertEq(daoMock.getAmountRoleHolders(ROLE_TWO), 3, "Should be exactly 3 delegates");

        // --- 4. RE-ELECTION FLOW ---
        console2.log("--- Step 4: Re-election ---");

        // Change votes: Frank transfers 90 to Alice.
        // New weights: Alice (120), Bob (60), Frank (0)
        // Frank is still a nominee, but has 0 votes.
        vm.prank(frank);
        simpleErc20Votes.transfer(alice, 90 ether);

        assertEq(simpleErc20Votes.getVotes(alice), 120 ether, "Alice new vote balance wrong");
        assertEq(simpleErc20Votes.getVotes(frank), 0, "Frank new vote balance wrong");

        // Attempt early execution (should fail due to throttle)
        // Throttle is 600 blocks.
        vm.expectRevert(); // Powers__MandateThrottled
        vm.prank(eve);
        daoMock.request(MANDATE_ELECT, abi.encode(), nonce++, "Run Election Early");

        // Advance time
        vm.roll(block.number + 601);

        // Add a new nominee "Gary" with 50 votes to test displacement?
        // Current nominees: Alice (120), Bob (60), Frank (0).
        // Let's nominate Gary and give him 50 votes.
        // Max holders = 3.
        // Expected order: Alice (120), Bob (60), Gary (50), Frank (0).
        // Elected: Alice, Bob, Gary. Frank should be removed.

        // Give Gary Role 1 to nominate
        vm.prank(address(daoMock));
        daoMock.assignRole(ROLE_ONE, gary);

        vm.prank(gary);
        daoMock.request(MANDATE_NOMINATE, abi.encode(true), nonce++, "Gary Nominates");

        vm.prank(gary); // Gary mints his own votes
        simpleErc20Votes.mint(50 ether);
        vm.prank(gary);
        simpleErc20Votes.delegate(gary);

        // Execute Election
        vm.prank(eve);
        daoMock.request(MANDATE_ELECT, abi.encode(), nonce++, "Run Election Again");

        // Verification
        assertTrue(daoMock.hasRoleSince(alice, ROLE_TWO) > 0, "Alice should keep Role 2");
        assertTrue(daoMock.hasRoleSince(bob, ROLE_TWO) > 0, "Bob should keep Role 2");
        assertTrue(daoMock.hasRoleSince(gary, ROLE_TWO) > 0, "Gary should gain Role 2");
        assertFalse(daoMock.hasRoleSince(frank, ROLE_TWO) > 0, "Frank should lose Role 2");

        assertEq(daoMock.getAmountRoleHolders(ROLE_TWO), 3, "Should be exactly 3 delegates");
    }
}

// contract ElectionListFlow_IntegrationTest is TestSetupElectionListFlow {
//     uint16 constant MANDATE_NOMINATE = 1;
//     uint16 constant MANDATE_START_ELECTION = 2;
//     uint16 constant MANDATE_END_ELECTION = 3;
//     uint16 constant VOTE_MANDATE_ID = 4; // Expected ID for the dynamically deployed vote mandate

//     function testElectionListFlow_FullInteraction() public {
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

//         // Verify intermediate vote counts (Election ID matches VOTE_MANDATE_ID = 4)
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

//         // Test Multi-Candidate Voting (Gary tries to vote for Alice AND Bob) - Should fail due to MaxVotes=1
//         bool[] memory multiVote = new bool[](3);
//         multiVote[0] = true;
//         multiVote[1] = true;

//         // Need a fresh voter for this test, let's use Ian
//         vm.prank(address(daoMock));
//         daoMock.assignRole(ROLE_ONE, ian);

//         vm.expectRevert("Voter tries to vote for more than maxVotes nominees.");
//         vm.prank(ian);
//         daoMock.request(
//             VOTE_MANDATE_ID,
//             abi.encode(multiVote),
//             nonce++,
//             "Ian votes for multiple"
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

//         // Fast forward
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

contract ExternalRoleParentFlow_IntegrationTest is TestSetupAssignExternalRoleParentFlow {
    // Mandate IDs
    // Parent Mandate 1: "Admin can assign any role" (BespokeAction_Simple)
    // Child Mandate 1: "Adopt Role 1" (AssignExternalRole)
    uint16 constant PARENT_MANDATE_ASSIGN = 1;
    uint16 constant CHILD_MANDATE_SYNC = 1;

    function setUp() public override {
        super.setUp();

        // Assign ADMIN_ROLE (0) to Alice in Parent (daoMock) so she can execute the Parent mandate.
        // The Parent mandate "Admin can assign any role" has allowedRole = 0.
        vm.prank(address(daoMock));
        daoMock.assignRole(ADMIN_ROLE, alice);
    }

    function testExternalRole_InitialState() public {
        // Verify Parent Roles
        assertTrue(daoMock.hasRoleSince(alice, ROLE_ONE) > 0, "Alice should have Role 1 in Parent");
        assertTrue(daoMock.hasRoleSince(bob, ROLE_ONE) > 0, "Bob should have Role 1 in Parent");

        // Verify Frank (random user) does not have Role 1
        assertFalse(daoMock.hasRoleSince(frank, ROLE_ONE) > 0, "Frank should NOT have Role 1 in Parent");

        // Verify Child Roles (Should be empty for Role 1 initially)
        assertFalse(daoMockChild1.hasRoleSince(alice, ROLE_ONE) > 0, "Alice should NOT have Role 1 in Child");
        assertFalse(daoMockChild1.hasRoleSince(bob, ROLE_ONE) > 0, "Bob should NOT have Role 1 in Child");
    }

    function testExternalRole_InheritFlow() public {
        console2.log("--- Inherit Flow (Parent -> Child Sync) ---");

        // Alice has Role 1 in Parent (from setup).
        // She executes Child Mandate to sync.

        vm.prank(alice);
        daoMockChild1.request(
            CHILD_MANDATE_SYNC,
            abi.encode(alice), // Account to sync
            nonce++,
            "Alice Syncs Role"
        );

        assertTrue(daoMockChild1.hasRoleSince(alice, ROLE_ONE) > 0, "Alice should have synced Role 1 in Child");
    }

    function testExternalRole_ParentActionFlow() public {
        console2.log("--- Parent Action Flow (Assign -> Sync) ---");

        // 1. Assign Role 1 to Frank in Parent via Mandate
        // Parent Mandate takes: "uint256 roleId", "address account"
        // Note: BespokeAction_Simple expects params in abi.encode(params_) where params_ is string[].
        // Wait, let's check BespokeAction_Simple.sol again.

        // BespokeAction_Simple.sol:
        // (data[mandateHash].targetContract, data[mandateHash].targetFunction, params_) = abi.decode(config, (address, bytes4, string[]));
        // inputParams = abi.encode(params_);

        // handleRequest:
        // calldatas[0] = abi.encodePacked(data[mandateHash].targetFunction, mandateCalldata);

        // mandateCalldata comes from request(..., mandateCalldata, ...).
        // The "params_" in config are just descriptions for UI?
        // The prompt context for BespokeAction_Simple.sol says:
        // initializeMandate: inputParams = abi.encode(params_);

        // When calling request(), we pass the arguments encoded.
        // The Parent Mandate config in TestConstitutions:
        // dynamicParams[0] = "uint256 roleId"; dynamicParams[1] = "address account";
        // config: abi.encode(..., dynamicParams)

        // So BespokeAction_Simple decodes "params_" as ["uint256 roleId", "address account"].
        // This inputParams is mostly metadata.
        // But handleRequest appends mandateCalldata directly to selector.
        // So we need to encode (uint256, address).

        bytes memory params = abi.encode(ROLE_ONE, frank);

        vm.prank(alice); // Alice is Admin
        daoMock.request(PARENT_MANDATE_ASSIGN, params, nonce++, "Assign Frank Role 1");

        assertTrue(daoMock.hasRoleSince(frank, ROLE_ONE) > 0, "Frank should have Role 1 in Parent");
        assertFalse(daoMockChild1.hasRoleSince(frank, ROLE_ONE) > 0, "Frank should NOT have Role 1 in Child yet");

        // 2. Frank Syncs in Child
        vm.prank(frank);
        daoMockChild1.request(CHILD_MANDATE_SYNC, abi.encode(frank), nonce++, "Frank Syncs Role");

        assertTrue(daoMockChild1.hasRoleSince(frank, ROLE_ONE) > 0, "Frank should have synced Role 1 in Child");
    }

    function testExternalRole_RevocationFlow() public {
        console2.log("--- Revocation Flow (Lose in Parent -> Sync Removal) ---");

        // Setup: Bob has Role 1 in Parent. Sync him first.
        vm.prank(bob);
        daoMockChild1.request(CHILD_MANDATE_SYNC, abi.encode(bob), nonce++, "Bob Syncs");
        assertTrue(daoMockChild1.hasRoleSince(bob, ROLE_ONE) > 0, "Bob synced");

        // 1. Revoke Bob in Parent
        // We use direct revocation here as the Parent Mandate is configured for assignment only.
        vm.prank(address(daoMock));
        daoMock.revokeRole(ROLE_ONE, bob);

        assertFalse(daoMock.hasRoleSince(bob, ROLE_ONE) > 0, "Bob lost Role 1 in Parent");
        assertTrue(daoMockChild1.hasRoleSince(bob, ROLE_ONE) > 0, "Bob still has Role 1 in Child");

        // 2. Bob Syncs (Removal) in Child
        vm.prank(bob);
        daoMockChild1.request(CHILD_MANDATE_SYNC, abi.encode(bob), nonce++, "Bob Syncs Removal");

        assertFalse(daoMockChild1.hasRoleSince(bob, ROLE_ONE) > 0, "Bob should have lost Role 1 in Child");
    }

    function testExternalRole_ErrorFlows() public {
        console2.log("--- Error Flows ---");

        // Case A: Sync when not in Parent (Frank)
        assertFalse(daoMock.hasRoleSince(frank, ROLE_ONE) > 0, "Frank has no role");

        vm.expectRevert("Account does not have role at parent");
        vm.prank(frank);
        daoMockChild1.request(CHILD_MANDATE_SYNC, abi.encode(frank), nonce++, "Frank try sync");

        // Case B: Sync when already synced (Alice)
        // First sync Alice
        vm.prank(alice);
        daoMockChild1.request(CHILD_MANDATE_SYNC, abi.encode(alice), nonce++, "Alice Syncs");

        // Try sync again
        // AssignExternalRole checks: if A (has in child) and B (has in parent) -> Revert "Account already has role at parent"
        vm.expectRevert("Account already has role at parent");
        vm.prank(alice);
        daoMockChild1.request(CHILD_MANDATE_SYNC, abi.encode(alice), nonce++, "Alice try sync again");
    }
}
