// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.26;

// import { console } from "forge-std/Test.sol";
// // import { Console } from "forge-std/console.sol";
// import { TestSetupExecutive } from "../../TestSetup.t.sol";
// import { StatementOfIntent } from "../../../src/mandates/executive/StatementOfIntent.sol";
// import { Governor_CreateProposal } from "../../../src/mandates/integrations/Governor_CreateProposal.sol";
// import { Governor_ExecuteProposal } from "../../../src/mandates/integrations/Governor_ExecuteProposal.sol";
// import { OpenAction } from "../../../src/mandates/executive/OpenAction.sol";
// import { PresetActions_Single } from "../../../src/mandates/executive/PresetActions_Single.sol";
// import { Governor } from "@openzeppelin/contracts/governance/Governor.sol";

// /// @title Executive Mandate Fuzz Tests
// /// @notice Comprehensive fuzz testing for all executive mandate implementations using pre-initialized mandates
// /// @dev Tests use mandates from executiveTestConstitution:
// ///      mandateId 1: StatementOfIntent
// ///      mandateId 2: Governor_CreateProposal
// ///      mandateId 3: Governor_ExecuteProposal
// ///      mandateId 5: PresetActions_Single
// contract ExecutiveFuzzTest is TestSetupExecutive {
//     // Mandate instances for testing
//     StatementOfIntent statementOfIntent;
//     Governor_CreateProposal governorCreateProposal;
//     Governor_ExecuteProposal governorExecuteProposal;
//     PresetActions_Single presetSingleAction;
//     OpenAction openAction;

//     // State variables to avoid stack too deep errors
//     uint256 returnedActionId;
//     address[] returnedTargets;
//     uint256[] returnedValues;
//     bytes[] returnedCalldatas;
//     bytes[] mandateInitDatas;
//     address[] mandatesToAdopt;
//     string[] descriptions;
//     PresetActions_Single.Data presetDataSingle;

//     function setUp() public override {
//         super.setUp();

//         // Initialize mandate instances from deployed addresses
//         // Note: mandateId 1 uses StatementOfIntent from multi mandates (mandateAddresses[4])
//         statementOfIntent = StatementOfIntent(mandateAddresses[4]);
//         governorCreateProposal = Governor_CreateProposal(mandateAddresses[9]);
//         governorExecuteProposal = Governor_ExecuteProposal(mandateAddresses[10]);
//         presetSingleAction = PresetActions_Single(mandateAddresses[1]);
//         openAction = OpenAction(mandateAddresses[3]);
//     }

//     //////////////////////////////////////////////////////////////
//     //               STATEMENT OF INTENT FUZZ                   //
//     //////////////////////////////////////////////////////////////

//     /// @notice Fuzz test StatementOfIntent (mandateId 1) with random data
//     function testFuzzStatementOfIntentWithRandomDataAtExecutive(
//         uint256 arrayLength,
//         address[] memory targetsFuzzed,
//         bytes[] memory calldatasFuzzed,
//         uint256 nonceFuzzed
//     ) public {
//         // Bound inputs
//         arrayLength = bound(arrayLength, 1, MAX_FUZZ_TARGETS);
//         vm.assume(targetsFuzzed.length >= arrayLength);
//         vm.assume(calldatasFuzzed.length >= arrayLength);

//         targets = new address[](arrayLength);
//         values = new uint256[](arrayLength);
//         calldatas = new bytes[](arrayLength);

//         for (i = 0; i < arrayLength; i++) {
//             targets[i] = targetsFuzzed[i];
//             values[i] = 0;
//             calldatas[i] = calldatasFuzzed[i];
//         }

//         mandateCalldata = abi.encode(targets, values, calldatas);

//         (returnedActionId, returnedTargets, returnedValues, returnedCalldatas) =
//             statementOfIntent.handleRequest(alice, address(daoMock), 1, mandateCalldata, nonceFuzzed);

