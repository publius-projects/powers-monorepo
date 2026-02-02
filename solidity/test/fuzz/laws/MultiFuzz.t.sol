// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.26;

// import { Test } from "forge-std/Test.sol";
// import { TestSetupMulti } from "../../TestSetup.t.sol";
// import { OpenAction } from "../../../src/mandates/executive/OpenAction.sol";
// import { StatementOfIntent } from "../../../src/mandates/executive/StatementOfIntent.sol";
// import { BespokeAction_Simple } from "../../../src/mandates/executive/BespokeAction_Simple.sol";
// import { PresetActions_Single } from "../../../src/mandates/executive/PresetActions_Single.sol";
// import { PresetActions_Multiple } from "../../../src/mandates/executive/PresetActions_Multiple.sol";
// import { BespokeAction_Advanced } from "../../../src/mandates/executive/BespokeAction_Advanced.sol";

// /// @title Multi Mandate Fuzz Tests
// /// @notice Comprehensive fuzz testing for all multi mandate implementations using pre-initialized mandates
// /// @dev Tests use mandates from multiTestConstitution:
// ///      mandateId 1: OpenAction
// ///      mandateId 2: StatementOfIntent
// ///      mandateId 3: BespokeAction_Simple (mint)
// ///      mandateId 4: BespokeAction_Advanced (assignRole)
// ///      mandateId 5: PresetActions_Single (label roles)
// ///      mandateId 6: PresetActions_Multiple (multiple label actions)
// ///      mandateId 7: PresetActions_Single (another preset action)
// contract MultiFuzzTest is TestSetupMulti {
//     // Mandate instances for testing
//     OpenAction openAction;
//     StatementOfIntent statementOfIntent;
//     BespokeAction_Simple bespokeActionSimple;
//     PresetActions_Single presetSingleAction;
//     PresetActions_Multiple presetMultipleActions;
//     BespokeAction_Advanced bespokeActionAdvanced;

//     // State variables to avoid stack too deep errors
//     uint256 returnedActionId;
//     address[] returnedTargets;
//     uint256[] returnedValues;
//     bytes[] returnedCalldatas;
//     bool[] selections;
//     bytes[] dynamicParts;
//     uint256 expectedCount;
//     uint256 quantity;
//     bytes largeCalldata;
//     PresetActions_Single.Data presetDataSingle;
//     PresetActions_Multiple.Data presetDataMultiple;

//     function setUp() public override {
//         super.setUp();

//         // Initialize mandate instances from deployed addresses
//         presetSingleAction = PresetActions_Single(mandateAddresses[1]);
//         presetMultipleActions = PresetActions_Multiple(mandateAddresses[2]);
//         openAction = OpenAction(mandateAddresses[3]);
//         statementOfIntent = StatementOfIntent(mandateAddresses[4]);
//         bespokeActionAdvanced = BespokeAction_Advanced(mandateAddresses[5]);
//         bespokeActionSimple = BespokeAction_Simple(mandateAddresses[6]);
//     }

//     //////////////////////////////////////////////////////////////
//     //                  OPEN ACTION FUZZ                        //
//     //////////////////////////////////////////////////////////////

//     /// @notice Fuzz test OpenAction (mandateId 1) with random arrays
//     function testFuzzOpenActionWithRandomArrays(
//         uint256 arrayLength,
//         address[] memory targetsFuzzed,
//         uint256[] memory valuesFuzzed,
//         uint256 nonceFuzzed
//     ) public {
//         // Bound inputs
//         arrayLength = bound(arrayLength, 1, MAX_FUZZ_TARGETS);
//         vm.assume(targetsFuzzed.length >= arrayLength);
//         vm.assume(valuesFuzzed.length >= arrayLength);

//         // Create properly sized arrays
//         targets = new address[](arrayLength);
//         values = new uint256[](arrayLength);
//         calldatas = new bytes[](arrayLength);

//         for (i = 0; i < arrayLength; i++) {
//             targets[i] = targetsFuzzed[i];
//             values[i] = valuesFuzzed[i];
//             calldatas[i] = abi.encodeWithSelector(daoMock.labelRole.selector, i + 1, "Role");
//         }

