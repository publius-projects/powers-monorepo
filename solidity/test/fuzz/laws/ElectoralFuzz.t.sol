// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.26;

// import "forge-std/Test.sol";
// import { MandateUtilities } from "../../../src/libraries/MandateUtilities.sol";
// import { TestSetupElectoral } from "../../TestSetup.t.sol";
// import { ElectionList_Tally } from "../../../src/mandates/integrations/ElectionList_Tally.sol";
// import { PeerSelect } from "../../../src/mandates/electoral/PeerSelect.sol";
// import { ElectionList_Vote } from "../../../src/mandates/integrations/ElectionList_Vote.sol";
// import { TaxSelect } from "../../../src/mandates/electoral/TaxSelect.sol";
// import { SelfSelect } from "../../../src/mandates/electoral/SelfSelect.sol";
// import { RenounceRole } from "../../../src/mandates/electoral/RenounceRole.sol";
// import { NStrikesRevokesRoles } from "../../../src/mandates/electoral/NStrikesRevokesRoles.sol";
// import { RoleByRoles } from "../../../src/mandates/electoral/RoleByRoles.sol";
// import { PowersTypes } from "../../../src/interfaces/PowersTypes.sol";
// import { Erc20DelegateElection } from "@mocks/Erc20DelegateElection.sol";
// import { ElectionList } from "../../../src/helpers/ElectionList.sol";
// import { Nominees } from "../../../src/helpers/Nominees.sol";
// import { Erc20Taxed } from "@mocks/Erc20Taxed.sol";
// import { FlagActions } from "../../../src/helpers/FlagActions.sol";

// /// @title Electoral Mandate Fuzz Tests
// /// @notice Comprehensive fuzz testing for all electoral mandate implementations using pre-initialized mandates
// /// @dev Tests use mandates from electoralTestConstitution:
// ///      mandateId 1: ElectionList_Tally (Erc20DelegateElection, roleId=3, maxHolders=3)
// ///      mandateId 2: PeerSelect (maxHolders=2, roleId=4, maxVotes=1, Nominees)
// ///      mandateId 3: ElectionList_Vote (ElectionList, maxVotes=1)
// ///      mandateId 4: TaxSelect (Erc20Taxed, threshold=1000, roleId=4)
// ///      mandateId 6: SelfSelect (roleId=4)
// ///      mandateId 7: RenounceRole (roles=[1,2])
// ///      mandateId 8: NStrikesRevokesRoles (roleId=3, strikes=2, FlagActions)
// ///      mandateId 9: RoleByRoles (targetRole=4, neededRoles=[1,2])
// ///      mandateId 10: PresetActions_Single (label roles)
// contract ElectoralFuzzTest is TestSetupElectoral {
//     // Mandate instances for testing
//     ElectionList_Tally openElectionEnd;
//     PeerSelect peerSelect;
//     ElectionList_Vote openElectionVote;
//     TaxSelect taxSelect;
//     SelfSelect selfSelect;
//     RenounceRole renounceRole;
//     NStrikesRevokesRoles nStrikesRevokesRoles;
//     RoleByRoles roleByRoles;

//     // Mock contract instances
//     Erc20DelegateElection erc20DelegateElection;
//     ElectionList openElection;
//     Nominees nomineesContract;
//     Erc20Taxed erc20Taxed;
//     FlagActions flagActions;

//     // State variables to avoid stack too deep errors
//     uint256 returnedActionId;
//     address[] returnedTargets;
//     uint256[] returnedValues;
//     bytes[] returnedCalldatas;
//     uint256[] roleIds;
//     address[] accountsArray;
//     address[] nomineesList;
//     uint256 taxPaidAmount;
//     uint256 tokenAmount;
//     uint256 blocksPaid;

//     function setUp() public override {
//         super.setUp();

//         // Initialize mandate instances from deployed addresses
//         openElectionEnd = ElectionList_Tally(mandateAddresses[11]);
//         peerSelect = PeerSelect(mandateAddresses[12]);
//         openElectionVote = ElectionList_Vote(mandateAddresses[13]);
//         nStrikesRevokesRoles = NStrikesRevokesRoles(mandateAddresses[14]);
//         taxSelect = TaxSelect(mandateAddresses[15]);
//         roleByRoles = RoleByRoles(mandateAddresses[17]);
//         selfSelect = SelfSelect(mandateAddresses[18]);
//         renounceRole = RenounceRole(mandateAddresses[19]);

