// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

// ─────────────────────────────────────────────────────────────────────────────
//  Staking Pool Governance — Deployment Script
//
//  ⚠️  DEMONSTRATION / REFERENCE DESIGN — NOT a UK-compliant production system.
//      Compliance for a staking product attaches to the activity and entity (FCA
//      cryptoasset regime, s21 FSMA financial-promotions restriction, Money
//      Laundering Regulations, etc.), not to how these mandates are wired. The
//      target SimpleStakingPool is itself a self-described demo/mock. Governance
//      cannot KYC/geo-gate stakers (the pool's stake/unstake/claim are
//      permissionless). Obtain qualified UK counsel before any real-money use.
//      See Spec.md § "Regulatory status".
//
//  Governs solidity/test/mocks/SimpleStakingPool.sol via Powers ownership.
//  Four privileged pool knobs are distributed across five roles with checks and
//  balances. See README.md / Spec.md for the full design.
// ─────────────────────────────────────────────────────────────────────────────

// scripts
import { console2 } from "forge-std/console2.sol";
import { Configurations } from "@script/Configurations.s.sol";
import { DeployHelpers } from "../DeployHelpers.s.sol";
import { IMandateRegistry } from "@src/core/helpers/MandateRegistry.sol";

// powers contracts
import { PowersTypes } from "@src/interfaces/PowersTypes.sol";
import { Powers } from "@src/Powers.sol";
import { IPowers } from "@src/interfaces/IPowers.sol";

// helpers
import { Nominees } from "@src/core/helpers/Nominees.sol";
import { PowersPaymaster } from "@src/core/helpers/PowersPaymaster.sol";
import { IEntryPoint } from "@lib/account-abstraction/contracts/interfaces/IEntryPoint.sol";

// the governed protocol + mock tokens
import { SimpleStakingPool } from "../../test/mocks/SimpleStakingPool.sol";
import { SimpleErc20Votes } from "../../test/mocks/SimpleErc20Votes.sol";
import { IERC20 } from "@lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";