//         // Test with mandateId 1 (OpenAction)
//         mandateCalldata = abi.encode(targets, values, calldatas);

//         (returnedActionId, returnedTargets, returnedValues, returnedCalldatas) =
//             openAction.handleRequest(alice, address(daoMock), 1, mandateCalldata, nonceFuzzed);

//         // Verify returned values match input
//         assertEq(returnedTargets.length, arrayLength);
//         assertEq(returnedValues.length, arrayLength);
//         assertEq(returnedCalldatas.length, arrayLength);

//         for (i = 0; i < arrayLength; i++) {
//             assertEq(returnedTargets[i], targets[i]);
//             assertEq(returnedValues[i], values[i]);
//             assertEq(returnedCalldatas[i], calldatas[i]);
//         }
//     }

//     /// @notice Fuzz test OpenAction with mismatched array lengths
//     function testFuzzOpenActionWithMismatchedArrays(
//         uint256 targetsLength,
//         uint256 valuesLength,
//         uint256 calldatasLength,
//         uint256 nonceFuzzed
//     ) public {
//         // Bound inputs to different lengths
//         targetsLength = bound(targetsLength, 1, MAX_FUZZ_TARGETS);
//         valuesLength = bound(valuesLength, 1, MAX_FUZZ_TARGETS);
//         calldatasLength = bound(calldatasLength, 1, MAX_FUZZ_TARGETS);
//         vm.assume(targetsLength != valuesLength || valuesLength != calldatasLength);

//         targets = new address[](targetsLength);
//         values = new uint256[](valuesLength);
//         calldatas = new bytes[](calldatasLength);

//         for (i = 0; i < targetsLength; i++) {
//             targets[i] = address(daoMock);
//         }

//         for (i = 0; i < valuesLength; i++) {
//             values[i] = 0;
//         }

//         for (i = 0; i < calldatasLength; i++) {
//             calldatas[i] = abi.encodeWithSelector(daoMock.labelRole.selector, i + 1, "Role");
//         }

//         mandateCalldata = abi.encode(targets, values, calldatas);

//         // Should still decode but may fail on execution
//         (returnedActionId, returnedTargets,,) =
//             openAction.handleRequest(alice, address(daoMock), 1, mandateCalldata, nonceFuzzed);

//         assertEq(returnedTargets.length, targetsLength);
//     }

//     /// @notice Fuzz test OpenAction with empty arrays
//     function testFuzzOpenActionWithEmptyArrays(uint256 nonceFuzzed) public {
//         targets = new address[](0);
//         values = new uint256[](0);
//         calldatas = new bytes[](0);

//         mandateCalldata = abi.encode(targets, values, calldatas);

//         (returnedActionId, returnedTargets, returnedValues, returnedCalldatas) =
//             openAction.handleRequest(alice, address(daoMock), 1, mandateCalldata, nonceFuzzed);

//         assertEq(returnedTargets.length, 0);
//         assertEq(returnedValues.length, 0);
//         assertEq(returnedCalldatas.length, 0);
//     }

//     //////////////////////////////////////////////////////////////
//     //               STATEMENT OF INTENT FUZZ                   //
//     //////////////////////////////////////////////////////////////

//     /// @notice Fuzz test StatementOfIntent (mandateId 2) with random data
//     function testFuzzStatementOfIntentWithRandomDataAtMulti(
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
//             statementOfIntent.handleRequest(alice, address(daoMock), 2, mandateCalldata, nonceFuzzed);

//         // Verify data is empty
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
//         largeCalldata = new bytes(calldataLength);
//         for (i = 0; i < calldataLength; i++) {
//             // forge-lint: disable-next-line(unsafe-typecast)
//             largeCalldata[i] = bytes1(uint8(i % 256));
//         }
//         calldatas[0] = largeCalldata;

//         mandateCalldata = abi.encode(targets, values, calldatas);

//         (returnedActionId, returnedTargets,, returnedCalldatas) =
//             statementOfIntent.handleRequest(alice, address(daoMock), 2, mandateCalldata, nonceFuzzed);

