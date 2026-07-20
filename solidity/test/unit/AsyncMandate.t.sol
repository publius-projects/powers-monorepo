// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.26;

import { AsyncMandate } from "@src/AsyncMandate.sol";
import { IMandate } from "@src/interfaces/IMandate.sol";
import { MandateUtilities } from "@src/libraries/MandateUtilities.sol";
import { IERC165 } from "@lib/openzeppelin-contracts/contracts/interfaces/IERC165.sol";
import { PowersEvents } from "@src/interfaces/PowersEvents.sol";
import { PowersErrors } from "@src/interfaces/PowersErrors.sol";
import { TestSetupAsync } from "../TestSetup.t.sol";
import { AsyncMandateMock } from "../mocks/MandateMocks.sol";

//////////////////////////////////////////////////
//              BASIC BEHAVIOUR TESTS          //
//////////////////////////////////////////////////
contract AsyncMandateBasicTest is TestSetupAsync {
    AsyncMandateMock asyncMock;

    function setUp() public override {
        super.setUp();
        asyncMock = AsyncMandateMock(registerTestMandate(address(new AsyncMandateMock(address(registry)))));
    }

    function testInitializeMandateSetsNameDescription() public {
        // prep
        mandateId = 1;
        nameDescription = "Test Async Mandate";
        configBytes = abi.encode();

        // act
        vm.prank(address(daoMock));
        asyncMock.initializeMandate(mandateId, nameDescription, inputParams, configBytes);

        // assert
        assertEq(asyncMock.getNameDescription(address(daoMock), mandateId), nameDescription);
    }

    function testInitializeMandateSetsConfig() public {
        // prep
        mandateId = 1;
        nameDescription = "Test Async Mandate";
        configBytes = abi.encode(address(0x1234), uint256(99), true);

        // act
        vm.prank(address(daoMock));
        asyncMock.initializeMandate(mandateId, nameDescription, inputParams, configBytes);

        // assert
        assertEq(keccak256(asyncMock.getConfig(address(daoMock), mandateId)), keccak256(configBytes));
    }

    function testInitializeMandateSetsInputParams() public {
        // prep
        mandateId = 1;
        nameDescription = "Test Async Mandate";
        inputParams = abi.encode("string param", uint256(42));
        configBytes = abi.encode();

        // act
        vm.prank(address(daoMock));
        asyncMock.initializeMandate(mandateId, nameDescription, inputParams, configBytes);

        // assert
        assertEq(keccak256(asyncMock.getInputParams(address(daoMock), mandateId)), keccak256(inputParams));
        delete inputParams;
    }

    function testInitializeMandateEmitsEvent() public {
        // prep
        mandateId = 1;
        nameDescription = "Test Async Mandate";
        configBytes = abi.encode("config data");

        // assert: event emitted
        vm.expectEmit(true, true, false, true);
        emit IMandate.Mandate__Initialized(address(daoMock), mandateId, nameDescription, inputParams, configBytes);

        vm.prank(address(daoMock));
        asyncMock.initializeMandate(mandateId, nameDescription, inputParams, configBytes);
    }

    function testInitializeMandateRevertsWithEmptyName() public {
        // prep
        mandateId = 1;
        nameDescription = "";

        // act & assert
        vm.expectRevert("String too short");
        vm.prank(address(daoMock));
        asyncMock.initializeMandate(mandateId, nameDescription, inputParams, configBytes);
    }

    function testInitializeMandateRevertsWithNameTooLong() public {
        // prep
        mandateId = 1;
        nameDescription = string(abi.encodePacked(new bytes(256)));

        // act & assert
        vm.expectRevert("String too long");
        vm.prank(address(daoMock));
        asyncMock.initializeMandate(mandateId, nameDescription, inputParams, configBytes);
    }

    function testInitializeMandateIsUnrestricted() public {
        // prep: alice is not the Powers contract
        mandateId = 1;
        nameDescription = "Anyone can initialize";
        configBytes = abi.encode();

        // act: alice can call initializeMandate directly
        vm.prank(alice);
        asyncMock.initializeMandate(mandateId, nameDescription, inputParams, configBytes);

        // assert: mandate stored under alice's address as powers
        assertEq(asyncMock.getNameDescription(alice, mandateId), nameDescription);
    }

    function testInitializeMandateOverwritesPreviousData() public {
        // prep: first initialization
        mandateId = 1;
        nameDescription = "First Name";
        configBytes = abi.encode("first config");
        vm.prank(address(daoMock));
        asyncMock.initializeMandate(mandateId, nameDescription, inputParams, configBytes);

        // act: re-initialize with new data
        string memory newName = "Second Name";
        bytes memory newConfig = abi.encode("second config");
        vm.prank(address(daoMock));
        asyncMock.initializeMandate(mandateId, newName, inputParams, newConfig);

        // assert: new data is stored
        assertEq(asyncMock.getNameDescription(address(daoMock), mandateId), newName);
        assertEq(keccak256(asyncMock.getConfig(address(daoMock), mandateId)), keccak256(newConfig));
    }

    function testInitializeMandateWithMaxLengthName() public {
        // prep: 255-character name (maximum allowed)
        mandateId = 1;
        nameDescription = string(abi.encodePacked(new bytes(255)));
        configBytes = abi.encode();

        // act
        vm.prank(address(daoMock));
        asyncMock.initializeMandate(mandateId, nameDescription, inputParams, configBytes);

        // assert
        assertEq(asyncMock.getNameDescription(address(daoMock), mandateId), nameDescription);
    }
}