//         // Initialize mock contract instances
//         erc20DelegateElection = Erc20DelegateElection(helperAddresses[10]);
//         openElection = ElectionList(helperAddresses[9]);
//         nomineesContract = Nominees(helperAddresses[8]);
//         erc20Taxed = Erc20Taxed(helperAddresses[1]);
//         flagActions = FlagActions(helperAddresses[6]);
//     }

//     //////////////////////////////////////////////////////////////
//     //                  SELF SELECT FUZZ                        //
//     //////////////////////////////////////////////////////////////

//     /// @notice Fuzz test SelfSelect (mandateId 6) with various accounts
//     /// @dev mandateId 6 is configured to self-assign role 4
//     function testFuzzSelfSelectWithVariousAccounts(address accountFuzzed, uint256 nonceFuzzed) public {
//         vm.assume(accountFuzzed != address(0));
//         vm.deal(accountFuzzed, 1 ether);

//         // Verify account doesn't have role initially
//         vm.assume(daoMock.hasRoleSince(accountFuzzed, 4) == 0);

//         mandateCalldata = abi.encode();

//         (returnedActionId, returnedTargets,, returnedCalldatas) =
//             selfSelect.handleRequest(accountFuzzed, address(daoMock), 6, mandateCalldata, nonceFuzzed);

//         // Verify structure
//         assertEq(returnedTargets.length, 1);
//         assertEq(returnedTargets[0], address(daoMock));
//         assertEq(returnedCalldatas.length, 1);

//         // Verify the calldata contains assignRole for the correct account
//         bytes memory expectedCalldata = abi.encodeWithSelector(daoMock.assignRole.selector, 4, accountFuzzed);
//         assertEq(returnedCalldatas[0], expectedCalldata);
//     }

//     /// @notice Fuzz test SelfSelect with multiple different accounts
//     function testFuzzSelfSelectConsistency(
//         address account1,
//         address account2,
//         uint256 nonceFuzzed1,
//         uint256 nonceFuzzed2
//     ) public {
//         vm.assume(account1 != address(0));
//         vm.assume(account2 != address(0));
//         vm.assume(account1 != account2);
//         vm.assume(nonceFuzzed1 != nonceFuzzed2);

//         // Test with first account
//         (returnedActionId, returnedTargets,, returnedCalldatas) =
//             selfSelect.handleRequest(account1, address(daoMock), 6, abi.encode(), nonceFuzzed1);

//         bytes memory firstCalldata = returnedCalldatas[0];

//         // Test with second account
//         (returnedActionId, returnedTargets,, returnedCalldatas) =
//             selfSelect.handleRequest(account2, address(daoMock), 6, abi.encode(), nonceFuzzed2);

//         // Both should target same contract but different calldatas
//         assertEq(returnedTargets[0], address(daoMock));
//         assertTrue(keccak256(firstCalldata) != keccak256(returnedCalldatas[0]));
//     }

//     //////////////////////////////////////////////////////////////
//     //                  RENOUNCE ROLE FUZZ                      //
//     //////////////////////////////////////////////////////////////

//     /// @notice Fuzz test RenounceRole (mandateId 7) with valid roles
//     /// @dev mandateId 7 is configured to allow renouncing roles 1 and 2
//     function testFuzzRenounceRoleWithValidRoles(
//         address accountFuzzed,
//         bool renounceRole1,
//         bool renounceRole2,
//         uint256 nonceFuzzed
//     ) public {
//         vm.assume(accountFuzzed != address(0));

//         // Assign both roles to the account
//         vm.startPrank(address(daoMock));
//         daoMock.assignRole(1, accountFuzzed);
//         daoMock.assignRole(2, accountFuzzed);
//         vm.stopPrank();

//         mandateCalldata = abi.encode(1); // revoke role 1

//         (returnedActionId, returnedTargets,, returnedCalldatas) =
//             renounceRole.handleRequest(accountFuzzed, address(daoMock), 7, mandateCalldata, nonceFuzzed);

//         // Should return calls for each role to renounce
//         assertTrue(returnedTargets.length > 0);
//         for (i = 0; i < returnedTargets.length; i++) {
//             assertEq(returnedTargets[i], address(daoMock));
//         }
//     }

//     //////////////////////////////////////////////////////////////
//     //                  ROLE BY ROLES FUZZ                      //
//     //////////////////////////////////////////////////////////////

