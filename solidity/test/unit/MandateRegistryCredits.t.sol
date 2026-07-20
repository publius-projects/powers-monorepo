// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.26;

import { TestSetupPowers } from "../TestSetup.t.sol";
import { MandateRegistry } from "@src/core/helpers/MandateRegistry.sol";
import { IMandate } from "@src/interfaces/IMandate.sol";
import { Mandate } from "@src/Mandate.sol";
import { OpenAction } from "@src/core/mandates/executive/OpenAction.sol";
import { PowersTypes } from "@src/interfaces/PowersTypes.sol";

/// @dev Minimal priced mandate for tests: declares its own price (in credits) and dev payees, the way a
/// real paying mandate would override the base getters. Everything else is inherited from Mandate.
contract PricedMandate is Mandate {
    uint256 internal immutable PRICE_CREDITS;
    address[] internal DEV_PAYEES;

    constructor(address registry_, uint256 priceCredits_, address[] memory devs_) Mandate(registry_) {
        PRICE_CREDITS = priceCredits_;
        DEV_PAYEES = devs_;
    }

    function priceInCredits() public view override returns (uint256) {
        return PRICE_CREDITS;
    }

    function devs() public view override returns (address[] memory) {
        return DEV_PAYEES;
    }
}

/// @notice Unit tests for the paid tier on MandateRegistry: developer-declared credit pricing, the
/// owner-set credit->wei exchange rate, per-adoption charging, developer split, withdrawals, and the
/// "registry-down blocks new adoptions only" invariant.
contract MandateRegistryCreditsTest is TestSetupPowers {
    address internal owner_; // registry owner (a Powers org in prod, an EOA in tests)

    function setUp() public override {
        super.setUp();
        owner_ = registry.owner();
        vm.deal(address(this), 100 ether);
        // Pin the exchange rate to 1 wei/credit for the shared registry, so credit prices below equal
        // their wei cost unless a test changes the rate explicitly. (The deploy script seeds a network
        // rate; tests set their own to stay deterministic.)
        vm.prank(owner_);
        registry.setWeiPerCredit(1);
    }

    // ─── helpers ─────────────────────────────────────────────────────────────

    /// @dev Deploys a fresh free OpenAction against the shared registry, registers it under `name`.
    function _deployRegistered(string memory name) internal returns (address mandate) {
        mandate = address(new OpenAction(address(registry)));
        vm.prank(owner_);
        registry.registerMandate(name, mandate, keccak256(abi.encodePacked(name)));
    }

    /// @dev Deploys a priced mandate (developer declares price/devs) against the registry, registers it.
    function _deployPriced(string memory name, uint256 priceCredits, address[] memory devs)
        internal
        returns (address mandate)
    {
        mandate = address(new PricedMandate(address(registry), priceCredits, devs));
        vm.prank(owner_);
        registry.registerMandate(name, mandate, keccak256(abi.encodePacked(name)));
    }

    function _twoDevs() internal view returns (address[] memory devs) {
        devs = new address[](2);
        devs[0] = alice;
        devs[1] = bob;
    }

    function _setRate(uint256 rate) internal {
        vm.prank(owner_);
        registry.setWeiPerCredit(rate);
    }

    // ─── pricing config ──────────────────────────────────────────────────────

    function testDefaultFeeBpsIsTenPercent() public view {
        assertEq(registry.feeBps(), 1000);
    }

    function testConstructorDefaultWeiPerCreditIsOne() public {
        MandateRegistry fresh = new MandateRegistry(address(this));
        assertEq(fresh.weiPerCredit(), 1, "constructor seeds default rate of 1 wei/credit");
    }

    function testSetFeeBpsRevertsAboveCap() public {
        vm.prank(owner_);
        vm.expectRevert(abi.encodeWithSelector(MandateRegistry.FeeTooHigh.selector, uint16(3001), uint16(3000)));
        registry.setFeeBps(3001);
    }

    function testSetWeiPerCredit() public {
        vm.expectEmit(true, true, true, true);
        emit MandateRegistry.WeiPerCreditSet(1e15);
        vm.prank(owner_);
        registry.setWeiPerCredit(1e15);
        assertEq(registry.weiPerCredit(), 1e15);
    }

    function testSetWeiPerCreditOnlyOwner() public {
        vm.prank(alice);
        vm.expectRevert();
        registry.setWeiPerCredit(1e15);
    }

    // ─── charging via onAdopt ────────────────────────────────────────────────

    function testFreeMandateDoesNotMoveCredits() public {
        address mandate = _deployRegistered("FreeMandate"); // price 0 by default
        address org = address(daoMock);
        registry.buyCredits{ value: 1 ether }(org);

        uint256 before = registry.credits(org);
        vm.prank(mandate);
        registry.onAdopt(org);

        assertEq(registry.credits(org), before, "free mandate must not charge");
        assertEq(registry.earnings(owner_), 0);
    }

    function testPricedMandateRevertsWithoutCredits() public {
        address mandate = _deployPriced("PricedNoCredits", 1 ether, _twoDevs()); // 1 ether credits, rate 1
        address org = address(daoMock);

        vm.prank(mandate);
        vm.expectRevert(
            abi.encodeWithSelector(MandateRegistry.InsufficientCredits.selector, org, uint256(1 ether), uint256(0))
        );
        registry.onAdopt(org);
    }

    function testOnAdoptRevertsForUnregistered() public {
        address unregistered = address(new OpenAction(address(registry)));
        vm.prank(unregistered);
        vm.expectRevert(abi.encodeWithSelector(MandateRegistry.NotRegistered.selector, unregistered));
        registry.onAdopt(address(daoMock));
    }

    function testOnAdoptRevertsWhenPricedMandateHasNoDevs() public {
        address[] memory noDevs = new address[](0);
        address mandate = _deployPriced("PricedNoDevs", 0.01 ether, noDevs);
        address org = address(daoMock);
        registry.buyCredits{ value: 0.05 ether }(org);

        vm.prank(mandate);
        vm.expectRevert(abi.encodeWithSelector(MandateRegistry.NoDevs.selector, mandate));
        registry.onAdopt(org);
    }

    function testOnAdoptRevertsWhenExchangeRateUnset() public {
        _setRate(0);
        address mandate = _deployPriced("PricedRateUnset", 100, _twoDevs());
        address org = address(daoMock);
        registry.buyCredits{ value: 1 ether }(org);

        vm.prank(mandate);
        vm.expectRevert(MandateRegistry.ExchangeRateNotSet.selector);
        registry.onAdopt(org);
    }

    function testChargeSplitsFeeAndDevsEvenly() public {
        uint256 priceCredits = 0.01 ether; // rate 1 => costWei == priceCredits
        address mandate = _deployPriced("PricedEven", priceCredits, _twoDevs());
        address org = address(daoMock);
        registry.buyCredits{ value: 0.05 ether }(org);

        vm.prank(mandate);
        registry.onAdopt(org);

        uint256 costWei = priceCredits;
        uint256 fee = (costWei * 1000) / 10_000; // 10%
        uint256 share = (costWei - fee) / 2;

        assertEq(registry.credits(org), 0.05 ether - costWei, "credits debited by cost");
        assertEq(registry.earnings(owner_), fee, "fee to owner");
        assertEq(registry.earnings(alice), share, "dev0 share");
        assertEq(registry.earnings(bob), share, "dev1 share");
        assertEq(fee + share + share, costWei, "no wei lost (even case)");
    }

    function testChargeRemainderGoesToFirstDev() public {
        // credit price chosen so the dev portion is odd → 1 wei remainder to devs[0]
        uint256 priceCredits = 105; // fee = 105*1000/10000 = 10; devPortion = 95; /2 = 47 rem 1
        address mandate = _deployPriced("PricedOdd", priceCredits, _twoDevs());
        address org = address(daoMock);
        registry.buyCredits{ value: 1 ether }(org);

        vm.prank(mandate);
        registry.onAdopt(org);

        uint256 costWei = priceCredits; // rate 1
        uint256 fee = (costWei * 1000) / 10_000; // 10
        uint256 devPortion = costWei - fee; // 95
        uint256 share = devPortion / 2; // 47
        uint256 remainder = devPortion - (share * 2); // 1

        assertEq(registry.earnings(owner_), fee);
        assertEq(registry.earnings(alice), share + remainder, "first dev gets remainder");
        assertEq(registry.earnings(bob), share);
        assertEq(fee + registry.earnings(alice) + registry.earnings(bob), costWei, "no wei lost (odd case)");
    }

    function testExchangeRateMultipliesCost() public {
        // Same developer credit price, a non-trivial rate: the wei cost scales by weiPerCredit, and the
        // registry owner reprices via the rate alone — the mandate's price is untouched.
        uint256 priceCredits = 100;
        uint256 rate = 1e14; // 0.0001 ETH per credit
        _setRate(rate);
        address mandate = _deployPriced("PricedRate", priceCredits, _twoDevs());
        address org = address(daoMock);
        registry.buyCredits{ value: 1 ether }(org);

        vm.prank(mandate);
        registry.onAdopt(org);

        uint256 costWei = priceCredits * rate; // 100 * 1e14 = 1e16
        uint256 fee = (costWei * 1000) / 10_000;
        uint256 share = (costWei - fee) / 2;

        assertEq(registry.credits(org), 1 ether - costWei, "credits debited by scaled cost");
        assertEq(registry.earnings(owner_), fee, "fee to owner");
        assertEq(registry.earnings(alice), share, "dev0 share");
        assertEq(registry.earnings(bob), share, "dev1 share");
    }

    // ─── withdrawals ─────────────────────────────────────────────────────────

    function testWithdrawEarningsPaysThenZeroes() public {
        address mandate = _deployPriced("PricedForWithdraw", 0.01 ether, _twoDevs());
        address org = address(daoMock);
        registry.buyCredits{ value: 0.05 ether }(org);
        vm.prank(mandate);
        registry.onAdopt(org);

        uint256 aliceOwed = registry.earnings(alice);
        assertGt(aliceOwed, 0);

        uint256 balBefore = alice.balance;
        vm.prank(alice);
        registry.withdrawEarnings();

        assertEq(alice.balance, balBefore + aliceOwed, "alice received earnings");
        assertEq(registry.earnings(alice), 0, "earnings zeroed");

        // second withdraw pays nothing
        vm.prank(alice);
        vm.expectRevert(MandateRegistry.NothingToWithdraw.selector);
        registry.withdrawEarnings();
    }

    // ─── deactivation / registry-down invariant ──────────────────────────────

    function testOnAdoptRevertsAfterDeactivation() public {
        address mandate = _deployPriced("PricedThenDeactivated", 0.01 ether, _twoDevs());
        registry.buyCredits{ value: 0.05 ether }(address(daoMock));

        (uint16 maj, uint16 min, uint16 pat) = IMandate(mandate).version();
        vm.prank(owner_);
        registry.deactivateMandate(maj, min, pat, "PricedThenDeactivated");

        vm.prank(mandate);
        vm.expectRevert(abi.encodeWithSelector(MandateRegistry.NotRegistered.selector, mandate));
        registry.onAdopt(address(daoMock));
    }

    function testAdoptedMandateStillExecutesAfterRegistryDeactivation() public {
        // Adopt a free registered mandate on daoMock, then deactivate it in the registry, then confirm
        // the already-adopted mandate still executes (execution never touches the registry) but a new
        // adoption of it now reverts.
        address mandate = _deployRegistered("ExecInvariant");

        conditions.allowedRole = ROLE_ONE; // alice holds ROLE_ONE in TestSetupPowers
        uint16 newMandateId;
        vm.prank(address(daoMock));
        newMandateId = daoMock.adoptMandate(
            MandateInitData({
                nameDescription: "Exec invariant mandate",
                targetMandate: mandate,
                config: abi.encode(),
                conditions: conditions
            })
        );

        // deactivate in the registry
        (uint16 maj, uint16 min, uint16 pat) = IMandate(mandate).version();
        vm.prank(owner_);
        registry.deactivateMandate(maj, min, pat, "ExecInvariant");

        // already-adopted mandate still executes: request a no-op action through it
        address[] memory t = new address[](0);
        uint256[] memory v = new uint256[](0);
        bytes[] memory c = new bytes[](0);
        vm.prank(alice);
        daoMock.request(newMandateId, abi.encode(t, v, c), nonce, "still works");

        // but re-adopting the now-deactivated mandate reverts at the mandate-side onAdopt
        vm.prank(address(daoMock));
        vm.expectRevert(abi.encodeWithSelector(MandateRegistry.NotRegistered.selector, mandate));
        daoMock.adoptMandate(
            MandateInitData({
                nameDescription: "re-adopt attempt",
                targetMandate: mandate,
                config: abi.encode(),
                conditions: conditions
            })
        );
    }

    // ─── credits are per-org and fundable by anyone ──────────────────────────

    function testBuyCreditsCreditsNamedOrgNotPayer() public {
        address org = address(daoMock);
        registry.buyCredits{ value: 2 ether }(org);
        assertEq(registry.credits(org), 2 ether);
        assertEq(registry.credits(address(this)), 0);
    }
}