//////////////////////////////////////////////////
//            HELPER FUNCTION TESTS            //
//////////////////////////////////////////////////
contract AsyncMandateHelperTest is TestSetupAsync {
    AsyncMandateMock asyncMock;

    function setUp() public override {
        super.setUp();
        asyncMock = AsyncMandateMock(registerTestMandate(address(new AsyncMandateMock(address(registry)))));
    }

    function testGetNameDescriptionReturnsStoredValue() public {
        // prep
        mandateId = 2;
        nameDescription = "Stored Name";
        vm.prank(address(daoMock));
        asyncMock.initializeMandate(mandateId, nameDescription, inputParams, configBytes);

        // act & assert
        assertEq(asyncMock.getNameDescription(address(daoMock), mandateId), nameDescription);
    }

    function testGetConfigReturnsStoredValue() public {
        // prep
        mandateId = 2;
        nameDescription = "Mandate";
        configBytes = abi.encode(uint256(777), address(0xBEEF));
        vm.prank(address(daoMock));
        asyncMock.initializeMandate(mandateId, nameDescription, inputParams, configBytes);

        // act & assert
        assertEq(keccak256(asyncMock.getConfig(address(daoMock), mandateId)), keccak256(configBytes));
    }

    function testGetInputParamsReturnsStoredValue() public {
        // prep
        mandateId = 2;
        nameDescription = "Mandate";
        inputParams = abi.encode("param1", uint256(100));
        vm.prank(address(daoMock));
        asyncMock.initializeMandate(mandateId, nameDescription, inputParams, configBytes);

        // act & assert
        assertEq(keccak256(asyncMock.getInputParams(address(daoMock), mandateId)), keccak256(inputParams));
        delete inputParams;
    }

    function testGetNameDescriptionForNonExistentMandateReturnsEmpty() public view {
        // act & assert: no initialization performed
        assertEq(asyncMock.getNameDescription(address(daoMock), 999), "");
    }

    function testGetInputParamsForNonExistentMandateReturnsEmpty() public view {
        // act & assert
        assertEq(asyncMock.getInputParams(address(daoMock), 999).length, 0);
    }

    function testGetConfigForNonExistentMandateReturnsEmpty() public view {
        // act & assert
        assertEq(asyncMock.getConfig(address(daoMock), 999).length, 0);
    }

    function testMandatesForDifferentMandateIdsAreIndependent() public {
        // prep: initialize two mandates with different IDs
        vm.startPrank(address(daoMock));
        asyncMock.initializeMandate(1, "First Mandate", inputParams, abi.encode("config1"));
        asyncMock.initializeMandate(2, "Second Mandate", inputParams, abi.encode("config2"));
        vm.stopPrank();

        // assert: each mandate returns its own data
        assertEq(asyncMock.getNameDescription(address(daoMock), 1), "First Mandate");
        assertEq(asyncMock.getNameDescription(address(daoMock), 2), "Second Mandate");
        assertEq(keccak256(asyncMock.getConfig(address(daoMock), 1)), keccak256(abi.encode("config1")));
        assertEq(keccak256(asyncMock.getConfig(address(daoMock), 2)), keccak256(abi.encode("config2")));
    }

    function testMandatesForDifferentPowersAreIndependent() public {
        // prep: initialize same mandateId under two different Powers contracts
        mandateId = 1;
        nameDescription = "Same ID, Different Powers";
        vm.prank(address(daoMock));
        asyncMock.initializeMandate(mandateId, "DAO Mock Data", inputParams, abi.encode("dao config"));

        vm.prank(address(daoMockChild1));
        asyncMock.initializeMandate(mandateId, "Child DAO Data", inputParams, abi.encode("child config"));

        // assert: each Powers contract gets its own data
        assertEq(asyncMock.getNameDescription(address(daoMock), mandateId), "DAO Mock Data");
        assertEq(asyncMock.getNameDescription(address(daoMockChild1), mandateId), "Child DAO Data");
    }
}

