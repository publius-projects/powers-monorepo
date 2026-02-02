// SPDX-License-Identifier: MIT

/// @title ChecksTest - Unit tests for Checks library
/// @notice Tests the Checks library functions
/// @dev Provides comprehensive coverage of all Checks functions
/// @author 7Cedars

pragma solidity 0.8.26;

import { Checks } from "../../src/libraries/Checks.sol";
import { PowersTypes } from "../../src/interfaces/PowersTypes.sol";
import { TestSetupPowers } from "../TestSetup.t.sol";

contract ChecksTest is TestSetupPowers {
    //////////////////////////////////////////////////////////////
    //                  REQUEST CHECKS                          //
    //////////////////////////////////////////////////////////////
    function testcheckWithNoRequirements() public {
        // Setup: Create conditions with no requirements
        mandateCalldata = abi.encode(true);
        uint48 latestExecution;

        // Should not revert when no requirements
        Checks.check(mandateId, mandateCalldata, address(daoMock), nonce, latestExecution);
    }

    //////////////////////////////////////////////////////////////
    //                  HELPER FUNCTIONS                        //
    //////////////////////////////////////////////////////////////
    function testHashActionId() public {
        mandateId = 1;
        mandateCalldata = abi.encode(true);
        nonce = 123;

        actionId = Checks.computeActionId(mandateId, mandateCalldata, nonce);
        assertEq(actionId, uint256(keccak256(abi.encode(mandateId, mandateCalldata, nonce))));
    }

    function testGetConditions() public view {
        // Test getting conditions for an existing mandate
        PowersTypes.Conditions memory conditionsResult = Checks.getConditions(address(daoMock), 1);

        // Verify we get valid conditions back
        assertTrue(conditionsResult.allowedRole != 0 || conditionsResult.allowedRole == type(uint256).max);
    }

    function testcheckWithZeroThrottle() public {
        // Setup: Use mandateId 6 from powersTestConstitution which has no throttle (throttleExecution = 0)
        // it does have a parentMandate needFulfilled, so we need to complete it.
        mandateId = 3;
        address[] memory tar = new address[](1);
        uint256[] memory val = new uint256[](1);
        bytes[] memory cal = new bytes[](1);
        tar[0] = address(daoMock);
        val[0] = 0;
        cal[0] = abi.encodeWithSelector(daoMock.labelRole.selector, ROLE_ONE, "TestMember");
        mandateCalldata = abi.encode(tar, val, cal);
        uint48 latestExecution = uint48(block.number - 1); // Very recent execution

        // First, we need to vote on mandate 4
        vm.prank(bob);
        uint256 proposalActionId = daoMock.propose(3, mandateCalldata, nonce, "Test proposal");
        (mandateAddress, mandateHash, active) = daoMock.getAdoptedMandate(mandateId);
        conditions = daoMock.getConditions(mandateId);
        for (i = 0; i < users.length; i++) {
            if (daoMock.hasRoleSince(users[i], conditions.allowedRole) != 0) {
                vm.prank(users[i]);
                daoMock.castVote(proposalActionId, FOR);
            }
        }
        vm.roll(block.number + conditions.votingPeriod + conditions.timelock + 1);
        vm.prank(alice);
        daoMock.request(mandateId, mandateCalldata, nonce, "Test proposal");

        // now we execute mandate 6
        // Should not revert when throttle is zero
        vm.prank(charlotte);
        Checks.check(5, mandateCalldata, address(daoMock), nonce, latestExecution);
    }

    function testGetConditionsForNonExistentMandate() public view {
        // Test getting conditions for a non-existent mandate
        PowersTypes.Conditions memory conditionsResult = Checks.getConditions(address(daoMock), 999);

        // Should return default/empty conditions
        assertEq(conditionsResult.allowedRole, 0);
        assertEq(conditionsResult.quorum, 0);
        assertEq(conditionsResult.succeedAt, 0);
        assertEq(conditionsResult.votingPeriod, 0);
        assertEq(conditionsResult.needFulfilled, 0);
        assertEq(conditionsResult.needNotFulfilled, 0);
        assertEq(conditionsResult.timelock, 0);
        assertEq(conditionsResult.throttleExecution, 0);
    }

    //////////////////////////////////////////////////////////////
    //                  DELAY EXECUTION CHECKS                   //
    //////////////////////////////////////////////////////////////
    function testcheckWithDelayExecution() public {
        // Setup: Use mandateId 4 from powersTestConstitution which now has timelock = 250
        mandateId = 3;
        address[] memory tar = new address[](1);
        uint256[] memory val = new uint256[](1);
        bytes[] memory cal = new bytes[](1);
        tar[0] = address(daoMock);
        val[0] = 0;
        cal[0] = abi.encodeWithSelector(daoMock.labelRole.selector, ROLE_ONE, "TestMember");
        mandateCalldata = abi.encode(tar, val, cal);

        // First, we need to vote on mandate 3
        vm.prank(bob);
        uint256 proposalActionId = daoMock.propose(3, mandateCalldata, nonce, "Test proposal");
        (mandateAddress, mandateHash, active) = daoMock.getAdoptedMandate(3);
        conditions = daoMock.getConditions(3);
        for (i = 0; i < users.length; i++) {
            if (daoMock.hasRoleSince(users[i], conditions.allowedRole) != 0) {
                vm.prank(users[i]);
                daoMock.castVote(proposalActionId, FOR);
            }
        }

        // Advance time past voting period and execute mandate 3
        vm.roll(block.number + conditions.votingPeriod + 1);

        // First execution should not succeed (there is also a delay for the first execution)
        vm.prank(alice);
        vm.expectRevert(Checks.Checks__DeadlineNotPassed.selector);
        daoMock.request(mandateId, mandateCalldata, nonce, "First execution");
    }

    function testcheckWithDelayExecutionPassed() public {
        // Setup: Use mandateId 4 from powersTestConstitution which now has timelock = 250
        mandateId = 3;
        address[] memory tar = new address[](1);
        uint256[] memory val = new uint256[](1);
        bytes[] memory cal = new bytes[](1);
        tar[0] = address(daoMock);
        val[0] = 0;
        cal[0] = abi.encodeWithSelector(daoMock.labelRole.selector, ROLE_ONE, "TestMember");
        mandateCalldata = abi.encode(tar, val, cal);

        // First, we need to vote on mandate 3
        vm.prank(bob);
        uint256 proposalActionId = daoMock.propose(3, mandateCalldata, nonce, "Test proposal");
        (mandateAddress, mandateHash, active) = daoMock.getAdoptedMandate(3);
        conditions = daoMock.getConditions(3);
        for (i = 0; i < users.length; i++) {
            if (daoMock.hasRoleSince(users[i], conditions.allowedRole) != 0) {
                vm.prank(users[i]);
                daoMock.castVote(proposalActionId, FOR);
            }
        }

        // Advance blocks past the delay period (250 blocks)
        vm.roll(block.number + conditions.votingPeriod + conditions.timelock + 1);

        // Second execution should succeed now that delay has passed
        vm.prank(alice);
        uint256 secondActionId = daoMock.request(mandateId, mandateCalldata, nonce, "Second execution after delay");
        assertTrue(daoMock.getActionState(secondActionId) == ActionState.Fulfilled);
    }

    function testcheckWithZeroDelayExecution() public {
        // Setup: Use mandateId 1 from powersTestConstitution which has no delay (timelock = 0)
        mandateId = 1;
        bytes[] memory encodedParams = new bytes[](1);
        encodedParams[0] = abi.encode();
        mandateCalldata = abi.encode(encodedParams); // Mandate 1 expects a bytes[] with an address parameter

        // First execution should succeed
        vm.prank(charlotte);
        uint256 firstActionId = daoMock.request(mandateId, mandateCalldata, nonce, "First execution");
        assertTrue(daoMock.getActionState(firstActionId) == ActionState.Fulfilled);

        // Second execution should also succeed immediately (no delay)
        vm.prank(david);
        uint256 secondActionId = daoMock.request(mandateId, mandateCalldata, nonce + 1, "Second execution immediately");
        assertTrue(daoMock.getActionState(secondActionId) == ActionState.Fulfilled);
    }

    //////////////////////////////////////////////////////////////
    //                  THROTTLE EXECUTION CHECKS                //
    //////////////////////////////////////////////////////////////
    function testcheckWithThrottleExecutionGapTooSmall() public {
        // Setup: Use mandateId 5 from mandateTestConstitution which has throttleExecution = 5000
        mandateId = 3;
        address[] memory tar = new address[](1);
        uint256[] memory val = new uint256[](1);
        bytes[] memory cal = new bytes[](1);
        tar[0] = address(daoMock);
        val[0] = 0;
        cal[0] = abi.encodeWithSelector(daoMock.labelRole.selector, ROLE_ONE, "TestMember");
        mandateCalldata = abi.encode(tar, val, cal);

        // we first propose, vote and execute mandate 4.
        vm.prank(bob);
        uint256 proposalActionId = daoMock.propose(mandateId, mandateCalldata, nonce, "Test proposal");
        (mandateAddress, mandateHash, active) = daoMock.getAdoptedMandate(mandateId);
        conditions = daoMock.getConditions(mandateId);
        for (i = 0; i < users.length; i++) {
            if (daoMock.hasRoleSince(users[i], conditions.allowedRole) != 0) {
                vm.prank(users[i]);
                daoMock.castVote(proposalActionId, FOR);
            }
        }
        vm.roll(block.number + conditions.votingPeriod + conditions.timelock + 10_000);

        // Create latestExecution array with recent execution (gap too small)
        uint48 latestExecution = uint48(block.number - 1000);

        // Should revert when execution gap is too small
        vm.expectRevert(Checks.Checks__ExecutionGapTooSmall.selector);
        Checks.check(mandateId, mandateCalldata, address(daoMock), nonce, latestExecution);
    }

    function testcheckWithThrottleExecutionGapSufficient() public {
        // Setup: Use mandateId 5 from mandateTestConstitution which has throttleExecution = 5000
        mandateId = 3;
        address[] memory tar = new address[](1);
        uint256[] memory val = new uint256[](1);
        bytes[] memory cal = new bytes[](1);
        tar[0] = address(daoMock);
        val[0] = 0;
        cal[0] = abi.encodeWithSelector(daoMock.labelRole.selector, ROLE_ONE, "TestMember");
        mandateCalldata = abi.encode(tar, val, cal);

        // we first propose, vote and execute mandate 3.
        vm.prank(bob);
        uint256 proposalActionId = daoMock.propose(mandateId, mandateCalldata, nonce, "Test proposal");
        (mandateAddress, mandateHash, active) = daoMock.getAdoptedMandate(mandateId);
        conditions = daoMock.getConditions(mandateId);
        for (i = 0; i < users.length; i++) {
            if (daoMock.hasRoleSince(users[i], conditions.allowedRole) != 0) {
                vm.prank(users[i]);
                daoMock.castVote(proposalActionId, FOR);
            }
        }
        vm.roll(block.number + conditions.votingPeriod + conditions.timelock + 10_000);

        // Create latestExecution array with sufficient gap
        uint48 latestExecution = uint48(block.number - 6000);

        // Should not revert when execution gap is sufficient
        Checks.check(mandateId, mandateCalldata, address(daoMock), nonce, latestExecution);
    }

    function testcheckWithThrottleExecutionExactlyAtThreshold() public {
        // Setup: Use mandateId 5 from mandateTestConstitution which has throttleExecution = 5000
        mandateId = 3;
        address[] memory tar = new address[](1);
        uint256[] memory val = new uint256[](1);
        bytes[] memory cal = new bytes[](1);
        tar[0] = address(daoMock);
        val[0] = 0;
        cal[0] = abi.encodeWithSelector(daoMock.labelRole.selector, ROLE_ONE, "TestMember");
        mandateCalldata = abi.encode(tar, val, cal);

        // we first propose, vote and execute mandate 4.
        vm.prank(bob);
        uint256 proposalActionId = daoMock.propose(mandateId, mandateCalldata, nonce, "Test proposal");
        (mandateAddress, mandateHash, active) = daoMock.getAdoptedMandate(mandateId);
        conditions = daoMock.getConditions(mandateId);
        for (i = 0; i < users.length; i++) {
            if (daoMock.hasRoleSince(users[i], conditions.allowedRole) != 0) {
                vm.prank(users[i]);
                daoMock.castVote(proposalActionId, FOR);
            }
        }
        vm.roll(block.number + conditions.votingPeriod + conditions.timelock + 10_000);

        // Create latestExecution array with exactly the throttle threshold
        uint48 latestExecution = uint48(block.number - 5000);

        // Should not revert when execution gap equals throttle threshold
        Checks.check(mandateId, mandateCalldata, address(daoMock), nonce, latestExecution);
    }
}
