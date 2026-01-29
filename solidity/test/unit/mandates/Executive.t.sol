// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import { Test } from "forge-std/Test.sol";
import { TestSetupExecutive } from "../../TestSetup.t.sol";

import { Powers } from "@src/Powers.sol";
import { MandateUtilities } from "@src/libraries/MandateUtilities.sol";
import { PowersTypes } from "@src/interfaces/PowersTypes.sol";
import { PowersEvents } from "@src/interfaces/PowersEvents.sol";
import { PowersErrors } from "@src/interfaces/PowersErrors.sol";

import { PowersMock } from "@mocks/PowersMock.sol";
import { OpenAction } from "@src/mandates/executive/OpenAction.sol";
import { PresetActions_Single } from "@src/mandates/executive/PresetActions_Single.sol";
import { SimpleErc1155 } from "@mocks/SimpleErc1155.sol";
import { ReturnDataMock } from "@mocks/ReturnDataMock.sol";

contract StatementOfIntentTest is TestSetupExecutive {
    function setUp() public override {
        super.setUp();
        mandateId = findMandateIdInOrg("StatementOfIntent: A mandate to propose actions without execution.", daoMock);
    }

    function testStatementOfIntentRequestWorks() public {
        description = "Proposing an action via StatementOfIntent";
        mandateCalldata = abi.encode(true);

        vm.prank(alice);
        daoMock.request(mandateId, mandateCalldata, nonce, description);

        actionId = MandateUtilities.computeActionId(mandateId, mandateCalldata, nonce);
        PowersTypes.ActionState actionState = daoMock.getActionState(actionId);
        assertEq(uint8(actionState), uint8(PowersTypes.ActionState.Fulfilled));
    }

    function testStatementOfIntentDoesNotExecutePayload() public {
        // Prepare payload that would mint tokens if executed
        callData = abi.encodeWithSignature("mint(uint256,address)", 100, alice);

        targets = new address[](1);
        targets[0] = address(simpleErc1155);

        values = new uint256[](1);
        values[0] = 0;

        calldatas = new bytes[](1);
        calldatas[0] = callData;

        mandateCalldata = abi.encode(targets, values, calldatas);
        nonce = 999;

        balanceBefore = simpleErc1155.balanceOf(alice, 0);

        vm.prank(alice);
        daoMock.request(mandateId, mandateCalldata, nonce, "Try to mint");

        balanceAfter = simpleErc1155.balanceOf(alice, 0);

        // Assert balance did NOT change
        assertEq(balanceAfter, balanceBefore, "StatementOfIntent should not execute the payload");
    }

    function testStatementOfIntentProposeRevertsIfNoVoteNeeded() public {
        // In executiveTestConstitution, StatementOfIntent has 0 voting period, so propose should revert
        mandateCalldata = abi.encode(true);
        nonce = 888;

        vm.prank(alice);
        vm.expectRevert(PowersErrors.Powers__NoVoteNeeded.selector);
        daoMock.propose(mandateId, mandateCalldata, nonce, "Proposing when not needed");
    }
}