//         assertEq(returnedCalldatas[0].length, 0);
//     }

//     //////////////////////////////////////////////////////////////
//     //               BESPOKE ACTION SIMPLE FUZZ                 //
//     //////////////////////////////////////////////////////////////

//     /// @notice Fuzz test BespokeAction_Simple (mandateId 3) with various quantities
//     /// @dev mandateId 3 is configured to mint coins on SimpleErc1155 with uint256 Quantity parameter
//     function testFuzzBespokeAction_SimpleWithVariousQuantities(uint256 quantityFuzzed, uint256 nonceFuzzed) public {
//         // Bound quantity to reasonable values
//         quantityFuzzed = bound(quantityFuzzed, 1, type(uint128).max);

//         mandateCalldata = abi.encode(quantityFuzzed);

//         (returnedActionId, returnedTargets,, returnedCalldatas) =
//             bespokeActionSimple.handleRequest(alice, address(daoMock), 3, mandateCalldata, nonceFuzzed);

//         // Verify structure
//         assertEq(returnedTargets.length, 1);
//         assertEq(returnedCalldatas.length, 1);

//         // Verify target is the SimpleErc1155 mock
//         mandateHash = keccak256(abi.encode(address(daoMock), uint16(3)));
//         assertEq(returnedTargets[0], bespokeActionSimple.targetContract(mandateHash));

//         // Verify function selector
//         bytes4 selector = bytes4(returnedCalldatas[0]);
//         assertEq(selector, bespokeActionSimple.targetFunction(mandateHash));
//     }

//     /// @notice Fuzz test BespokeAction_Simple with edge case values
//     function testFuzzBespokeAction_SimpleWithEdgeCases(bool useMax, uint256 nonceFuzzed) public {
//         quantity = useMax ? type(uint256).max : 1;

//         mandateCalldata = abi.encode(quantity);

//         (returnedActionId, returnedTargets,, returnedCalldatas) =
//             bespokeActionSimple.handleRequest(alice, address(daoMock), 3, mandateCalldata, nonceFuzzed);

//         assertEq(returnedTargets.length, 1);
//         assertEq(returnedCalldatas.length, 1);
//     }

//     //////////////////////////////////////////////////////////////
//     //               PRESET SINGLE ACTION FUZZ                  //
//     //////////////////////////////////////////////////////////////

//     /// @notice Fuzz test PresetActions_Single (mandateId 5) returns preset data regardless of input
//     /// @dev mandateId 5 is configured to label role 1 as "Member" and role 2 as "Delegate"
//     // function testFuzzPresetActions_SingleIgnoresInput(
//     //     bytes memory inputCalldataFuzzed,
//     //     uint256 nonceFuzzed
//     // ) public {
//     //     // Bound inputs
//     //     vm.assume(inputCalldataFuzzed.length <= MAX_FUZZ_CALLDATA_LENGTH);

//     //     // Get preset data for mandateId 5
//     //     mandateHash = keccak256(abi.encode(address(daoMock), uint16(5)));
//     //     presetDataSingle = presetSingleAction.getData(mandateHash);

//     //     // Call with different inputs
//     //     (returnedActionId, returnedTargets, returnedValues, returnedCalldatas) =
//     //         presetSingleAction.handleRequest(alice, address(daoMock), 5, inputCalldataFuzzed, nonceFuzzed);

//     //     // Store first call results
//     //     address[] memory firstTargets = returnedTargets;
//     //     uint256[] memory firstValues = returnedValues;
//     //     bytes[] memory firstCalldatas = returnedCalldatas;

//     //     bytes memory differentInput = abi.encode("completely different");
//     //     (returnedActionId, returnedTargets, returnedValues, returnedCalldatas) =
//     //         presetSingleAction.handleRequest(alice, address(daoMock), 5, differentInput, nonceFuzzed + 1);

//     //     // Both should return same preset data
//     //     assertEq(firstTargets.length, returnedTargets.length);
//     //     assertEq(firstTargets.length, presetDataSingle.targets.length);