//         // Verify that return data is empty
//         assertEq(returnedTargets.length, 1);
//         assertEq(returnedTargets[0], address(0));
//     }

//     /// @notice Fuzz test StatementOfIntent with large calldata
//     function testFuzzStatementOfIntentWithLargeCalldata(uint256 calldataLength, uint256 nonceFuzzed) public {
//         // Bound inputs
//         calldataLength = bound(calldataLength, 1, MAX_FUZZ_CALLDATA_LENGTH);

//         targets = new address[](1);
//         targets[0] = address(daoMock);
//         values = new uint256[](1);
//         values[0] = 0;
//         calldatas = new bytes[](1);

//         // Create large calldata
//         bytes memory largeCalldata = new bytes(calldataLength);
//         for (i = 0; i < calldataLength; i++) {
//             // forge-lint: disable-next-line(unsafe-typecast)
//             largeCalldata[i] = bytes1(uint8(i % 256));
//         }
//         calldatas[0] = largeCalldata;

//         mandateCalldata = abi.encode(targets, values, calldatas);

//         (returnedActionId, returnedTargets,, returnedCalldatas) =
//             openAction.handleRequest(alice, address(daoMock), 6, mandateCalldata, nonceFuzzed);

//         assertEq(returnedCalldatas[0].length, calldataLength);
//     }

//     //////////////////////////////////////////////////////////////
//     //              GOVERNOR CREATE PROPOSAL FUZZ               //
//     //////////////////////////////////////////////////////////////

//     /// @notice Fuzz test Governor_CreateProposal (mandateId 2) with random proposal data
//     /// @dev mandateId 2 is configured to create proposals on SimpleGovernor mock
//     function testFuzzGovernor_CreateProposalWithRandomData(
//         uint256 arrayLength,
//         address[] memory targetsFuzzed,
//         uint256[] memory valuesFuzzed,
//         bytes[] memory calldatasFuzzed,
//         string memory descriptionFuzzed,
//         uint256 nonceFuzzed
//     ) public {
//         // Bound inputs
//         arrayLength = bound(arrayLength, 1, MAX_FUZZ_TARGETS);
//         vm.assume(targetsFuzzed.length >= arrayLength);
//         vm.assume(valuesFuzzed.length >= arrayLength);
//         vm.assume(calldatasFuzzed.length >= arrayLength);

//         // Ensure description is not empty (required by the mandate)
//         vm.assume(bytes(descriptionFuzzed).length > 0);

//         targets = new address[](arrayLength);
//         values = new uint256[](arrayLength);
//         calldatas = new bytes[](arrayLength);

//         for (i = 0; i < arrayLength; i++) {
//             targets[i] = targetsFuzzed[i];
//             values[i] = valuesFuzzed[i];
//             calldatas[i] = calldatasFuzzed[i];
//         }

//         mandateCalldata = abi.encode(targets, values, calldatas, descriptionFuzzed);

//         (returnedActionId, returnedTargets, returnedValues, returnedCalldatas) =
//             governorCreateProposal.handleRequest(alice, address(daoMock), 2, mandateCalldata, nonceFuzzed);

//         // Verify structure
//         assertEq(returnedTargets.length, 1);
//         assertEq(returnedValues.length, 1);
//         assertEq(returnedCalldatas.length, 1);

//         // Verify target is the SimpleGovernor mock
//         assertEq(returnedTargets[0], helperAddresses[4]); // SimpleGovernor

//         // Verify function selector is propose
//         bytes4 selector = bytes4(returnedCalldatas[0]);
//         assertEq(selector, Governor.propose.selector);
//     }

//     /// @notice Fuzz test Governor_CreateProposal with empty arrays (should revert)
//     function testFuzzGovernor_CreateProposalWithEmptyArrays(string memory descriptionFuzzed, uint256 nonceFuzzed)
//         public
//     {
//         vm.assume(bytes(descriptionFuzzed).length > 0);