contract OpenActionTest is TestSetupExecutive {
    event CoinsMinted(address indexed to, uint256 amount);

    function setUp() public override {
        super.setUp();
        mandateId = findMandateIdInOrg("OpenAction: A mandate to execute any action with full power.", daoMock);
    }

    ////////////////////////////////////////////////////////////////
    //                     EXECUTE OPEN ACTION FLOW               //
    ////////////////////////////////////////////////////////////////

    function testOpenActionExecuteExternal() public {
        // 1. Prepare calldata for external action (Mint coins on SimpleErc1155)
        mintAmount = 100;
        callData = abi.encodeWithSelector(
            bytes4(keccak256("mint(uint256,address)")),
            mintAmount,
            alice // mint to alice to see event emitted correctly
        );

        // 2. Prepare mandate inputs
        targets = new address[](1);
        targets[0] = address(simpleErc1155);

        values = new uint256[](1);
        values[0] = 0;

        calldatas = new bytes[](1);
        calldatas[0] = callData;

        // Encode mandate calldata
        // OpenAction expects: abi.encode(address[] targets, uint256[] values, bytes[] calldatas)
        mandateCalldata = abi.encode(targets, values, calldatas);

        description = "Minting coins via OpenAction";

        // 3. Execute request (OpenAction allows immediate execution by public)
        // Verify balance before
        balanceBefore = simpleErc1155.balanceOf(alice, 0);

        vm.prank(alice); // Alice can execute as allowedRole is max (public)
        daoMock.request(mandateId, mandateCalldata, nonce, description);

        // 4. Verify result
        balanceAfter = simpleErc1155.balanceOf(alice, 0);
        assertEq(balanceAfter, balanceBefore + mintAmount, "Balance should increase by mint amount");
    }

    function testOpenActionExecuteMultipleExternalActions() public {
        // Execute two actions: Mint coins twice
        mintAmount = 50;
        callData = abi.encodeWithSelector(bytes4(keccak256("mint(uint256,address)")), mintAmount, alice);

        targets = new address[](2);
        targets[0] = address(simpleErc1155);
        targets[1] = address(simpleErc1155);

        values = new uint256[](2);
        values[0] = 0;
        values[1] = 0;

        calldatas = new bytes[](2);
        calldatas[0] = callData;
        calldatas[1] = callData;

        mandateCalldata = abi.encode(targets, values, calldatas);
        nonce = 222;

        balanceBefore = simpleErc1155.balanceOf(alice, 0);

        vm.prank(bob);
        daoMock.request(mandateId, mandateCalldata, nonce, "Double Mint");

        balanceAfter = simpleErc1155.balanceOf(alice, 0);
        assertEq(balanceAfter, balanceBefore + (mintAmount * 2), "Balance should increase by 2x mint amount");
    }

    function testOpenActionRevertsIfCalldataMalformed() public {
        // Send random bytes that cannot be decoded as (address[], uint256[], bytes[])
        mandateCalldata = abi.encode("random string");

        vm.prank(alice);
        vm.expectRevert(); // Should revert during decoding in OpenAction.handleRequest
        daoMock.request(mandateId, mandateCalldata, nonce, "Malformed call");
    }
}

contract BespokeAction_SimpleTest is TestSetupExecutive {
    function setUp() public override {
        super.setUp();
        mandateId = findMandateIdInOrg("BespokeAction_Simple: A mandate to execute a simple function call.", daoMock);
    }

    function testSimpleExecute() public {
        mintAmount = 50;
        // In this mandate, mandateCalldata is appended directly to the selector.
        // mint takes one uint256 parameter.
        mandateCalldata = abi.encode(mintAmount, alice);

        balanceBefore = simpleErc1155.balanceOf(alice, 0);

        vm.prank(alice); // Alice has Role 1, which is allowed
        daoMock.request(mandateId, mandateCalldata, nonce, "Mint 50 coins");

        balanceAfter = simpleErc1155.balanceOf(alice, 0);
        assertEq(balanceAfter, balanceBefore + mintAmount, "Balance should increase by minted amount");
    }

    function testSimpleRevertsUnauthorized() public {
        // Frank does not have Role 1
        mandateCalldata = abi.encode(100);

        vm.prank(frank);
        vm.expectRevert(PowersErrors.Powers__CannotCallMandate.selector);
        daoMock.request(mandateId, mandateCalldata, nonce, "Unauthorized request");
    }
}

