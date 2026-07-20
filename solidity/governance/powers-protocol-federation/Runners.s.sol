// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import { console2 } from "forge-std/console2.sol";
import { Powers } from "@src/Powers.sol";
import { IPowers } from "@src/interfaces/IPowers.sol";
import { PowersTypes } from "@src/interfaces/PowersTypes.sol";
import { PowersProtocolFederationActions } from "./Actions.s.sol";

/// @title PowersProtocolFederationRunners
/// @notice Stateless checkpoint runners for the three interlocking organisations.
///         Each run*() reads current on-chain state, advances as far as conditions
///         allow, then stops at the first phase still blocked by a voting window or
///         timelock - logging what it did and what it is waiting for.
///
/// Pass the SAME (nonce, parameters) on every call for a given flow invocation.
contract PowersProtocolFederationRunners is PowersProtocolFederationActions {
    // ── INITIAL SETUP (call once per organisation immediately after deploy) ────
    function runInitialSetup(address powers, uint256[] memory keys, uint256 nonce) public {
        if (bytes(Powers(payable(powers)).getRoleLabel(1)).length > 0) {
            console2.log("Runner: initial setup already complete for", powers);
            return;
        }
        uint16 setupId = findMandateIdInOrg("Initial Setup: Assign role labels and revokes itself after execution", Powers(payable(powers)));
        vm.startBroadcast(keys[0]);
        IPowers(powers).request(setupId, abi.encode(), nonce, "Executing initial setup");
        vm.stopBroadcast();
        console2.log("Runner: initial setup complete for", powers);
    }

    // ── CORE C1 - Pay Core-Development Invoice ─────────────────────────────────
    function runCoreInvoice(address core, address recipient, uint256 amount, uint256[] memory memberKeys, uint256 nonce) public {
        uint16 proposeId = findMandateIdInOrg("Propose Core Invoice: Members propose paying a core-development invoice (USDC).", Powers(payable(core)));
        uint16 executeId = findMandateIdInOrg("Execute Core Invoice: Pay the approved core-development invoice in USDC.", Powers(payable(core)));
        bytes memory cd = abi.encode(recipient, amount);

        (, , , uint48 executedAt,,,) = IPowers(core).getActionData(calculateActionId(executeId, cd, nonce));
        if (executedAt > 0) { console2.log("Runner: core invoice already paid."); return; }

        (, uint48 proposedAt,,,,,) = IPowers(core).getActionData(calculateActionId(proposeId, cd, nonce));
        if (proposedAt == 0) {
            console2.log("Runner [0]: proposing core invoice.");
            proposeCoreInvoice(core, recipient, amount, memberKeys, nonce);
            console2.log("Runner: pausing - voting window open.");
            return;
        }

        (, , uint256 voteEnd,,,,) = IPowers(core).getActionVoteData(calculateActionId(proposeId, cd, nonce));
        if (block.number <= voteEnd) { console2.log("Runner: pausing - vote still open."); return; }
        if (!_timelockPast(core, executeId, proposedAt)) { console2.log("Runner: pausing - execution timelock active."); return; }

        console2.log("Runner [1]: executing core invoice payment.");
        executeCoreInvoice(core, recipient, amount, memberKeys, nonce);
        console2.log("Runner: core invoice complete.");
    }

    // ── ENDOWMENT E1 - Invest: Supply to Aave (happy path, no veto) ────────────
    function runEndowmentInvest(address endowment, address asset, uint256 amount, uint256[] memory investorKeys, uint256 nonce) public {
        uint16 proposeId = findMandateIdInOrg("Propose Aave Investment: Investors propose supplying an asset to the Aave v3 pool.", Powers(payable(endowment)));
        uint16 executeId = findMandateIdInOrg("Execute Aave Investment: Supply the approved asset to the Aave v3 pool if not vetoed.", Powers(payable(endowment)));
        bytes memory cd = abi.encode(asset, amount);

        (, , , uint48 executedAt,,,) = IPowers(endowment).getActionData(calculateActionId(executeId, cd, nonce));
        if (executedAt > 0) { console2.log("Runner: investment already executed."); return; }

        (, uint48 proposedAt,,,,,) = IPowers(endowment).getActionData(calculateActionId(proposeId, cd, nonce));
        if (proposedAt == 0) {
            console2.log("Runner [0]: proposing Aave investment.");
            proposeInvest(endowment, asset, amount, investorKeys, nonce);
            console2.log("Runner: pausing - vote + Core veto window open.");
            return;
        }

        (, , uint256 voteEnd,,,,) = IPowers(endowment).getActionVoteData(calculateActionId(proposeId, cd, nonce));
        if (block.number <= voteEnd) { console2.log("Runner: pausing - investor vote still open."); return; }
        if (!_timelockPast(endowment, executeId, proposedAt)) { console2.log("Runner: pausing - 15-min investment timelock (Core veto window)."); return; }

        console2.log("Runner [1]: executing Aave supply.");
        executeInvest(endowment, asset, amount, investorKeys, nonce);
        console2.log("Runner: investment complete.");
    }

    // ── ENDOWMENT E2 - Divest: Withdraw from Aave ──────────────────────────────
    function runEndowmentDivest(address endowment, address asset, uint256 amount, uint256[] memory investorKeys, uint256 nonce) public {
        uint16 proposeId = findMandateIdInOrg("Propose Aave Divestment: Investors propose withdrawing an asset from the Aave v3 pool.", Powers(payable(endowment)));
        uint16 executeId = findMandateIdInOrg("Execute Aave Divestment: Withdraw the approved asset from the Aave v3 pool to the treasury.", Powers(payable(endowment)));
        bytes memory cd = abi.encode(asset, amount);

        (, , , uint48 executedAt,,,) = IPowers(endowment).getActionData(calculateActionId(executeId, cd, nonce));
        if (executedAt > 0) { console2.log("Runner: divestment already executed."); return; }

        (, uint48 proposedAt,,,,,) = IPowers(endowment).getActionData(calculateActionId(proposeId, cd, nonce));
        if (proposedAt == 0) {
            console2.log("Runner [0]: proposing Aave divestment.");
            proposeDivest(endowment, asset, amount, investorKeys, nonce);
            console2.log("Runner: pausing - investor vote open.");
            return;
        }

        (, , uint256 voteEnd,,,,) = IPowers(endowment).getActionVoteData(calculateActionId(proposeId, cd, nonce));
        if (block.number <= voteEnd) { console2.log("Runner: pausing - investor vote still open."); return; }
        if (!_timelockPast(endowment, executeId, proposedAt)) { console2.log("Runner: pausing - divestment timelock active."); return; }

        console2.log("Runner [1]: executing Aave withdraw.");
        executeDivest(endowment, asset, amount, investorKeys, nonce);
        console2.log("Runner: divestment complete.");
    }

    // ── MANDATES M3 - Add a Mandate to the Registry (happy path, no veto) ──────
    function runRegistryAddition(address mandates, string memory name, address mandateAddr, bytes32 codeHash, uint256[] memory assessorKeys, uint256 nonce) public {
        uint16 proposeId = findMandateIdInOrg("Propose Registry Addition: Assessors propose listing a mandate in the registry.", Powers(payable(mandates)));
        uint16 executeId = findMandateIdInOrg("Execute Registry Addition: Register the approved, un-vetoed mandate in the registry.", Powers(payable(mandates)));
        bytes memory cd = abi.encode(name, mandateAddr, codeHash);

        (, , , uint48 executedAt,,,) = IPowers(mandates).getActionData(calculateActionId(executeId, cd, nonce));
        if (executedAt > 0) { console2.log("Runner: registry addition already executed."); return; }

        (, uint48 proposedAt,,,,,) = IPowers(mandates).getActionData(calculateActionId(proposeId, cd, nonce));
        if (proposedAt == 0) {
            console2.log("Runner [0]: proposing registry addition.");
            proposeRegistryAddition(mandates, name, mandateAddr, codeHash, assessorKeys, nonce);
            console2.log("Runner: pausing - vote + Council veto window open.");
            return;
        }

        (, , uint256 voteEnd,,,,) = IPowers(mandates).getActionVoteData(calculateActionId(proposeId, cd, nonce));
        if (block.number <= voteEnd) { console2.log("Runner: pausing - assessor vote still open."); return; }
        if (!_timelockPast(mandates, executeId, proposedAt)) { console2.log("Runner: pausing - registry timelock (Council veto window)."); return; }

        console2.log("Runner [1]: registering mandate.");
        executeRegistryAddition(mandates, name, mandateAddr, codeHash, assessorKeys, nonce);
        console2.log("Runner: registry addition complete.");
    }

    // ── Shared predicates ───────────────────────────────────────────────────────
    function _timelockPast(address powers, uint16 mandateId, uint48 proposedAt) internal view returns (bool) {
        if (proposedAt == 0) return false;
        PowersTypes.Conditions memory cond = IPowers(powers).getConditions(mandateId);
        return block.number >= uint256(proposedAt) + uint256(cond.timelock);
    }
}