//         targets = new address[](0);
//         values = new uint256[](0);
//         calldatas = new bytes[](0);

//         mandateCalldata = abi.encode(targets, values, calldatas, descriptionFuzzed);

//         // Should revert due to empty targets
//         vm.expectRevert("Governor_CreateProposal: No targets provided");
//         governorCreateProposal.handleRequest(alice, address(daoMock), 2, mandateCalldata, nonceFuzzed);
//     }

//     /// @notice Fuzz test Governor_CreateProposal with mismatched array lengths (should revert)
//     function testFuzzGovernor_CreateProposalWithMismatchedArrays(
//         uint256 targetsLength,
//         uint256 valuesLength,
//         uint256 calldatasLength,
//         string memory descriptionFuzzed,
//         uint256 nonceFuzzed
//     ) public {
//         vm.assume(bytes(descriptionFuzzed).length > 0 && bytes(descriptionFuzzed).length < 10_000);
//         targetsLength = bound(targetsLength, 1, MAX_FUZZ_TARGETS);
//         valuesLength = bound(valuesLength, 1, MAX_FUZZ_TARGETS);
//         calldatasLength = bound(calldatasLength, 1, MAX_FUZZ_TARGETS);
//         vm.assume(targetsLength != valuesLength || valuesLength != calldatasLength);

//         console.log("WAYPOINT 0");
//         console.log(targetsLength);
//         console.log(valuesLength);
//         console.log(calldatasLength);

//         address[] memory targetsFuzzed = new address[](targetsLength);
//         uint256[] memory valuesFuzzed = new uint256[](valuesLength);
//         bytes[] memory calldatasFuzzed = new bytes[](calldatasLength);

//         console.log("WAYPOINT 1");

//         for (i = 0; i < targetsLength; i++) {
//             targetsFuzzed[i] = address(daoMock);
//         }
//         console.log("WAYPOINT 2");

//         for (i = 0; i < valuesLength; i++) {
//             valuesFuzzed[i] = 0;
//         }
//         console.log("WAYPOINT 3");

//         for (i = 0; i < calldatasLength; i++) {
//             calldatasFuzzed[i] = abi.encodeWithSelector(daoMock.labelRole.selector, 1, "Test");
//         }
//         console.log("WAYPOINT 4");

//         mandateCalldata = abi.encode(targetsFuzzed, valuesFuzzed, calldatasFuzzed, descriptionFuzzed);
//         console.log("WAYPOINT 5");

//         // Should revert due to mismatched array lengths
//         vm.expectRevert();
//         governorCreateProposal.handleRequest(alice, address(daoMock), 2, mandateCalldata, nonceFuzzed);
//     }

//     /// @notice Fuzz test Governor_CreateProposal with empty description (should revert)
//     function testFuzzGovernor_CreateProposalWithEmptyDescription(uint256 arrayLength, uint256 nonceFuzzed) public {
//         arrayLength = bound(arrayLength, 1, MAX_FUZZ_TARGETS);

//         targets = new address[](arrayLength);
//         values = new uint256[](arrayLength);
//         calldatas = new bytes[](arrayLength);

//         for (i = 0; i < arrayLength; i++) {
//             targets[i] = address(daoMock);
//             values[i] = 0;
//             calldatas[i] = abi.encodeWithSelector(daoMock.labelRole.selector, 1, "Test");
//         }

//         mandateCalldata = abi.encode(targets, values, calldatas, "");

//         // Should revert due to empty description
//         vm.expectRevert("Governor_CreateProposal: Description cannot be empty");
//         governorCreateProposal.handleRequest(alice, address(daoMock), 2, mandateCalldata, nonceFuzzed);
//     }

//     //////////////////////////////////////////////////////////////
//     //              GOVERNOR EXECUTE PROPOSAL FUZZ              //
//     //////////////////////////////////////////////////////////////