//     /// @notice Fuzz test RoleByRoles (mandateId 9) with various role combinations
//     /// @dev mandateId 9 assigns role 4 if account has roles 1 and 2
//     function testFuzzRoleByRolesWithRoleCombinations(address accountFuzzed, uint256 nonceFuzzed) public {
//         vm.assume(accountFuzzed != address(0));

//         bool hasRole1 = daoMock.hasRoleSince(accountFuzzed, 1) != 0;
//         bool hasRole2 = daoMock.hasRoleSince(accountFuzzed, 2) != 0;

//         mandateCalldata = abi.encode(accountFuzzed);

//         (returnedActionId, returnedTargets,, returnedCalldatas) =
//             roleByRoles.handleRequest(accountFuzzed, address(daoMock), 9, mandateCalldata, nonceFuzzed);

//         // If account has either role exist, should send empty array
//         if (hasRole1 || hasRole2) {
//             assertEq(returnedTargets[0], address(daoMock));
//         } else {
//             assertEq(returnedTargets[0], address(0));
//         }
//     }

//     /// @notice Fuzz test RoleByRoles with multiple accounts
//     function testFuzzRoleByRolesWithMultipleAccounts(
//         address[] memory accountsFuzzed,
//         uint256 numberOfAccounts,
//         uint256 nonceFuzzed
//     ) public {
//         numberOfAccounts = bound(numberOfAccounts, 5, 20);
//         vm.assume(accountsFuzzed.length >= numberOfAccounts);

//         // Assign required roles to all accounts
//         vm.startPrank(address(daoMock));
//         for (i = 0; i < numberOfAccounts; i++) {
//             if (accountsFuzzed[i] != address(0)) {
//                 daoMock.assignRole(1, accountsFuzzed[i]);
//                 daoMock.assignRole(2, accountsFuzzed[i]);
//             }
//         }
//         vm.stopPrank();

//         for (i = 0; i < numberOfAccounts; i++) {
//             console.log("accountsFuzzed[%s] = %s", i, accountsFuzzed[i]);
//         }

//         // Test with each account
//         for (i = 0; i < numberOfAccounts; i++) {
//             if (accountsFuzzed[i] != address(0)) {
//                 (returnedActionId, returnedTargets,,) = roleByRoles.handleRequest(
//                     accountsFuzzed[i], address(daoMock), 9, abi.encode(accountsFuzzed[i]), nonceFuzzed
//                 );

//                 assertEq(returnedTargets.length, 1);
//                 assertEq(returnedTargets[0], address(daoMock));
//             }
//         }
//     }

//     //////////////////////////////////////////////////////////////
//     //                  ELECTION SELECT FUZZ                    //
//     //////////////////////////////////////////////////////////////

//     /// @notice Fuzz test ElectionList_Tally (mandateId 1) action generation
//     /// @dev mandateId 1 runs delegate elections for role 3
//     function testFuzzElectionList_TallyActionGeneration(
//         address[] memory nomineesFuzzed,
//         uint256 numberOfNominees,
//         address callerFuzzed,
//         uint256 nonceFuzzed
//     ) public {
//         vm.assume(callerFuzzed != address(0));
//         numberOfNominees = bound(numberOfNominees, 1, 10);
//         vm.assume(nomineesFuzzed.length >= numberOfNominees);

//         // Setup nominees
//         for (i = 0; i < numberOfNominees; i++) {
//             vm.assume(nomineesFuzzed[i] != address(0));
//             vm.assume(!erc20DelegateElection.isNominee(nomineesFuzzed[i]));
//             vm.prank(address(daoMock));
//             erc20DelegateElection.nominate(nomineesFuzzed[i], true);
//         }
//         mandateCalldata = abi.encode();

//         (returnedActionId, returnedTargets,, returnedCalldatas) =
//             openElectionEnd.handleRequest(callerFuzzed, address(daoMock), 1, mandateCalldata, nonceFuzzed);

//         // Should generate action targeting the election contract
//         assertTrue(returnedTargets.length > 0);
//         // First target should be the election contract
//         assertEq(returnedTargets[0], address(daoMock));
//     }

//     /// @notice Fuzz test ElectionList_Tally with various nonces
//     function testFuzzElectionList_TallyWithVariousNonces(uint256 nonce1, uint256 nonce2) public {
//         vm.assume(nonce1 != nonce2);

//         (returnedActionId,,,) = openElectionEnd.handleRequest(alice, address(daoMock), 1, abi.encode(), nonce1);

//         uint256 firstActionId = returnedActionId;

