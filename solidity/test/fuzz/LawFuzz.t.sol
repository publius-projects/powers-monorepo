// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.26;

import { TestSetupMandate } from "../TestSetup.t.sol";
import { IMandate } from "../../src/interfaces/IMandate.sol";
import { PresetActions_Single } from "../../src/mandates/executive/PresetActions_Single.sol";
import { OpenAction } from "../../src/mandates/executive/OpenAction.sol";
import { StatementOfIntent } from "../../src/mandates/executive/StatementOfIntent.sol";
import { BespokeAction_Simple } from "../../src/mandates/executive/BespokeAction_Simple.sol";
import { BespokeAction_Advanced } from "../../src/mandates/executive/BespokeAction_Advanced.sol";
import { IERC165 } from "@openzeppelin/contracts/utils/introspection/IERC165.sol";

// /// @title Mandate Fuzz Tests
// /// @notice Comprehensive fuzz testing for the Mandate.sol contract and its implementations
// /// @dev Tests various edge cases and random inputs for mandate functionality
// contract MandateFuzzTest is TestSetupMandate {
//     // Mandate instances for testing
//     PresetActions_Single presetSingleAction;
//     OpenAction openAction;
//     StatementOfIntent statementOfIntent;
//     BespokeAction_Simple bespokeActionSimple;
//     BespokeAction_Advanced bespokeActionAdvanced;

//     // Test state tracking
//     mapping(bytes32 => bool) fuzzMandateHashes;
//     mapping(uint16 => bool) fuzzMandateIds;

//     function setUp() public override {
//         super.setUp();

//         // Initialize mandate instances
//         presetSingleAction = PresetActions_Single(mandateAddresses[4]);
//         openAction = OpenAction(mandateAddresses[3]);
//         statementOfIntent = StatementOfIntent(mandateAddresses[6]);
//         bespokeActionSimple = BespokeAction_Simple(mandateAddresses[7]);
//         bespokeActionAdvanced = BespokeAction_Advanced(mandateAddresses[8]);
//     }

//     //////////////////////////////////////////////////////////////
//     //                  LAW INITIALIZATION FUZZ                 //
//     //////////////////////////////////////////////////////////////

//     /// @notice Fuzz test mandate initialization with random parameters
//     function testFuzzMandateInitialization(
//         uint16 indexFuzzed,
//         string memory nameDescriptionFuzzed,
//         bytes memory inputParamsFuzzed,
//         bytes memory configFuzzed
//     ) public {
//         // Bound inputs
//         vm.assume(indexFuzzed > 0);
//         vm.assume(bytes(nameDescriptionFuzzed).length >= 1 && bytes(nameDescriptionFuzzed).length <= 255);

//         // Test mandate initialization
//         vm.prank(address(daoMock));
//         presetSingleAction.initializeMandate(indexFuzzed, nameDescriptionFuzzed, inputParamsFuzzed, configFuzzed);

//         // Verify mandate was initialized
//         mandateHash = keccak256(abi.encode(address(daoMock), indexFuzzed));
//         assertTrue(fuzzMandateHashes[mandateHash] || mandateHash != bytes32(0));
//     }

//     /// @notice Fuzz test mandate initialization with edge case strings
//     function testFuzzMandateInitializationStrings(uint16 indexFuzzed, string memory nameDescriptionFuzzed) public {
//         // Bound inputs
//         vm.assume(indexFuzzed > 0);
//         vm.assume(bytes(nameDescriptionFuzzed).length >= 1 && bytes(nameDescriptionFuzzed).length <= 255);

//         // Test with various string lengths
//         inputParamsBytes = new bytes(0);
//         configBytes = new bytes(0);

//         vm.prank(address(daoMock));
//         presetSingleAction.initializeMandate(indexFuzzed, nameDescriptionFuzzed, inputParamsBytes, configBytes);
//         // Verify mandate was initialized
//         string memory retrievedName = presetSingleAction.getNameDescription(address(daoMock), indexFuzzed);
//         assertEq(retrievedName, nameDescriptionFuzzed);
//     }

//     //////////////////////////////////////////////////////////////
//     //                  LAW UTILITIES FUZZ                     //
//     //////////////////////////////////////////////////////////////

//     /// @notice Fuzz test mandate data retrieval
//     function testFuzzMandateDataRetrieval(
//         uint16 mandateIdFuzzed,
//         string memory nameDescriptionFuzzed,
//         bytes memory configFuzzed
//     ) public {
//         // Bound inputs
//         vm.assume(mandateIdFuzzed > 0);
//         vm.assume(bytes(nameDescriptionFuzzed).length >= 1 && bytes(nameDescriptionFuzzed).length <= 255);
//         vm.assume(configFuzzed.length <= MAX_FUZZ_CALLDATA_LENGTH);

//         // Initialize mandate
//         vm.prank(address(daoMock));
//         presetSingleAction.initializeMandate(mandateIdFuzzed, nameDescriptionFuzzed, "", configFuzzed);

//         // Test data retrieval
//         string memory retrievedName = presetSingleAction.getNameDescription(address(daoMock), mandateIdFuzzed);
//         bytes memory retrievedInputParams = presetSingleAction.getInputParams(address(daoMock), mandateIdFuzzed);
//         bytes memory retrievedConfig = presetSingleAction.getConfig(address(daoMock), mandateIdFuzzed);