//     /// @notice Fuzz test Governor_ExecuteProposal (mandateId 3) with random proposal data
//     /// @dev mandateId 3 is configured to execute proposals on SimpleGovernor mock
//     function testFuzzGovernor_ExecuteProposalWithRandomData(
//         uint256 arrayLength,
//         address[] memory targetsFuzzed,
//         uint256[] memory valuesFuzzed,
//         bytes[] memory calldatasFuzzed,
//         string memory descriptionFuzzed,
//         uint256 nonceFuzzed
//     ) public {
//         // Bound inputs
//         arrayLength = bound(arrayLength, 1, MAX_FUZZ_TARGETS);
//         vm.assume(targetsFuzzed.length >= arrayLength);
//         vm.assume(valuesFuzzed.length >= arrayLength);
//         vm.assume(calldatasFuzzed.length >= arrayLength);

//         // Ensure description is not empty (required by the mandate)
//         vm.assume(bytes(descriptionFuzzed).length > 0);

//         targets = new address[](arrayLength);
//         values = new uint256[](arrayLength);
//         calldatas = new bytes[](arrayLength);

//         for (i = 0; i < arrayLength; i++) {
//             targets[i] = targetsFuzzed[i];
//             values[i] = valuesFuzzed[i];
//             calldatas[i] = calldatasFuzzed[i];
//         }

//         mandateCalldata = abi.encode(targets, values, calldatas, descriptionFuzzed);

//         // Note: This will likely revert because the proposal doesn't exist or isn't in Succeeded state
//         // But we can still test the validation logic
//         vm.expectRevert();
//         governorExecuteProposal.handleRequest(alice, address(daoMock), 3, mandateCalldata, nonceFuzzed);
//     }

//     /// @notice Fuzz test Governor_ExecuteProposal with empty arrays (should revert)
//     function testFuzzGovernor_ExecuteProposalWithEmptyArrays(string memory descriptionFuzzed, uint256 nonceFuzzed)
//         public
//     {
//         vm.assume(bytes(descriptionFuzzed).length > 0);

//         targets = new address[](0);
//         values = new uint256[](0);
//         calldatas = new bytes[](0);

//         mandateCalldata = abi.encode(targets, values, calldatas, descriptionFuzzed);

//         // Should revert due to empty targets
//         vm.expectRevert("Governor_ExecuteProposal: No targets provided");
//         governorExecuteProposal.handleRequest(alice, address(daoMock), 3, mandateCalldata, nonceFuzzed);
//     }

//     /// @notice Fuzz test Governor_ExecuteProposal with empty description (should revert)
//     function testFuzzGovernor_ExecuteProposalWithEmptyDescription(uint256 arrayLength, uint256 nonceFuzzed) public {
//         arrayLength = bound(arrayLength, 1, MAX_FUZZ_TARGETS);

//         targets = new address[](arrayLength);
//         values = new uint256[](arrayLength);
//         calldatas = new bytes[](arrayLength);

//         for (i = 0; i < arrayLength; i++) {
//             targets[i] = address(daoMock);
//             values[i] = 0;
//             calldatas[i] = abi.encodeWithSelector(daoMock.labelRole.selector, 1, "Test");
//         }

//         mandateCalldata = abi.encode(targets, values, calldatas, "");

//         // Should revert due to empty description
//         vm.expectRevert("Governor_ExecuteProposal: Description cannot be empty");
//         governorExecuteProposal.handleRequest(alice, address(daoMock), 3, mandateCalldata, nonceFuzzed);
//     }

//     //////////////////////////////////////////////////////////////
//     //               PRESET SINGLE ACTION FUZZ                  //
//     //////////////////////////////////////////////////////////////

//     /// @notice Fuzz test PresetActions_Single (mandateId 5) returns preset data regardless of input
//     /// @dev mandateId 5 is configured to label role 1 as "Member" and role 2 as "Delegate"
//     function testFuzzPresetActions_SingleIgnoresInput(bytes memory inputCalldataFuzzed, uint256 nonceFuzzed) public {
//         // Bound inputs
//         vm.assume(inputCalldataFuzzed.length <= MAX_FUZZ_CALLDATA_LENGTH);