//     //     for (i = 0; i < firstTargets.length; i++) {
//     //         assertEq(firstTargets[i], returnedTargets[i]);
//     //         assertEq(firstTargets[i], presetDataSingle.targets[i]);
//     //         assertEq(firstValues[i], returnedValues[i]);
//     //         assertEq(firstValues[i], presetDataSingle.values[i]);
//     //         assertEq(firstCalldatas[i], returnedCalldatas[i]);
//     //         assertEq(firstCalldatas[i], presetDataSingle.calldatas[i]);
//     //     }
//     // }

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
//     //              PRESET MULTIPLE ACTIONS FUZZ                //
//     //////////////////////////////////////////////////////////////

//     /// @notice Fuzz test PresetActions_Multiple (mandateId 6) with random selection patterns
//     /// @dev mandateId 6 is configured with 2 actions: "Assign Member Role" and "Assign Delegate Role"
//     function testFuzzPresetActions_MultipleWithRandomSelections(bool selectFirst, bool selectSecond, uint256 nonceFuzzed)
//         public
//     {
//         // Get preset data for mandateId 6
//         mandateHash = keccak256(abi.encode(address(daoMock), uint16(6)));
//         presetDataMultiple = presetMultipleActions.getData(mandateHash);

//         // Create selections array matching the preset data length
//         selections = new bool[](presetDataMultiple.descriptions.length);
//         selections[0] = selectFirst;
//         if (selections.length > 1) {
//             selections[1] = selectSecond;
//         }

//         // Count expected selections
//         expectedCount = 0;
//         for (i = 0; i < selections.length; i++) {
//             if (selections[i]) {
//                 expectedCount++;
//             }
//         }

//         mandateCalldata = abi.encode(selections);

//         (returnedActionId, returnedTargets,, returnedCalldatas) =
//             presetMultipleActions.handleRequest(alice, address(daoMock), 6, mandateCalldata, nonceFuzzed);

//         // Verify correct number of actions returned
//         if (expectedCount == 0) {
//             // Should return empty arrays or single empty element
//             assertTrue(returnedTargets.length <= 1);
//         } else {
//             assertEq(returnedTargets.length, expectedCount);
//             assertEq(returnedCalldatas.length, expectedCount);
//         }
//     }

//     /// @notice Fuzz test PresetActions_Multiple with all false selections
//     function testFuzzPresetActions_MultipleWithAllFalse(uint256 nonceFuzzed) public {
//         // Get preset data for mandateId 6
//         mandateHash = keccak256(abi.encode(address(daoMock), uint16(6)));
//         presetDataMultiple = presetMultipleActions.getData(mandateHash);

//         selections = new bool[](presetDataMultiple.descriptions.length);
//         for (i = 0; i < selections.length; i++) {
//             selections[i] = false;
//         }

//         mandateCalldata = abi.encode(selections);

//         (returnedActionId, returnedTargets,,) =
//             presetMultipleActions.handleRequest(alice, address(daoMock), 6, mandateCalldata, nonceFuzzed);

//         // Should return empty or single element
//         assertTrue(returnedTargets.length <= 1);
//     }

//     /// @notice Fuzz test PresetActions_Multiple with all true selections
//     function testFuzzPresetActions_MultipleWithAllTrue(uint256 nonceFuzzed) public {
//         // Get preset data for mandateId 6
//         mandateHash = keccak256(abi.encode(address(daoMock), uint16(6)));
//         presetDataMultiple = presetMultipleActions.getData(mandateHash);

//         selections = new bool[](presetDataMultiple.descriptions.length);
//         for (i = 0; i < selections.length; i++) {
//             selections[i] = true;
//         }

//         mandateCalldata = abi.encode(selections);

//         (returnedActionId, returnedTargets,, returnedCalldatas) =
//             presetMultipleActions.handleRequest(alice, address(daoMock), 6, mandateCalldata, nonceFuzzed);

//         // Should return all actions
//         assertEq(returnedTargets.length, presetDataMultiple.descriptions.length);
//         assertEq(returnedCalldatas.length, presetDataMultiple.descriptions.length);
//     }

//     //////////////////////////////////////////////////////////////
//     //              BESPOKE ACTION ADVANCED FUZZ                //
//     //////////////////////////////////////////////////////////////

