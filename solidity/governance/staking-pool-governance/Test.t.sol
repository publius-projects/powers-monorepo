// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.26;

// Run with: forge test --match-contract StakingPoolGovernance_test -vvv
//
// ⚠️ DEMONSTRATION / REFERENCE DESIGN — not a UK-compliant production system.
//    Only SEPOLIA_RPC_URL is required to run these tests (synthetic accounts are
//    used internally — no private-key env vars needed).

import { Test, console2 } from "forge-std/Test.sol";
import { Powers } from "@src/Powers.sol";
import { IPowers } from "@src/interfaces/IPowers.sol";
import { Configurations } from "@script/Configurations.s.sol";
import { SimpleStakingPool } from "../../test/mocks/SimpleStakingPool.sol";
import { SimpleErc20Votes } from "../../test/mocks/SimpleErc20Votes.sol";

import { Deploy } from "./Deploy.s.sol";
import { StakingPoolGovernanceRunners } from "./Runners.s.sol";

contract StakingPoolGovernance_test is Test {
    Configurations helperConfig;
    Deploy deploy;
    address powers;
    SimpleStakingPool pool;
    SimpleErc20Votes rewardToken;
    StakingPoolGovernanceRunners runners;

    // Synthetic keys (never real keys from env).
    uint256 constant ADMIN_KEY     = 1;
    uint256 constant STAKER1_KEY   = 2;
    uint256 constant STAKER2_KEY   = 3;
    uint256 constant COMMITTEE_KEY = 4;
    uint256 constant GUARDIAN_KEY  = 5;
    uint256 constant MONITOR_KEY   = 6;
    uint256 constant CAND1_KEY     = 7;
    uint256 constant CAND2_KEY     = 8;
    uint256 constant CAND3_KEY     = 9;

    address testAdmin;
    address testStaker1;
    address testStaker2;
    address testCommittee;
    address testGuardian;
    address testMonitor;

    uint256[] adminKeys;
    uint256[] stakerKeys;
    uint256[] committeeKeys;
    uint256[] guardianKeys;
    uint256[] monitorKeys;

    function setUp() public {
        vm.createSelectFork(vm.envString("SEPOLIA_RPC_URL"));
        helperConfig = new Configurations();

        testAdmin     = vm.addr(ADMIN_KEY);
        testStaker1   = vm.addr(STAKER1_KEY);
        testStaker2   = vm.addr(STAKER2_KEY);
        testCommittee = vm.addr(COMMITTEE_KEY);
        testGuardian  = vm.addr(GUARDIAN_KEY);
        testMonitor   = vm.addr(MONITOR_KEY);

        adminKeys     = [ADMIN_KEY];
        stakerKeys    = [STAKER1_KEY, STAKER2_KEY];
        committeeKeys = [COMMITTEE_KEY];
        guardianKeys  = [GUARDIAN_KEY];
        monitorKeys   = [MONITOR_KEY];

        // Fund synthetic accounts, the test contract, and the broadcast default sender
        // (the Deploy script seeds the paymaster with 0.05 ETH under vm.broadcast()).
        for (uint256 i = 1; i <= 9; i++) vm.deal(vm.addr(i), 10 ether);
        vm.deal(address(this), 10 ether);
        vm.deal(DEFAULT_SENDER, 100 ether);

        deploy = new Deploy();
        powers = address(deploy.run());
        pool = deploy.pool();
        rewardToken = deploy.rewardToken();

        runners = new StakingPoolGovernanceRunners();
        runners.runInitialSetup(powers, adminKeys, block.timestamp);

        // Force-assign roles to synthetic EOAs (test setup only — bypasses governance).
        vm.startPrank(powers);
        IPowers(powers).assignRole(0, testAdmin);
        IPowers(powers).assignRole(1, testStaker1);
        IPowers(powers).assignRole(1, testStaker2);
        IPowers(powers).assignRole(2, testCommittee);
        IPowers(powers).assignRole(3, testGuardian);
        IPowers(powers).assignRole(4, testMonitor);
        vm.stopPrank();
    }

    ///////////////////////////////////////////////////////////////////////////
    //                           INITIAL STATE
    ///////////////////////////////////////////////////////////////////////////

    function test_initialState() public view {
        assertEq(Powers(payable(powers)).getRoleLabel(1), "Stakers", "role 1 = Stakers");
        assertEq(Powers(payable(powers)).getRoleLabel(2), "Rate Committee", "role 2 = Rate Committee");
        assertEq(Powers(payable(powers)).getRoleLabel(3), "Guardian", "role 3 = Guardian");
        assertEq(Powers(payable(powers)).getRoleLabel(4), "Compliance Monitor", "role 4 = Compliance Monitor");
        assertEq(pool.owner(), powers, "Powers should own the staking pool");

        uint16 counter = Powers(payable(powers)).mandateCounter();
        console2.log("Total mandates deployed:", counter);
        assertTrue(counter > 20, "should have deployed all flow mandates");
    }

    ///////////////////////////////////////////////////////////////////////////
    //                 SET REWARD RATE — HAPPY PATH (Flow 4)
    ///////////////////////////////////////////////////////////////////////////

    function test_rewardRateHappyPath() public {
        uint256 nonce = block.timestamp;
        uint256 newRate = 3_170_000_000; // ~100% APR knob

        // [0] Committee proposes + votes.
        runners.proposeRewardRate(powers, newRate, committeeKeys, nonce);
        vm.roll(block.number + daysToBlocks(7) + 1); // close 1-week vote

        // Fulfil proposal, open execution (starts 48h timelock).
        runners.fulfillRewardRateProposal(powers, newRate, committeeKeys, nonce);
        runners.openRewardRateExecution(powers, newRate, committeeKeys, nonce);
        vm.roll(block.number + daysToBlocks(2) + 1); // past 48h timelock

        // [1] Execute.
        runners.executeRewardRate(powers, newRate, committeeKeys, nonce);

        assertEq(pool.rewardRatePerTokenPerSecond(), newRate, "reward rate should be updated");
        console2.log("Reward-rate happy path passed.");
    }

    ///////////////////////////////////////////////////////////////////////////
    //          SET REWARD RATE — BLOCKED BY STAKER VETO (Flow 4)
    ///////////////////////////////////////////////////////////////////////////

    function test_rewardRateVetoBlocks() public {
        uint256 nonce = block.timestamp + 1;
        uint256 newRate = 9_999;

        // Committee proposes + votes, then proposal is fulfilled.
        runners.proposeRewardRate(powers, newRate, committeeKeys, nonce);
        vm.roll(block.number + daysToBlocks(7) + 1);
        runners.fulfillRewardRateProposal(powers, newRate, committeeKeys, nonce);

        // Stakers cast + fulfil a veto within the veto window.
        runners.proposeVetoRewardRate(powers, newRate, stakerKeys, nonce);
        vm.roll(block.number + daysToBlocks(1) + 1); // close 24h veto vote
        runners.fulfillVetoRewardRate(powers, newRate, stakerKeys, nonce);

        // Open execution + pass timelock, then execution must revert (needNotFulfilled = veto).
        runners.openRewardRateExecution(powers, newRate, committeeKeys, nonce);
        vm.roll(block.number + daysToBlocks(2) + 1);

        uint16 executeId = runners.findMandateIdInOrg(
            "Execute Reward Rate: Set the approved reward rate on the staking pool after the veto window and timelock.",
            Powers(payable(powers))
        );
        vm.prank(testCommittee);
        vm.expectRevert();
        IPowers(powers).request(executeId, abi.encode(newRate), nonce, "should be blocked by veto");

        assertEq(pool.rewardRatePerTokenPerSecond(), 0, "reward rate must be unchanged after veto");
        console2.log("Reward-rate veto correctly blocked execution.");
    }

    ///////////////////////////////////////////////////////////////////////////
    //               GUARDIAN INSTANT PAUSE (Flow 5)
    ///////////////////////////////////////////////////////////////////////////

    function test_guardianInstantPause() public {
        assertFalse(pool.paused(), "pool starts unpaused");
        runners.runGuardianPause(powers, guardianKeys, block.timestamp + 2);
        assertTrue(pool.paused(), "Guardian should have paused the pool instantly");
        console2.log("Guardian instant-pause passed.");
    }

    ///////////////////////////////////////////////////////////////////////////
    //        COMPLIANCE FLAG + MONITOR PAUSE (Flows 5 & 6)
    ///////////////////////////////////////////////////////////////////////////

    function test_complianceFlagAndMonitorPause() public {
        uint256 nonce = block.timestamp + 3;

        // Signal-only flag is recorded on-chain (no execution effect).
        runners.runComplianceFlag(powers, "Suspicious jurisdiction", testStaker1, monitorKeys, nonce);
        uint16 flagId = runners.findMandateIdInOrg(
            "Raise Compliance Flag: The Compliance Monitor records a compliance finding on-chain. Signal-only; no execution.",
            Powers(payable(powers))
        );
        (,,, uint48 flagFulfilledAt,,,) = IPowers(powers).getActionData(
            runners.calculateActionId(flagId, abi.encode("Suspicious jurisdiction", testStaker1), nonce)
        );
        assertTrue(flagFulfilledAt > 0, "compliance flag should be recorded");

        // Monitor trips the emergency pause.
        runners.monitorPause(powers, monitorKeys, nonce + 1);
        assertTrue(pool.paused(), "Compliance Monitor should be able to pause the pool");
        console2.log("Compliance flag + monitor pause passed.");
    }

    ///////////////////////////////////////////////////////////////////////////
    //            ELECT RATE COMMITTEE — PEER SELECT (Flow 2)
    ///////////////////////////////////////////////////////////////////////////

    function test_committeeElectionHappyPath() public {
        uint256 nonce = block.timestamp + 4;

        // Candidates must be Stakers to self-nominate; seed role 1 for them.
        vm.startPrank(powers);
        IPowers(powers).assignRole(1, vm.addr(CAND1_KEY));
        IPowers(powers).assignRole(1, vm.addr(CAND2_KEY));
        IPowers(powers).assignRole(1, vm.addr(CAND3_KEY));
        vm.stopPrank();

        // Three candidates nominate for the Committee.
        uint256[] memory candidateKeys = new uint256[](3);
        candidateKeys[0] = CAND1_KEY;
        candidateKeys[1] = CAND2_KEY;
        candidateKeys[2] = CAND3_KEY;
        runners.nominateForCommittee(powers, candidateKeys, nonce);

        // Stakers elect all three. succeedAt is measured against the full eligible-voter
        // snapshot (5 role-1 holders here: 2 base Stakers + 3 candidates), so all five vote.
        uint256[] memory electorate = new uint256[](5);
        electorate[0] = STAKER1_KEY;
        electorate[1] = STAKER2_KEY;
        electorate[2] = CAND1_KEY;
        electorate[3] = CAND2_KEY;
        electorate[4] = CAND3_KEY;

        bool[] memory selection = new bool[](3);
        selection[0] = true;
        selection[1] = true;
        selection[2] = true;
        (, bytes memory calldata_) = runners.proposeElectCommittee(powers, selection, electorate, nonce + 100);
        vm.roll(block.number + daysToBlocks(7) + 1);
        runners.executeElectCommittee(powers, calldata_, stakerKeys, nonce + 100);

        assertTrue(Powers(payable(powers)).hasRoleSince(vm.addr(CAND1_KEY), 2) > 0, "candidate 1 elected to Committee");
        assertTrue(Powers(payable(powers)).hasRoleSince(vm.addr(CAND2_KEY), 2) > 0, "candidate 2 elected to Committee");
        assertTrue(Powers(payable(powers)).hasRoleSince(vm.addr(CAND3_KEY), 2) > 0, "candidate 3 elected to Committee");
        console2.log("Committee election (PeerSelect) passed.");
    }

    ///////////////////////////////////////////////////////////////////////////
    //             SWEEP STRAY TOKENS — HAPPY PATH (Flow 7)
    ///////////////////////////////////////////////////////////////////////////

    function test_sweepHappyPath() public {
        uint256 nonce = block.timestamp + 5;
        uint256 amount = 10e18;
        address recipient = vm.addr(42);

        // Seed stray reward tokens in the pool (reward token != staking token, so sweepable).
        rewardToken.mint(address(pool), amount);

        runners.proposeSweep(powers, address(rewardToken), recipient, amount, committeeKeys, nonce);
        vm.roll(block.number + daysToBlocks(7) + 1);
        runners.fulfillSweepProposal(powers, address(rewardToken), recipient, amount, committeeKeys, nonce);
        runners.openSweepExecution(powers, address(rewardToken), recipient, amount, committeeKeys, nonce);
        vm.roll(block.number + daysToBlocks(7) + 1); // extra-long timelock
        runners.executeSweep(powers, address(rewardToken), recipient, amount, committeeKeys, nonce);

        assertEq(rewardToken.balanceOf(recipient), amount, "swept tokens should reach the recipient");
        console2.log("Sweep happy path passed.");
    }

    ///////////////////////////////////////////////////////////////////////////
    //     REMAINING FLOWS RESOLVE (reform + paymaster nameDescriptions)
    ///////////////////////////////////////////////////////////////////////////

    function test_remainingFlowMandatesResolve() public view {
        // Guards that the Actions nameDescription strings match Deploy for the flows
        // not executed end-to-end above.
        runners.findMandateIdInOrg("Propose Governance Reform: Stakers vote (supermajority) to adopt new governance mandates.", Powers(payable(powers)));
        runners.findMandateIdInOrg("Adopt New Mandates: Execute an approved governance reform by adopting the proposed mandates.", Powers(payable(powers)));
        runners.findMandateIdInOrg("Propose to Fund Paymaster: Propose an ETH transfer that tops up the gasless paymaster.", Powers(payable(powers)));
        runners.findMandateIdInOrg("Execute Fund Paymaster: Send 0.05 ETH from the treasury to the paymaster deposit.", Powers(payable(powers)));
        runners.findMandateIdInOrg("Propose to Withdraw from Paymaster: Propose withdrawing ETH from the paymaster back to the treasury.", Powers(payable(powers)));
        runners.findMandateIdInOrg("Execute Withdraw from Paymaster: Execute the proposed ETH withdrawal from the paymaster.", Powers(payable(powers)));
        runners.findMandateIdInOrg("Community Un-pause: Stakers vote to resume staking after a pause.", Powers(payable(powers)));
        runners.findMandateIdInOrg("Leave as Staker: A Staker voluntarily renounces the Staker role.", Powers(payable(powers)));
        console2.log("All remaining flow mandates resolve.");
    }

    ///////////////////////////////////////////////////////////////////////////
    //                             HELPERS
    ///////////////////////////////////////////////////////////////////////////

    function daysToBlocks(uint256 quantityDays) internal view returns (uint256) {
        return quantityDays * 24 * helperConfig.getBlocksPerHour(block.chainid);
    }
}
