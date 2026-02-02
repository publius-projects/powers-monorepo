// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.26;

import { Test } from "forge-std/Test.sol";
import { Mandate } from "../../src/Mandate.sol";
import { MandateUtilities } from "../../src/libraries/MandateUtilities.sol";
import { IMandate } from "../../src/interfaces/IMandate.sol";
import { IERC165 } from "@openzeppelin/contracts/interfaces/IERC165.sol";
import { PowersEvents } from "../../src/interfaces/PowersEvents.sol";
import { TestSetupMandate } from "../TestSetup.t.sol";
import { OpenAction } from "../../src/mandates/executive/OpenAction.sol";
import { PresetActions_Single } from "../../src/mandates/executive/PresetActions_Single.sol";
import { EmptyTargetsMandate, MockTargetsMandate } from "../mocks/MandateMocks.sol";

/// @notice Comprehensive unit tests for Mandate.sol contract
/// @dev Tests all functionality of the Mandate base contract including initialization, execution, and helper functions

//////////////////////////////////////////////////
//              BASIC LAW TESTS                //
//////////////////////////////////////////////////
contract MandateBasicTest is TestSetupMandate {
    Mandate testMandate;

    function setUp() public override {
        super.setUp();

        vm.prank(address(daoMock));
        testMandate = new OpenAction();
    }

    function testInitializeMandateSetsCorrectState() public {
        // prep: create test data
        mandateId = daoMock.mandateCounter();
        nameDescription = "Test Mandate";
        configBytes = abi.encode();

        // act: initialize the mandate
        vm.prank(address(daoMock));
        daoMock.adoptMandate(
            MandateInitData({
                nameDescription: nameDescription,
                targetMandate: address(testMandate),
                config: configBytes,
                conditions: conditions
            })
        );

        // assert: verify mandate data is set correctly
        assertEq(testMandate.getNameDescription(address(daoMock), mandateId), nameDescription);
        assertEq(keccak256(testMandate.getConfig(address(daoMock), mandateId)), keccak256(configBytes));
    }

    function testInitializeMandateEmitsEvent() public {
        // prep: create test data
        mandateId = daoMock.mandateCounter();
        nameDescription = "Test Mandate";
        configBytes = abi.encode("test config");

        // assert: verify event is emitted
        vm.expectEmit(true, true, false, true);
        emit PowersEvents.MandateAdopted(mandateId);

        vm.prank(address(daoMock));
        daoMock.adoptMandate(
            MandateInitData({
                nameDescription: nameDescription,
                targetMandate: address(testMandate),
                config: configBytes,
                conditions: conditions
            })
        );
    }

    function testInitializeMandateRevertsWithEmptyName() public {
        // prep: create test data with empty name
        mandateId = daoMock.mandateCounter();
        nameDescription = "";
        configBytes = abi.encode("test config");

        // act & assert: verify initialization reverts
        vm.expectRevert("String too short");
        vm.prank(address(daoMock));
        daoMock.adoptMandate(
            MandateInitData({
                nameDescription: nameDescription,
                targetMandate: address(testMandate),
                config: configBytes,
                conditions: conditions
            })
        );
    }

    function testInitializeMandateRevertsWithTooLongName() public {
        // prep: create test data with too long name
        mandateId = daoMock.mandateCounter();
        nameDescription = string(abi.encodePacked(new bytes(256))); // 256 character string
        configBytes = abi.encode();

        // act & assert: verify initialization reverts
        vm.expectRevert("String too long");
        vm.prank(address(daoMock));
        daoMock.adoptMandate(
            MandateInitData({
                nameDescription: nameDescription,
                targetMandate: address(testMandate),
                config: configBytes,
                conditions: conditions
            })
        );
    }

    function testExecuteMandateRevertsIfNotCalledFromPowers() public {
        // prep: initialize the mandate
        mandateId = daoMock.mandateCounter();
        nameDescription = "Test Mandate";
        configBytes = abi.encode("test config");

        vm.prank(address(daoMock));
        daoMock.adoptMandate(
            MandateInitData({
                nameDescription: nameDescription,
                targetMandate: address(testMandate),
                config: configBytes,
                conditions: conditions
            })
        );

        // act & assert: verify execution reverts when not called from Powers
        vm.expectRevert("Only Powers");
        vm.prank(alice);
        testMandate.executeMandate(alice, mandateId, abi.encode(true), nonce);
    }

    function testExecuteMandateSucceedsWhenCalledFromPowers() public {
        // prep: initialize the mandate
        mandateId = daoMock.mandateCounter();
        nameDescription = "Test Mandate";
        configBytes = abi.encode("test config");
        conditions.allowedRole = 1;
        vm.prank(address(daoMock));
        daoMock.assignRole(1, alice);

        targets = new address[](1);
        targets[0] = address(daoMock);

        values = new uint256[](1);
        values[0] = 0;

        calldatas = new bytes[](1);
        calldatas[0] = abi.encodeWithSelector(daoMock.labelRole.selector, ROLE_ONE, "Member");

        vm.prank(address(daoMock));
        daoMock.adoptMandate(
            MandateInitData({
                nameDescription: nameDescription,
                targetMandate: address(testMandate),
                config: configBytes,
                conditions: conditions
            })
        );

        // act: execute mandate from Powers contract
        vm.prank(alice);
        daoMock.request(mandateId, abi.encode(targets, values, calldatas), nonce, "Test Mandate");

        actionId = MandateUtilities.computeActionId(mandateId, abi.encode(targets, values, calldatas), nonce);

        // assert: verify execution succeeds
        assertTrue(daoMock.getActionState(actionId) == ActionState.Fulfilled);
    }
}

