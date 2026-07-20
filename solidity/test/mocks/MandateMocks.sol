// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.26;

import { Mandate } from "@src/Mandate.sol";
import { AsyncMandate } from "@src/AsyncMandate.sol";
import { MandateUtilities } from "@src/libraries/MandateUtilities.sol";

/// @notice Mock mandate contract that returns empty targets for testing
contract EmptyTargetsMandate is Mandate {
    constructor(address registry_) Mandate(registry_) { }

    function handleRequest(address, address, uint16, bytes calldata, uint256)
        public
        pure
        override
        returns (uint256 actionId, address[] memory targets, uint256[] memory values, bytes[] memory calldatas)
    {
        // Return empty arrays
        actionId = 1;
        targets = new address[](0);
        values = new uint256[](0);
        calldatas = new bytes[](0);
    }
}

/// @notice Mock mandate contract that returns specific targets for testing
contract MockTargetsMandate is Mandate {
    constructor(address registry_) Mandate(registry_) { }

    function handleRequest(address, address, uint16, bytes calldata, uint256)
        public
        pure
        override
        returns (uint256 actionId, address[] memory targets, uint256[] memory values, bytes[] memory calldatas)
    {
        // Return specific test data
        actionId = 1;
        targets = new address[](2);
        targets[0] = address(0x1);
        targets[1] = address(0x2);

        values = new uint256[](2);
        values[0] = 1 ether;
        values[1] = 2 ether;

        calldatas = new bytes[](2);
        calldatas[0] = abi.encodeWithSignature("test1()");
        calldatas[1] = abi.encodeWithSignature("test2()");
    }
}

/// @notice Returns mismatched targets/values/calldatas arrays, causing Powers__InvalidCallData in fulfill.
contract MismatchedArraysMandate is Mandate {
    constructor(address registry_) Mandate(registry_) { }

    function handleRequest(address, address, uint16 mandateId, bytes calldata mandateCalldata, uint256 nonce)
        public
        pure
        override
        returns (uint256 actionId, address[] memory targets, uint256[] memory values, bytes[] memory calldatas)
    {
        actionId = MandateUtilities.computeActionId(mandateId, mandateCalldata, nonce);
        targets = new address[](1);
        values = new uint256[](2); // intentional mismatch
        calldatas = new bytes[](1);
    }
}

/// @notice Returns 26 targets (over PowersMock's MAX_EXECUTIONS_LENGTH=25), causing Powers__ExecutionArrayTooLong.
contract TooManyTargetsMandate is Mandate {
    uint256 constant TOO_MANY = 26;

    constructor(address registry_) Mandate(registry_) { }

    function handleRequest(address, address, uint16 mandateId, bytes calldata mandateCalldata, uint256 nonce)
        public
        pure
        override
        returns (uint256 actionId, address[] memory targets, uint256[] memory values, bytes[] memory calldatas)
    {
        actionId = MandateUtilities.computeActionId(mandateId, mandateCalldata, nonce);
        targets = new address[](TOO_MANY);
        values = new uint256[](TOO_MANY);
        calldatas = new bytes[](TOO_MANY);
    }
}

/// @notice Minimal concrete AsyncMandate for unit testing.
/// Captures oracle call data and exposes _replyPowers for direct testing.
contract AsyncMandateMock is AsyncMandate {
    constructor(address registry_) AsyncMandate(registry_) { }

    address public pendingPowers;
    uint16 public pendingMandateId;
    uint256 public pendingActionId;
    bool public oracleCalled;

    function handleRequest(address, address, uint16 mandateId, bytes calldata mandateCalldata, uint256 nonce)
        public
        view
        override
        returns (uint256 actionId, address[] memory targets, uint256[] memory values, bytes[] memory calldatas)
    {
        actionId = MandateUtilities.computeActionId(mandateId, mandateCalldata, nonce);
        targets = new address[](0);
        values = new uint256[](0);
        calldatas = new bytes[](0);
    }

    function _callOracle(uint16 mandateId, uint256 actionId, address[] memory, uint256[] memory, bytes[] memory)
        internal
        override
    {
        pendingPowers = msg.sender;
        pendingMandateId = mandateId;
        pendingActionId = actionId;
        oracleCalled = true;
    }

    /// @notice Simulates an oracle responding and calling back to fulfill the action.
    function simulateOracleCallback() external {
        address[] memory targets = new address[](0);
        uint256[] memory values = new uint256[](0);
        bytes[] memory calldatas = new bytes[](0);
        _replyPowers(pendingPowers, pendingMandateId, pendingActionId, targets, values, calldatas);
    }

    /// @notice Exposes _replyPowers for targeted unit testing.
    function callReplyPowers(
        address powers,
        uint16 mandateId_,
        uint256 actionId_,
        address[] calldata targets,
        uint256[] calldata values,
        bytes[] calldata calldatas
    ) external {
        _replyPowers(powers, mandateId_, actionId_, targets, values, calldatas);
    }
}

/// @notice Reverts with or without data, used to test fulfill failure handling.
contract AlwaysRevertMock {
    error AlwaysRevertMock__Reverted();

    function revertWithData() external pure {
        revert AlwaysRevertMock__Reverted();
    }

    function revertNoData() external pure {
        assembly {
            revert(0, 0)
        }
    }
}
