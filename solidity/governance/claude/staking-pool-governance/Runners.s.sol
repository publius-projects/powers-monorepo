// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

// ─────────────────────────────────────────────────────────────────────────────
//  Staking Pool Governance - stateless flow runners
//
//  Each run*() reads current on-chain state, advances the flow as far as
//  conditions allow, then stops at the first phase still blocked by a voting
//  window or timelock - logging what it did and what it is waiting for.
//
//  Pass the SAME (params, nonce) on every call for one flow invocation; use a
//  fresh nonce to start a new, independent invocation.
// ─────────────────────────────────────────────────────────────────────────────

import { console2 } from "forge-std/console2.sol";
import { Powers } from "@src/Powers.sol";
import { IPowers } from "@src/interfaces/IPowers.sol";
import { PowersTypes } from "@src/interfaces/PowersTypes.sol";
import { StakingPoolGovernanceActions } from "./Actions.s.sol";

contract StakingPoolGovernanceRunners is StakingPoolGovernanceActions {
    ///////////////////////////////////////////////////////////////////////////
    //                           INITIAL SETUP
    ///////////////////////////////////////////////////////////////////////////

    /// @notice Execute the one-time setup mandate (labels roles, wires paymaster, self-revokes).
    function runInitialSetup(address powers, uint256[] memory privateKeys, uint256 nonce) public {
        if (_isSetupComplete(powers)) {
            console2.log("Runner: initial setup already complete.");
            return;
        }
        uint16 setupId = findMandateIdInOrg("Initial Setup: Assign role labels and revokes itself after execution", Powers(payable(powers)));
        vm.startBroadcast(privateKeys[0]);
        IPowers(powers).request(setupId, abi.encode(), nonce, "Executing initial setup");
        vm.stopBroadcast();
        console2.log("Runner: initial setup complete.");
    }

    ///////////////////////////////////////////////////////////////////////////
    //                          SET REWARD RATE FLOW
    ///////////////////////////////////////////////////////////////////////////
    //   [0] Committee proposes + votes (1-week vote)
    //   ⏳ vote closes; propose fulfilled + execution opened
    //   ⏳ 48h execution timelock (Stakers may veto within this window)
    //   [1] Execute the rate change on the pool
    function runRewardRateFlow(
        address powers,
        uint256 newRate,
        uint256[] memory committeeKeys,
        uint256 nonce
    ) public {
        uint16 proposeId = findMandateIdInOrg("Propose Reward Rate: The Rate Committee votes to propose a new per-token per-second reward rate.", Powers(payable(powers)));
        uint16 executeId = findMandateIdInOrg("Execute Reward Rate: Set the approved reward rate on the staking pool after the veto window and timelock.", Powers(payable(powers)));

        bytes memory calldata_ = abi.encode(newRate);

        // Done?
        (,,, uint48 execFulfilledAt,,,) = IPowers(powers).getActionData(calculateActionId(executeId, calldata_, nonce));
        if (execFulfilledAt > 0) { console2.log("Runner: reward-rate flow already complete."); return; }

        // [0] proposal
        (, uint48 proposeProposedAt,,,,,) = IPowers(powers).getActionData(calculateActionId(proposeId, calldata_, nonce));
        if (proposeProposedAt == 0) {
            console2.log("Runner [0]: Committee proposing reward rate.");
            proposeRewardRate(powers, newRate, committeeKeys, nonce);
            console2.log("Runner: pausing - 1-week Committee vote now open.");
            return;
        }

        // proposal vote still open?
        (,, uint256 proposeVoteEnd,,,,) = IPowers(powers).getActionVoteData(calculateActionId(proposeId, calldata_, nonce));
        if (block.number <= proposeVoteEnd) {
            console2.log("Runner: pausing - Committee vote still open. Blocks remaining:", proposeVoteEnd - block.number);
            return;
        }

        // proposal fulfilled + execution opened?
        (, uint48 execProposedAt,, uint48 proposeFulfilledAt,,,) = _proposeAndExecState(powers, proposeId, executeId, calldata_, nonce);
        if (proposeFulfilledAt == 0) {
            console2.log("Runner: fulfilling proposal and opening execution (starts 48h timelock).");
            fulfillRewardRateProposal(powers, newRate, committeeKeys, nonce);
            openRewardRateExecution(powers, newRate, committeeKeys, nonce);
            console2.log("Runner: pausing - 48h execution timelock. Stakers may veto within this window.");
            return;
        }
        if (execProposedAt == 0) {
            console2.log("Runner: opening execution proposal (starts 48h timelock).");
            openRewardRateExecution(powers, newRate, committeeKeys, nonce);
            return;
        }

        // timelock past?
        if (!_isTimelockPast(powers, executeId, execProposedAt)) {
            console2.log("Runner: pausing - execution timelock still active.");
            _logTimelockRemaining(powers, executeId, execProposedAt);
            return;
        }

        console2.log("Runner [1]: executing reward-rate change.");
        executeRewardRate(powers, newRate, committeeKeys, nonce);
        console2.log("Runner: reward-rate flow complete.");
    }

    ///////////////////////////////////////////////////////////////////////////
    //                       EMERGENCY PAUSE (GUARDIAN)
    ///////////////////////////////////////////////////////////////////////////

    /// @notice Guardian instantly pauses the pool (single instantaneous step).
    function runGuardianPause(address powers, uint256[] memory guardianKeys, uint256 nonce) public {
        uint16 id = findMandateIdInOrg("Guardian Pause: The Guardian instantly halts new staking (emergency circuit-breaker).", Powers(payable(powers)));
        (,,, uint48 fulfilledAt,,,) = IPowers(powers).getActionData(calculateActionId(id, abi.encode(), nonce));
        if (fulfilledAt > 0) { console2.log("Runner: guardian pause already executed for this nonce."); return; }
        console2.log("Runner: Guardian pausing pool.");
        guardianPause(powers, guardianKeys, nonce);
    }

    ///////////////////////////////////////////////////////////////////////////
    //                        COMPLIANCE MONITORING
    ///////////////////////////////////////////////////////////////////////////

    /// @notice Compliance Monitor records a finding (single signal-only step).
    function runComplianceFlag(address powers, string memory finding, address subject, uint256[] memory monitorKeys, uint256 nonce) public {
        uint16 id = findMandateIdInOrg("Raise Compliance Flag: The Compliance Monitor records a compliance finding on-chain. Signal-only; no execution.", Powers(payable(powers)));
        (,,, uint48 fulfilledAt,,,) = IPowers(powers).getActionData(calculateActionId(id, abi.encode(finding, subject), nonce));
        if (fulfilledAt > 0) { console2.log("Runner: compliance flag already recorded for this nonce."); return; }
        raiseComplianceFlag(powers, finding, subject, monitorKeys, nonce);
    }

    ///////////////////////////////////////////////////////////////////////////
    //                          SWEEP FLOW
    ///////////////////////////////////////////////////////////////////////////
    //   [0] Committee proposes + votes (1-week vote)
    //   ⏳ vote closes; propose fulfilled + execution opened
    //   ⏳ 7-day execution timelock (Stakers may veto)
    //   [1] Execute the sweep
    function runSweepFlow(
        address powers,
        address token,
        address to,
        uint256 amount,
        uint256[] memory committeeKeys,
        uint256 nonce
    ) public {
        uint16 proposeId = findMandateIdInOrg("Propose Sweep: The Rate Committee votes to propose sweeping stray tokens out of the staking pool.", Powers(payable(powers)));
        uint16 executeId = findMandateIdInOrg("Execute Sweep: Sweep the approved tokens out of the staking pool after the veto window and long timelock.", Powers(payable(powers)));

        bytes memory calldata_ = abi.encode(token, to, amount);

        (,,, uint48 execFulfilledAt,,,) = IPowers(powers).getActionData(calculateActionId(executeId, calldata_, nonce));
        if (execFulfilledAt > 0) { console2.log("Runner: sweep flow already complete."); return; }

        (, uint48 proposeProposedAt,,,,,) = IPowers(powers).getActionData(calculateActionId(proposeId, calldata_, nonce));
        if (proposeProposedAt == 0) {
            console2.log("Runner [0]: Committee proposing sweep.");
            proposeSweep(powers, token, to, amount, committeeKeys, nonce);
            console2.log("Runner: pausing - 1-week Committee vote now open.");
            return;
        }

        (,, uint256 proposeVoteEnd,,,,) = IPowers(powers).getActionVoteData(calculateActionId(proposeId, calldata_, nonce));
        if (block.number <= proposeVoteEnd) {
            console2.log("Runner: pausing - Committee vote still open. Blocks remaining:", proposeVoteEnd - block.number);
            return;
        }

        (, uint48 execProposedAt,, uint48 proposeFulfilledAt,,,) = _proposeAndExecState(powers, proposeId, executeId, calldata_, nonce);
        if (proposeFulfilledAt == 0) {
            console2.log("Runner: fulfilling proposal and opening execution (starts 7-day timelock).");
            fulfillSweepProposal(powers, token, to, amount, committeeKeys, nonce);
            openSweepExecution(powers, token, to, amount, committeeKeys, nonce);
            console2.log("Runner: pausing - 7-day execution timelock. Stakers may veto within this window.");
            return;
        }
        if (execProposedAt == 0) {
            openSweepExecution(powers, token, to, amount, committeeKeys, nonce);
            return;
        }

        if (!_isTimelockPast(powers, executeId, execProposedAt)) {
            console2.log("Runner: pausing - 7-day execution timelock still active.");
            _logTimelockRemaining(powers, executeId, execProposedAt);
            return;
        }

        console2.log("Runner [1]: executing sweep.");
        executeSweep(powers, token, to, amount, committeeKeys, nonce);
        console2.log("Runner: sweep flow complete.");
    }

    ///////////////////////////////////////////////////////////////////////////
    //                        SHARED STATE PREDICATES
    ///////////////////////////////////////////////////////////////////////////

    function _isSetupComplete(address powers) internal view returns (bool) {
        return bytes(Powers(payable(powers)).getRoleLabel(1)).length > 0;
    }

    /// @dev Returns the execute action's proposedAt/fulfilledAt and the propose action's fulfilledAt.
    function _proposeAndExecState(address powers, uint16 proposeId, uint16 executeId, bytes memory calldata_, uint256 nonce)
        internal
        view
        returns (uint16, uint48 execProposedAt, uint48 execRequestedAt, uint48 proposeFulfilledAt, uint48, address, uint256)
    {
        (,,, proposeFulfilledAt,,,) = IPowers(powers).getActionData(calculateActionId(proposeId, calldata_, nonce));
        (, execProposedAt, execRequestedAt,,,,) = IPowers(powers).getActionData(calculateActionId(executeId, calldata_, nonce));
        return (0, execProposedAt, execRequestedAt, proposeFulfilledAt, 0, address(0), 0);
    }

    function _isTimelockPast(address powers, uint16 mandateId, uint48 proposedAt) internal view returns (bool) {
        if (proposedAt == 0) return false;
        PowersTypes.Conditions memory cond = IPowers(powers).getConditions(mandateId);
        return block.number >= uint256(proposedAt) + uint256(cond.timelock);
    }

    function _logTimelockRemaining(address powers, uint16 mandateId, uint48 proposedAt) internal view {
        if (proposedAt == 0) return;
        PowersTypes.Conditions memory cond = IPowers(powers).getConditions(mandateId);
        uint256 deadline = uint256(proposedAt) + uint256(cond.timelock);
        if (block.number < deadline) {
            console2.log("Runner: blocks remaining until timelock expires:", deadline - block.number);
        }
    }
}