//         (returnedActionId,,,) = openElectionEnd.handleRequest(alice, address(daoMock), 1, abi.encode(), nonce2);
//         // Different nonces should produce different action IDs
//         assertTrue(firstActionId != returnedActionId);
//     }

//     //////////////////////////////////////////////////////////////
//     //                  PEER SELECT FUZZ                        //
//     //////////////////////////////////////////////////////////////

//     /// @notice Fuzz test PeerSelect (mandateId 2) with various nominees
//     /// @dev mandateId 2 selects role 4 by peer voting with max 2 holders and 1 vote per voter
//     function testFuzzPeerSelectWithVaryingNominees(
//         address[] memory nomineesFuzzed,
//         uint256 numberOfNominees,
//         uint256 voteFuzzed,
//         uint256 nonceFuzzed
//     ) public {
//         numberOfNominees = bound(numberOfNominees, 1, 10);
//         vm.assume(nomineesFuzzed.length >= numberOfNominees);

//         // Setup nominees
//         nomineesList = new address[](numberOfNominees);
//         for (i = 0; i < numberOfNominees; i++) {
//             vm.assume(nomineesFuzzed[i] != address(0));
//             vm.assume(!nomineesContract.isNominee(nomineesFuzzed[i]));
//             vm.prank(address(daoMock));
//             nomineesContract.nominate(nomineesFuzzed[i], true);
//             nomineesList[i] = nomineesFuzzed[i];
//         }
//         bool[] memory selection = new bool[](nomineesList.length);
//         selection[voteFuzzed % nomineesList.length] = true;
//         mandateCalldata = abi.encode(selection);

//         (returnedActionId, returnedTargets,, returnedCalldatas) =
//             peerSelect.handleRequest(alice, address(daoMock), 2, mandateCalldata, nonceFuzzed);

//         // Should generate actions
//         assertTrue(returnedTargets.length > 0);
//     }

//     /// @notice Fuzz test PeerSelect action consistency
//     function testFuzzPeerSelectActionConsistency(
//         address[] memory nomineesFuzzed,
//         uint256 numberOfNominees,
//         uint256 voteFuzzed,
//         address caller1,
//         address caller2,
//         uint256 nonceFuzzed1,
//         uint256 nonceFuzzed2
//     ) public {
//         numberOfNominees = bound(numberOfNominees, 1, 10);
//         vm.assume(nomineesFuzzed.length >= numberOfNominees);
//         vm.assume(caller1 != address(0));
//         vm.assume(caller2 != address(0));
//         vm.assume(caller1 != caller2);
//         vm.assume(nonceFuzzed1 != nonceFuzzed2);

//         // Setup nominees
//         nomineesList = new address[](numberOfNominees);
//         for (i = 0; i < numberOfNominees; i++) {
//             vm.assume(nomineesFuzzed[i] != address(0));
//             vm.assume(!nomineesContract.isNominee(nomineesFuzzed[i]));
//             vm.prank(address(daoMock));
//             nomineesContract.nominate(nomineesFuzzed[i], true);
//             nomineesList[i] = nomineesFuzzed[i];
//         }
//         bool[] memory selection = new bool[](nomineesList.length);
//         selection[voteFuzzed % nomineesList.length] = true;
//         mandateCalldata = abi.encode(selection);

//         (returnedActionId, returnedTargets,, returnedCalldatas) =
//             peerSelect.handleRequest(caller1, address(daoMock), 2, mandateCalldata, nonceFuzzed1);

//         uint256 firstTargetLength = returnedTargets.length;
//         bytes memory firstCalldata = returnedCalldatas[0];

//         (returnedActionId, returnedTargets,, returnedCalldatas) =
//             peerSelect.handleRequest(caller2, address(daoMock), 2, mandateCalldata, nonceFuzzed2);

//         // Both should generate consistent action structure
//         assertEq(returnedTargets.length, firstTargetLength);
//         assertEq(returnedCalldatas[0], firstCalldata);
//     }

//     //////////////////////////////////////////////////////////////
//     //                VOTE IN OPEN ELECTION FUZZ                //
//     //////////////////////////////////////////////////////////////

//     /// @notice Fuzz test ElectionList_Vote (mandateId 3) with various candidates
//     /// @dev mandateId 3 allows voting in open elections with max 1 vote == ElectionList_Vote.
//     function testFuzzElectionList_VoteWithCandidates(
//         address[] memory candidatesFuzzed,
//         uint256 quantity,
//         uint256 nonceFuzzed,
//         uint256 voteFuzzed
//     ) public {
//         quantity = bound(quantity, 1, 100);
//         vm.assume(candidatesFuzzed.length >= quantity);
//         uint256 numberOfCandidates;