//         // Get preset data for mandateId 5
//         mandateHash = keccak256(abi.encode(address(daoMock), uint16(5)));
//         presetDataSingle = presetSingleAction.getData(mandateHash);

//         // Call with different inputs
//         (returnedActionId, returnedTargets, returnedValues, returnedCalldatas) =
//             presetSingleAction.handleRequest(alice, address(daoMock), 5, inputCalldataFuzzed, nonceFuzzed);

//         // Store first call results
//         address[] memory firstTargets = returnedTargets;
//         uint256[] memory firstValues = returnedValues;
//         bytes[] memory firstCalldatas = returnedCalldatas;

//         bytes memory differentInput = abi.encode("completely different");
//         (returnedActionId, returnedTargets, returnedValues, returnedCalldatas) =
//             presetSingleAction.handleRequest(alice, address(daoMock), 5, differentInput, nonceFuzzed);

//         // Both should return same preset data
//         assertEq(firstTargets.length, returnedTargets.length);
//         assertEq(firstTargets.length, presetDataSingle.targets.length);

//         for (i = 0; i < firstTargets.length; i++) {
//             assertEq(firstTargets[i], returnedTargets[i]);
//             assertEq(firstTargets[i], presetDataSingle.targets[i]);
//             assertEq(firstValues[i], returnedValues[i]);
//             assertEq(firstValues[i], presetDataSingle.values[i]);
//             assertEq(firstCalldatas[i], returnedCalldatas[i]);
//             assertEq(firstCalldatas[i], presetDataSingle.calldatas[i]);
//         }
//     }

//     /// @notice Fuzz test PresetActions_Single with various nonces
//     function testFuzzPresetActions_SingleWithVariousNonces(uint256 nonce1, uint256 nonce2) public {
//         vm.assume(nonce1 != nonce2);

//         mandateCalldata = abi.encode();

//         (returnedActionId, returnedTargets,,) =
//             presetSingleAction.handleRequest(alice, address(daoMock), 5, mandateCalldata, nonce1);

//         uint256 firstActionId = returnedActionId;
//         address[] memory firstTargets = returnedTargets;

//         (returnedActionId, returnedTargets,,) =
//             presetSingleAction.handleRequest(alice, address(daoMock), 5, mandateCalldata, nonce2);

//         // Different nonces should produce different action IDs
//         assertTrue(firstActionId != returnedActionId);

//         // But same targets
//         assertEq(firstTargets.length, returnedTargets.length);
//         for (i = 0; i < firstTargets.length; i++) {
//             assertEq(firstTargets[i], returnedTargets[i]);
//         }
//     }

//     //////////////////////////////////////////////////////////////
//     //                  CROSS-LAW FUZZ TESTS                    //
//     //////////////////////////////////////////////////////////////

//     /// @notice Fuzz test action ID generation consistency across all executive mandates
//     function testFuzzActionIdConsistency(uint16 mandateIdFuzzed, bytes memory mandateCalldataFuzzed, uint256 nonceFuzzed)
//         public
//     {
//         // Bound to valid mandate IDs (1-5 from the executive constitution)
//         mandateIdFuzzed = uint16(bound(mandateIdFuzzed, 1, 5));
//         vm.assume(mandateCalldataFuzzed.length <= MAX_FUZZ_CALLDATA_LENGTH);

//         // Test with StatementOfIntent
//         targets = new address[](1);
//         targets[0] = address(daoMock);
//         values = new uint256[](1);
//         values[0] = 0;
//         calldatas = new bytes[](1);
//         calldatas[0] = abi.encodeWithSelector(daoMock.labelRole.selector, 1, "Test");

//         mandateCalldata = abi.encode(targets, values, calldatas);

//         (returnedActionId,,,) =
//             statementOfIntent.handleRequest(alice, address(daoMock), mandateIdFuzzed, mandateCalldata, nonceFuzzed);