//////////////////////////////////////////////////
//         VERSION AND INTERFACE TESTS         //
//////////////////////////////////////////////////
contract AsyncMandateVersionInterfaceTest is TestSetupAsync {
    AsyncMandateMock asyncMock;

    function setUp() public override {
        super.setUp();
        asyncMock = AsyncMandateMock(registerTestMandate(address(new AsyncMandateMock(address(registry)))));
    }

    function testVersionReturnsExpectedValues() public view {
        (uint16 major, uint16 minor, uint16 patch) = asyncMock.version();
        assertEq(major, 0);
        assertEq(minor, 1);
        assertEq(patch, 9);
    }

    function testSupportsIMandateInterface() public view {
        assertTrue(asyncMock.supportsInterface(type(IMandate).interfaceId));
    }

    function testSupportsERC165Interface() public view {
        assertTrue(asyncMock.supportsInterface(type(IERC165).interfaceId));
    }

    function testDoesNotSupportRandomInterface() public view {
        assertFalse(asyncMock.supportsInterface(0xDEADBEEF));
    }
}

//////////////////////////////////////////////////
//          EXECUTE MANDATE TESTS              //
//////////////////////////////////////////////////
contract AsyncMandateExecuteTest is TestSetupAsync {
    AsyncMandateMock asyncMock;

    function setUp() public override {
        super.setUp();
        asyncMock = AsyncMandateMock(registerTestMandate(address(new AsyncMandateMock(address(registry)))));
    }

    function testExecuteMandateRevertsIfMandateNotInitialized() public {
        // act & assert: executeMandate called from daoMock, but initializeMandate was never called
        // mandates[hash].powers == address(0) != msg.sender(daoMock) → revert
        vm.expectRevert(IMandate.OnlyPowers.selector);
        vm.prank(address(daoMock));
        asyncMock.executeMandate(alice, 5, mandateCalldata, nonce);
    }

    function testExecuteMandateRevertsIfCalledByWrongAddress() public {
        // prep: initialize mandate for daoMock
        mandateId = 1;
        vm.prank(address(daoMock));
        asyncMock.initializeMandate(mandateId, "Async Mandate", inputParams, configBytes);

        // act & assert: alice tries to execute — not the registered powers
        vm.expectRevert(IMandate.OnlyPowers.selector);
        vm.prank(alice);
        asyncMock.executeMandate(alice, mandateId, mandateCalldata, nonce);
    }

    function testExecuteMandateRevertsIfCalledByDifferentPowers() public {
        // prep: initialize mandate for daoMock
        mandateId = 1;
        vm.prank(address(daoMock));
        asyncMock.initializeMandate(mandateId, "Async Mandate", inputParams, configBytes);

        // act & assert: daoMockChild1 (different powers) tries to execute — not registered
        vm.expectRevert(IMandate.OnlyPowers.selector);
        vm.prank(address(daoMockChild1));
        asyncMock.executeMandate(alice, mandateId, mandateCalldata, nonce);
    }

    function testExecuteMandateCallsOracleAndReturnsTrueOnSuccess() public {
        // prep: initialize mandate for daoMock
        mandateId = 1;
        vm.prank(address(daoMock));
        asyncMock.initializeMandate(mandateId, "Async Mandate", inputParams, configBytes);

        // act: executeMandate called from daoMock
        vm.prank(address(daoMock));
        bool success = asyncMock.executeMandate(alice, mandateId, mandateCalldata, nonce);

        // assert: returned true and oracle was invoked
        assertTrue(success);
        assertTrue(asyncMock.oracleCalled());
    }

    function testExecuteMandateCapturesPendingDataInCallOracle() public {
        // prep: initialize and set calldata
        mandateId = 1;
        mandateCalldata = abi.encode(address(0xABCD), uint256(42));
        vm.prank(address(daoMock));
        asyncMock.initializeMandate(mandateId, "Async Mandate", inputParams, configBytes);

        // act
        vm.prank(address(daoMock));
        asyncMock.executeMandate(alice, mandateId, mandateCalldata, nonce);

        // assert: oracle captured the correct actionId and powers address
        uint256 expectedActionId = MandateUtilities.computeActionId(mandateId, mandateCalldata, nonce);
        assertEq(asyncMock.pendingActionId(), expectedActionId);
        assertEq(asyncMock.pendingMandateId(), mandateId);
        assertEq(asyncMock.pendingPowers(), address(daoMock));
    }

    function testHandleRequestReturnsEmptyArraysByDefault() public view {
        // act: call handleRequest directly
        (uint256 actionId, address[] memory tgts, uint256[] memory vals, bytes[] memory cds) =
            asyncMock.handleRequest(alice, address(daoMock), 1, mandateCalldata, nonce);

        // assert: returns computed actionId and empty arrays
        uint256 expectedActionId = MandateUtilities.computeActionId(1, mandateCalldata, nonce);
        assertEq(actionId, expectedActionId);
        assertEq(tgts.length, 0);
        assertEq(vals.length, 0);
        assertEq(cds.length, 0);
    }
}