//     /// @notice Fuzz test BespokeAction_Advanced (mandateId 4) with varying addresses
//     /// @dev mandateId 4 is configured to assign role 1 with a dynamic address parameter
//     function testFuzzBespokeAction_AdvancedWithVariousAddresses(address accountFuzzed, uint256 nonceFuzzed) public {
//         vm.assume(accountFuzzed != address(0));

//         // mandateId 4 expects 1 dynamic part (the account address)
//         dynamicParts = new bytes[](1);
//         dynamicParts[0] = abi.encode(accountFuzzed);

//         mandateCalldata = abi.encode(dynamicParts);

//         (returnedActionId, returnedTargets,, returnedCalldatas) =
//             bespokeActionAdvanced.handleRequest(alice, address(daoMock), 4, mandateCalldata, nonceFuzzed);

//         // Verify structure
//         assertEq(returnedTargets.length, 1);
//         assertEq(returnedTargets[0], address(daoMock)); // Should target the daoMock
//         assertEq(returnedCalldatas.length, 1);

//         // Verify the calldata contains assignRole selector
//         bytes4 selector = bytes4(returnedCalldatas[0]);
//         bytes4 expectedSelector = bytes4(keccak256("assignRole(uint256,address)"));
//         assertEq(selector, expectedSelector);
//     }

//     /// @notice Fuzz test BespokeAction_Advanced with multiple different accounts
//     // function testFuzzBespokeAction_AdvancedConsistency(
//     //     address account1,
//     //     address account2,
//     //     uint256 nonceFuzzed
//     // ) public {
//     //     vm.assume(account1 != address(0));
//     //     vm.assume(account2 != address(0));
//     //     vm.assume(account1 != account2);

//     //     // Test with first account
//     //     dynamicParts = new bytes[](1);
//     //     dynamicParts[0] = abi.encode(account1);

//     //     (returnedActionId, returnedTargets, , returnedCalldatas) =
//     //         bespokeActionAdvanced.handleRequest(alice, address(daoMock), 4, abi.encode(dynamicParts), nonceFuzzed);

//     //     address firstTarget = returnedTargets[0];
//     //     bytes memory firstCalldata = returnedCalldatas[0];

//     //     // Test with second account
//     //     dynamicParts = new bytes[](1);
//     //     dynamicParts[0] = abi.encode(account2);

//     //     (returnedActionId, returnedTargets, , returnedCalldatas) =
//     //         bespokeActionAdvanced.handleRequest(alice, address(daoMock), 4, abi.encode(dynamicParts), nonceFuzzed + 1);

//     //     // Both should target same contract
//     //     assertEq(firstTarget, returnedTargets[0]);

//     //     // But different calldatas (different accounts)
//     //     assertTrue(keccak256(firstCalldata) != keccak256(returnedCalldatas[0]));
//     // }

//     //////////////////////////////////////////////////////////////
//     //                  CROSS-LAW FUZZ TESTS                    //
//     //////////////////////////////////////////////////////////////

//     /// @notice Fuzz test action ID generation consistency across all mandates
//     function testFuzzActionIdConsistency(uint16 mandateIdFuzzed, bytes memory mandateCalldataFuzzed, uint256 nonceFuzzed)
//         public
//     {
//         // Bound to valid mandate IDs (1-7 from the constitution)
//         mandateIdFuzzed = uint16(bound(mandateIdFuzzed, 1, 7));
//         vm.assume(mandateCalldataFuzzed.length <= MAX_FUZZ_CALLDATA_LENGTH);

//         // Test with OpenAction
//         targets = new address[](1);
//         targets[0] = address(daoMock);
//         values = new uint256[](1);
//         values[0] = 0;
//         calldatas = new bytes[](1);
//         calldatas[0] = abi.encodeWithSelector(daoMock.labelRole.selector, 1, "Test");

//         mandateCalldata = abi.encode(targets, values, calldatas);

//         (returnedActionId,,,) = openAction.handleRequest(alice, address(daoMock), mandateIdFuzzed, mandateCalldata, nonceFuzzed);