//         // Verify action ID matches expected pattern
//         uint256 expected = uint256(keccak256(abi.encode(mandateIdFuzzed, mandateCalldata, nonceFuzzed)));
//         assertEq(returnedActionId, expected);
//     }

//     /// @notice Fuzz test that all executive mandates properly handle governor contract validation
//     function testFuzzGovernorContractValidation(uint256 arrayLength, uint256 nonceFuzzed) public {
//         // Bound inputs
//         arrayLength = bound(arrayLength, 1, MAX_FUZZ_TARGETS);

//         targets = new address[](arrayLength);
//         values = new uint256[](arrayLength);
//         calldatas = new bytes[](arrayLength);

//         for (i = 0; i < arrayLength; i++) {
//             targets[i] = address(daoMock);
//             values[i] = 0;
//             calldatas[i] = abi.encodeWithSelector(daoMock.labelRole.selector, 1, "Test");
//         }

//         string memory testDescription = "Test Proposal";
//         mandateCalldata = abi.encode(targets, values, calldatas, testDescription);

//         // Test Governor_CreateProposal (mandateId 2) - should work with valid governor
//         (returnedActionId, returnedTargets,,) =
//             governorCreateProposal.handleRequest(alice, address(daoMock), 2, mandateCalldata, nonceFuzzed);

//         // Should target the SimpleGovernor mock
//         assertEq(returnedTargets[0], helperAddresses[4]);

//         // Test Governor_ExecuteProposal (mandateId 3) - should revert due to proposal not existing
//         vm.expectRevert();
//         governorExecuteProposal.handleRequest(alice, address(daoMock), 3, mandateCalldata, nonceFuzzed);
//     }

//     /// @notice Fuzz test all executive mandates with maximum allowed calldata size
//     function testFuzzAllExecutiveMandatesWithMaxCalldata(uint256 nonceFuzzed) public {
//         // Create maximum size arrays
//         targets = new address[](MAX_FUZZ_TARGETS);
//         values = new uint256[](MAX_FUZZ_TARGETS);
//         calldatas = new bytes[](MAX_FUZZ_TARGETS);

//         for (i = 0; i < MAX_FUZZ_TARGETS; i++) {
//             // casting to 'uint160' is safe because used to create unique addresses only
//             // forge-lint: disable-next-line(unsafe-typecast)
//             targets[i] = address(uint160(i + 1));
//             values[i] = i;

//             // Create large calldata
//             bytes memory largeCalldata = new bytes(100);
//             for (j = 0; j < 100; j++) {
//                 // forge-lint: disable-next-line(unsafe-typecast)
//                 largeCalldata[j] = bytes1(uint8(j % 256));
//             }
//             calldatas[i] = largeCalldata;
//         }

//         string memory testDescription = "Large Proposal Test";
//         mandateCalldata = abi.encode(targets, values, calldatas, testDescription);

//         // Test StatementOfIntent with large data
//         (returnedActionId, returnedTargets,, returnedCalldatas) =
//             openAction.handleRequest(alice, address(daoMock), 6, mandateCalldata, nonceFuzzed); // calls open action

//         assertEq(returnedTargets.length, MAX_FUZZ_TARGETS);
//         assertEq(returnedCalldatas.length, MAX_FUZZ_TARGETS);

//         // Test Governor_CreateProposal with large data
//         (returnedActionId, returnedTargets,, returnedCalldatas) =
//             governorCreateProposal.handleRequest(alice, address(daoMock), 2, mandateCalldata, nonceFuzzed);

//         assertEq(returnedTargets.length, 1);
//         assertEq(returnedTargets[0], helperAddresses[4]); // Should target SimpleGovernor
//     }

//     /// @notice Fuzz test nonce uniqueness across all executive mandates
//     function testFuzzNonceUniqueness(uint256 nonce1Fuzzed, uint256 nonce2Fuzzed) public {
//         vm.assume(nonce1Fuzzed != nonce2Fuzzed);

