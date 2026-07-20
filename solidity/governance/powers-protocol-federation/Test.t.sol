// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.26;

// Run with: forge test --match-contract PowersProtocolFederation_test -vvv
// Requires an Ethereum Sepolia RPC (Aave v3 + the canonical MandateRegistry live there):
//   export SEPOLIA_RPC_URL=<your-url>

import { Test, console2 } from "forge-std/Test.sol";
import { Powers } from "@src/Powers.sol";
import { IPowers } from "@src/interfaces/IPowers.sol";
import { PowersTypes } from "@src/interfaces/PowersTypes.sol";
import { Configurations } from "@script/Configurations.s.sol";
import { Deploy } from "./Deploy.s.sol";
import { PowersProtocolFederationRunners } from "./Runners.s.sol";

interface IERC20Min {
    function balanceOf(address) external view returns (uint256);
}

contract PowersProtocolFederation_test is Test {
    Configurations helperConfig;
    Deploy deploy;
    PowersProtocolFederationRunners runners;

    address core;
    address mandates;
    address endowment;

    // Synthetic keys — founding cohort seeded by the setup mandate uses keys 1..3.
    uint256 constant ADMIN_KEY = 1;
    uint256 constant MEMBER_KEY_1 = 1;
    uint256 constant MEMBER_KEY_2 = 2;
    uint256 constant MEMBER_KEY_3 = 3;

    uint256[] adminKeys;
    uint256[] memberKeys;   // role 1 in every org (acc1..3)
    uint256[] councilKeys;  // role 2 in Core/Mandates (acc1)

    // Ethereum Sepolia test USDC (Aave v3 reserve; aave-address-book AaveV3Sepolia).
    address constant USDC = 0x94a9D9AC8a22534E3FaCa9F4e7F2E2cf85d5E4C8;
    // Foundry's default broadcast sender — funded so Deploy can seed the central paymaster.
    address constant FOUNDRY_DEFAULT_SENDER = 0x1804c8AB1F12E6bbf3894d4083f33e07309d1f38;

    function setUp() public {
        // DeployHelpers reads these at construction; supply synthetic values so no
        // real keys are needed to run the tests.
        vm.setEnv("TEST_ACCOUNT_KEY_1", "1");
        vm.setEnv("TEST_ACCOUNT_KEY_2", "2");
        vm.setEnv("TEST_ACCOUNT_KEY_3", "3");

        uint256 fork = vm.createFork(vm.envString("SEPOLIA_RPC_URL"));
        vm.selectFork(fork);
        helperConfig = new Configurations();

        adminKeys = [ADMIN_KEY];
        memberKeys = [MEMBER_KEY_1, MEMBER_KEY_2, MEMBER_KEY_3];
        councilKeys = [MEMBER_KEY_1];

        // Fund the synthetic accounts, this contract, and the deploy broadcaster
        // (the last two cover the 0.15 ETH central-paymaster seeding).
        vm.deal(vm.addr(1), 10 ether);
        vm.deal(vm.addr(2), 10 ether);
        vm.deal(vm.addr(3), 10 ether);
        vm.deal(address(this), 10 ether);
        vm.deal(tx.origin, 10 ether);
        vm.deal(FOUNDRY_DEFAULT_SENDER, 10 ether);

        deploy = new Deploy();
        (Powers c, Powers m, Powers e) = deploy.run();
        core = address(c);
        mandates = address(m);
        endowment = address(e);

        runners = new PowersProtocolFederationRunners();
        runners.runInitialSetup(endowment, adminKeys, block.timestamp);
        runners.runInitialSetup(core, adminKeys, block.timestamp + 1);
        runners.runInitialSetup(mandates, adminKeys, block.timestamp + 2);
    }

    // ═══════════════════════════════════════════════════════════════════════════
    //                       DETERMINISTIC STRUCTURE TESTS
    // ═══════════════════════════════════════════════════════════════════════════

    function test_initialState() public view {
        // Core role labels.
        assertEq(Powers(payable(core)).getRoleLabel(1), "Core Member", "Core role 1");
        assertEq(Powers(payable(core)).getRoleLabel(2), "Security Council", "Core role 2");
        assertEq(Powers(payable(core)).getRoleLabel(4), "Funded Sub-org", "Core role 4");
        // Mandates + Endowment labels.
        assertEq(Powers(payable(mandates)).getRoleLabel(1), "Mandate Assessor", "Mandates role 1");
        assertEq(Powers(payable(endowment)).getRoleLabel(1), "Endowment Investor", "Endowment role 1");
        assertEq(Powers(payable(endowment)).getRoleLabel(2), "Core Beneficiary", "Endowment role 2");

        // Each organisation has a non-trivial constitution.
        assertTrue(Powers(payable(core)).mandateCounter() > 20, "Core mandates");
        assertTrue(Powers(payable(mandates)).mandateCounter() > 20, "Mandates mandates");
        assertTrue(Powers(payable(endowment)).mandateCounter() > 12, "Endowment mandates");
    }

    function test_crossOrgSeatsAssigned() public view {
        // Core Powers holds the Core Beneficiary seat (role 2) inside the Endowment.
        assertTrue(IPowers(endowment).hasRoleSince(core, 2) > 0, "Core should hold Endowment role 2");
        // Mandates Powers holds the Funded Sub-org seat (role 4) inside Core.
        assertTrue(IPowers(core).hasRoleSince(mandates, 4) > 0, "Mandates should hold Core role 4");
    }

    function test_foundingCohortSeeded() public view {
        for (uint256 k = 1; k <= 3; k++) {
            assertTrue(IPowers(core).hasRoleSince(vm.addr(k), 1) > 0, "member should hold Core role 1");
            assertTrue(IPowers(mandates).hasRoleSince(vm.addr(k), 1) > 0, "assessor should hold Mandates role 1");
            assertTrue(IPowers(endowment).hasRoleSince(vm.addr(k), 1) > 0, "investor should hold Endowment role 1");
        }
    }

    /// @notice The Core organisational veto over Endowment investment is wired:
    ///         the veto slot is callable only by the Core Beneficiary seat and is
    ///         gated behind the investment proposal.
    function test_coreInvestmentVetoWiring() public view {
        uint16 vetoId = runners.findMandateIdInOrg("Core Veto of Aave Investment: The Core organisation blocks a proposed investment.", Powers(payable(endowment)));
        PowersTypes.Conditions memory c = IPowers(endowment).getConditions(vetoId);
        assertEq(c.allowedRole, 2, "veto slot must be the Core Beneficiary seat");
        assertTrue(c.needFulfilled != 0, "veto slot must follow the investment proposal");

        uint16 execId = runners.findMandateIdInOrg("Execute Aave Investment: Supply the approved asset to the Aave v3 pool if not vetoed.", Powers(payable(endowment)));
        PowersTypes.Conditions memory ce = IPowers(endowment).getConditions(execId);
        assertEq(ce.needNotFulfilled, vetoId, "investment execution must be blocked by the veto");
    }

    // ═══════════════════════════════════════════════════════════════════════════
    //                          RUNTIME FLOW TESTS
    // ═══════════════════════════════════════════════════════════════════════════

    /// @notice Happy path: Core Members propose, approve and pay a USDC invoice.
    function test_coreInvoice_endToEnd() public {
        address dev = makeAddr("coreDeveloper");
        uint256 amount = 500e6;
        uint256 nonce = 1001;

        // Fund the Core treasury with USDC to pay from.
        deal(USDC, core, 1_000e6);

        uint16 proposeId = runners.findMandateIdInOrg("Propose Core Invoice: Members propose paying a core-development invoice (USDC).", Powers(payable(core)));
        uint16 executeId = runners.findMandateIdInOrg("Execute Core Invoice: Pay the approved core-development invoice in USDC.", Powers(payable(core)));
        bytes memory cd = abi.encode(dev, amount);

        _passProposal(core, proposeId, cd, memberKeys, nonce);
        _executeTimelock(core, executeId, cd, MEMBER_KEY_1, nonce);

        assertEq(IERC20Min(USDC).balanceOf(dev), amount, "developer should have been paid");
        console2.log("Core invoice paid end-to-end.");
    }

    /// @notice Negative: a Security Council veto blocks a Core governance reform.
    function test_coreReform_blockedByCouncilVeto() public {
        uint256 nonce = 2002;
        address[] memory newMandates = new address[](0);
        uint256[] memory roleIds = new uint256[](0);
        bytes memory cd = abi.encode(newMandates, roleIds);

        uint16 proposeId = runners.findMandateIdInOrg("Propose Core Reform: Members vote to adopt new governance mandates.", Powers(payable(core)));
        uint16 vetoId = runners.findMandateIdInOrg("Veto Core Reform: The Security Council blocks a proposed governance reform.", Powers(payable(core)));
        uint16 adoptId = runners.findMandateIdInOrg("Adopt Core Reform: Execute an approved, un-vetoed governance reform.", Powers(payable(core)));

        // Members pass the reform proposal.
        _passProposal(core, proposeId, cd, memberKeys, nonce);

        // Security Council casts its veto (no vote — a signalling statement).
        vm.prank(vm.addr(councilKeys[0]));
        IPowers(core).request(vetoId, cd, nonce, "Council veto");

        // Attempt to adopt — must revert because needNotFulfilled(veto) is now Fulfilled.
        vm.prank(vm.addr(MEMBER_KEY_1));
        IPowers(core).propose(adoptId, cd, nonce, "propose adopt");
        PowersTypes.Conditions memory c = IPowers(core).getConditions(adoptId);
        vm.roll(block.number + c.timelock + 2);

        vm.expectRevert();
        vm.prank(vm.addr(MEMBER_KEY_1));
        IPowers(core).request(adoptId, cd, nonce, "adopt (should fail)");
        console2.log("Reform correctly blocked by Security Council veto.");
    }

    // ═══════════════════════════════════════════════════════════════════════════
    //                               HELPERS
    // ═══════════════════════════════════════════════════════════════════════════

    /// @notice Propose a voted step, pass it with FOR votes, and finalise it to Fulfilled.
    function _passProposal(address p, uint16 mandateId, bytes memory cd, uint256[] memory keys, uint256 nonce) internal {
        vm.prank(vm.addr(keys[0]));
        IPowers(p).propose(mandateId, cd, nonce, "propose");

        uint256 actionId = uint256(keccak256(abi.encode(mandateId, cd, nonce)));
        for (uint256 i = 0; i < keys.length; i++) {
            if (Powers(payable(p)).canCallMandate(vm.addr(keys[i]), mandateId)) {
                vm.prank(vm.addr(keys[i]));
                IPowers(p).castVote(actionId, 1); // 1 = FOR
            }
        }

        PowersTypes.Conditions memory c = IPowers(p).getConditions(mandateId);
        vm.roll(block.number + uint256(c.votingPeriod) + 2);

        // Finalise: request the statement so its state becomes Fulfilled.
        vm.prank(vm.addr(keys[0]));
        IPowers(p).request(mandateId, cd, nonce, "finalise proposal");
    }

    /// @notice Propose a timelocked execution step, wait out the timelock, then execute.
    function _executeTimelock(address p, uint16 mandateId, bytes memory cd, uint256 key, uint256 nonce) internal {
        vm.prank(vm.addr(key));
        IPowers(p).propose(mandateId, cd, nonce, "propose execution");

        PowersTypes.Conditions memory c = IPowers(p).getConditions(mandateId);
        vm.roll(block.number + uint256(c.timelock) + 2);

        vm.prank(vm.addr(key));
        IPowers(p).request(mandateId, cd, nonce, "execute");
    }

    function minutesToBlocks(uint256 minutes_, uint256 blocksPerHour) internal pure returns (uint32) {
        return uint32((minutes_ * blocksPerHour) / 60);
    }
}