//         // step 1: nominate candidates in ElectionList contract
//         vm.startPrank(address(daoMock));
//         for (i = 0; i < quantity; i++) {
//             if (candidatesFuzzed[i] != address(0) && !openElection.nominations(candidatesFuzzed[i])) {
//                 openElection.nominate(candidatesFuzzed[i], true);
//                 numberOfCandidates++;
//             }
//         }
//         openElection.openElection(100, 1);
//         vm.stopPrank();
//         bool[] memory votesArray = new bool[](numberOfCandidates);
//         votesArray[voteFuzzed % numberOfCandidates] = true;
//         mandateCalldata = abi.encode(votesArray);

//         vm.roll(block.number + 1);

//         // step 2: initialise a NEW ElectionList_Vote mandate
//         delete conditions;
//         conditions.allowedRole = type(uint256).max;
//         mandateId = daoMock.mandateCounter();
//         vm.prank(address(daoMock));
//         daoMock.adoptMandate(
//             PowersTypes.MandateInitData({
//                 nameDescription: "Vote In Open Election",
//                 targetMandate: mandateAddresses[13],
//                 config: abi.encode(
//                     helperAddresses[9], // ElectionList contract
//                     1 // max votes per voter
//                 ),
//                 conditions: conditions
//             })
//         );
//         // step 3: vote for candidates in ElectionList_Vote contract
//         vm.prank(address(daoMock));
//         (returnedActionId, returnedTargets,, returnedCalldatas) =
//             openElectionVote.handleRequest(alice, address(daoMock), mandateId, mandateCalldata, nonceFuzzed);

//         // step 4: checks
//         assertEq(returnedTargets.length, 1);
//         assertEq(returnedTargets[0], address(openElection));
//     }

//     /// @notice Fuzz test with multiple votes allowed.
//     function testFuzzElectionList_VoteWithMultipleVotes(
//         address[] memory candidatesFuzzed,
//         uint256 quantity,
//         uint256 nonceFuzzed,
//         uint256[] memory votesFuzzed
//     ) public {
//         quantity = bound(quantity, 1, 100);
//         vm.assume(candidatesFuzzed.length >= quantity);
//         vm.assume(votesFuzzed.length > 3);
//         uint256 numberOfCandidates;

//         // step 1: nominate candidates in ElectionList contract
//         vm.startPrank(address(daoMock));
//         for (i = 0; i < quantity; i++) {
//             if (candidatesFuzzed[i] != address(0) && !openElection.nominations(candidatesFuzzed[i])) {
//                 openElection.nominate(candidatesFuzzed[i], true);
//                 numberOfCandidates++;
//             }
//         }
//         openElection.openElection(100, 1);
//         vm.stopPrank();

//         console.log("WAYPOINT 1");

//         // Create votes array allowing multiple votes
//         bool[] memory votesArray = new bool[](numberOfCandidates);
//         console.log("WAYPOINT 2");
//         for (j = 0; j < 3;) {
//             // Vote three times max
//             uint256 index = votesFuzzed[j] % numberOfCandidates;
//             votesArray[index] = true;
//             j++;
//             console.log("WAYPOINT 3");
//         }
//         mandateCalldata = abi.encode(votesArray);

//         vm.roll(block.number + 1);

//         // step 2: initialise a NEW ElectionList_Vote mandate with multiple votes allowed
//         delete conditions;
//         conditions.allowedRole = type(uint256).max;
//         mandateId = daoMock.mandateCounter();
//         vm.prank(address(daoMock));
//         daoMock.adoptMandate(
//             PowersTypes.MandateInitData({
//                 nameDescription: "Vote In Open Election Multiple",
//                 targetMandate: mandateAddresses[13],
//                 config: abi.encode(
//                     helperAddresses[9], // ElectionList contract
//                     3 // max votes per voter increased to 3
//                 ),
//                 conditions: conditions
//             })
//         );

//         // step 3: vote for candidates in ElectionList_Vote contract
//         vm.prank(alice);
//         actionId = daoMock.request(mandateId, mandateCalldata, nonceFuzzed, "");