//         targets = new address[](1);
//         targets[0] = address(daoMock);
//         values = new uint256[](1);
//         values[0] = 0;
//         calldatas = new bytes[](1);
//         calldatas[0] = abi.encodeWithSelector(daoMock.labelRole.selector, 1, "Test");

//         mandateCalldata = abi.encode(targets, values, calldatas);
//         mandateId = 1;

//         // Get action IDs with different nonces
//         (returnedActionId,,,) =
//             statementOfIntent.handleRequest(alice, address(daoMock), mandateId, mandateCalldata, nonce1Fuzzed);
//         uint256 firstActionId = returnedActionId;

//         (returnedActionId,,,) =
//             statementOfIntent.handleRequest(alice, address(daoMock), mandateId, mandateCalldata, nonce2Fuzzed);

//         // Different nonces should produce different action IDs
//         assertTrue(firstActionId != returnedActionId);
//     }

//     //////////////////////////////////////////////////////////////
//     //                  EDGE CASE FUZZ TESTS                    //
//     //////////////////////////////////////////////////////////////

//     /// @notice Fuzz test with extremely large array indices
//     function testFuzzWithLargeArrayIndices(uint256 arrayLength, uint256 nonceFuzzed) public {
//         // Bound inputs
//         arrayLength = bound(arrayLength, 1, MAX_FUZZ_TARGETS);

//         targets = new address[](arrayLength);
//         values = new uint256[](arrayLength);
//         calldatas = new bytes[](arrayLength);

//         for (i = 0; i < arrayLength; i++) {
//             // casting to 'uint160' is safe because used to create unique addresses only
//             // forge-lint: disable-next-line(unsafe-typecast)
//             targets[i] = address(uint160(i + 1));
//             values[i] = type(uint256).max - i; // Use large values
//             calldatas[i] = abi.encodeWithSelector(daoMock.labelRole.selector, type(uint256).max - i, "Role");
//         }

//         string memory testDescription = "Large Values Test";
//         mandateCalldata = abi.encode(targets, values, calldatas, testDescription);

//         (, returnedTargets, returnedValues,) =
//             openAction.handleRequest(alice, address(daoMock), 6, mandateCalldata, nonceFuzzed);

//         // Verify large values are preserved
//         for (i = 0; i < arrayLength; i++) {
//             assertEq(returnedValues[i], type(uint256).max - i);
//         }
//     }

//     /// @notice Fuzz test with random bytes in calldata
//     function testFuzzWithRandomBytesCalldata(bytes memory randomBytesFuzzed, uint256 nonceFuzzed) public {
//         // Bound inputs
//         vm.assume(randomBytesFuzzed.length <= MAX_FUZZ_CALLDATA_LENGTH);

//         targets = new address[](1);
//         targets[0] = address(daoMock);
//         values = new uint256[](1);
//         values[0] = 0;
//         calldatas = new bytes[](1);
//         calldatas[0] = randomBytesFuzzed;

//         mandateCalldata = abi.encode(targets, values, calldatas);

//         (,,, returnedCalldatas) = openAction.handleRequest(alice, address(daoMock), 6, mandateCalldata, nonceFuzzed);

//         // Should preserve random bytes
//         assertEq(returnedCalldatas[0], randomBytesFuzzed);
//     }

//     /// @notice Fuzz test mandate data retrieval consistency
//     function testFuzzMandateDataConsistency(uint16 mandateIdFuzzed) public {
//         // Bound to valid mandate IDs
//         mandateIdFuzzed = uint16(bound(mandateIdFuzzed, 1, 5));

//         // Get mandate conditions from daoMock
//         conditions = daoMock.getConditions(mandateIdFuzzed);

//         // Verify conditions are valid
//         assertTrue(conditions.quorum <= 100);
//         assertTrue(conditions.succeedAt <= 100);
//     }
// }
