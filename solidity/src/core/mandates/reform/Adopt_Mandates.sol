// SPDX-License-Identifier: MIT

/// @notice Adopt a set of fully configured mandates through governance.
/// @dev Builds calls to `IPowers.adoptMandate` for each mandate supplied at runtime. The caller
///      provides complete `MandateInitData` structs, which are passed through unmodified: name,
///      target, config and conditions are all preserved. This mandate is a transport, not a
///      policy — what may be adopted is constrained by the conditions on the reform flow that
///      gates this mandate, not by degrading the payload. No self-destruction occurs.
///
///      v0.2.0 — previously the calldata was `(address[] mandates, uint256[] roleIds)` and every
///      adoption was forced to an empty config, zeroed conditions and the name "Reform mandate",
///      which made it impossible to adopt any mandate needing configuration or a vote. v0.1.9
///      remains registered for organisations already wired to the old shape; see
///      `governance/REFORM_MANDATES.md`.
///
/// @author 7Cedars,

pragma solidity ^0.8.26;

import { Mandate } from "@src/Mandate.sol";
import { MandateUtilities } from "@src/libraries/MandateUtilities.sol";
import { IPowers } from "@src/interfaces/IPowers.sol";
import { PowersTypes } from "@src/interfaces/PowersTypes.sol";

contract Adopt_Mandates is Mandate {
    /// @notice Thrown when the caller supplies an empty mandate array — an adoption that would
    ///         execute no calls at all.
    error Adopt_Mandates__NoMandates();

    constructor(address registry_) Mandate(registry_) {
        emit Mandate__Deployed("");
    }

    function initializeMandate(uint16 index, string memory nameDescription, bytes memory, bytes memory config)
        public
        override
    {
        string[] memory params = new string[](1);
        // Full MandateInitData[]: (nameDescription, targetMandate, config, conditions), where
        // conditions is (allowedRole, votingPeriod, timelock, throttleExecution, needFulfilled,
        // needNotFulfilled, quorum, succeedAt, maxExecutionDelay).
        params[0] =
        "(string,address,bytes,(uint256,uint32,uint32,uint32,uint16,uint16,uint8,uint8,uint32))[] mandateInitData";
        super.initializeMandate(index, nameDescription, abi.encode(params), config);
    }

    /// @notice Build calls to adopt the mandates supplied at runtime
    /// @param mandateCalldata abi-encoded `PowersTypes.MandateInitData[]`
    /// @dev Each struct is forwarded to `IPowers.adoptMandate` exactly as given. Mandates are
    ///      adopted in array order, so an entry chaining to an earlier one via `needFulfilled`
    ///      must reference the id that entry will receive — `mandateCounter` at execution time,
    ///      plus its index. That prediction is only valid if no other adoption lands between
    ///      proposal and execution; callers should re-check `mandateCounter` before executing.
    function handleRequest(
        address,
        /*caller*/
        address powers,
        uint16 mandateId,
        bytes calldata mandateCalldata,
        uint256 nonce
    )
        public
        pure
        override
        returns (uint256 actionId, address[] memory targets, uint256[] memory values, bytes[] memory calldatas)
    {
        actionId = MandateUtilities.computeActionId(mandateId, mandateCalldata, nonce);

        PowersTypes.MandateInitData[] memory mandateInitData =
            abi.decode(mandateCalldata, (PowersTypes.MandateInitData[]));

        uint256 length = mandateInitData.length;
        if (length == 0) revert Adopt_Mandates__NoMandates();

        // Powers.fulfill enforces MAX_EXECUTIONS_LENGTH (a per-instance immutable) and reverts
        // with Powers__ExecutionArrayTooLong, so no length cap is duplicated here.
        (targets, values, calldatas) = MandateUtilities.createEmptyArrays(length);

        for (uint256 i; i < length; i++) {
            targets[i] = powers;
            calldatas[i] = abi.encodeWithSelector(IPowers.adoptMandate.selector, mandateInitData[i]);
        }
        return (actionId, targets, values, calldatas);
    }

    /// @notice v0.2.0 — runtime calldata takes full MandateInitData structs.
    /// @dev Bumped from the inherited (0, 1, 9) so this registers alongside the previous version
    ///      rather than replacing it; DeployMandates reads the version off the deployed contract.
    function version() public pure override returns (uint16 major, uint16 minor, uint16 patch) {
        return (0, 2, 0);
    }
}