//////////////////////////////////////////////////
//              HELPER FUNCTION TESTS          //
//////////////////////////////////////////////////
contract MandateHelperTest is TestSetupMandate {
    Mandate testMandate;

    function setUp() public override {
        super.setUp();
        testMandate = new OpenAction();
    }

    function testGetNameDescription() public {
        // prep: initialize mandate
        mandateId = 1;
        nameDescription = "Test Mandate Name";
        inputParams = abi.encode("test input");
        configBytes = abi.encode();

        vm.prank(address(daoMock));
        testMandate.initializeMandate(mandateId, nameDescription, inputParams, configBytes);

        // act: get name description
        retrievedName = testMandate.getNameDescription(address(daoMock), mandateId);

        // assert: verify name is correct
        assertEq(retrievedName, nameDescription);
        delete inputParams; // clean up
    }

    function testGetConfig() public {
        // prep: initialize mandate
        mandateId = 1;
        nameDescription = "Test Mandate";
        inputParams = abi.encode("test input");
        configBytes = abi.encode("test config", 456, false);

        vm.prank(address(daoMock));
        testMandate.initializeMandate(mandateId, nameDescription, inputParams, configBytes);

        // act: get config
        retrievedConfig = testMandate.getConfig(address(daoMock), mandateId);

        // assert: verify config is correct
        assertEq(keccak256(retrievedConfig), keccak256(configBytes));
        delete inputParams; // clean up
    }

    function testGetNameDescriptionRevertsForNonExistentMandate() public {
        // act & assert: verify getting name for non-existent mandate returns empty string
        retrievedName = testMandate.getNameDescription(address(daoMock), 999);
        assertEq(retrievedName, "");
    }

    function testGetInputParamsRevertsForNonExistentMandate() public {
        // act & assert: verify getting params for non-existent mandate returns empty bytes
        retrievedParams = testMandate.getInputParams(address(daoMock), 999);
        assertEq(retrievedParams.length, 0);
    }

    function testGetConfigRevertsForNonExistentMandate() public {
        // act & assert: verify getting config for non-existent mandate returns empty bytes
        retrievedConfig = testMandate.getConfig(address(daoMock), 999);
        assertEq(retrievedConfig.length, 0);
    }
}