//         // Verify action ID matches expected pattern
//         uint256 expectedForOpen = uint256(keccak256(abi.encode(mandateIdFuzzed, mandateCalldata, nonceFuzzed)));
//         assertEq(returnedActionId, expectedForOpen);
//     }

//     /// @notice Fuzz test that all mandates properly handle zero address targets
//     function testFuzzAllMandatesWithZeroAddressTargets(uint256 arrayLength, uint256 nonceFuzzed) public {
//         // Bound inputs
//         arrayLength = bound(arrayLength, 1, MAX_FUZZ_TARGETS);

//         targets = new address[](arrayLength);
//         values = new uint256[](arrayLength);
//         calldatas = new bytes[](arrayLength);

//         for (i = 0; i < arrayLength; i++) {
//             targets[i] = address(0); // Zero address
//             values[i] = 0;
//             calldatas[i] = "";
//         }

//         mandateCalldata = abi.encode(targets, values, calldatas);

//         // Test OpenAction (mandateId 1)
//         (returnedActionId, returnedTargets,,) =
//             openAction.handleRequest(alice, address(daoMock), 1, mandateCalldata, nonceFuzzed);

//         // Should not revert, just return zero addresses
//         for (i = 0; i < returnedTargets.length; i++) {
//             assertEq(returnedTargets[i], address(0));
//         }

//         // Test StatementOfIntent (mandateId 2)
//         (returnedActionId, returnedTargets,,) =
//             statementOfIntent.handleRequest(alice, address(daoMock), 2, mandateCalldata, nonceFuzzed);

//         for (i = 0; i < returnedTargets.length; i++) {
//             assertEq(returnedTargets[i], address(0));
//         }
//     }

//     /// @notice Fuzz test all mandates with maximum allowed calldata size
//     function testFuzzAllMandatesWithMaxCalldata(uint256 nonceFuzzed) public {
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
//             largeCalldata = new bytes(100);
//             for (j = 0; j < 100; j++) {
//                 // forge-lint: disable-next-line(unsafe-typecast)
//                 largeCalldata[j] = bytes1(uint8(j % 256));
//             }
//             calldatas[i] = largeCalldata;
//         }

//         mandateCalldata = abi.encode(targets, values, calldatas);

//         // Test OpenAction with large data
//         (returnedActionId, returnedTargets,, returnedCalldatas) =
//             openAction.handleRequest(alice, address(daoMock), 1, mandateCalldata, nonceFuzzed);

//         assertEq(returnedTargets.length, MAX_FUZZ_TARGETS);
//         assertEq(returnedCalldatas.length, MAX_FUZZ_TARGETS);
//     }

//     /// @notice Fuzz test nonce uniqueness across all mandates
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
//         (returnedActionId,,,) = openAction.handleRequest(alice, address(daoMock), mandateId, mandateCalldata, nonce1Fuzzed);
//         uint256 firstActionId = returnedActionId;

//         (returnedActionId,,,) = openAction.handleRequest(alice, address(daoMock), mandateId, mandateCalldata, nonce2Fuzzed);

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

//         mandateCalldata = abi.encode(targets, values, calldatas);

//         (, returnedTargets, returnedValues,) =
//             openAction.handleRequest(alice, address(daoMock), 1, mandateCalldata, nonceFuzzed);

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

//         (,,, returnedCalldatas) = openAction.handleRequest(alice, address(daoMock), 1, mandateCalldata, nonceFuzzed);

//         // Should preserve random bytes
//         assertEq(returnedCalldatas[0], randomBytesFuzzed);
//     }

//     /// @notice Fuzz test mandate data retrieval consistency
//     function testFuzzMandateDataConsistency(uint16 mandateIdFuzzed) public {
//         // Bound to valid mandate IDs
//         mandateIdFuzzed = uint16(bound(mandateIdFuzzed, 1, 7));

//         // Get mandate conditions from daoMock
//         conditions = daoMock.getConditions(mandateIdFuzzed);

//         // Verify conditions are valid
//         assertTrue(conditions.quorum <= 100);
//         assertTrue(conditions.succeedAt <= 100);
//     }
// }