//////////////////////////////////////////////////
//            ASYNC FLOW TESTS                 //
//////////////////////////////////////////////////
contract AsyncMandateFlowTest is TestSetupAsync {
    AsyncMandateMock asyncMock;

    function setUp() public override {
        super.setUp();
        asyncMock = AsyncMandateMock(registerTestMandate(address(new AsyncMandateMock(address(registry)))));

        // Adopt the async mock as a mandate in daoMock accessible by ROLE_ONE holders
        conditions.allowedRole = ROLE_ONE;
        mandateId = daoMock.mandateCounter();
        vm.prank(address(daoMock));
        daoMock.adoptMandate(
            MandateInitData({
                nameDescription: "Async Test Mandate",
                targetMandate: address(asyncMock),
                config: abi.encode(),
                conditions: conditions
            })
        );
        delete conditions;
    }

    function testFullAsyncFlowRequestThenOracleCallbackFulfills() public {
        // prep
        mandateCalldata = abi.encode(address(0x1), uint256(100));
        actionId = MandateUtilities.computeActionId(mandateId, mandateCalldata, nonce);

        // act: alice requests the async mandate — this triggers _callOracle but NOT fulfill
        vm.prank(alice);
        daoMock.request(mandateId, mandateCalldata, nonce, "Test Async Request");

        // assert: action is in Requested state (not yet Fulfilled)
        assertEq(uint8(daoMock.getActionState(actionId)), uint8(ActionState.Requested));

        // act: oracle callback arrives and calls _replyPowers → fulfill
        asyncMock.simulateOracleCallback();

        // assert: action is now Fulfilled
        assertEq(uint8(daoMock.getActionState(actionId)), uint8(ActionState.Fulfilled));
    }

    function testReplyPowersDirectlyFulfillsRequestedAction() public {
        // prep: request the action first to set it to Requested state
        mandateCalldata = abi.encode(address(0x2), uint256(200));
        actionId = MandateUtilities.computeActionId(mandateId, mandateCalldata, nonce);

        vm.prank(alice);
        daoMock.request(mandateId, mandateCalldata, nonce, "Test Request");

        assertEq(uint8(daoMock.getActionState(actionId)), uint8(ActionState.Requested));

        // act: call _replyPowers directly (bypassing _callOracle)
        asyncMock.callReplyPowers(
            address(daoMock), mandateId, actionId, new address[](0), new uint256[](0), new bytes[](0)
        );

        // assert: action is Fulfilled
        assertEq(uint8(daoMock.getActionState(actionId)), uint8(ActionState.Fulfilled));
    }

    function testReplyPowersRevertsIfActionNotRequested() public {
        // prep: compute an actionId that was never requested
        mandateCalldata = abi.encode(address(0x3), uint256(300));
        actionId = MandateUtilities.computeActionId(mandateId, mandateCalldata, nonce);

        // act & assert: calling fulfill on a non-requested action reverts
        vm.expectRevert(PowersErrors.Powers__ActionNotRequested.selector);
        asyncMock.callReplyPowers(
            address(daoMock), mandateId, actionId, new address[](0), new uint256[](0), new bytes[](0)
        );
    }

    function testCancelRecoversStuckAsyncAction() public {
        // prep: request a direct (quorum == 0), async mandate whose oracle never calls back
        mandateCalldata = abi.encode(address(0x5), uint256(500));
        actionId = MandateUtilities.computeActionId(mandateId, mandateCalldata, nonce);

        vm.prank(alice);
        daoMock.request(mandateId, mandateCalldata, nonce, "Test Async Request");

        // assert: action is stuck in Requested — the oracle never calls simulateOracleCallback()
        assertEq(uint8(daoMock.getActionState(actionId)), uint8(ActionState.Requested));

        // act: the original caller cancels the stuck action directly (no propose() ever happened)
        vm.prank(alice);
        daoMock.cancel(mandateId, mandateCalldata, nonce);

        // assert: action is now recoverably Cancelled instead of stuck forever
        assertEq(uint8(daoMock.getActionState(actionId)), uint8(ActionState.Cancelled));
    }

    function testLateOracleCallbackRevertsAfterCancellation() public {
        // prep: request, then cancel before the oracle ever responds
        mandateCalldata = abi.encode(address(0x6), uint256(600));
        actionId = MandateUtilities.computeActionId(mandateId, mandateCalldata, nonce);

        vm.prank(alice);
        daoMock.request(mandateId, mandateCalldata, nonce, "Test Async Request");

        vm.prank(alice);
        daoMock.cancel(mandateId, mandateCalldata, nonce);

        // act & assert: a late oracle callback arriving after cancellation is a clean no-op revert,
        // not a double-execution risk — fulfill() already checks action.cancelledAt > 0.
        vm.expectRevert(PowersErrors.Powers__ActionNotRequested.selector);
        asyncMock.simulateOracleCallback();
    }

    function testExecuteMandateDoesNotCallFulfillDirectly() public {
        // prep: adopt with alice's role access
        mandateCalldata = abi.encode(address(0x4), uint256(400));
        actionId = MandateUtilities.computeActionId(mandateId, mandateCalldata, nonce);

        // act: request the mandate (triggers executeMandate internally)
        vm.prank(alice);
        daoMock.request(mandateId, mandateCalldata, nonce, "Async Request");

        // assert: action is Requested but NOT yet Fulfilled — confirms async two-phase design
        assertEq(uint8(daoMock.getActionState(actionId)), uint8(ActionState.Requested));
        assertNotEq(uint8(daoMock.getActionState(actionId)), uint8(ActionState.Fulfilled));

        // assert: oracle was called and has pending data ready for callback
        assertTrue(asyncMock.oracleCalled());
        assertEq(asyncMock.pendingActionId(), actionId);
    }
}