//         // step 4: checks
//         assertEq(uint8(daoMock.getActionState(actionId)), uint8(ActionState.Fulfilled), "Action should be fulfilled");
//         // Get nominees and count total votes
//         nominees = openElection.getNominees();
//         uint256 totalVotes = 0;
//         for (uint256 k = 0; k < nominees.length; k++) {
//             totalVotes += openElection.getVoteCount(nominees[k], openElection.currentElectionId());
//         }
//         assertTrue(totalVotes >= 1, "Total votes should be at least 1");
//         assertTrue(totalVotes <= 3, "Total votes should be at most 3");
//     }

//     //////////////////////////////////////////////////////////////
//     //                  TAX SELECT FUZZ                         //
//     //////////////////////////////////////////////////////////////

//     /// @notice Fuzz test TaxSelect (mandateId 4) with various accounts
//     /// @dev mandateId 4 assigns role 4 based on tax threshold of 1000
//     function testFuzzTaxSelectWithVariousAccounts(address accountFuzzed, uint256 nonceFuzzed) public {
//         vm.assume(accountFuzzed != address(0));
//         vm.roll(block.number + 1000);
//         mandateCalldata = abi.encode(accountFuzzed);

//         (returnedActionId, returnedTargets,, returnedCalldatas) =
//             taxSelect.handleRequest(accountFuzzed, address(daoMock), 4, mandateCalldata, nonceFuzzed);

//         // always returns an array to set the action to fulfilled.
//         assertTrue(returnedTargets.length > 0);
//     }

//     /// @notice Fuzz test TaxSelect with threshold edge cases
//     function testFuzzTaxSelectThresholdEdgeCases(address accountFuzzed, int256 taxPaidFuzzed, uint256 nonceFuzzed)
//         public
//     {
//         vm.assume(accountFuzzed != address(0));
//         taxPaidFuzzed = bound(taxPaidFuzzed, -100, 100);

//         TaxSelect.Data memory data = TaxSelect(mandateAddresses[14]).getData(MandateUtilities.hashMandate(address(daoMock), 4));
//         uint256 actualTaxPaid = uint256(int256(data.thresholdTaxPaid) + taxPaidFuzzed);

//         vm.mockCall(
//             address(helperAddresses[1]), abi.encodeWithSelector(Erc20Taxed.getTaxLogs.selector), abi.encode(actualTaxPaid)
//         );

//         vm.roll(block.number + 1000);

//         // Test at threshold boundary
//         bool meetsThreshold = actualTaxPaid >= data.thresholdTaxPaid;

//         mandateCalldata = abi.encode(accountFuzzed);
//         (returnedActionId, returnedTargets,,) =
//             taxSelect.handleRequest(accountFuzzed, address(daoMock), 4, mandateCalldata, nonceFuzzed);
//         if (meetsThreshold) assertTrue(returnedTargets.length > 0);
//     }

//     //////////////////////////////////////////////////////////////
//     //               N STRIKES REVOKES ROLES FUZZ               //
//     //////////////////////////////////////////////////////////////

//     /// @notice Fuzz test NStrikesRevokesRoles (mandateId 8) with varying strike counts
//     /// @dev mandateId 8 revokes role 3 after 2 strikes
//     function testFuzzNStrikesRevokesRolesWithStrikes(
//         address accountFuzzed,
//         uint256 strikeCountFuzzed,
//         uint256 nonceFuzzed
//     ) public {
//         vm.assume(accountFuzzed != address(0));
//         strikeCountFuzzed = bound(strikeCountFuzzed, 0, 10);

//         // Assign role 3 to account
//         vm.prank(address(daoMock));
//         daoMock.assignRole(3, accountFuzzed);

//         // Mock getActionState to always return Fulfilled
//         vm.mockCall(
//             address(daoMock), abi.encodeWithSelector(daoMock.getActionState.selector), abi.encode(ActionState.Fulfilled)
//         );

//         // Flag actions with varying strike counts
//         for (i = 0; i < strikeCountFuzzed; i++) {
//             vm.prank(address(daoMock));
//             flagActions.flag(i, 3, accountFuzzed, 8);
//         }

//         mandateCalldata = abi.encode();

//         // Should revert if strikes < 2
//         bool meetsThreshold = strikeCountFuzzed >= 2;
//         if (!meetsThreshold) vm.expectRevert("Not enough strikes to revoke roles.");

//         (returnedActionId, returnedTargets,, returnedCalldatas) =
//             nStrikesRevokesRoles.handleRequest(accountFuzzed, address(daoMock), 8, mandateCalldata, nonceFuzzed);

//         // Should generate revocation if strikes >= 2
//         if (meetsThreshold) {
//             assertTrue(returnedTargets.length > 0);
//             assertEq(returnedTargets[0], address(daoMock));
//         }
//     }

