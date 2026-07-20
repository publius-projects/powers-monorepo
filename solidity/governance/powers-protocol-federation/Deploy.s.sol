// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

// ─── Scripts / helpers ────────────────────────────────────────────────────────
import { console2 } from "forge-std/console2.sol";
import { Configurations } from "@script/Configurations.s.sol";
import { DeployHelpers } from "@governance/DeployHelpers.s.sol";
import { IMandateRegistry } from "@src/core/helpers/MandateRegistry.sol";
import { MandateRegistry } from "@src/core/helpers/MandateRegistry.sol";

// ─── Powers protocol ──────────────────────────────────────────────────────────
import { PowersTypes } from "@src/interfaces/PowersTypes.sol";
import { Powers } from "@src/Powers.sol";
import { IPowers } from "@src/interfaces/IPowers.sol";

// ─── Helper contracts ─────────────────────────────────────────────────────────
import { Nominees } from "@src/core/helpers/Nominees.sol";
import { PowersPaymaster } from "@src/core/helpers/PowersPaymaster.sol";
import { IEntryPoint } from "@lib/account-abstraction/contracts/interfaces/IEntryPoint.sol";

/// @title Powers Protocol Federation - Deployment Script
/// @notice Deploys three interlocking Powers organisations in one shot:
///         Endowment Governance, Core Governance and Mandates Governance.
///         They are co-deployed because each needs the others' addresses (and
///         some cross-organisation mandate IDs) to wire the funding ring.
///
/// Build order matters: Endowment first (its veto + income-stream mandate IDs are
/// referenced by Core), then Core (its "fund Mandates" mandate ID is referenced by
/// Mandates), then Mandates.
contract Deploy is DeployHelpers {
    // ── Shared build scratch (reset between organisations) ─────────────────────
    Configurations helperConfig;
    IMandateRegistry registry;
    PowersTypes.MandateInitData[] constitution;
    PowersTypes.Conditions conditions;
    PowersTypes.Flow[] flows;

    address[] targets;
    uint256[] values;
    bytes[] calldatas;
    string[] inputParams;
    string[] dynamicParams;

    // ── The three organisations ────────────────────────────────────────────────
    Powers corePowers;
    Powers mandatesPowers;
    Powers endowmentPowers;

    // ── Per-organisation helpers ───────────────────────────────────────────────
    // One central paymaster, owned & funded by Core, sponsors gas for all three orgs.
    PowersPaymaster centralPaymaster;
    MandateRegistry mandatesOwnedRegistry;   // the registry that Mandates Governance governs

    Nominees coreMemberNominees;
    Nominees coreCouncilNominees;
    Nominees mandatesAssessorNominees;
    Nominees mandatesCouncilNominees;
    Nominees endowmentInvestorNominees;

    // ── Cross-organisation mandate IDs (captured while building) ───────────────
    uint16 endowmentInvestVetoMandateId;   // Endowment E1 step 2 - Core casts its veto here
    uint16 endowmentStreamMandateId;        // Endowment E3 - Core draws the income stream here
    uint16 coreFundMandatesStep2Id;         // Core C4 step 2 - Mandates requests its budget here

    // ── Constants ────────────────────────────────────────────────────────────────
    // Mandate versions are no longer pinned here: _push resolves each mandate to its
    // latest registered version on the canonical registry (see _push / getLatestVersion).

    address constant ENTRY_POINT = 0x0000000071727De22E5E9d8BAf0edAc6f37da032;
    uint256 constant PAYMASTER_SEED = 0.05 ether;

    // Ethereum Sepolia external addresses (verified against aave-address-book: AaveV3Sepolia).
    address constant AAVE_POOL = 0x6Ae43d3271ff6888e7Fc43Fd7321a503ff738951;
    address constant USDC = 0x94a9D9AC8a22534E3FaCa9F4e7F2E2cf85d5E4C8;
    address constant WETH = 0xC558DBdd856501FCd9aaF1E62eae57A9F0629a3c;

    // Endowment → Core recurring income stream: a fixed 100 USDC (6 decimals) per period.
    uint256 constant STREAM_AMOUNT = 100e6;

    function run() external returns (Powers core, Powers mandates, Powers endowment) {
        helperConfig = new Configurations();
        registry = IMandateRegistry(helperConfig.getMandateRegistry(block.chainid));

        // ── Deploy all contracts up front so every address is known ────────────
        vm.startBroadcast();
        // Three Powers instances (metadata URI left blank - see TODO below).
        endowmentPowers = _newPowers("Powers Protocol - Endowment Governance");
        corePowers = _newPowers("Powers Protocol - Core Governance");
        mandatesPowers = _newPowers("Powers Protocol - Mandates Governance");

        // One central paymaster owned by Core (constructor transfers ownership to corePowers),
        // seeded with the whole federation's gas budget. Core adds the other two orgs as
        // sponsored targets in its SETUP mandate; the frontend points every org's
        // Powers.paymaster() at this same contract.
        centralPaymaster = new PowersPaymaster(IEntryPoint(ENTRY_POINT), address(corePowers));
        centralPaymaster.deposit{ value: 3 * PAYMASTER_SEED }();

        // The registry that Mandates Governance is intended to govern: the existing canonical
        // MandateRegistry taken from configuration (same address the orgs constitute from), rather
        // than a fresh throwaway deployment. Its owner-only calls (paid-tier config, register/
        // deactivate, withdraw earnings) will revert until its ownership is transferred to
        // mandatesPowers out-of-band — see README "Mandate registry model".
        mandatesOwnedRegistry = MandateRegistry(helperConfig.getMandateRegistry(block.chainid));

        // Nominees registries backing each election (owned by the deployer for now).
        endowmentInvestorNominees = new Nominees();
        coreMemberNominees = new Nominees();
        coreCouncilNominees = new Nominees();
        mandatesAssessorNominees = new Nominees();
        mandatesCouncilNominees = new Nominees();
        vm.stopBroadcast();

        console2.log("Endowment Governance deployed at:", address(endowmentPowers));
        console2.log("Core Governance deployed at:", address(corePowers));
        console2.log("Mandates Governance deployed at:", address(mandatesPowers));
        console2.log("Central PowersPaymaster (Core-owned) deployed at:", address(centralPaymaster));
        console2.log("Mandates-governed MandateRegistry (from config) at:", address(mandatesOwnedRegistry));

        // ── Constitute Endowment (first: exposes cross-org mandate IDs) ────────
        _resetBuild();
        buildEndowment();
        vm.startBroadcast();
        endowmentPowers.constitute(constitution);
        endowmentPowers.closeConstitute(msg.sender, flows);
        endowmentInvestorNominees.transferOwnership(address(endowmentPowers));
        vm.stopBroadcast();
        console2.log("Endowment Governance constituted.");

        // ── Constitute Core (references Endowment IDs) ─────────────────────────
        _resetBuild();
        buildCore();
        vm.startBroadcast();
        corePowers.constitute(constitution);
        corePowers.closeConstitute(msg.sender, flows);
        coreMemberNominees.transferOwnership(address(corePowers));
        coreCouncilNominees.transferOwnership(address(corePowers));
        vm.stopBroadcast();
        console2.log("Core Governance constituted.");

        // ── Constitute Mandates (references Core IDs) ──────────────────────────
        _resetBuild();
        buildMandates();
        vm.startBroadcast();
        mandatesPowers.constitute(constitution);
        mandatesPowers.closeConstitute(msg.sender, flows);
        mandatesAssessorNominees.transferOwnership(address(mandatesPowers));
        mandatesCouncilNominees.transferOwnership(address(mandatesPowers));
        vm.stopBroadcast();
        console2.log("Mandates Governance constituted.");

        return (corePowers, mandatesPowers, endowmentPowers);
    }

    // ═══════════════════════════════════════════════════════════════════════════
    //                           ENDOWMENT GOVERNANCE
    // ═══════════════════════════════════════════════════════════════════════════
    function buildEndowment() internal {
        uint16 mandateCount = 0;

        // ── SETUP (id 1): labels, cross-org Core seat, founding investors,
        //    standing Aave approvals, treasury + paymaster wiring, then self-revoke.
        //    Note: this org is added to the central paymaster's sponsored targets by
        //    Core's SETUP mandate (Core owns the paymaster), not here.
        targets = new address[](13);
        values = new uint256[](13);
        calldatas = new bytes[](13);
        for (uint256 i = 0; i < targets.length; i++) targets[i] = address(endowmentPowers);
        calldatas[0] = abi.encodeWithSelector(IPowers.labelRole.selector, 0, "Admin", "");
        calldatas[1] = abi.encodeWithSelector(IPowers.labelRole.selector, type(uint256).max, "Public", "");
        calldatas[2] = abi.encodeWithSelector(IPowers.labelRole.selector, 1, "Endowment Investor", "");
        calldatas[3] = abi.encodeWithSelector(IPowers.labelRole.selector, 2, "Core Beneficiary", "");
        // Cross-org seat: the Core Powers contract holds role 2 here.
        calldatas[4] = abi.encodeWithSelector(IPowers.assignRole.selector, 2, address(corePowers));
        // Founding investor cohort (tune/remove before a live deploy).
        calldatas[5] = abi.encodeWithSelector(IPowers.assignRole.selector, 1, testAccount1);
        calldatas[6] = abi.encodeWithSelector(IPowers.assignRole.selector, 1, testAccount2);
        calldatas[7] = abi.encodeWithSelector(IPowers.assignRole.selector, 1, testAccount3);
        // Standing max approvals so Aave supply() can pull tokens in one step.
        targets[8] = USDC;
        calldatas[8] = abi.encodeWithSignature("approve(address,uint256)", AAVE_POOL, type(uint256).max);
        targets[9] = WETH;
        calldatas[9] = abi.encodeWithSignature("approve(address,uint256)", AAVE_POOL, type(uint256).max);
        calldatas[10] = abi.encodeWithSelector(IPowers.setTreasury.selector, address(endowmentPowers));
        calldatas[11] = abi.encodeWithSelector(IPowers.setPaymaster.selector, address(centralPaymaster));
        calldatas[12] = abi.encodeWithSelector(IPowers.revokeMandate.selector, mandateCount + 1);

        mandateCount++;
        conditions.allowedRole = type(uint256).max;
        _push("Initial Setup: Assign role labels and revokes itself after execution", "PresetActions", abi.encode(targets, values, calldatas));

        // ── FLOW: Elect Endowment Investors (Nominate → PeerSelect) ────────────
        _flow3(mandateCount + 1, mandateCount + 2, mandateCount + 2, "Elect Investors: Nominate and peer-elect the Endowment Investor role.", false);
        mandateCount++;
        conditions.allowedRole = type(uint256).max; // anyone may stand
        _push("Nominate for Endowment Investor: Any account nominates itself as an investor candidate.", "Nominate", abi.encode(address(endowmentInvestorNominees)));
        mandateCount++;
        conditions.allowedRole = 1;
        conditions.votingPeriod = _mins(5);
        conditions.quorum = 50;
        conditions.succeedAt = 66;
        _push("Elect Endowment Investors: Investors peer-vote candidates into role 1 (one-time election).", "PeerSelect", abi.encode(uint8(3), uint256(1), address(endowmentInvestorNominees)));

        // ── FLOW E1: Invest - Supply to Aave (with Core organisational veto) ───
        _flow3(mandateCount + 1, mandateCount + 2, mandateCount + 3, "Endowment E1 - Invest: Propose, allow a Core veto window, then supply to Aave.", true);
        // step 1: propose (Investor vote)
        inputParams = _p2("address Asset", "uint256 Amount");
        mandateCount++;
        conditions.allowedRole = 1;
        conditions.votingPeriod = _mins(5);
        conditions.quorum = 50;
        conditions.succeedAt = 66;
        _push("Propose Aave Investment: Investors propose supplying an asset to the Aave v3 pool.", "StatementOfIntent", abi.encode(inputParams));
        // step 2: Core veto slot (only the Core Beneficiary seat can call)
        mandateCount++;
        endowmentInvestVetoMandateId = mandateCount;
        conditions.allowedRole = 2;
        conditions.needFulfilled = mandateCount - 1;
        _push("Core Veto of Aave Investment: The Core organisation blocks a proposed investment.", "StatementOfIntent", abi.encode(inputParams));
        // step 3: execute supply (dynamic asset+amount, static onBehalfOf=self, referralCode=0)
        dynamicParams = _p2("address Asset", "uint256 Amount");
        mandateCount++;
        conditions.allowedRole = 1;
        conditions.needFulfilled = mandateCount - 2;
        conditions.needNotFulfilled = mandateCount - 1;
        conditions.timelock = _mins(15); // long enough to contain the full cross-org veto cycle
        _push(
            "Execute Aave Investment: Supply the approved asset to the Aave v3 pool if not vetoed.",
            "BespokeAction_Advanced",
            abi.encode(AAVE_POOL, bytes4(keccak256("supply(address,uint256,address,uint16)")), bytes(""), dynamicParams, abi.encode(address(endowmentPowers), uint16(0)))
        );

        // ── FLOW E2: Divest - Withdraw from Aave (no Core veto; exit stays fast)
        _flow2(mandateCount + 1, mandateCount + 2, "Endowment E2 - Divest: Propose and withdraw from Aave.");
        inputParams = _p2("address Asset", "uint256 Amount");
        mandateCount++;
        conditions.allowedRole = 1;
        conditions.votingPeriod = _mins(5);
        conditions.quorum = 50;
        conditions.succeedAt = 66;
        _push("Propose Aave Divestment: Investors propose withdrawing an asset from the Aave v3 pool.", "StatementOfIntent", abi.encode(inputParams));
        dynamicParams = _p2("address Asset", "uint256 Amount");
        mandateCount++;
        conditions.allowedRole = 1;
        conditions.needFulfilled = mandateCount - 1;
        conditions.timelock = _mins(3);
        _push(
            "Execute Aave Divestment: Withdraw the approved asset from the Aave v3 pool to the treasury.",
            "BespokeAction_Advanced",
            abi.encode(AAVE_POOL, bytes4(keccak256("withdraw(address,uint256,address)")), bytes(""), dynamicParams, abi.encode(address(endowmentPowers)))
        );

        // ── FLOW E3: Endowment Income Stream to Core (recurring, throttled) ────
        _flow1(mandateCount + 1, "Endowment E3 - Income Stream: A throttled fixed drip of USDC to Core Governance.");
        targets = new address[](1);
        values = new uint256[](1);
        calldatas = new bytes[](1);
        targets[0] = USDC;
        calldatas[0] = abi.encodeWithSignature("transfer(address,uint256)", address(corePowers), STREAM_AMOUNT);
        mandateCount++;
        endowmentStreamMandateId = mandateCount;
        conditions.allowedRole = 2; // Core Beneficiary draws it (via ExternalAction from Core)
        conditions.throttleExecution = _mins(10); // at most once per period
        _push("Draw Endowment Income Stream: Transfer the fixed per-period income to Core Governance.", "PresetActions", abi.encode(targets, values, calldatas));

        // ── FLOW E4: Treasury Transfer / Recover Tokens ───────────────────────
        _flow1(mandateCount + 1, "Endowment E4 - Recover: Governed transfer of any token the treasury holds.");
        mandateCount++;
        conditions.allowedRole = 1;
        conditions.votingPeriod = _mins(5);
        conditions.quorum = 50;
        conditions.succeedAt = 66;
        conditions.timelock = _mins(2);
        _push("Endowment Recover Tokens: Investors vote to move any token held by the treasury.", "OpenAction", abi.encode());

        // ── FLOW E5: Governance Reform (investors self-govern) ────────────────
        _flow2(mandateCount + 1, mandateCount + 2, "Endowment E5 - Reform: Propose and adopt new mandates.");
        // Must match Adopt_Mandates v0.2.0's declared input exactly: the propose (and veto)
        // steps are matched to the execute step by hashing the *same* mandateCalldata, so a
        // frontend rendering the wrong shape here produces a proposal that cannot be executed.
        inputParams = _p1(
            "(string,address,bytes,(uint256,uint32,uint32,uint32,uint16,uint16,uint8,uint8,uint32))[] mandateInitData"
        );
        mandateCount++;
        conditions.allowedRole = 1;
        conditions.votingPeriod = _mins(7);
        conditions.quorum = 50;
        conditions.succeedAt = 66;
        _push("Propose Endowment Reform: Investors vote to adopt new governance mandates.", "StatementOfIntent", abi.encode(inputParams));
        mandateCount++;
        conditions.allowedRole = 1;
        conditions.needFulfilled = mandateCount - 1;
        conditions.timelock = _mins(6);
        _push("Adopt Endowment Reform: Execute an approved endowment governance reform.", "Adopt_Mandates", abi.encode());

        // Paymaster funding is centralised in Core (Core owns the shared paymaster), so this
        // organisation has no Fund/Withdraw Paymaster flows of its own.
    }

    // ═══════════════════════════════════════════════════════════════════════════
    //                             CORE GOVERNANCE
    // ═══════════════════════════════════════════════════════════════════════════
    function buildCore() internal {
        uint16 mandateCount = 0;

        // ── SETUP (id 1) ───────────────────────────────────────────────────────
        // Core owns the central paymaster (constructor already lists corePowers as a
        // sponsored target), so this SETUP is where the two affiliate orgs get added.
        targets = new address[](16);
        values = new uint256[](16);
        calldatas = new bytes[](16);
        for (uint256 i = 0; i < targets.length; i++) targets[i] = address(corePowers);
        calldatas[0] = abi.encodeWithSelector(IPowers.labelRole.selector, 0, "Admin", "");
        calldatas[1] = abi.encodeWithSelector(IPowers.labelRole.selector, type(uint256).max, "Public", "");
        calldatas[2] = abi.encodeWithSelector(IPowers.labelRole.selector, 1, "Core Member", "");
        calldatas[3] = abi.encodeWithSelector(IPowers.labelRole.selector, 2, "Security Council", "");
        calldatas[4] = abi.encodeWithSelector(IPowers.labelRole.selector, 3, "Whitelisted Auditor", "");
        calldatas[5] = abi.encodeWithSelector(IPowers.labelRole.selector, 4, "Funded Sub-org", "");
        // Cross-org seat: the Mandates Powers contract holds role 4 here.
        calldatas[6] = abi.encodeWithSelector(IPowers.assignRole.selector, 4, address(mandatesPowers));
        // Founding member + council cohort.
        calldatas[7] = abi.encodeWithSelector(IPowers.assignRole.selector, 1, testAccount1);
        calldatas[8] = abi.encodeWithSelector(IPowers.assignRole.selector, 1, testAccount2);
        calldatas[9] = abi.encodeWithSelector(IPowers.assignRole.selector, 1, testAccount3);
        calldatas[10] = abi.encodeWithSelector(IPowers.assignRole.selector, 2, testAccount1);
        calldatas[11] = abi.encodeWithSelector(IPowers.setTreasury.selector, address(corePowers));
        calldatas[12] = abi.encodeWithSelector(IPowers.setPaymaster.selector, address(centralPaymaster));
        // Register the two affiliate orgs on the shared paymaster (corePowers is already
        // registered by the paymaster constructor).
        targets[13] = address(centralPaymaster);
        calldatas[13] = abi.encodeWithSelector(PowersPaymaster.addSponsoredTarget.selector, address(mandatesPowers));
        targets[14] = address(centralPaymaster);
        calldatas[14] = abi.encodeWithSelector(PowersPaymaster.addSponsoredTarget.selector, address(endowmentPowers));
        calldatas[15] = abi.encodeWithSelector(IPowers.revokeMandate.selector, mandateCount + 1);

        mandateCount++;
        conditions.allowedRole = type(uint256).max;
        _push("Initial Setup: Assign role labels and revokes itself after execution", "PresetActions", abi.encode(targets, values, calldatas));

        // ── FLOW 0: Elect Core Members ────────────────────────────────────────
        _flow2(mandateCount + 1, mandateCount + 2, "Elect Core Members: Nominate and peer-elect the Core Member role.");
        mandateCount++;
        conditions.allowedRole = type(uint256).max;
        _push("Nominate for Core Member: Any account nominates itself as a Core Member candidate.", "Nominate", abi.encode(address(coreMemberNominees)));
        mandateCount++;
        conditions.allowedRole = 1;
        conditions.votingPeriod = _mins(5);
        conditions.quorum = 50;
        conditions.succeedAt = 66;
        _push("Elect Core Members: Members peer-vote candidates into role 1 (one-time election).", "PeerSelect", abi.encode(uint8(5), uint256(1), address(coreMemberNominees)));

        // ── FLOW 1: Elect Security Council ────────────────────────────────────
        _flow2(mandateCount + 1, mandateCount + 2, "Elect Security Council: Members nominate and peer-elect the Council.");
        mandateCount++;
        conditions.allowedRole = 1;
        _push("Nominate for Security Council: Members nominate themselves for the Security Council.", "Nominate", abi.encode(address(coreCouncilNominees)));
        mandateCount++;
        conditions.allowedRole = 1;
        conditions.votingPeriod = _mins(5);
        conditions.quorum = 50;
        conditions.succeedAt = 66;
        _push("Elect Security Council: Members peer-vote 3 candidates into role 2 (one-time election).", "PeerSelect", abi.encode(uint8(3), uint256(2), address(coreCouncilNominees)));

        // ── FLOW 2 (C1): Pay Core-Development Invoice ─────────────────────────
        // Scope/reference for the invoice is carried in the proposal description text.
        _flow2(mandateCount + 1, mandateCount + 2, "Core C1 - Pay Invoice: Propose then pay a core-development invoice.");
        inputParams = _p2("address Recipient", "uint256 Amount");
        mandateCount++;
        conditions.allowedRole = 1;
        conditions.votingPeriod = _mins(5);
        conditions.quorum = 30;
        conditions.succeedAt = 51;
        _push("Propose Core Invoice: Members propose paying a core-development invoice (USDC).", "StatementOfIntent", abi.encode(inputParams));
        mandateCount++;
        conditions.allowedRole = 1;
        conditions.needFulfilled = mandateCount - 1;
        conditions.timelock = _mins(2);
        _push("Execute Core Invoice: Pay the approved core-development invoice in USDC.", "BespokeAction_Simple", abi.encode(USDC, bytes4(keccak256("transfer(address,uint256)")), inputParams));

        // ── FLOW 3 (C2): Whitelist / De-whitelist an Audit Organisation ───────
        _flow2(mandateCount + 1, mandateCount + 2, "Core C2 - Audit Whitelist: Assign or revoke the Whitelisted Auditor role.");
        dynamicParams = _p1("address Account");
        mandateCount++;
        conditions.allowedRole = 1;
        conditions.votingPeriod = _mins(5);
        conditions.quorum = 50;
        conditions.succeedAt = 66;
        _push("Whitelist Auditor: Members vote to grant the Whitelisted Auditor role (role 3).", "BespokeAction_Advanced", abi.encode(address(corePowers), IPowers.assignRole.selector, abi.encode(uint256(3)), dynamicParams, bytes("")));
        mandateCount++;
        conditions.allowedRole = 1;
        conditions.votingPeriod = _mins(5);
        conditions.quorum = 50;
        conditions.succeedAt = 66;
        _push("De-whitelist Auditor: Members vote to revoke the Whitelisted Auditor role (role 3).", "BespokeAction_Advanced", abi.encode(address(corePowers), IPowers.revokeRole.selector, abi.encode(uint256(3)), dynamicParams, bytes("")));

        // ── FLOW 4 (C3): Commission a Core Audit → Pay on Completion ──────────
        _flow2(mandateCount + 1, mandateCount + 2, "Core C3 - Audit: Commission a core audit then pay the auditor.");
        inputParams = _p2("address Auditor", "uint256 Fee");
        mandateCount++;
        conditions.allowedRole = 1;
        conditions.votingPeriod = _mins(5);
        conditions.quorum = 30;
        conditions.succeedAt = 51;
        _push("Commission Core Audit: Members propose commissioning a core-protocol audit.", "StatementOfIntent", abi.encode(inputParams));
        mandateCount++;
        conditions.allowedRole = 1;
        conditions.votingPeriod = _mins(5);
        conditions.quorum = 30;
        conditions.succeedAt = 51;
        conditions.needFulfilled = mandateCount - 1;
        conditions.timelock = _mins(2);
        _push("Pay Core Auditor: Pay the commissioned auditor in USDC after completion.", "BespokeAction_Simple", abi.encode(USDC, bytes4(keccak256("transfer(address,uint256)")), inputParams));

        // ── FLOW 5 (C4): Fund the Mandates Organisation (cross-org, receiving) ─
        _flow2(mandateCount + 1, mandateCount + 2, "Core C4 - Fund Mandates: Ratify then transfer a budget to the Mandates organisation.");
        inputParams = _p2("address To", "uint256 Amount");
        mandateCount++;
        conditions.allowedRole = 1;
        conditions.votingPeriod = _mins(5);
        conditions.quorum = 50;
        conditions.succeedAt = 51;
        _push("Ratify Mandates Budget: Core Members ratify a funding transfer to the Mandates treasury.", "StatementOfIntent", abi.encode(inputParams));
        mandateCount++;
        coreFundMandatesStep2Id = mandateCount;
        conditions.allowedRole = 4; // the Mandates Powers contract triggers this via ExternalAction
        conditions.needFulfilled = mandateCount - 1;
        conditions.timelock = _mins(1);
        _push("Transfer Mandates Budget: Send the ratified USDC budget to the Mandates treasury.", "BespokeAction_Simple", abi.encode(USDC, bytes4(keccak256("transfer(address,uint256)")), inputParams));

        // ── FLOW 6 (C5): Emergency Pause / Restart Core Funding Flows ─────────
        // Targets the execute mandates of C1 (flow 2, pos 1), C3 (flow 4, pos 1), C4 (flow 5, pos 1).
        _flow1(mandateCount + 1, "Core C5 - Emergency Pause: The Security Council pauses or restarts the funding flows.");
        uint8[] memory pauseFlows = new uint8[](3);
        uint8[] memory pauseMandates = new uint8[](3);
        pauseFlows[0] = 2; pauseMandates[0] = 1; // C1 execute
        pauseFlows[1] = 4; pauseMandates[1] = 1; // C3 pay
        pauseFlows[2] = 5; pauseMandates[2] = 1; // C4 transfer
        mandateCount++;
        conditions.allowedRole = 2; // Security Council, instant
        _push("Pause Core Funding: The Security Council pauses (or restarts) the C1/C3/C4 execute mandates.", "PauseMandates", abi.encode(pauseFlows, pauseMandates));

        // ── FLOW 7 (C6): Treasury Transfer / Recover Tokens ───────────────────
        _flow1(mandateCount + 1, "Core C6 - Recover: Governed transfer of any token the treasury holds.");
        mandateCount++;
        conditions.allowedRole = 1;
        conditions.votingPeriod = _mins(5);
        conditions.quorum = 50;
        conditions.succeedAt = 66;
        conditions.timelock = _mins(2);
        _push("Core Recover Tokens: Members vote to move any token held by the treasury.", "OpenAction", abi.encode());

        // ── FLOW 8 (C7): Governance Reform (Security Council veto) ────────────
        _flow3(mandateCount + 1, mandateCount + 2, mandateCount + 3, "Core C7 - Reform: Propose, allow a Council veto, then adopt new mandates.", true);
        // Must match Adopt_Mandates v0.2.0's declared input exactly: the propose (and veto)
        // steps are matched to the execute step by hashing the *same* mandateCalldata, so a
        // frontend rendering the wrong shape here produces a proposal that cannot be executed.
        inputParams = _p1(
            "(string,address,bytes,(uint256,uint32,uint32,uint32,uint16,uint16,uint8,uint8,uint32))[] mandateInitData"
        );
        mandateCount++;
        conditions.allowedRole = 1;
        conditions.votingPeriod = _mins(7);
        conditions.quorum = 50;
        conditions.succeedAt = 66;
        _push("Propose Core Reform: Members vote to adopt new governance mandates.", "StatementOfIntent", abi.encode(inputParams));
        mandateCount++;
        conditions.allowedRole = 2;
        conditions.needFulfilled = mandateCount - 1;
        _push("Veto Core Reform: The Security Council blocks a proposed governance reform.", "StatementOfIntent", abi.encode(inputParams));
        mandateCount++;
        conditions.allowedRole = 1;
        conditions.needFulfilled = mandateCount - 2;
        conditions.needNotFulfilled = mandateCount - 1;
        conditions.timelock = _mins(6);
        _push("Adopt Core Reform: Execute an approved, un-vetoed governance reform.", "Adopt_Mandates", abi.encode());

        // ── FLOW 9 (C8): Draw Endowment Income (cross-org) ────────────────────
        _flow1(mandateCount + 1, "Core C8 - Draw Income: Collect the recurring income stream from the Endowment.");
        inputParams = new string[](0);
        mandateCount++;
        conditions.allowedRole = 1;
        _push("Draw Endowment Income: Core triggers the Endowment income stream into the Core treasury.", "ExternalAction_Simple", abi.encode(address(endowmentPowers), endowmentStreamMandateId, "Draw endowment income stream", inputParams));

        // ── FLOW 10 (C9): Veto an Endowment Investment (cross-org) ────────────
        _flow2(mandateCount + 1, mandateCount + 2, "Core C9 - Veto Investment: Decide then cast Core's veto over a new Endowment investment.");
        inputParams = _p2("address Asset", "uint256 Amount");
        mandateCount++;
        conditions.allowedRole = 1;
        conditions.votingPeriod = _mins(5);
        conditions.quorum = 30;
        conditions.succeedAt = 51;
        _push("Propose Investment Veto: Core Members vote to veto a proposed Endowment investment.", "StatementOfIntent", abi.encode(inputParams));
        mandateCount++;
        conditions.allowedRole = 1;
        conditions.needFulfilled = mandateCount - 1;
        _push("Cast Investment Veto: Fire Core's veto into the Endowment investment veto slot.", "ExternalAction_Simple", abi.encode(address(endowmentPowers), endowmentInvestVetoMandateId, "Core veto of endowment investment", inputParams));

        // ── FLOW 11/12: Fund + Withdraw the shared central Paymaster ──────────
        // Core owns the central paymaster, so it is the only org with these flows.
        mandateCount = _paymasterFlows(mandateCount, 1, address(centralPaymaster), "Core");
    }

    // ═══════════════════════════════════════════════════════════════════════════
    //                           MANDATES GOVERNANCE
    // ═══════════════════════════════════════════════════════════════════════════
    function buildMandates() internal {
        uint16 mandateCount = 0;

        // ── SETUP (id 1) ───────────────────────────────────────────────────────
        // Also seeds the mandates-owned registry's paid tier: setWeiPerCredit / setFeeBps
        // run here as mandatesPowers (the registry owner), so onlyOwner passes. Ongoing
        // changes go through the governed M8/M9 flows below.
        // Note: this org is added to the central paymaster's sponsored targets by Core's
        // SETUP mandate (Core owns the paymaster), not here.
        targets = new address[](12);
        values = new uint256[](12);
        calldatas = new bytes[](12);
        for (uint256 i = 0; i < targets.length; i++) targets[i] = address(mandatesPowers);
        calldatas[0] = abi.encodeWithSelector(IPowers.labelRole.selector, 0, "Admin", "");
        calldatas[1] = abi.encodeWithSelector(IPowers.labelRole.selector, type(uint256).max, "Public", "");
        calldatas[2] = abi.encodeWithSelector(IPowers.labelRole.selector, 1, "Mandate Assessor", "");
        calldatas[3] = abi.encodeWithSelector(IPowers.labelRole.selector, 2, "Security Council", "");
        calldatas[4] = abi.encodeWithSelector(IPowers.labelRole.selector, 3, "Whitelisted Auditor", "");
        calldatas[5] = abi.encodeWithSelector(IPowers.assignRole.selector, 1, testAccount1);
        calldatas[6] = abi.encodeWithSelector(IPowers.assignRole.selector, 1, testAccount2);
        calldatas[7] = abi.encodeWithSelector(IPowers.assignRole.selector, 1, testAccount3);
        calldatas[8] = abi.encodeWithSelector(IPowers.assignRole.selector, 2, testAccount1);
        calldatas[9] = abi.encodeWithSelector(IPowers.setTreasury.selector, address(mandatesPowers));
        calldatas[10] = abi.encodeWithSelector(IPowers.setPaymaster.selector, address(centralPaymaster));
        calldatas[11] = abi.encodeWithSelector(IPowers.revokeMandate.selector, mandateCount + 1);

        mandateCount++;
        conditions.allowedRole = type(uint256).max;
        _push("Initial Setup: Assign role labels and revokes itself after execution", "PresetActions", abi.encode(targets, values, calldatas));

        // ── FLOW 0: Elect Mandate Assessors ───────────────────────────────────
        _flow2(mandateCount + 1, mandateCount + 2, "Elect Mandate Assessors: Nominate and peer-elect the Assessor role.");
        mandateCount++;
        conditions.allowedRole = type(uint256).max;
        _push("Nominate for Mandate Assessor: Any account nominates itself as an Assessor candidate.", "Nominate", abi.encode(address(mandatesAssessorNominees)));
        mandateCount++;
        conditions.allowedRole = 1;
        conditions.votingPeriod = _mins(5);
        conditions.quorum = 50;
        conditions.succeedAt = 66;
        _push("Elect Mandate Assessors: Assessors peer-vote candidates into role 1 (one-time election).", "PeerSelect", abi.encode(uint8(5), uint256(1), address(mandatesAssessorNominees)));

        // ── FLOW 1: Elect Security Council ────────────────────────────────────
        _flow2(mandateCount + 1, mandateCount + 2, "Elect Mandates Security Council: Assessors nominate and peer-elect the Council.");
        mandateCount++;
        conditions.allowedRole = 1;
        _push("Nominate for Mandates Council: Assessors nominate themselves for the Security Council.", "Nominate", abi.encode(address(mandatesCouncilNominees)));
        mandateCount++;
        conditions.allowedRole = 1;
        conditions.votingPeriod = _mins(5);
        conditions.quorum = 50;
        conditions.succeedAt = 66;
        _push("Elect Mandates Council: Assessors peer-vote 3 candidates into role 2 (one-time election).", "PeerSelect", abi.encode(uint8(3), uint256(2), address(mandatesCouncilNominees)));

        // ── FLOW 2 (M1): Pay Mandate-Development Invoice ──────────────────────
        _flow2(mandateCount + 1, mandateCount + 2, "Mandates M1 - Pay Invoice: Propose then pay a mandate-development invoice.");
        inputParams = _p2("address Recipient", "uint256 Amount");
        mandateCount++;
        conditions.allowedRole = 1;
        conditions.votingPeriod = _mins(5);
        conditions.quorum = 30;
        conditions.succeedAt = 51;
        _push("Propose Mandate Invoice: Assessors propose paying a mandate-development invoice (USDC).", "StatementOfIntent", abi.encode(inputParams));
        mandateCount++;
        conditions.allowedRole = 1;
        conditions.needFulfilled = mandateCount - 1;
        conditions.timelock = _mins(2);
        _push("Execute Mandate Invoice: Pay the approved mandate-development invoice in USDC.", "BespokeAction_Simple", abi.encode(USDC, bytes4(keccak256("transfer(address,uint256)")), inputParams));

        // ── FLOW 3 (M2): Commission a Mandate Audit → Pay on Completion ───────
        _flow2(mandateCount + 1, mandateCount + 2, "Mandates M2 - Audit: Commission a mandate audit then pay the auditor.");
        inputParams = _p2("address Auditor", "uint256 Fee");
        mandateCount++;
        conditions.allowedRole = 1;
        conditions.votingPeriod = _mins(5);
        conditions.quorum = 30;
        conditions.succeedAt = 51;
        _push("Commission Mandate Audit: Assessors propose commissioning a mandate audit.", "StatementOfIntent", abi.encode(inputParams));
        mandateCount++;
        conditions.allowedRole = 1;
        conditions.needFulfilled = mandateCount - 1;
        conditions.timelock = _mins(2);
        _push("Pay Mandate Auditor: Pay the commissioned auditor in USDC after completion.", "BespokeAction_Simple", abi.encode(USDC, bytes4(keccak256("transfer(address,uint256)")), inputParams));

        // ── FLOW 4 (M3): Add a Mandate to the Registry (Council veto window) ──
        _flow3(mandateCount + 1, mandateCount + 2, mandateCount + 3, "Mandates M3 - Add to Registry: Propose, allow a Council veto, then register.", true);
        inputParams = new string[](3);
        inputParams[0] = "string MandateName";
        inputParams[1] = "address MandateAddress";
        inputParams[2] = "bytes32 CreationCodeHash";
        mandateCount++;
        conditions.allowedRole = 1;
        conditions.votingPeriod = _mins(5);
        conditions.quorum = 50;
        conditions.succeedAt = 66;
        _push("Propose Registry Addition: Assessors propose listing a mandate in the registry.", "StatementOfIntent", abi.encode(inputParams));
        mandateCount++;
        conditions.allowedRole = 2;
        conditions.needFulfilled = mandateCount - 1;
        _push("Veto Registry Addition: The Security Council blocks a proposed registry listing.", "StatementOfIntent", abi.encode(inputParams));
        mandateCount++;
        conditions.allowedRole = 1;
        conditions.needFulfilled = mandateCount - 2;
        conditions.needNotFulfilled = mandateCount - 1;
        conditions.timelock = _mins(6);
        _push("Execute Registry Addition: Register the approved, un-vetoed mandate in the registry.", "BespokeAction_Simple", abi.encode(address(mandatesOwnedRegistry), bytes4(keccak256("registerMandate(string,address,bytes32)")), inputParams));

        // ── FLOW 5 (M4): Remove a Mandate from the Registry ───────────────────
        _flow2(mandateCount + 1, mandateCount + 2, "Mandates M4 - Remove from Registry: Propose then deactivate a registry listing.");
        inputParams = new string[](4);
        inputParams[0] = "uint16 Major";
        inputParams[1] = "uint16 Minor";
        inputParams[2] = "uint16 Patch";
        inputParams[3] = "string MandateName";
        mandateCount++;
        conditions.allowedRole = 1;
        conditions.votingPeriod = _mins(5);
        conditions.quorum = 50;
        conditions.succeedAt = 66;
        _push("Propose Registry Removal: Assessors propose deactivating a registry listing.", "StatementOfIntent", abi.encode(inputParams));
        mandateCount++;
        conditions.allowedRole = 1;
        conditions.needFulfilled = mandateCount - 1;
        conditions.timelock = _mins(2);
        _push("Execute Registry Removal: Deactivate the approved mandate in the registry.", "BespokeAction_Simple", abi.encode(address(mandatesOwnedRegistry), bytes4(keccak256("deactivateMandate(uint16,uint16,uint16,string)")), inputParams));

        // ── FLOW 6 (M5): Request Funding from Core (cross-org, requesting) ────
        _flow2(mandateCount + 1, mandateCount + 2, "Mandates M5 - Request Funding: Decide an ask then request a budget from Core.");
        inputParams = _p2("address To", "uint256 Amount");
        mandateCount++;
        conditions.allowedRole = 1;
        conditions.votingPeriod = _mins(5);
        conditions.quorum = 50;
        conditions.succeedAt = 51;
        _push("Propose Funding Request: Assessors decide the budget to request from Core.", "StatementOfIntent", abi.encode(inputParams));
        mandateCount++;
        conditions.allowedRole = 1;
        conditions.needFulfilled = mandateCount - 1;
        conditions.timelock = _mins(1);
        _push("Send Funding Request: Fire the budget request into Core's fund-Mandates transfer.", "ExternalAction_Simple", abi.encode(address(corePowers), coreFundMandatesStep2Id, "Mandates budget request", inputParams));

        // ── FLOW 7 (M6): Treasury Transfer / Recover Tokens ───────────────────
        _flow1(mandateCount + 1, "Mandates M6 - Recover: Governed transfer of any token the treasury holds.");
        mandateCount++;
        conditions.allowedRole = 1;
        conditions.votingPeriod = _mins(5);
        conditions.quorum = 50;
        conditions.succeedAt = 66;
        conditions.timelock = _mins(2);
        _push("Mandates Recover Tokens: Assessors vote to move any token held by the treasury.", "OpenAction", abi.encode());

        // ── FLOW 8 (M7): Governance Reform (Council veto) ─────────────────────
        _flow3(mandateCount + 1, mandateCount + 2, mandateCount + 3, "Mandates M7 - Reform: Propose, allow a Council veto, then adopt new mandates.", true);
        // Must match Adopt_Mandates v0.2.0's declared input exactly: the propose (and veto)
        // steps are matched to the execute step by hashing the *same* mandateCalldata, so a
        // frontend rendering the wrong shape here produces a proposal that cannot be executed.
        inputParams = _p1(
            "(string,address,bytes,(uint256,uint32,uint32,uint32,uint16,uint16,uint8,uint8,uint32))[] mandateInitData"
        );
        mandateCount++;
        conditions.allowedRole = 1;
        conditions.votingPeriod = _mins(7);
        conditions.quorum = 50;
        conditions.succeedAt = 66;
        _push("Propose Mandates Reform: Assessors vote to adopt new governance mandates.", "StatementOfIntent", abi.encode(inputParams));
        mandateCount++;
        conditions.allowedRole = 2;
        conditions.needFulfilled = mandateCount - 1;
        _push("Veto Mandates Reform: The Security Council blocks a proposed governance reform.", "StatementOfIntent", abi.encode(inputParams));
        mandateCount++;
        conditions.allowedRole = 1;
        conditions.needFulfilled = mandateCount - 2;
        conditions.needNotFulfilled = mandateCount - 1;
        conditions.timelock = _mins(6);
        _push("Adopt Mandates Reform: Execute an approved, un-vetoed governance reform.", "Adopt_Mandates", abi.encode());

        // ── FLOW 9 (M8): Set Registry Exchange Rate (paid tier) ───────────────
        // Governs weiPerCredit on the mandates-owned registry: reprices every priced
        // community mandate at once. Executes as mandatesPowers (the registry owner).
        _flow2(mandateCount + 1, mandateCount + 2, "Mandates M8 - Set Exchange Rate: Propose then set the registry credit -> wei rate.");
        inputParams = _p1("uint256 WeiPerCredit");
        mandateCount++;
        conditions.allowedRole = 1;
        conditions.votingPeriod = _mins(5);
        conditions.quorum = 50;
        conditions.succeedAt = 66;
        _push("Propose Registry Exchange Rate: Assessors propose a new credit -> wei rate for the registry.", "StatementOfIntent", abi.encode(inputParams));
        mandateCount++;
        conditions.allowedRole = 1;
        conditions.needFulfilled = mandateCount - 1;
        conditions.timelock = _mins(2);
        _push("Set Registry Exchange Rate: Update weiPerCredit on the mandates-owned registry.", "BespokeAction_Simple", abi.encode(address(mandatesOwnedRegistry), IMandateRegistry.setWeiPerCredit.selector, inputParams));

        // ── FLOW 10 (M9): Set Registry Protocol Fee (paid tier) ───────────────
        _flow2(mandateCount + 1, mandateCount + 2, "Mandates M9 - Set Protocol Fee: Propose then set the registry protocol fee (bps).");
        inputParams = _p1("uint16 FeeBps");
        mandateCount++;
        conditions.allowedRole = 1;
        conditions.votingPeriod = _mins(5);
        conditions.quorum = 50;
        conditions.succeedAt = 66;
        _push("Propose Registry Protocol Fee: Assessors propose a new protocol fee (basis points).", "StatementOfIntent", abi.encode(inputParams));
        mandateCount++;
        conditions.allowedRole = 1;
        conditions.needFulfilled = mandateCount - 1;
        conditions.timelock = _mins(2);
        _push("Set Registry Protocol Fee: Update feeBps on the mandates-owned registry.", "BespokeAction_Simple", abi.encode(address(mandatesOwnedRegistry), IMandateRegistry.setFeeBps.selector, inputParams));

        // ── FLOW 11 (M10): Withdraw Registry Earnings (paid tier) ─────────────
        // withdrawEarnings() pays msg.sender; called as mandatesPowers it pulls the
        // protocol-fee earnings accrued to owner() into the Mandates treasury.
        _flow1(mandateCount + 1, "Mandates M10 - Withdraw Registry Earnings: Sweep accrued protocol fees into the treasury.");
        targets = new address[](1);
        values = new uint256[](1);
        calldatas = new bytes[](1);
        targets[0] = address(mandatesOwnedRegistry);
        calldatas[0] = abi.encodeWithSelector(IMandateRegistry.withdrawEarnings.selector);
        mandateCount++;
        conditions.allowedRole = 1;
        conditions.votingPeriod = _mins(5);
        conditions.quorum = 50;
        conditions.succeedAt = 66;
        conditions.timelock = _mins(2);
        _push("Withdraw Registry Earnings: Sweep the registry's accrued protocol fees to the Mandates treasury.", "PresetActions", abi.encode(targets, values, calldatas));

        // Paymaster funding is centralised in Core (Core owns the shared paymaster), so this
        // organisation has no Fund/Withdraw Paymaster flows of its own.
    }

    // ═══════════════════════════════════════════════════════════════════════════
    //                              BUILD HELPERS
    // ═══════════════════════════════════════════════════════════════════════════

    /// @notice Deploy a Powers instance with a blank metadata URI.
    /// TODO: set metadata URI before deploying - upload a JSON file to Pinata
    /// (https://pinata.cloud) and paste the resulting URL as the second argument.
    function _newPowers(string memory name) internal returns (Powers) {
        return new Powers(
            name,
            "", // TODO: set metadata URI before deploying
            helperConfig.getMaxCallDataLength(block.chainid),
            helperConfig.getMaxReturnDataLength(block.chainid),
            helperConfig.getMaxExecutionsLength(block.chainid),
            address(registry)
        );
    }

    /// @notice Push a mandate onto the current constitution, then clear conditions.
    /// @dev Resolves the mandate to its latest registered version on the canonical registry.
    ///      getLatestVersion reverts if the name was never registered, surfacing a missing
    ///      canonical-registry entry early (before constitute() would fail the onAdopt gate).
    function _push(string memory nameDescription, string memory mandateName, bytes memory config) internal {
        (uint16 major, uint16 minor, uint16 patch) = registry.getLatestVersion(mandateName);
        constitution.push(PowersTypes.MandateInitData({
            nameDescription: nameDescription,
            targetMandate: registry.getMandateAddress(major, minor, patch, mandateName),
            config: config,
            conditions: conditions
        }));
        delete conditions;
    }

    /// @notice Add the two standard Account-Abstraction paymaster flows.
    /// @param mandateCount current mandate counter (before these flows)
    /// @param role the elected role that governs the paymaster
    /// @return the updated mandate counter
    function _paymasterFlows(uint16 mandateCount, uint256 role, address paymaster, string memory prefix) internal returns (uint16) {
        // Fund Paymaster
        _flow2(mandateCount + 1, mandateCount + 2, string(abi.encodePacked(prefix, " - Fund Paymaster: Propose and execute an ETH deposit into the paymaster.")));
        mandateCount++;
        conditions.allowedRole = role;
        _push(string(abi.encodePacked("Propose to Fund Paymaster (", prefix, "): Propose depositing ETH into the paymaster.")), "StatementOfIntent", abi.encode());
        targets = new address[](1);
        values = new uint256[](1);
        calldatas = new bytes[](1);
        targets[0] = paymaster;
        values[0] = PAYMASTER_SEED;
        calldatas[0] = abi.encodeWithSignature("deposit()");
        mandateCount++;
        conditions.allowedRole = role;
        conditions.votingPeriod = _mins(5);
        conditions.quorum = 20;
        conditions.succeedAt = 51;
        conditions.needFulfilled = mandateCount - 1;
        _push(string(abi.encodePacked("Execute Fund Paymaster (", prefix, "): Deposit 0.05 ETH into the paymaster.")), "PresetActions", abi.encode(targets, values, calldatas));

        // Withdraw from Paymaster
        _flow2(mandateCount + 1, mandateCount + 2, string(abi.encodePacked(prefix, " - Withdraw Paymaster: Propose and execute an ETH withdrawal from the paymaster.")));
        inputParams = _p2("address withdrawAddress", "uint256 amount");
        mandateCount++;
        conditions.allowedRole = role;
        _push(string(abi.encodePacked("Propose to Withdraw from Paymaster (", prefix, "): Propose withdrawing ETH from the paymaster.")), "StatementOfIntent", abi.encode(inputParams));
        mandateCount++;
        conditions.allowedRole = role;
        conditions.votingPeriod = _mins(5);
        conditions.quorum = 20;
        conditions.succeedAt = 51;
        conditions.needFulfilled = mandateCount - 1;
        _push(string(abi.encodePacked("Execute Withdraw from Paymaster (", prefix, "): Withdraw the proposed ETH from the paymaster.")), "BespokeAction_Simple", abi.encode(paymaster, bytes4(keccak256("withdrawTo(address,uint256)")), inputParams));

        return mandateCount;
    }

    // ── Flow registration helpers ──────────────────────────────────────────────
    function _flow1(uint16 a, string memory nameDescription) internal {
        uint16[] memory ids = new uint16[](1);
        ids[0] = a;
        flows.push(PowersTypes.Flow({ mandateIds: ids, nameDescription: nameDescription }));
    }

    function _flow2(uint16 a, uint16 b, string memory nameDescription) internal {
        uint16[] memory ids = new uint16[](2);
        ids[0] = a; ids[1] = b;
        flows.push(PowersTypes.Flow({ mandateIds: ids, nameDescription: nameDescription }));
    }

    /// @dev `three` unused when only two positions differ; kept for readability.
    function _flow3(uint16 a, uint16 b, uint16 c, string memory nameDescription, bool) internal {
        uint16[] memory ids = new uint16[](3);
        ids[0] = a; ids[1] = b; ids[2] = c;
        flows.push(PowersTypes.Flow({ mandateIds: ids, nameDescription: nameDescription }));
    }

    // ── Small utilities ─────────────────────────────────────────────────────────
    function _mins(uint256 m) internal view returns (uint32) {
        return minutesToBlocks(m, helperConfig.getBlocksPerHour(block.chainid));
    }

    function _p1(string memory a) internal pure returns (string[] memory p) {
        p = new string[](1);
        p[0] = a;
    }

    function _p2(string memory a, string memory b) internal pure returns (string[] memory p) {
        p = new string[](2);
        p[0] = a; p[1] = b;
    }

    function _resetBuild() internal {
        delete constitution;
        delete flows;
        delete conditions;
    }
}