//////////////////////////////////////////////////
//              INTERFACE SUPPORT TESTS        //
//////////////////////////////////////////////////
contract MandateInterfaceTest is TestSetupMandate {
    Mandate testMandate;

    function setUp() public override {
        super.setUp();
        testMandate = new OpenAction();
    }

    function testSupportsIMandateInterface() public {
        // act: check if contract supports IMandate interface
        supportsInterface = testMandate.supportsInterface(type(IMandate).interfaceId);

        // assert: verify interface is supported
        assertTrue(supportsInterface);
    }

    function testSupportsERC165Interface() public {
        // act: check if contract supports ERC165 interface
        supportsInterface = testMandate.supportsInterface(type(IERC165).interfaceId);

        // assert: verify interface is supported
        assertTrue(supportsInterface);
    }

    function testDoesNotSupportRandomInterface() public {
        // act: check if contract supports random interface
        supportsInterface = testMandate.supportsInterface(0x12345678);

        // assert: verify interface is not supported
        assertFalse(supportsInterface);
    }
}

//////////////////////////////////////////////////
//              LAW UTILITIES TESTS            //
//////////////////////////////////////////////////
contract MandateUtilitiesTest is TestSetupMandate {
    function testHashActionIdReturnsConsistentHash() public {
        // prep: create test data
        mandateId = 1;
        mandateCalldata = abi.encode(true, "test", 123);
        nonce = 123;

        // act: hash the action ID
        actionId = MandateUtilities.computeActionId(mandateId, mandateCalldata, nonce);

        // assert: verify hash is consistent
        assertEq(actionId, uint256(keccak256(abi.encode(mandateId, mandateCalldata, nonce))));
    }

    function testHashMandateReturnsConsistentHash() public {
        // prep: create test data
        mandateId = 1;
        powersAddress = address(daoMock);

        // act: hash the mandate
        mandateHash = MandateUtilities.hashMandate(powersAddress, mandateId);

        // assert: verify hash is consistent
        assertEq(mandateHash, keccak256(abi.encode(powersAddress, mandateId)));
    }

    function testCreateEmptyArraysReturnsCorrectArrays() public {
        // prep: create test data
        uint256 length = 5;

        // act: create empty arrays
        (targets, values, calldatas) = MandateUtilities.createEmptyArrays(length);

        // assert: verify arrays are created with correct length
        assertEq(targets.length, length);
        assertEq(values.length, length);
        assertEq(calldatas.length, length);

        // assert: verify all elements are zero/empty
        for (i = 0; i < length; i++) {
            assertEq(targets[i], address(0));
            assertEq(values[i], 0);
            assertEq(calldatas[i].length, 0);
        }
    }

    function testCheckStringLengthWithValidString() public pure {
        // act & assert: verify valid string length passes
        MandateUtilities.checkStringLength("Valid String", 1, 100);
    }

    function testCheckStringLengthRevertsWithTooShort() public {
        // act & assert: verify too short string reverts
        vm.expectRevert("String too short");
        MandateUtilities.checkStringLength("", 1, 100);
    }

    function testCheckStringLengthRevertsWithTooLong() public {
        // prep: create a string longer than max length
        string memory longString = string(abi.encodePacked(new bytes(300)));

        // act & assert: verify too long string reverts
        vm.expectRevert("String too long");
        MandateUtilities.checkStringLength(longString, 1, 100);
    }
}