/// @title Staking Pool Governance Deployment Script
contract Deploy is DeployHelpers {
    Configurations helperConfig;
    PowersTypes.MandateInitData[] constitution;
    PowersTypes.Conditions conditions;
    PowersTypes.Flow[] flows;
    Powers powers;
    IMandateRegistry registry;

    // external contracts governed / used by this organisation (public so scripts/tests can read them)
    SimpleErc20Votes public stakingToken;
    SimpleErc20Votes public rewardToken;
    SimpleStakingPool public pool;
    Nominees public stakerNominees;
    Nominees public committeeNominees;
    PowersPaymaster public powersPaymaster;

    // scratch arrays reused while building the constitution
    address[] targets;
    uint256[] values;
    bytes[] calldatas;
    string[] inputParams;

    // Mandate registry version.
    uint16 constant MAJOR = 0;
    uint16 constant MINOR = 1;
    uint16 constant PATCH = 8;

    // Canonical ERC-4337 v0.7 EntryPoint (same address on all supported networks).
    address constant ENTRY_POINT = 0x0000000071727De22E5E9d8BAf0edAc6f37da032;

    // Account-abstraction paymaster seed.
    uint256 constant PAYMASTER_SEED = 0.05 ether;

    function run() external returns (Powers) {
        // step 0: setup
        helperConfig = new Configurations();
        registry = IMandateRegistry(helperConfig.getMandateRegistry(block.chainid));

        // step 1: deploy the governed protocol, helpers and the Powers instance
        vm.startBroadcast();
        // Demo tokens: a plain staking token and a separate reward token.
        stakingToken = new SimpleErc20Votes();
        rewardToken = new SimpleErc20Votes();
        pool = new SimpleStakingPool(IERC20(address(stakingToken)), IERC20(address(rewardToken)), 0);

        stakerNominees = new Nominees();
        committeeNominees = new Nominees();

        powers = new Powers(
            "Staking Pool Governance", // name
            "https://aqua-famous-sailfish-288.mypinata.cloud/ipfs/bafkreiejezgv4itvryovwbuatrxjbsxt4p536bcp6fepdzh5z2n3aqjici",
            helperConfig.getMaxCallDataLength(block.chainid),
            helperConfig.getMaxReturnDataLength(block.chainid),
            helperConfig.getMaxExecutionsLength(block.chainid),
            address(registry)
        );

        // Gasless participation: deploy + pre-fund an ERC-4337 paymaster.
        powersPaymaster = new PowersPaymaster(IEntryPoint(ENTRY_POINT), address(powers));
        powersPaymaster.deposit{ value: PAYMASTER_SEED }();
        vm.stopBroadcast();

        console2.log("Powers deployed at:", address(powers));
        console2.log("SimpleStakingPool deployed at:", address(pool));
        console2.log("PowersPaymaster deployed at:", address(powersPaymaster));

        // step 2: build the constitution
        uint256 constitutionLength = createConstitution();
        console2.log("Constitution length:", constitutionLength);

        // step 3: constitute, then hand ownership of the pool + helpers to Powers
        vm.startBroadcast();
        powers.constitute(constitution);
        powers.closeConstitute(msg.sender, flows);

        pool.transferOwnership(address(powers));
        stakerNominees.transferOwnership(address(powers));
        committeeNominees.transferOwnership(address(powers));
        vm.stopBroadcast();
        console2.log("Powers successfully constituted; pool + nominees owned by Powers.");

        return powers;
    }

    function createConstitution() internal returns (uint256) {
        uint16 mandateCount = 0;

        ////////////////////////////////////////////////////////////////////////
        //                        SETUP (mandateId = 1)                       //
        ////////////////////////////////////////////////////////////////////////
        // Labels every role, wires treasury + paymaster, then revokes itself.
        targets = new address[](10);
        values = new uint256[](10);
        calldatas = new bytes[](10);
        for (uint256 i = 0; i < targets.length; i++) {
            targets[i] = address(powers);
        }
        calldatas[0] = abi.encodeWithSelector(IPowers.labelRole.selector, 0, "Admin", "");
        calldatas[1] = abi.encodeWithSelector(IPowers.labelRole.selector, type(uint256).max, "Public", "");
        calldatas[2] = abi.encodeWithSelector(IPowers.labelRole.selector, 1, "Stakers", "");
        calldatas[3] = abi.encodeWithSelector(IPowers.labelRole.selector, 2, "Rate Committee", "");
        calldatas[4] = abi.encodeWithSelector(IPowers.labelRole.selector, 3, "Guardian", "");
        calldatas[5] = abi.encodeWithSelector(IPowers.labelRole.selector, 4, "Compliance Monitor", "");
        calldatas[6] = abi.encodeWithSelector(IPowers.setTreasury.selector, address(powers));
        calldatas[7] = abi.encodeWithSelector(IPowers.setPaymaster.selector, address(powersPaymaster));
        targets[8] = address(powersPaymaster);
        calldatas[8] = abi.encodeWithSelector(PowersPaymaster.addSponsoredTarget.selector, address(powers));
        calldatas[9] = abi.encodeWithSelector(IPowers.revokeMandate.selector, mandateCount + 1); // revoke self

        mandateCount++;
        conditions.allowedRole = type(uint256).max; // anyone can trigger one-time setup
        constitution.push(
            PowersTypes.MandateInitData({
                nameDescription: "Initial Setup: Assign role labels and revokes itself after execution",
                targetMandate: registry.getMandateAddress(MAJOR, MINOR, PATCH, "PresetActions"),
                config: abi.encode(targets, values, calldatas),
                conditions: conditions
            })
        );
        delete conditions;

        ////////////////////////////////////////////////////////////////////////
        //                     FLOW 1: STAKER MEMBERSHIP                      //
        ////////////////////////////////////////////////////////////////////////
        // Anyone nominates; Stakers peer-elect new Stakers; Stakers may leave.
        // (Genesis Stakers are seeded via the generic Admin assign in Flow 3.)
        {
            uint16[] memory ids = new uint16[](3);
            ids[0] = mandateCount + 1;
            ids[1] = mandateCount + 2;
            ids[2] = mandateCount + 3;
            flows.push(PowersTypes.Flow({ mandateIds: ids, nameDescription: "Staker Membership: nominate, peer-elect, and renounce the Staker role." }));
        }

        // Nominate as a Staker candidate (public).
        mandateCount++;
        conditions.allowedRole = type(uint256).max;
        constitution.push(
            PowersTypes.MandateInitData({
                nameDescription: "Nominate as Staker: Any account nominates itself as a candidate for the Staker role. (set shouldNominate=false to withdraw)",
                targetMandate: registry.getMandateAddress(MAJOR, MINOR, PATCH, "Nominate"),
                config: abi.encode(address(stakerNominees)),
                conditions: conditions
            })
        );
        delete conditions;

        // Peer-elect Stakers from the nominee pool (existing Stakers vote).
        // Quorum-gated + reads live nominee/role state → set maxExecutionDelay (stale-state rule).
        mandateCount++;
        conditions.allowedRole = 1; // Stakers vote
        conditions.votingPeriod = daysToBlocks(7, helperConfig.getBlocksPerHour(block.chainid));
        conditions.quorum = 30;
        conditions.succeedAt = 51;
        conditions.maxExecutionDelay = daysToBlocks(7, helperConfig.getBlocksPerHour(block.chainid));
        constitution.push(
            PowersTypes.MandateInitData({
                nameDescription: "Elect Stakers: Existing Stakers peer-vote to elect up to 5 members from the nominee pool. One-time election; revokes itself after execution.",
                targetMandate: registry.getMandateAddress(MAJOR, MINOR, PATCH, "PeerSelect"),
                config: abi.encode(uint8(5), uint256(1), address(stakerNominees)),
                conditions: conditions
            })
        );
        delete conditions;

        // Renounce the Staker role (credible exit).
        mandateCount++;
        conditions.allowedRole = 1;
        {
            uint256[] memory renounceable = new uint256[](1);
            renounceable[0] = 1;
            constitution.push(
                PowersTypes.MandateInitData({
                    nameDescription: "Leave as Staker: A Staker voluntarily renounces the Staker role.",
                    targetMandate: registry.getMandateAddress(MAJOR, MINOR, PATCH, "RenounceRole"),
                    config: abi.encode(renounceable),
                    conditions: conditions
                })
            );
        }
        delete conditions;

        ////////////////////////////////////////////////////////////////////////
        //                     FLOW 2: ELECT RATE COMMITTEE                   //
        ////////////////////////////////////////////////////////////////////////
        // Stakers nominate + peer-elect the Rate Committee (economic stewards).
        {
            uint16[] memory ids = new uint16[](2);
            ids[0] = mandateCount + 1;
            ids[1] = mandateCount + 2;
            flows.push(PowersTypes.Flow({ mandateIds: ids, nameDescription: "Elect Rate Committee: Stakers nominate and elect the economic stewards." }));
        }

        // Nominate for the Rate Committee (Stakers only).
        mandateCount++;
        conditions.allowedRole = 1;
        constitution.push(
            PowersTypes.MandateInitData({
                nameDescription: "Nominate for Committee: A Staker nominates itself as a candidate for the Rate Committee. (set shouldNominate=false to withdraw)",
                targetMandate: registry.getMandateAddress(MAJOR, MINOR, PATCH, "Nominate"),
                config: abi.encode(address(committeeNominees)),
                conditions: conditions
            })
        );
        delete conditions;

        // Peer-elect the Committee (Stakers vote).
        mandateCount++;
        conditions.allowedRole = 1; // Stakers vote
        conditions.votingPeriod = daysToBlocks(7, helperConfig.getBlocksPerHour(block.chainid));
        conditions.quorum = 30;
        conditions.succeedAt = 51;
        conditions.maxExecutionDelay = daysToBlocks(7, helperConfig.getBlocksPerHour(block.chainid));
        constitution.push(
            PowersTypes.MandateInitData({
                nameDescription: "Elect Committee: Stakers peer-vote to elect up to 3 Rate Committee members from the nominee pool. One-time election; revokes itself after execution.",
                targetMandate: registry.getMandateAddress(MAJOR, MINOR, PATCH, "PeerSelect"),
                config: abi.encode(uint8(3), uint256(2), address(committeeNominees)),
                conditions: conditions
            })
        );
        delete conditions;

        ////////////////////////////////////////////////////////////////////////
        //                  FLOW 3: ADMIN ROLE ADMINISTRATION                 //
        ////////////////////////////////////////////////////////////////////////
        // Generic Admin assign/revoke — covers Guardian(3), Compliance Monitor(4),
        // and genesis Staker(1) seeding so the peer elections can bootstrap.
        {
            uint16[] memory ids = new uint16[](2);
            ids[0] = mandateCount + 1;
            ids[1] = mandateCount + 2;
            flows.push(PowersTypes.Flow({ mandateIds: ids, nameDescription: "Admin Role Administration: Admin assigns or revokes Guardian, Compliance Monitor, and genesis Staker roles." }));
        }

        string[] memory roleParams = new string[](2);
        roleParams[0] = "uint256 roleId";
        roleParams[1] = "address account";

        // Admin assigns a role.
        mandateCount++;
        conditions.allowedRole = 0; // Admin
        constitution.push(
            PowersTypes.MandateInitData({
                nameDescription: "Admin Assign Role: Admin assigns a role (Guardian, Compliance Monitor, or genesis Staker) to an account.",
                targetMandate: registry.getMandateAddress(MAJOR, MINOR, PATCH, "BespokeAction_Simple"),
                config: abi.encode(address(powers), IPowers.assignRole.selector, roleParams),
                conditions: conditions
            })
        );
        delete conditions;

        // Admin revokes a role.
        mandateCount++;
        conditions.allowedRole = 0; // Admin
        conditions.needFulfilled = mandateCount - 1; // must have assigned first
        constitution.push(
            PowersTypes.MandateInitData({
                nameDescription: "Admin Revoke Role: Admin revokes a previously assigned role from an account.",
                targetMandate: registry.getMandateAddress(MAJOR, MINOR, PATCH, "BespokeAction_Simple"),
                config: abi.encode(address(powers), IPowers.revokeRole.selector, roleParams),
                conditions: conditions
            })
        );
        delete conditions;

        ////////////////////////////////////////////////////////////////////////
        //                      FLOW 4: SET REWARD RATE                       //
        ////////////////////////////////////////////////////////////////////////
        // Committee proposes → Stakers may veto (fast window) → timelock → execute.
        {
            uint16[] memory ids = new uint16[](3);
            ids[0] = mandateCount + 1;
            ids[1] = mandateCount + 2;
            ids[2] = mandateCount + 3;
            flows.push(PowersTypes.Flow({ mandateIds: ids, nameDescription: "Set Reward Rate: Committee proposes a new APR, Stakers can veto, timelock then execute." }));
        }

        string[] memory rateParams = new string[](1);
        rateParams[0] = "uint256 NewRate";

        // Propose a new reward rate (Committee vote).
        mandateCount++;
        conditions.allowedRole = 2; // Rate Committee
        conditions.votingPeriod = daysToBlocks(7, helperConfig.getBlocksPerHour(block.chainid));
        conditions.quorum = 30;
        conditions.succeedAt = 51;
        constitution.push(
            PowersTypes.MandateInitData({
                nameDescription: "Propose Reward Rate: The Rate Committee votes to propose a new per-token per-second reward rate.",
                targetMandate: registry.getMandateAddress(MAJOR, MINOR, PATCH, "StatementOfIntent"),
                config: abi.encode(rateParams),
                conditions: conditions
            })
        );
        delete conditions;

        // Veto a proposed rate (Stakers, fast window — Carlisle rapid-access).
        mandateCount++;
        conditions.allowedRole = 1; // Stakers
        conditions.votingPeriod = daysToBlocks(1, helperConfig.getBlocksPerHour(block.chainid)); // ~24h
        conditions.quorum = 30;
        conditions.succeedAt = 51;
        conditions.needFulfilled = mandateCount - 1; // proposal must have passed first
        constitution.push(
            PowersTypes.MandateInitData({
                nameDescription: "Veto Reward Rate: Stakers vote within the veto window to block a proposed reward-rate change.",
                targetMandate: registry.getMandateAddress(MAJOR, MINOR, PATCH, "StatementOfIntent"),
                config: abi.encode(rateParams),
                conditions: conditions
            })
        );
        delete conditions;

        // Execute the rate change (Committee; timelock > veto window).
        mandateCount++;
        conditions.allowedRole = 2; // Rate Committee
        conditions.needFulfilled = mandateCount - 2; // proposal fulfilled
        conditions.needNotFulfilled = mandateCount - 1; // veto NOT fulfilled
        conditions.timelock = daysToBlocks(2, helperConfig.getBlocksPerHour(block.chainid)); // 48h > 24h veto window
        constitution.push(
            PowersTypes.MandateInitData({
                nameDescription: "Execute Reward Rate: Set the approved reward rate on the staking pool after the veto window and timelock.",
                targetMandate: registry.getMandateAddress(MAJOR, MINOR, PATCH, "BespokeAction_Simple"),
                config: abi.encode(address(pool), bytes4(keccak256("setRewardRate(uint256)")), rateParams),
                conditions: conditions
            })
        );
        delete conditions;

        ////////////////////////////////////////////////////////////////////////
        //                  FLOW 5: EMERGENCY PAUSE / UN-PAUSE                //
        ////////////////////////////////////////////////////////////////////////
        // Guardian OR Compliance Monitor can pause instantly (one-directional).
        // Lifting the pause is a deliberate Staker vote.
        {
            uint16[] memory ids = new uint16[](3);
            ids[0] = mandateCount + 1;
            ids[1] = mandateCount + 2;
            ids[2] = mandateCount + 3;
            flows.push(PowersTypes.Flow({ mandateIds: ids, nameDescription: "Emergency Pause / Un-pause: Guardian or Monitor pauses instantly; Stakers vote to un-pause." }));
        }

        bytes4 setPausedSelector = bytes4(keccak256("setPaused(bool)"));
        string[] memory noParams = new string[](0);

        // Guardian instant pause (paused=true baked in; can ONLY pause).
        mandateCount++;
        conditions.allowedRole = 3; // Guardian — no vote, no timelock
        constitution.push(
            PowersTypes.MandateInitData({
                nameDescription: "Guardian Pause: The Guardian instantly halts new staking (emergency circuit-breaker).",
                targetMandate: registry.getMandateAddress(MAJOR, MINOR, PATCH, "BespokeAction_Advanced"),
                config: abi.encode(address(pool), setPausedSelector, abi.encode(true), noParams, bytes("")),
                conditions: conditions
            })
        );
        delete conditions;

        // Compliance Monitor instant pause (shared trip on a compliance finding).
        mandateCount++;
        conditions.allowedRole = 4; // Compliance Monitor — no vote, no timelock
        constitution.push(
            PowersTypes.MandateInitData({
                nameDescription: "Monitor Pause: The Compliance Monitor instantly halts new staking on a compliance finding.",
                targetMandate: registry.getMandateAddress(MAJOR, MINOR, PATCH, "BespokeAction_Advanced"),
                config: abi.encode(address(pool), setPausedSelector, abi.encode(true), noParams, bytes("")),
                conditions: conditions
            })
        );
        delete conditions;

        // Community un-pause (Stakers vote; deliberate).
        mandateCount++;
        conditions.allowedRole = 1; // Stakers
        conditions.votingPeriod = daysToBlocks(2, helperConfig.getBlocksPerHour(block.chainid));
        conditions.quorum = 30;
        conditions.succeedAt = 51;
        constitution.push(
            PowersTypes.MandateInitData({
                nameDescription: "Community Un-pause: Stakers vote to resume staking after a pause.",
                targetMandate: registry.getMandateAddress(MAJOR, MINOR, PATCH, "BespokeAction_Advanced"),
                config: abi.encode(address(pool), setPausedSelector, abi.encode(false), noParams, bytes("")),
                conditions: conditions
            })
        );
        delete conditions;

        ////////////////////////////////////////////////////////////////////////
        //                    FLOW 6: COMPLIANCE MONITORING                   //
        ////////////////////////////////////////////////////////////////////////
        // Signal-only: the Monitor records on-chain compliance findings.
        {
            uint16[] memory ids = new uint16[](1);
            ids[0] = mandateCount + 1;
            flows.push(PowersTypes.Flow({ mandateIds: ids, nameDescription: "Compliance Monitoring: The Compliance Monitor records on-chain compliance flags (signal-only, no execution)." }));
        }

        string[] memory flagParams = new string[](2);
        flagParams[0] = "string Finding";
        flagParams[1] = "address Subject";

        mandateCount++;
        conditions.allowedRole = 4; // Compliance Monitor
        constitution.push(
            PowersTypes.MandateInitData({
                nameDescription: "Raise Compliance Flag: The Compliance Monitor records a compliance finding on-chain. Signal-only; no execution.",
                targetMandate: registry.getMandateAddress(MAJOR, MINOR, PATCH, "StatementOfIntent"),
                config: abi.encode(flagParams),
                conditions: conditions
            })
        );
        delete conditions;

        ////////////////////////////////////////////////////////////////////////
        //                       FLOW 7: SWEEP STRAY TOKENS                   //
        ////////////////////////////////////////////////////////////////////////
        // Highest-risk. Committee proposes → Stakers may veto → long timelock.
        {
            uint16[] memory ids = new uint16[](3);
            ids[0] = mandateCount + 1;
            ids[1] = mandateCount + 2;
            ids[2] = mandateCount + 3;
            flows.push(PowersTypes.Flow({ mandateIds: ids, nameDescription: "Sweep Stray Tokens: Committee proposes a sweep, Stakers can veto, long timelock then execute." }));
        }

        string[] memory sweepParams = new string[](3);
        sweepParams[0] = "address Token";
        sweepParams[1] = "address To";
        sweepParams[2] = "uint256 Amount";

        // Propose a sweep (Committee vote).
        mandateCount++;
        conditions.allowedRole = 2; // Rate Committee
        conditions.votingPeriod = daysToBlocks(7, helperConfig.getBlocksPerHour(block.chainid));
        conditions.quorum = 30;
        conditions.succeedAt = 51;
        constitution.push(
            PowersTypes.MandateInitData({
                nameDescription: "Propose Sweep: The Rate Committee votes to propose sweeping stray tokens out of the staking pool.",
                targetMandate: registry.getMandateAddress(MAJOR, MINOR, PATCH, "StatementOfIntent"),
                config: abi.encode(sweepParams),
                conditions: conditions
            })
        );
        delete conditions;

        // Veto a sweep (Stakers).
        mandateCount++;
        conditions.allowedRole = 1; // Stakers
        conditions.votingPeriod = daysToBlocks(2, helperConfig.getBlocksPerHour(block.chainid));
        conditions.quorum = 30;
        conditions.succeedAt = 51;
        conditions.needFulfilled = mandateCount - 1;
        constitution.push(
            PowersTypes.MandateInitData({
                nameDescription: "Veto Sweep: Stakers vote within the veto window to block a proposed token sweep.",
                targetMandate: registry.getMandateAddress(MAJOR, MINOR, PATCH, "StatementOfIntent"),
                config: abi.encode(sweepParams),
                conditions: conditions
            })
        );
        delete conditions;

        // Execute the sweep (Committee; extra-long timelock).
        mandateCount++;
        conditions.allowedRole = 2; // Rate Committee
        conditions.needFulfilled = mandateCount - 2;
        conditions.needNotFulfilled = mandateCount - 1;
        conditions.timelock = daysToBlocks(7, helperConfig.getBlocksPerHour(block.chainid)); // extra-long
        constitution.push(
            PowersTypes.MandateInitData({
                nameDescription: "Execute Sweep: Sweep the approved tokens out of the staking pool after the veto window and long timelock.",
                targetMandate: registry.getMandateAddress(MAJOR, MINOR, PATCH, "BespokeAction_Simple"),
                config: abi.encode(address(pool), bytes4(keccak256("sweep(address,address,uint256)")), sweepParams),
                conditions: conditions
            })
        );
        delete conditions;

        ////////////////////////////////////////////////////////////////////////
        //                       FLOW 8: GOVERNANCE REFORM                    //
        ////////////////////////////////////////////////////////////////////////
        // Ostrom DP3 — the affected role (Stakers) governs reform, highest bar.
        {
            uint16[] memory ids = new uint16[](2);
            ids[0] = mandateCount + 1;
            ids[1] = mandateCount + 2;
            flows.push(PowersTypes.Flow({ mandateIds: ids, nameDescription: "Governance Reform: Stakers propose and adopt new governance mandates." }));
        }

        string[] memory reformParams = new string[](2);
        reformParams[0] = "address[] Mandates";
        reformParams[1] = "uint256[] RoleIds";

        // Propose reform (Stakers, supermajority).
        mandateCount++;
        conditions.allowedRole = 1; // Stakers
        conditions.votingPeriod = daysToBlocks(14, helperConfig.getBlocksPerHour(block.chainid));
        conditions.quorum = 50;
        conditions.succeedAt = 66;
        conditions.maxExecutionDelay = daysToBlocks(14, helperConfig.getBlocksPerHour(block.chainid));
        constitution.push(
            PowersTypes.MandateInitData({
                nameDescription: "Propose Governance Reform: Stakers vote (supermajority) to adopt new governance mandates.",
                targetMandate: registry.getMandateAddress(MAJOR, MINOR, PATCH, "StatementOfIntent"),
                config: abi.encode(reformParams),
                conditions: conditions
            })
        );
        delete conditions;

        // Adopt mandates (Stakers, timelock).
        mandateCount++;
        conditions.allowedRole = 1; // Stakers
        conditions.needFulfilled = mandateCount - 1;
        conditions.timelock = daysToBlocks(15, helperConfig.getBlocksPerHour(block.chainid));
        constitution.push(
            PowersTypes.MandateInitData({
                nameDescription: "Adopt New Mandates: Execute an approved governance reform by adopting the proposed mandates.",
                targetMandate: registry.getMandateAddress(MAJOR, MINOR, PATCH, "Adopt_Mandates"),
                config: abi.encode(),
                conditions: conditions
            })
        );
        delete conditions;

        ////////////////////////////////////////////////////////////////////////
        //                     FLOW 9: FUND PAYMASTER (AA)                    //
        ////////////////////////////////////////////////////////////////////////
        {
            uint16[] memory ids = new uint16[](2);
            ids[0] = mandateCount + 1;
            ids[1] = mandateCount + 2;
            flows.push(PowersTypes.Flow({ mandateIds: ids, nameDescription: "Fund Paymaster: Propose and execute an ETH top-up of the gasless paymaster." }));
        }

        // Propose to fund the paymaster (Committee).
        mandateCount++;
        conditions.allowedRole = 2; // Rate Committee
        constitution.push(
            PowersTypes.MandateInitData({
                nameDescription: "Propose to Fund Paymaster: Propose an ETH transfer that tops up the gasless paymaster.",
                targetMandate: registry.getMandateAddress(MAJOR, MINOR, PATCH, "StatementOfIntent"),
                config: abi.encode(),
                conditions: conditions
            })
        );
        delete conditions;

        // Execute the paymaster funding (fixed 0.05 ETH to paymaster.deposit()).
        targets = new address[](1);
        values = new uint256[](1);
        calldatas = new bytes[](1);
        targets[0] = address(powersPaymaster);
        values[0] = PAYMASTER_SEED;
        calldatas[0] = abi.encodeWithSignature("deposit()");

        mandateCount++;
        conditions.allowedRole = 2; // Rate Committee
        conditions.votingPeriod = daysToBlocks(1, helperConfig.getBlocksPerHour(block.chainid));
        conditions.quorum = 30;
        conditions.succeedAt = 51;
        conditions.needFulfilled = mandateCount - 1;
        constitution.push(
            PowersTypes.MandateInitData({
                nameDescription: "Execute Fund Paymaster: Send 0.05 ETH from the treasury to the paymaster deposit.",
                targetMandate: registry.getMandateAddress(MAJOR, MINOR, PATCH, "PresetActions"),
                config: abi.encode(targets, values, calldatas),
                conditions: conditions
            })
        );
        delete conditions;

        ////////////////////////////////////////////////////////////////////////
        //                   FLOW 10: WITHDRAW FROM PAYMASTER (AA)            //
        ////////////////////////////////////////////////////////////////////////
        {
            uint16[] memory ids = new uint16[](2);
            ids[0] = mandateCount + 1;
            ids[1] = mandateCount + 2;
            flows.push(PowersTypes.Flow({ mandateIds: ids, nameDescription: "Withdraw from Paymaster: Propose and execute an ETH withdrawal from the paymaster." }));
        }

        string[] memory withdrawParams = new string[](2);
        withdrawParams[0] = "address withdrawAddress";
        withdrawParams[1] = "uint256 amount";

        // Propose to withdraw from the paymaster (Committee).
        mandateCount++;
        conditions.allowedRole = 2; // Rate Committee
        constitution.push(
            PowersTypes.MandateInitData({
                nameDescription: "Propose to Withdraw from Paymaster: Propose withdrawing ETH from the paymaster back to the treasury.",
                targetMandate: registry.getMandateAddress(MAJOR, MINOR, PATCH, "StatementOfIntent"),
                config: abi.encode(withdrawParams),
                conditions: conditions
            })
        );
        delete conditions;

        // Execute the withdrawal (Committee vote).
        mandateCount++;
        conditions.allowedRole = 2; // Rate Committee
        conditions.votingPeriod = daysToBlocks(1, helperConfig.getBlocksPerHour(block.chainid));
        conditions.quorum = 30;
        conditions.succeedAt = 51;
        conditions.needFulfilled = mandateCount - 1;
        constitution.push(
            PowersTypes.MandateInitData({
                nameDescription: "Execute Withdraw from Paymaster: Execute the proposed ETH withdrawal from the paymaster.",
                targetMandate: registry.getMandateAddress(MAJOR, MINOR, PATCH, "BespokeAction_Simple"),
                config: abi.encode(address(powersPaymaster), bytes4(keccak256("withdrawTo(address,uint256)")), withdrawParams),
                conditions: conditions
            })
        );
        delete conditions;

        return constitution.length;
    }
}