//     /// @notice Fuzz test NStrikesRevokesRoles at threshold boundary
//     function testFuzzNStrikesRevokesRolesThreshold(address accountFuzzed, uint256 nonceFuzzed, uint256 strikesFuzzed)
//         public
//     {
//         vm.assume(accountFuzzed != address(0));
//         strikesFuzzed = bound(strikesFuzzed, 0, 10);

//         // Assign role
//         vm.prank(address(daoMock));
//         daoMock.assignRole(3, accountFuzzed);

//         // Mock getActionState to always return Fulfilled
//         vm.mockCall(
//             address(daoMock), abi.encodeWithSelector(daoMock.getActionState.selector), abi.encode(ActionState.Fulfilled)
//         );

//         for (i = 0; i < strikesFuzzed; i++) {
//             vm.prank(address(daoMock));
//             flagActions.flag(i, 3, accountFuzzed, 8);
//         }

//         // Test at strike threshold (2 strikes needed)
//         bool atThreshold = strikesFuzzed >= 2;

//         mandateCalldata = abi.encode();

//         if (!atThreshold) vm.expectRevert("Not enough strikes to revoke roles.");
//         (returnedActionId, returnedTargets,,) =
//             nStrikesRevokesRoles.handleRequest(accountFuzzed, address(daoMock), 8, mandateCalldata, nonceFuzzed);
//         if (atThreshold) assertTrue(returnedTargets.length > 0);
//     }

//     //////////////////////////////////////////////////////////////
//     //                CROSS-LAW FUZZ TESTS                      //
//     //////////////////////////////////////////////////////////////

//     /// @notice Fuzz test action ID generation consistency across electoral mandates
//     function testFuzzElectoralActionIdConsistency(
//         uint16 mandateIdFuzzed,
//         bytes memory mandateCalldataFuzzed,
//         uint256 nonceFuzzed
//     ) public {
//         // Bound to valid electoral mandate IDs (1-10)
//         mandateIdFuzzed = uint16(bound(mandateIdFuzzed, 1, 10));
//         vm.assume(mandateCalldataFuzzed.length <= MAX_FUZZ_CALLDATA_LENGTH);

//         // Test with SelfSelect (simplest mandate)
//         mandateCalldata = abi.encode();

//         (returnedActionId,,,) = selfSelect.handleRequest(alice, address(daoMock), mandateIdFuzzed, mandateCalldata, nonceFuzzed);

//         // Verify action ID matches expected pattern
//         uint256 expectedActionId = uint256(keccak256(abi.encode(mandateIdFuzzed, mandateCalldata, nonceFuzzed)));
//         assertEq(returnedActionId, expectedActionId);
//     }

//     /// @notice Fuzz test nonce uniqueness across electoral mandates
//     function testFuzzElectoralNonceUniqueness(uint256 nonce1Fuzzed, uint256 nonce2Fuzzed) public {
//         vm.assume(nonce1Fuzzed != nonce2Fuzzed);

//         mandateCalldata = abi.encode();

//         // Get action IDs with different nonces
//         (returnedActionId,,,) = selfSelect.handleRequest(alice, address(daoMock), 6, mandateCalldata, nonce1Fuzzed);
//         uint256 firstActionId = returnedActionId;

//         (returnedActionId,,,) = selfSelect.handleRequest(alice, address(daoMock), 6, mandateCalldata, nonce2Fuzzed);

//         // Different nonces should produce different action IDs
//         assertTrue(firstActionId != returnedActionId);
//     }

//     /// @notice Fuzz test mandate data retrieval consistency
//     function testFuzzElectoralMandateDataConsistency(uint16 mandateIdFuzzed) public {
//         // Bound to valid mandate IDs
//         mandateIdFuzzed = uint16(bound(mandateIdFuzzed, 1, 10));

//         // Get mandate conditions from daoMock
//         conditions = daoMock.getConditions(mandateIdFuzzed);

//         // Verify conditions are valid
//         assertTrue(conditions.quorum <= 100);
//         assertTrue(conditions.succeedAt <= 100);
//         assertTrue(conditions.allowedRole == type(uint256).max); // All are public in test constitution
//     }

//     //////////////////////////////////////////////////////////////
//     //                EDGE CASE FUZZ TESTS                      //
//     //////////////////////////////////////////////////////////////