//////////////////////////////////////////////////
//              EDGE CASE TESTS                //
//////////////////////////////////////////////////
contract MandateEdgeCaseTest is TestSetupMandate {
    Mandate testMandate;

    function setUp() public override {
        super.setUp();
        testMandate = new OpenAction();
    }

    function testInitializeMandateWithMaximumLengthName() public {
        // prep: create test data with maximum length name (255 characters)
        mandateId = daoMock.mandateCounter();
        nameDescription = string(abi.encodePacked(new bytes(255)));
        configBytes = abi.encode("test config");

        // act: initialize the mandate
        vm.prank(address(daoMock));
        daoMock.adoptMandate(
            MandateInitData({
                nameDescription: nameDescription,
                targetMandate: address(testMandate),
                config: configBytes,
                conditions: conditions
            })
        );

        // assert: verify mandate is initialized successfully
        assertEq(testMandate.getNameDescription(address(daoMock), mandateId), nameDescription);
    }

    function testInitializeMandateWithMinimumLengthName() public {
        // prep: create test data with minimum length name (1 character)
        mandateId = daoMock.mandateCounter();
        nameDescription = "A";
        configBytes = abi.encode("test config");

        // act: initialize the mandate
        vm.prank(address(daoMock));
        daoMock.adoptMandate(
            MandateInitData({
                nameDescription: nameDescription,
                targetMandate: address(testMandate),
                config: configBytes,
                conditions: conditions
            })
        );

        // assert: verify mandate is initialized successfully
        assertEq(testMandate.getNameDescription(address(daoMock), mandateId), nameDescription);
    }

    function testInitializeMandateWithEmptyInputParams() public {
        // prep: create test data with empty input params
        mandateId = daoMock.mandateCounter();
        nameDescription = "Test Mandate";
        inputParams = abi.encode();
        configBytes = abi.encode("test config");

        // act: initialize the mandate
        vm.prank(address(daoMock));
        daoMock.adoptMandate(
            MandateInitData({
                nameDescription: nameDescription,
                targetMandate: address(testMandate),
                config: configBytes,
                conditions: conditions
            })
        );

        // assert: verify mandate is initialized successfully
        assertEq(testMandate.getInputParams(address(daoMock), mandateId).length, 288);
    }

    function testInitializeMandateWithEmptyConfig() public {
        // prep: create test data with empty config
        mandateId = daoMock.mandateCounter();
        nameDescription = "Test Mandate";
        configBytes = abi.encode();

        // act: initialize the mandate
        vm.prank(address(daoMock));
        daoMock.adoptMandate(
            MandateInitData({
                nameDescription: nameDescription,
                targetMandate: address(testMandate),
                config: configBytes,
                conditions: conditions
            })
        );

        // assert: verify mandate is initialized successfully
        assertEq(testMandate.getConfig(address(daoMock), mandateId).length, 0);
    }

    function testInitializeMandateWithComplexData() public {
        // prep: create test data with complex nested structures
        mandateId = daoMock.mandateCounter();
        nameDescription = "Complex Test Mandate";

        // Complex config with arrays
        address[] memory configAddresses = new address[](3);
        configAddresses[0] = address(0x1);
        configAddresses[1] = address(0x2);
        configAddresses[2] = address(0x3);

        configBytes = abi.encode(configAddresses, 789, false);

        // act: initialize the mandate
        vm.prank(address(daoMock));
        daoMock.adoptMandate(
            MandateInitData({
                nameDescription: nameDescription,
                targetMandate: address(testMandate),
                config: configBytes,
                conditions: conditions
            })
        );

        // assert: verify mandate is initialized successfully
        assertEq(testMandate.getNameDescription(address(daoMock), mandateId), nameDescription);
        assertEq(keccak256(testMandate.getConfig(address(daoMock), mandateId)), keccak256(configBytes));
    }

    function testMultipleMandatesWithSamePowers() public {
        // prep: initialize multiple mandates with same Powers contract
        mandateId = daoMock.mandateCounter();
        vm.startPrank(address(daoMock));

        // Create multiple mandate instances for testing
        Mandate testMandate1 = new OpenAction();
        Mandate testMandate2 = new OpenAction();
        Mandate testMandate3 = new OpenAction();

        // Adopt mandates using the proper pattern
        daoMock.adoptMandate(
            MandateInitData({
                nameDescription: "Mandate 1",
                targetMandate: address(testMandate1),
                config: abi.encode("config1"),
                conditions: conditions
            })
        );

        daoMock.adoptMandate(
            MandateInitData({
                nameDescription: "Mandate 2",
                targetMandate: address(testMandate2),
                config: abi.encode("config2"),
                conditions: conditions
            })
        );

        daoMock.adoptMandate(
            MandateInitData({
                nameDescription: "Mandate 3",
                targetMandate: address(testMandate3),
                config: abi.encode("config3"),
                conditions: conditions
            })
        );
        vm.stopPrank();

        // assert: verify all mandates are stored correctly
        assertEq(testMandate1.getNameDescription(address(daoMock), mandateId), "Mandate 1");
        assertEq(testMandate2.getNameDescription(address(daoMock), mandateId + 1), "Mandate 2");
        assertEq(testMandate3.getNameDescription(address(daoMock), mandateId + 2), "Mandate 3");
    }

    function testMandateWithDifferentPowersContracts() public {
        // prep: create multiple mandate instances to test separation
        mandateId = daoMock.mandateCounter();
        Mandate testMandate1 = new OpenAction();
        Mandate testMandate2 = new OpenAction();

        // prep: initialize mandates with same Powers contract but different mandate instances
        vm.prank(address(daoMock));
        daoMock.adoptMandate(
            MandateInitData({
                nameDescription: "Mandate for DAO",
                targetMandate: address(testMandate1),
                config: abi.encode("dao config"),
                conditions: conditions
            })
        );

        vm.prank(address(daoMock));
        daoMock.adoptMandate(
            MandateInitData({
                nameDescription: "Mandate for Another DAO",
                targetMandate: address(testMandate2),
                config: abi.encode("another config"),
                conditions: conditions
            })
        );

        // assert: verify mandates are stored separately with different mandate IDs
        assertEq(testMandate1.getNameDescription(address(daoMock), mandateId), "Mandate for DAO");
        assertEq(testMandate2.getNameDescription(address(daoMock), mandateId + 1), "Mandate for Another DAO");
    }
}