//         // Verify data matches
//         assertEq(retrievedName, nameDescriptionFuzzed);
//         assertEq(retrievedInputParams.length, configFuzzed.length); // length of preset input params
//         assertEq(retrievedConfig.length, configFuzzed.length);
//     }

//     /// @notice Fuzz test mandate hash generation
//     function testFuzzMandateHashGeneration(uint16 mandateIdFuzzed) public {
//         vm.assume(mandateIdFuzzed > 0 && mandateIdFuzzed < 1000);

//         // Generate mandate hash
//         mandateHash = keccak256(abi.encode(address(daoMock), mandateIdFuzzed));

//         // Verify hash is consistent
//         bytes32 mandateHash2 = keccak256(abi.encode(address(daoMock), mandateIdFuzzed));
//         assertEq(mandateHash, mandateHash2);

//         // Verify hash changes with different inputs
//         bytes32 differentHash = keccak256(abi.encode(address(daoMock), mandateIdFuzzed + 1));
//         assertTrue(mandateHash != differentHash);
//     }

//     //////////////////////////////////////////////////////////////
//     //                  LAW INTERFACE COMPLIANCE FUZZ          //
//     //////////////////////////////////////////////////////////////

//     /// @notice Fuzz test ERC165 interface compliance
//     function testFuzzERC165Compliance() public view {
//         // Should support IMandate interface
//         bool supportsIMandate = presetSingleAction.supportsInterface(type(IMandate).interfaceId);
//         assertTrue(supportsIMandate);

//         // Should support ERC165 interface
//         bool supportsERC165 = presetSingleAction.supportsInterface(type(IERC165).interfaceId);
//         assertTrue(supportsERC165);
//     }

//     //////////////////////////////////////////////////////////////
//     //                  LAW STATE MANAGEMENT FUZZ               //
//     //////////////////////////////////////////////////////////////

//     /// @notice Fuzz test mandate state consistency
//     function testFuzzMandateStateConsistency(
//         uint16 mandateIdFuzzed,
//         string memory nameDescriptionFuzzed,
//         bytes memory configFuzzed
//     ) public {
//         // Bound inputs
//         vm.assume(mandateIdFuzzed > 0 && mandateIdFuzzed < 1000);
//         vm.assume(bytes(nameDescriptionFuzzed).length >= 1 && bytes(nameDescriptionFuzzed).length <= 255);
//         vm.assume(configFuzzed.length <= 1000);

//         // Initialize mandate
//         vm.prank(address(daoMock));
//         presetSingleAction.initializeMandate(mandateIdFuzzed, nameDescriptionFuzzed, "", configFuzzed);

//         // Verify state consistency
//         string memory retrievedName = presetSingleAction.getNameDescription(address(daoMock), mandateIdFuzzed);
//         bytes memory retrievedInputParams = presetSingleAction.getInputParams(address(daoMock), mandateIdFuzzed);
//         bytes memory retrievedConfig = presetSingleAction.getConfig(address(daoMock), mandateIdFuzzed);

//         // State should be consistent
//         assertEq(retrievedName, nameDescriptionFuzzed);
//         assertEq(retrievedInputParams.length, configFuzzed.length);
//         assertEq(retrievedConfig.length, configFuzzed.length);

//         for (i = 0; i < configFuzzed.length; i++) {
//             assertEq(retrievedConfig[i], configFuzzed[i]);
//         }
//     }

//     /// @notice Fuzz test mandate state updates
//     function testFuzzMandateStateUpdates(
//         uint16 mandateIdFuzzed,
//         string[] memory nameDescriptionsFuzzed,
//         bytes[] memory configArrayFuzzed,
//         uint256 numberOfUpdates
//     ) public {
//         // Bound inputs
//         vm.assume(mandateIdFuzzed > 0 && mandateIdFuzzed < 1000);
//         vm.assume(nameDescriptionsFuzzed.length > numberOfUpdates);
//         vm.assume(configArrayFuzzed.length > numberOfUpdates);
//         vm.assume(numberOfUpdates > 0 && numberOfUpdates <= 10);

//         for (i = 0; i < numberOfUpdates; i++) {
//             vm.assume(bytes(nameDescriptionsFuzzed[i]).length >= 1 && bytes(nameDescriptionsFuzzed[i]).length <= 255);
//             vm.assume(configArrayFuzzed[i].length <= 1000);

//             // Initialize mandate with new data
//             vm.prank(address(daoMock));
//             presetSingleAction.initializeMandate(mandateIdFuzzed, nameDescriptionsFuzzed[i], "", configArrayFuzzed[i]);

//             // Verify state was updated
//             string memory retrievedName = presetSingleAction.getNameDescription(address(daoMock), mandateIdFuzzed);
//             bytes memory retrievedInputParams = presetSingleAction.getInputParams(address(daoMock), mandateIdFuzzed);
//             bytes memory retrievedConfig = presetSingleAction.getConfig(address(daoMock), mandateIdFuzzed);

//             assertEq(retrievedName, nameDescriptionsFuzzed[i]);
//             assertEq(retrievedConfig.length, configArrayFuzzed[i].length);
//         }
//     }
// }