//     /// @notice Fuzz test electoral mandates with zero addresses in bool array
//     function testFuzzElectoralWithZeroAddresses(uint256 arrayLength, uint256 nonceFuzzed) public {
//         arrayLength = bound(arrayLength, 1, 10);

//         // For ElectionList_Vote, we need a bool array, not address array
//         // Test with all false votes (no selections)
//         bool[] memory votesArray = new bool[](arrayLength);
//         // All elements are false by default

//         mandateCalldata = abi.encode(votesArray);

//         // Test ElectionList_Vote with no votes selected
//         // This should revert as no votes were cast
//         vm.expectRevert();
//         openElectionVote.handleRequest(alice, address(daoMock), 3, mandateCalldata, nonceFuzzed);
//     }

//     /// @notice Fuzz test electoral mandates with large nominee arrays
//     function testFuzzElectoralWithLargeArrays(uint256 numberOfNominees, uint256 voteIndex, uint256 nonceFuzzed) public {
//         numberOfNominees = bound(numberOfNominees, 1, MAX_FUZZ_TARGETS);

//         // Nominate many candidates in ElectionList
//         vm.startPrank(address(daoMock));
//         for (i = 0; i < numberOfNominees; i++) {
//             address nominee = address(uint160(i + 1000)); // Use offset to avoid collisions
//             if (!openElection.nominations(nominee)) {
//                 openElection.nominate(nominee, true);
//             }
//         }
//         openElection.openElection(1000, 1);
//         vm.stopPrank();

//         // Create votes array with one vote
//         bool[] memory votesArray = new bool[](numberOfNominees);
//         votesArray[voteIndex % numberOfNominees] = true;
//         mandateCalldata = abi.encode(votesArray);

//         vm.roll(block.number + 1);

//         // Initialize a new ElectionList_Vote mandate for this test
//         delete conditions;
//         conditions.allowedRole = type(uint256).max;
//         mandateId = daoMock.mandateCounter();
//         vm.prank(address(daoMock));
//         daoMock.adoptMandate(
//             PowersTypes.MandateInitData({
//                 nameDescription: "Vote In Open Election Large",
//                 targetMandate: mandateAddresses[13],
//                 config: abi.encode(
//                     helperAddresses[9], // ElectionList contract
//                     1 // max votes per voter
//                 ),
//                 conditions: conditions
//             })
//         );

//         vm.prank(address(daoMock));
//         (returnedActionId, returnedTargets,, returnedCalldatas) =
//             openElectionVote.handleRequest(alice, address(daoMock), mandateId, mandateCalldata, nonceFuzzed);

//         assertTrue(returnedTargets.length > 0);
//         assertEq(returnedTargets[0], address(openElection));
//     }

//     /// @notice Fuzz test RenounceRole with various role IDs
//     /// @dev mandateId 7 is configured to allow renouncing only roles 1 and 2
//     function testFuzzElectoralWithVariousRoleIds(uint256 roleIdFuzzed, address accountFuzzed, uint256 nonceFuzzed)
//         public
//     {
//         vm.assume(accountFuzzed != address(0));
//         roleIdFuzzed = bound(roleIdFuzzed, 1, 10); // Test roles 1-10

//         // Assign role to account
//         vm.prank(address(daoMock));
//         daoMock.assignRole(roleIdFuzzed, accountFuzzed);

//         // Verify role was assigned
//         assertTrue(daoMock.hasRoleSince(accountFuzzed, roleIdFuzzed) > 0);

//         // Test with RenounceRole (mandateId 7 allows roles 1 and 2 only)
//         mandateCalldata = abi.encode(roleIdFuzzed);

//         // Should revert if role is not in allowed list (not 1 or 2)
//         bool isAllowedRole = (roleIdFuzzed == 1 || roleIdFuzzed == 2);
//         if (!isAllowedRole) {
//             vm.expectRevert("Role not allowed to be renounced.");
//         }

//         (returnedActionId, returnedTargets,, returnedCalldatas) =
//             renounceRole.handleRequest(accountFuzzed, address(daoMock), 7, mandateCalldata, nonceFuzzed);

//         // If role is in allowed list, should succeed
//         if (isAllowedRole) {
//             assertTrue(returnedTargets.length > 0);
//             assertEq(returnedTargets[0], address(daoMock));
//             // Verify calldata is for revokeRole
//             bytes memory expectedCalldata =
//                 abi.encodeWithSelector(daoMock.revokeRole.selector, roleIdFuzzed, accountFuzzed);
//             assertEq(returnedCalldatas[0], expectedCalldata);
//         }
//     }
// }