//////////////////////////////////////////////////
//              HANDLE REQUEST TESTS           //
//////////////////////////////////////////////////
contract MandateHandleRequestTest is TestSetupMandate {
    Mandate testMandate;

    function setUp() public override {
        super.setUp();
        testMandate = new OpenAction();
    }

    function testHandleRequestReturnsCorrectActionId() public {
        // prep: create test data
        mandateId = 1;
        nonce = 123;
        targets = new address[](2);
        targets[0] = address(0x1);
        targets[1] = address(0x2);

        values = new uint256[](2);
        values[0] = 1 ether;
        values[1] = 2 ether;

        calldatas = new bytes[](2);
        calldatas[0] = abi.encodeWithSignature("function1()");
        calldatas[1] = abi.encodeWithSignature("function2(uint256)", 42);

        mandateCalldata = abi.encode(targets, values, calldatas);

        // act: call handleRequest
        (uint256 actionId,,,) = testMandate.handleRequest(alice, address(daoMock), mandateId, mandateCalldata, nonce);

        // assert: verify actionId is correct
        uint256 expectedActionId = MandateUtilities.computeActionId(mandateId, mandateCalldata, nonce);
        assertEq(actionId, expectedActionId);
    }

    function testHandleRequestReturnsCorrectDecodedData() public {
        // prep: create test data
        mandateId = 1;
        nonce = 456;
        targets = new address[](3);
        targets[0] = address(0x111);
        targets[1] = address(0x222);
        targets[2] = address(0x333);

        values = new uint256[](3);
        values[0] = 0;
        values[1] = 1 ether;
        values[2] = 2 ether;

        calldatas = new bytes[](3);
        calldatas[0] = abi.encodeWithSignature("transfer(address,uint256)", address(0x444), 1000);
        calldatas[1] = abi.encodeWithSignature("mint(address,uint256)", address(0x555), 2000);
        calldatas[2] = abi.encodeWithSignature("burn(uint256)", 500);

        mandateCalldata = abi.encode(targets, values, calldatas);

        // act: call handleRequest
        (
            uint256 actionId,
            address[] memory returnedTargets,
            uint256[] memory returnedValues,
            bytes[] memory returnedCalldatas
        ) = testMandate.handleRequest(bob, address(daoMock), mandateId, mandateCalldata, nonce);

        // assert: verify decoded data matches input
        assertEq(returnedTargets.length, targets.length);
        assertEq(returnedValues.length, values.length);
        assertEq(returnedCalldatas.length, calldatas.length);

        for (uint256 i = 0; i < targets.length; i++) {
            assertEq(returnedTargets[i], targets[i]);
            assertEq(returnedValues[i], values[i]);
            assertEq(keccak256(returnedCalldatas[i]), keccak256(calldatas[i]));
        }
    }

    function testHandleRequestWithEmptyArrays() public {
        // prep: create test data with empty arrays
        mandateId = 2;
        nonce = 789;
        targets = new address[](0);
        values = new uint256[](0);
        calldatas = new bytes[](0);

        mandateCalldata = abi.encode(targets, values, calldatas);

        // act: call handleRequest
        (
            uint256 actionId,
            address[] memory returnedTargets,
            uint256[] memory returnedValues,
            bytes[] memory returnedCalldatas
        ) = testMandate.handleRequest(alice, address(daoMock), mandateId, mandateCalldata, nonce);

        // assert: verify empty arrays are returned correctly
        assertEq(returnedTargets.length, 0);
        assertEq(returnedValues.length, 0);
        assertEq(returnedCalldatas.length, 0);

        // assert: verify actionId is still correct
        uint256 expectedActionId = MandateUtilities.computeActionId(mandateId, mandateCalldata, nonce);
        assertEq(actionId, expectedActionId);
    }

    function testHandleRequestWithSingleAction() public {
        // prep: create test data with single action
        mandateId = 3;
        nonce = 999;
        targets = new address[](1);
        targets[0] = address(0xABC);

        values = new uint256[](1);
        values[0] = 5 ether;

        calldatas = new bytes[](1);
        calldatas[0] =
            abi.encodeWithSignature("complexFunction(address,uint256,string)", address(0xDEF), 123, "test string");

        mandateCalldata = abi.encode(targets, values, calldatas);

        // act: call handleRequest
        (
            uint256 actionId,
            address[] memory returnedTargets,
            uint256[] memory returnedValues,
            bytes[] memory returnedCalldatas
        ) = testMandate.handleRequest(charlotte, address(daoMock), mandateId, mandateCalldata, nonce);

        // assert: verify single action is returned correctly
        assertEq(returnedTargets.length, 1);
        assertEq(returnedValues.length, 1);
        assertEq(returnedCalldatas.length, 1);

        assertEq(returnedTargets[0], targets[0]);
        assertEq(returnedValues[0], values[0]);
        assertEq(keccak256(returnedCalldatas[0]), keccak256(calldatas[0]));

        // assert: verify actionId is correct
        uint256 expectedActionId = MandateUtilities.computeActionId(mandateId, mandateCalldata, nonce);
        assertEq(actionId, expectedActionId);
    }

    function testHandleRequestWithDifferentCallers() public {
        // prep: create test data
        mandateId = 4;
        nonce = 111;
        targets = new address[](1);
        targets[0] = address(0x123);

        values = new uint256[](1);
        values[0] = 0;

        calldatas = new bytes[](1);
        calldatas[0] = abi.encodeWithSignature("viewFunction()");

        mandateCalldata = abi.encode(targets, values, calldatas);

        // act: call handleRequest with different callers
        (uint256 actionId1,,,) = testMandate.handleRequest(alice, address(daoMock), mandateId, mandateCalldata, nonce);
        (uint256 actionId2,,,) = testMandate.handleRequest(bob, address(daoMock), mandateId, mandateCalldata, nonce);
        (uint256 actionId3,,,) =
            testMandate.handleRequest(charlotte, address(daoMock), mandateId, mandateCalldata, nonce);

        // assert: verify actionId is the same regardless of caller (as expected for pure function)
        assertEq(actionId1, actionId2);
        assertEq(actionId2, actionId3);

        uint256 expectedActionId = MandateUtilities.computeActionId(mandateId, mandateCalldata, nonce);
        assertEq(actionId1, expectedActionId);
    }

    function testHandleRequestWithDifferentPowersAddresses() public {
        // prep: create test data
        mandateId = 5;
        nonce = 222;
        targets = new address[](1);
        targets[0] = address(0x456);

        values = new uint256[](1);
        values[0] = 1 ether;

        calldatas = new bytes[](1);
        calldatas[0] = abi.encodeWithSignature("payableFunction()");

        mandateCalldata = abi.encode(targets, values, calldatas);

        // act: call handleRequest with different powers addresses
        (uint256 actionId1,,,) = testMandate.handleRequest(alice, address(0x111), mandateId, mandateCalldata, nonce);
        (uint256 actionId2,,,) = testMandate.handleRequest(alice, address(0x222), mandateId, mandateCalldata, nonce);
        (uint256 actionId3,,,) = testMandate.handleRequest(alice, address(0x333), mandateId, mandateCalldata, nonce);

        // assert: verify actionId is the same regardless of powers address (as expected for pure function)
        assertEq(actionId1, actionId2);
        assertEq(actionId2, actionId3);

        uint256 expectedActionId = MandateUtilities.computeActionId(mandateId, mandateCalldata, nonce);
        assertEq(actionId1, expectedActionId);
    }

    function testHandleRequestWithComplexCalldata() public {
        // prep: create test data with complex nested structures
        mandateId = 6;
        nonce = 333;

        // Create complex calldata with multiple parameters
        targets = new address[](2);
        targets[0] = address(0xAAA);
        targets[1] = address(0xBBB);

        values = new uint256[](2);
        values[0] = 0;
        values[1] = 1 ether;

        calldatas = new bytes[](2);
        calldatas[0] = abi.encodeWithSignature(
            "multiParamFunction(address[],uint256[],bool,string)",
            new address[](2),
            new uint256[](2),
            true,
            "complex string"
        );
        calldatas[1] =
            abi.encodeWithSignature("anotherFunction(bytes32,address,uint256)", keccak256("test"), address(0xCCC), 999);

        mandateCalldata = abi.encode(targets, values, calldatas);

        // act: call handleRequest
        (
            uint256 actionId,
            address[] memory returnedTargets,
            uint256[] memory returnedValues,
            bytes[] memory returnedCalldatas
        ) = testMandate.handleRequest(alice, address(daoMock), mandateId, mandateCalldata, nonce);

        // assert: verify complex data is decoded correctly
        assertEq(returnedTargets.length, targets.length);
        assertEq(returnedValues.length, values.length);
        assertEq(returnedCalldatas.length, calldatas.length);

        for (uint256 i = 0; i < targets.length; i++) {
            assertEq(returnedTargets[i], targets[i]);
            assertEq(returnedValues[i], values[i]);
            assertEq(keccak256(returnedCalldatas[i]), keccak256(calldatas[i]));
        }

        // assert: verify actionId is correct
        uint256 expectedActionId = MandateUtilities.computeActionId(mandateId, mandateCalldata, nonce);
        assertEq(actionId, expectedActionId);
    }

    function testHandleRequestRevertsWithInvalidCalldata() public {
        // prep: create invalid calldata that cannot be decoded as (address[], uint256[], bytes[])
        mandateId = 7;
        nonce = 444;
        mandateCalldata = abi.encode("invalid data", 123, true);

        // act & assert: verify handleRequest reverts with invalid calldata
        vm.expectRevert();
        testMandate.handleRequest(alice, address(daoMock), mandateId, mandateCalldata, nonce);
    }

    function testHandleRequestWithMismatchedArrayLengths() public {
        // prep: create calldata with mismatched array lengths
        mandateId = 8;
        nonce = 555;

        targets = new address[](2);
        targets[0] = address(0x111);
        targets[1] = address(0x222);

        values = new uint256[](1); // Different length
        values[0] = 1 ether;

        calldatas = new bytes[](2);
        calldatas[0] = abi.encodeWithSignature("function1()");
        calldatas[1] = abi.encodeWithSignature("function2()");

        // This will create calldata with mismatched array lengths
        mandateCalldata = abi.encode(targets, values, calldatas);

        // act: call handleRequest (OpenAction doesn't validate array length consistency)
        (
            uint256 actionId,
            address[] memory returnedTargets,
            uint256[] memory returnedValues,
            bytes[] memory returnedCalldatas
        ) = testMandate.handleRequest(alice, address(daoMock), mandateId, mandateCalldata, nonce);

        // assert: verify that the function succeeds and returns the mismatched arrays as-is
        assertEq(returnedTargets.length, 2);
        assertEq(returnedValues.length, 1);
        assertEq(returnedCalldatas.length, 2);

        // assert: verify actionId is still correct
        uint256 expectedActionId = MandateUtilities.computeActionId(mandateId, mandateCalldata, nonce);
        assertEq(actionId, expectedActionId);
    }
}