contract BespokeAction_AdvancedTest is TestSetupExecutive {
    function setUp() public override {
        super.setUp();
        mandateId = findMandateIdInOrg(
            "BespokeAction_Advanced: A mandate to execute complex function calls with mixed parameters.", daoMock
        );
    }

    function testAdvancedExecute() public {
        // Configured to call assignRole(ROLE_ONE, address account)
        // Static param: ROLE_ONE (1)
        // Dynamic param: address account

        newMember = makeAddr("newMember");

        // Verify initial state
        assertEq(daoMock.hasRoleSince(newMember, ROLE_ONE), 0);

        vm.prank(alice); // Alice has Role 1, which is allowed
        daoMock.request(mandateId, abi.encode(newMember), nonce, "Assign Role");

        // Verify execution result
        assertNotEq(daoMock.hasRoleSince(newMember, ROLE_ONE), 0, "Role should be assigned");
    }

    function testAdvancedRevertsUnauthorized() public {
        vm.prank(frank); // Frank does not have Role 1
        vm.expectRevert(PowersErrors.Powers__CannotCallMandate.selector);
        daoMock.request(mandateId, abi.encode(alice), nonce, "Unauthorized request");
    }
}

contract PresetActions_SingleTest is TestSetupExecutive {
    function setUp() public override {
        super.setUp();
        mandateId = findMandateIdInOrg("PresetActions_Single: A mandate to execute preset actions.", daoMock);
    }

    function testPresetExecute() public {
        // Verify initial state
        assertEq(daoMock.getRoleLabel(ROLE_ONE), "");
        assertEq(daoMock.getRoleLabel(ROLE_TWO), "");

        // PresetActions_Single ignores the content of calldata (except for hashing)
        mandateCalldata = abi.encode(true);

        vm.prank(alice); // Alice has Role 1
        daoMock.request(mandateId, mandateCalldata, nonce, "Execute Preset Action");

        // Verify execution
        assertEq(daoMock.getRoleLabel(ROLE_ONE), "Member");
        assertEq(daoMock.getRoleLabel(ROLE_TWO), "Delegate");

        // Check action state
        actionId = MandateUtilities.computeActionId(mandateId, mandateCalldata, nonce);
        assertEq(uint8(daoMock.getActionState(actionId)), uint8(PowersTypes.ActionState.Fulfilled));
    }

    function testPresetRevertsUnauthorized() public {
        mandateCalldata = abi.encode(true);

        vm.prank(frank); // Frank does not have Role 1
        vm.expectRevert(PowersErrors.Powers__CannotCallMandate.selector);
        daoMock.request(mandateId, mandateCalldata, nonce, "Unauthorized");
    }
}

contract PresetActions_MultipleTest is TestSetupExecutive {
    // Placeholder for PresetActions_Multiple specific tests

    }

contract BespokeAction_OnReturnValueTest is TestSetupExecutive {
    event Consumed(uint256 value);

    function setUp() public override {
        super.setUp();
        mandateId = findMandateIdInOrg(
            "BespokeAction_OnReturnValue: Execute a call using return value of previous mandate call.", daoMock
        );
    }

    function testExecuteWithReturnValue() public {
        // 1. Execute Parent Action (BespokeActionReturner - ID 9)
        uint16 parentMandateId = findMandateIdInOrg("BespokeActionReturner: Returns a value for testing.", daoMock);
        bytes memory emptyCalldata = "";
        uint256 testNonce = 12_345;

        vm.prank(alice);
        daoMock.request(parentMandateId, emptyCalldata, testNonce, "Parent Action");

        // Verify parent action fulfilled
        uint256 parentActionId = MandateUtilities.computeActionId(parentMandateId, emptyCalldata, testNonce);
        assertEq(uint8(daoMock.getActionState(parentActionId)), uint8(PowersTypes.ActionState.Fulfilled));

        // 2. Execute Child Action (BespokeAction_OnReturnValue - ID 10)
        // Must use SAME calldata and nonce as parent

        vm.expectEmit(true, true, true, true);
        emit Consumed(42); // Expect 42 from ReturnDataMock.getValue()

        vm.prank(alice);
        daoMock.request(mandateId, emptyCalldata, testNonce, "Child Action");

        // Verify child action fulfilled
        actionId = MandateUtilities.computeActionId(mandateId, emptyCalldata, testNonce);
        assertEq(uint8(daoMock.getActionState(actionId)), uint8(PowersTypes.ActionState.Fulfilled));
    }
}
