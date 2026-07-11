// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

// ─────────────────────────────────────────────────────────────────────────────
//  Staking Pool Governance — Action helpers
//
//  One propose/execute helper (sometimes a few sub-steps) per governance flow.
//  Every lookup uses findMandateIdInOrg() with the EXACT nameDescription strings
//  from Deploy.s.sol — keep these character-perfect and in sync.
//
//  Multi-step flows (propose → veto window → timelock → execute) intentionally
//  expose granular functions; the caller (Runners.s.sol or Test.t.sol) advances
//  blocks between them. All steps of one flow share the SAME calldata + nonce so
//  Powers' needFulfilled / needNotFulfilled checks line up.
// ─────────────────────────────────────────────────────────────────────────────

import { console2 } from "forge-std/console2.sol";
import { Powers } from "@src/Powers.sol";
import { IPowers } from "@src/interfaces/IPowers.sol";
import { ActionHelpers } from "@governance/examples/actions/ActionHelpers.s.sol";

contract StakingPoolGovernanceActions is ActionHelpers {
    ///////////////////////////////////////////////////////////////
    //                 FLOW 1: STAKER MEMBERSHIP                //
    ///////////////////////////////////////////////////////////////

    /// @notice Each provided key nominates itself as a Staker candidate.
    function nominateStakers(address powers, uint256[] memory privateKeys, uint256 nonce) public {
        uint16 id = findMandateIdInOrg(
            "Nominate as Staker: Any account nominates itself as a candidate for the Staker role. (set shouldNominate=false to withdraw)",
            Powers(payable(powers))
        );
        for (uint256 i = 0; i < privateKeys.length; i++) {
            vm.startBroadcast(privateKeys[i]);
            IPowers(powers).request(id, abi.encode(true), nonce + i, "Nominate as Staker");
            vm.stopBroadcast();
            console2.log("Nominated Staker candidate:", vm.addr(privateKeys[i]));
        }
    }

    /// @notice Existing Stakers vote to elect `selection` from the current nominee list.
    function proposeElectStakers(
        address powers,
        bool[] memory selection,
        uint256[] memory voterKeys,
        uint256 nonce
    ) public returns (uint16 mandateId, bytes memory calldata_) {
        mandateId = findMandateIdInOrg(
            "Elect Stakers: Existing Stakers peer-vote to elect up to 5 members from the nominee pool. One-time election; revokes itself after execution.",
            Powers(payable(powers))
        );
        calldata_ = _encodeBoolSelections(selection);
        uint256 actionId = calculateActionId(mandateId, calldata_, nonce);

        vm.startBroadcast(voterKeys[0]);
        IPowers(powers).propose(mandateId, calldata_, nonce, "Elect Stakers");
        vm.stopBroadcast();
        (roleCount, againstVote, forVote, abstainVote) = voteOnProposal(powers, mandateId, actionId, voterKeys, nonce, 100);
        console2.log("Elect Stakers votes for:", forVote, "against:", againstVote);
    }

    /// @notice Execute the Staker election (after the voting period closes).
    function executeElectStakers(address powers, bytes memory calldata_, uint256[] memory voterKeys, uint256 nonce) public {
        uint16 id = findMandateIdInOrg(
            "Elect Stakers: Existing Stakers peer-vote to elect up to 5 members from the nominee pool. One-time election; revokes itself after execution.",
            Powers(payable(powers))
        );
        vm.startBroadcast(voterKeys[0]);
        IPowers(powers).request(id, calldata_, nonce, "Execute Staker election");
        vm.stopBroadcast();
        console2.log("Staker election executed.");
    }

    /// @notice A Staker renounces the Staker role.
    function leaveAsStaker(address powers, uint256[] memory privateKeys, uint256 nonce) public {
        uint16 id = findMandateIdInOrg("Leave as Staker: A Staker voluntarily renounces the Staker role.", Powers(payable(powers)));
        vm.startBroadcast(privateKeys[0]);
        IPowers(powers).request(id, abi.encode(uint256(1)), nonce, "Renounce Staker role");
        vm.stopBroadcast();
    }

    ///////////////////////////////////////////////////////////////
    //                 FLOW 2: ELECT RATE COMMITTEE             //
    ///////////////////////////////////////////////////////////////

    /// @notice Each provided key nominates itself for the Rate Committee.
    function nominateForCommittee(address powers, uint256[] memory privateKeys, uint256 nonce) public {
        uint16 id = findMandateIdInOrg(
            "Nominate for Committee: A Staker nominates itself as a candidate for the Rate Committee. (set shouldNominate=false to withdraw)",
            Powers(payable(powers))
        );
        for (uint256 i = 0; i < privateKeys.length; i++) {
            vm.startBroadcast(privateKeys[i]);
            IPowers(powers).request(id, abi.encode(true), nonce + i, "Nominate for Committee");
            vm.stopBroadcast();
            console2.log("Nominated Committee candidate:", vm.addr(privateKeys[i]));
        }
    }

    /// @notice Stakers vote to elect `selection` of the committee nominees.
    function proposeElectCommittee(
        address powers,
        bool[] memory selection,
        uint256[] memory voterKeys,
        uint256 nonce
    ) public returns (uint16 mandateId, bytes memory calldata_) {
        mandateId = findMandateIdInOrg(
            "Elect Committee: Stakers peer-vote to elect up to 3 Rate Committee members from the nominee pool. One-time election; revokes itself after execution.",
            Powers(payable(powers))
        );
        calldata_ = _encodeBoolSelections(selection);
        uint256 actionId = calculateActionId(mandateId, calldata_, nonce);

        vm.startBroadcast(voterKeys[0]);
        IPowers(powers).propose(mandateId, calldata_, nonce, "Elect Committee");
        vm.stopBroadcast();
        (roleCount, againstVote, forVote, abstainVote) = voteOnProposal(powers, mandateId, actionId, voterKeys, nonce, 100);
        console2.log("Elect Committee votes for:", forVote, "against:", againstVote);
    }

    /// @notice Execute the Committee election (after the voting period closes).
    function executeElectCommittee(address powers, bytes memory calldata_, uint256[] memory voterKeys, uint256 nonce) public {
        uint16 id = findMandateIdInOrg(
            "Elect Committee: Stakers peer-vote to elect up to 3 Rate Committee members from the nominee pool. One-time election; revokes itself after execution.",
            Powers(payable(powers))
        );
        vm.startBroadcast(voterKeys[0]);
        IPowers(powers).request(id, calldata_, nonce, "Execute Committee election");
        vm.stopBroadcast();
        console2.log("Committee election executed.");
    }

    ///////////////////////////////////////////////////////////////
    //              FLOW 3: ADMIN ROLE ADMINISTRATION           //
    ///////////////////////////////////////////////////////////////

    /// @notice Admin assigns a role to an account (Guardian, Monitor, genesis Staker).
    function adminAssignRole(address powers, uint256 roleId, address account, uint256[] memory adminKeys, uint256 nonce) public {
        uint16 id = findMandateIdInOrg(
            "Admin Assign Role: Admin assigns a role (Guardian, Compliance Monitor, or genesis Staker) to an account.",
            Powers(payable(powers))
        );
        vm.startBroadcast(adminKeys[0]);
        IPowers(powers).request(id, abi.encode(roleId, account), nonce, "Admin assign role");
        vm.stopBroadcast();
        console2.log("Admin assigned role", roleId, "to", account);
    }

    /// @notice Admin revokes a role from an account (must have assigned it first, same nonce).
    function adminRevokeRole(address powers, uint256 roleId, address account, uint256[] memory adminKeys, uint256 nonce) public {
        uint16 id = findMandateIdInOrg("Admin Revoke Role: Admin revokes a previously assigned role from an account.", Powers(payable(powers)));
        vm.startBroadcast(adminKeys[0]);
        IPowers(powers).request(id, abi.encode(roleId, account), nonce, "Admin revoke role");
        vm.stopBroadcast();
        console2.log("Admin revoked role", roleId, "from", account);
    }

    ///////////////////////////////////////////////////////////////
    //                   FLOW 4: SET REWARD RATE                //
    ///////////////////////////////////////////////////////////////

    /// @notice Committee proposes a new reward rate and votes to pass it.
    function proposeRewardRate(address powers, uint256 newRate, uint256[] memory committeeKeys, uint256 nonce) public returns (uint256 actionId) {
        uint16 id = findMandateIdInOrg("Propose Reward Rate: The Rate Committee votes to propose a new per-token per-second reward rate.", Powers(payable(powers)));
        bytes memory calldata_ = abi.encode(newRate);
        actionId = calculateActionId(id, calldata_, nonce);

        vm.startBroadcast(committeeKeys[0]);
        IPowers(powers).propose(id, calldata_, nonce, "Propose reward rate");
        vm.stopBroadcast();
        (roleCount, againstVote, forVote, abstainVote) = voteOnProposal(powers, id, actionId, committeeKeys, nonce, 100);
        console2.log("Propose reward rate votes for:", forVote, "against:", againstVote);
    }

    /// @notice Fulfil the passed rate proposal (request) so downstream checks see it Fulfilled.
    function fulfillRewardRateProposal(address powers, uint256 newRate, uint256[] memory committeeKeys, uint256 nonce) public {
        uint16 id = findMandateIdInOrg("Propose Reward Rate: The Rate Committee votes to propose a new per-token per-second reward rate.", Powers(payable(powers)));
        vm.startBroadcast(committeeKeys[0]);
        IPowers(powers).request(id, abi.encode(newRate), nonce, "Fulfil reward-rate proposal");
        vm.stopBroadcast();
    }

    /// @notice Stakers cast a veto vote against a proposed rate (within the veto window).
    function proposeVetoRewardRate(address powers, uint256 newRate, uint256[] memory stakerKeys, uint256 nonce) public {
        uint16 id = findMandateIdInOrg("Veto Reward Rate: Stakers vote within the veto window to block a proposed reward-rate change.", Powers(payable(powers)));
        bytes memory calldata_ = abi.encode(newRate);
        uint256 actionId = calculateActionId(id, calldata_, nonce);

        vm.startBroadcast(stakerKeys[0]);
        IPowers(powers).propose(id, calldata_, nonce, "Veto reward rate");
        vm.stopBroadcast();
        (roleCount, againstVote, forVote, abstainVote) = voteOnProposal(powers, id, actionId, stakerKeys, nonce, 100);
        console2.log("Veto reward rate votes for:", forVote);
    }

    /// @notice Fulfil the veto (request) so the executor's needNotFulfilled check blocks execution.
    function fulfillVetoRewardRate(address powers, uint256 newRate, uint256[] memory stakerKeys, uint256 nonce) public {
        uint16 id = findMandateIdInOrg("Veto Reward Rate: Stakers vote within the veto window to block a proposed reward-rate change.", Powers(payable(powers)));
        vm.startBroadcast(stakerKeys[0]);
        IPowers(powers).request(id, abi.encode(newRate), nonce, "Fulfil reward-rate veto");
        vm.stopBroadcast();
    }

    /// @notice Open the execution proposal so the timelock clock starts.
    function openRewardRateExecution(address powers, uint256 newRate, uint256[] memory committeeKeys, uint256 nonce) public {
        uint16 id = findMandateIdInOrg("Execute Reward Rate: Set the approved reward rate on the staking pool after the veto window and timelock.", Powers(payable(powers)));
        vm.startBroadcast(committeeKeys[0]);
        IPowers(powers).propose(id, abi.encode(newRate), nonce, "Open reward-rate execution");
        vm.stopBroadcast();
    }

    /// @notice Execute the approved rate change on the pool (after timelock).
    function executeRewardRate(address powers, uint256 newRate, uint256[] memory committeeKeys, uint256 nonce) public {
        uint16 id = findMandateIdInOrg("Execute Reward Rate: Set the approved reward rate on the staking pool after the veto window and timelock.", Powers(payable(powers)));
        vm.startBroadcast(committeeKeys[0]);
        IPowers(powers).request(id, abi.encode(newRate), nonce, "Execute reward rate");
        vm.stopBroadcast();
        console2.log("Reward rate executed:", newRate);
    }

    ///////////////////////////////////////////////////////////////
    //              FLOW 5: EMERGENCY PAUSE / UN-PAUSE          //
    ///////////////////////////////////////////////////////////////

    /// @notice Guardian instantly pauses the pool (no vote).
    function guardianPause(address powers, uint256[] memory guardianKeys, uint256 nonce) public {
        uint16 id = findMandateIdInOrg("Guardian Pause: The Guardian instantly halts new staking (emergency circuit-breaker).", Powers(payable(powers)));
        vm.startBroadcast(guardianKeys[0]);
        IPowers(powers).request(id, abi.encode(), nonce, "Guardian emergency pause");
        vm.stopBroadcast();
        console2.log("Guardian paused the pool.");
    }

    /// @notice Compliance Monitor instantly pauses the pool (no vote).
    function monitorPause(address powers, uint256[] memory monitorKeys, uint256 nonce) public {
        uint16 id = findMandateIdInOrg("Monitor Pause: The Compliance Monitor instantly halts new staking on a compliance finding.", Powers(payable(powers)));
        vm.startBroadcast(monitorKeys[0]);
        IPowers(powers).request(id, abi.encode(), nonce, "Monitor emergency pause");
        vm.stopBroadcast();
        console2.log("Compliance Monitor paused the pool.");
    }

    /// @notice Stakers vote to un-pause the pool.
    function proposeUnpause(address powers, uint256[] memory stakerKeys, uint256 nonce) public returns (uint256 actionId) {
        uint16 id = findMandateIdInOrg("Community Un-pause: Stakers vote to resume staking after a pause.", Powers(payable(powers)));
        actionId = calculateActionId(id, abi.encode(), nonce);
        vm.startBroadcast(stakerKeys[0]);
        IPowers(powers).propose(id, abi.encode(), nonce, "Propose un-pause");
        vm.stopBroadcast();
        (roleCount, againstVote, forVote, abstainVote) = voteOnProposal(powers, id, actionId, stakerKeys, nonce, 100);
    }

    /// @notice Execute the un-pause after the vote closes.
    function executeUnpause(address powers, uint256[] memory stakerKeys, uint256 nonce) public {
        uint16 id = findMandateIdInOrg("Community Un-pause: Stakers vote to resume staking after a pause.", Powers(payable(powers)));
        vm.startBroadcast(stakerKeys[0]);
        IPowers(powers).request(id, abi.encode(), nonce, "Execute un-pause");
        vm.stopBroadcast();
        console2.log("Pool un-paused.");
    }

    ///////////////////////////////////////////////////////////////
    //                FLOW 6: COMPLIANCE MONITORING             //
    ///////////////////////////////////////////////////////////////

    /// @notice Compliance Monitor records an on-chain compliance finding (signal-only).
    function raiseComplianceFlag(address powers, string memory finding, address subject, uint256[] memory monitorKeys, uint256 nonce) public {
        uint16 id = findMandateIdInOrg(
            "Raise Compliance Flag: The Compliance Monitor records a compliance finding on-chain. Signal-only; no execution.",
            Powers(payable(powers))
        );
        vm.startBroadcast(monitorKeys[0]);
        IPowers(powers).request(id, abi.encode(finding, subject), nonce, string.concat("Compliance flag: ", finding));
        vm.stopBroadcast();
        console2.log("Compliance flag raised for subject:", subject);
    }

    ///////////////////////////////////////////////////////////////
    //                  FLOW 7: SWEEP STRAY TOKENS              //
    ///////////////////////////////////////////////////////////////

    /// @notice Committee proposes a sweep and votes to pass it.
    function proposeSweep(address powers, address token, address to, uint256 amount, uint256[] memory committeeKeys, uint256 nonce) public returns (uint256 actionId) {
        uint16 id = findMandateIdInOrg("Propose Sweep: The Rate Committee votes to propose sweeping stray tokens out of the staking pool.", Powers(payable(powers)));
        bytes memory calldata_ = abi.encode(token, to, amount);
        actionId = calculateActionId(id, calldata_, nonce);
        vm.startBroadcast(committeeKeys[0]);
        IPowers(powers).propose(id, calldata_, nonce, "Propose sweep");
        vm.stopBroadcast();
        (roleCount, againstVote, forVote, abstainVote) = voteOnProposal(powers, id, actionId, committeeKeys, nonce, 100);
    }

    /// @notice Fulfil the passed sweep proposal.
    function fulfillSweepProposal(address powers, address token, address to, uint256 amount, uint256[] memory committeeKeys, uint256 nonce) public {
        uint16 id = findMandateIdInOrg("Propose Sweep: The Rate Committee votes to propose sweeping stray tokens out of the staking pool.", Powers(payable(powers)));
        vm.startBroadcast(committeeKeys[0]);
        IPowers(powers).request(id, abi.encode(token, to, amount), nonce, "Fulfil sweep proposal");
        vm.stopBroadcast();
    }

    /// @notice Open the sweep execution proposal so the (long) timelock starts.
    function openSweepExecution(address powers, address token, address to, uint256 amount, uint256[] memory committeeKeys, uint256 nonce) public {
        uint16 id = findMandateIdInOrg("Execute Sweep: Sweep the approved tokens out of the staking pool after the veto window and long timelock.", Powers(payable(powers)));
        vm.startBroadcast(committeeKeys[0]);
        IPowers(powers).propose(id, abi.encode(token, to, amount), nonce, "Open sweep execution");
        vm.stopBroadcast();
    }

    /// @notice Execute the sweep on the pool (after the long timelock).
    function executeSweep(address powers, address token, address to, uint256 amount, uint256[] memory committeeKeys, uint256 nonce) public {
        uint16 id = findMandateIdInOrg("Execute Sweep: Sweep the approved tokens out of the staking pool after the veto window and long timelock.", Powers(payable(powers)));
        vm.startBroadcast(committeeKeys[0]);
        IPowers(powers).request(id, abi.encode(token, to, amount), nonce, "Execute sweep");
        vm.stopBroadcast();
        console2.log("Sweep executed for token:", token);
    }

    ///////////////////////////////////////////////////////////////
    //                  FLOW 8: GOVERNANCE REFORM              //
    ///////////////////////////////////////////////////////////////

    /// @notice Stakers propose a governance reform (supermajority) and vote to pass it.
    function proposeReform(address powers, address[] memory newMandates, uint256[] memory roleIds, uint256[] memory stakerKeys, uint256 nonce) public returns (uint256 actionId) {
        uint16 id = findMandateIdInOrg("Propose Governance Reform: Stakers vote (supermajority) to adopt new governance mandates.", Powers(payable(powers)));
        bytes memory calldata_ = abi.encode(newMandates, roleIds);
        actionId = calculateActionId(id, calldata_, nonce);
        vm.startBroadcast(stakerKeys[0]);
        IPowers(powers).propose(id, calldata_, nonce, "Propose governance reform");
        vm.stopBroadcast();
        (roleCount, againstVote, forVote, abstainVote) = voteOnProposal(powers, id, actionId, stakerKeys, nonce, 100);
    }

    /// @notice Fulfil the passed reform proposal.
    function fulfillReformProposal(address powers, address[] memory newMandates, uint256[] memory roleIds, uint256[] memory stakerKeys, uint256 nonce) public {
        uint16 id = findMandateIdInOrg("Propose Governance Reform: Stakers vote (supermajority) to adopt new governance mandates.", Powers(payable(powers)));
        vm.startBroadcast(stakerKeys[0]);
        IPowers(powers).request(id, abi.encode(newMandates, roleIds), nonce, "Fulfil reform proposal");
        vm.stopBroadcast();
    }

    /// @notice Open the adopt-mandates execution so the timelock starts.
    function openReformExecution(address powers, address[] memory newMandates, uint256[] memory roleIds, uint256[] memory stakerKeys, uint256 nonce) public {
        uint16 id = findMandateIdInOrg("Adopt New Mandates: Execute an approved governance reform by adopting the proposed mandates.", Powers(payable(powers)));
        vm.startBroadcast(stakerKeys[0]);
        IPowers(powers).propose(id, abi.encode(newMandates, roleIds), nonce, "Open reform execution");
        vm.stopBroadcast();
    }

    /// @notice Adopt the new mandates after the timelock.
    function executeReform(address powers, address[] memory newMandates, uint256[] memory roleIds, uint256[] memory stakerKeys, uint256 nonce) public {
        uint16 id = findMandateIdInOrg("Adopt New Mandates: Execute an approved governance reform by adopting the proposed mandates.", Powers(payable(powers)));
        vm.startBroadcast(stakerKeys[0]);
        IPowers(powers).request(id, abi.encode(newMandates, roleIds), nonce, "Execute governance reform");
        vm.stopBroadcast();
        console2.log("Governance reform executed.");
    }

    ///////////////////////////////////////////////////////////////
    //          FLOW 9 & 10: PAYMASTER (gasless) FLOWS          //
    ///////////////////////////////////////////////////////////////

    /// @notice Committee proposes to fund the paymaster.
    function proposeFundPaymaster(address powers, uint256[] memory committeeKeys, uint256 nonce) public {
        uint16 id = findMandateIdInOrg("Propose to Fund Paymaster: Propose an ETH transfer that tops up the gasless paymaster.", Powers(payable(powers)));
        vm.startBroadcast(committeeKeys[0]);
        IPowers(powers).request(id, abi.encode(), nonce, "Propose fund paymaster");
        vm.stopBroadcast();
    }

    /// @notice Committee proposes to withdraw from the paymaster.
    function proposeWithdrawPaymaster(address powers, address withdrawAddress, uint256 amount, uint256[] memory committeeKeys, uint256 nonce) public {
        uint16 id = findMandateIdInOrg("Propose to Withdraw from Paymaster: Propose withdrawing ETH from the paymaster back to the treasury.", Powers(payable(powers)));
        vm.startBroadcast(committeeKeys[0]);
        IPowers(powers).request(id, abi.encode(withdrawAddress, amount), nonce, "Propose withdraw paymaster");
        vm.stopBroadcast();
    }

    ///////////////////////////////////////////////////////////////
    //                        HELPERS                           //
    ///////////////////////////////////////////////////////////////

    /// @notice Encode a bool[] the way PeerSelect expects: one 32-byte word per nominee.
    function _encodeBoolSelections(bool[] memory selection) internal pure returns (bytes memory encoded) {
        encoded = new bytes(selection.length * 32);
        for (uint256 j = 0; j < selection.length; j++) {
            bytes32 word = selection[j] ? bytes32(uint256(1)) : bytes32(uint256(0));
            for (uint256 k = 0; k < 32; k++) {
                encoded[j * 32 + k] = word[k];
            }
        }
    }
}
