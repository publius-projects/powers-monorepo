// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.26;

import { Test } from "forge-std/Test.sol";
import { Powers } from "@src/Powers.sol";
import { MandateRegistry } from "@src/core/helpers/MandateRegistry.sol";
import { PowersTypes } from "@src/interfaces/PowersTypes.sol";
import { PowersErrors } from "@src/interfaces/PowersErrors.sol";
import { OpenAction } from "@src/core/mandates/executive/OpenAction.sol";
import { StatementOfIntent } from "@src/core/mandates/executive/StatementOfIntent.sol";

/// @notice Unit tests for Powers.sol's MANDATE_REGISTRY enforcement.
/// @dev Covers both constitute() (genesis) and adoptMandate() (post-genesis) — both funnel through the
/// same internal _storeMandate/PowersUtilities.storeMandate path, so the registry check applies to both.
contract PowersMandateRegistryTest is Test {
    MandateRegistry registry;
    OpenAction registeredMandate;
    StatementOfIntent unregisteredMandate;

    uint16 constant MAJOR = 0;
    uint16 constant MINOR = 1;
    uint16 constant PATCH = 9;

    function setUp() public {
        registry = new MandateRegistry(address(this));
        registeredMandate = new OpenAction(address(registry));
        unregisteredMandate = new StatementOfIntent(address(registry)); // deliberately never registered

        registry.registerMandate("OpenAction", address(registeredMandate), keccak256(type(OpenAction).creationCode));
    }

    function _deployPowers(address mandateRegistry) internal returns (Powers) {
        return new Powers("Test DAO", "https://test.uri", 10_000, 10_000, 25, mandateRegistry);
    }

    function _constitutionFor(address targetMandate) internal pure returns (PowersTypes.MandateInitData[] memory) {
        PowersTypes.MandateInitData[] memory constitution = new PowersTypes.MandateInitData[](1);
        PowersTypes.Conditions memory conditions; // allowedRole defaults to 0 (ADMIN_ROLE)
        constitution[0] = PowersTypes.MandateInitData({
            nameDescription: "Test mandate", targetMandate: targetMandate, config: abi.encode(), conditions: conditions
        });
        return constitution;
    }

    // ─── BASIC BEHAVIOUR ─────────────────────────────────────────────────────

    function testConstructorSetsMandateRegistry() public {
        Powers powers = _deployPowers(address(registry));
        assertEq(powers.MANDATE_REGISTRY(), address(registry));
    }

    function testConstituteSucceedsWithRegisteredMandate() public {
        Powers powers = _deployPowers(address(registry));
        powers.constitute(_constitutionFor(address(registeredMandate)));

        (address mandate,, bool active) = powers.getAdoptedMandate(1);
        assertEq(mandate, address(registeredMandate));
        assertTrue(active);
    }

    function testAdoptMandateSucceedsWithRegisteredMandate() public {
        Powers powers = _deployPowers(address(registry));
        powers.constitute(new PowersTypes.MandateInitData[](0));
        powers.closeConstitute();

        uint16 mandateCounterBefore = powers.mandateCounter();
        PowersTypes.MandateInitData memory mandateInitData = _constitutionFor(address(registeredMandate))[0];

        vm.prank(address(powers)); // adoptMandate is onlyPowers
        powers.adoptMandate(mandateInitData);

        (address mandate,,) = powers.getAdoptedMandate(mandateCounterBefore);
        assertEq(mandate, address(registeredMandate));
    }

    function testZeroAddressRegistryStillEnforcedAtMandateLevel() public {
        // A zero-address Powers registry disables the Powers-side check, but the mandate itself
        // enforces registration via onAdopt (strict, no address(0) escape at the mandate level).
        // The mandate points at the canonical registry where it is unregistered, so adoption reverts.
        Powers powers = _deployPowers(address(0));

        vm.expectRevert(abi.encodeWithSelector(MandateRegistry.NotRegistered.selector, address(unregisteredMandate)));
        powers.constitute(_constitutionFor(address(unregisteredMandate)));
    }

    // ─── EDGE CASES ──────────────────────────────────────────────────────────

    function testConstituteRevertsWithUnregisteredMandate() public {
        Powers powers = _deployPowers(address(registry));

        vm.expectRevert(
            abi.encodeWithSelector(PowersErrors.Powers__MandateNotRegistered.selector, address(unregisteredMandate))
        );
        powers.constitute(_constitutionFor(address(unregisteredMandate)));
    }

    function testAdoptMandateRevertsWithUnregisteredMandate() public {
        Powers powers = _deployPowers(address(registry));
        powers.constitute(new PowersTypes.MandateInitData[](0));
        powers.closeConstitute();

        PowersTypes.MandateInitData memory mandateInitData = _constitutionFor(address(unregisteredMandate))[0];

        vm.prank(address(powers));
        vm.expectRevert(
            abi.encodeWithSelector(PowersErrors.Powers__MandateNotRegistered.selector, address(unregisteredMandate))
        );
        powers.adoptMandate(mandateInitData);
    }

    function testConstituteRevertsAfterMandateDeactivated() public {
        registry.deactivateMandate(MAJOR, MINOR, PATCH, "OpenAction");

        Powers powers = _deployPowers(address(registry));
        vm.expectRevert(
            abi.encodeWithSelector(PowersErrors.Powers__MandateNotRegistered.selector, address(registeredMandate))
        );
        powers.constitute(_constitutionFor(address(registeredMandate)));
    }

    function testConstituteSucceedsAgainAfterMandateReactivated() public {
        registry.deactivateMandate(MAJOR, MINOR, PATCH, "OpenAction");
        registry.reactivateMandate(MAJOR, MINOR, PATCH, "OpenAction");

        Powers powers = _deployPowers(address(registry));
        powers.constitute(_constitutionFor(address(registeredMandate)));

        (address mandate,, bool active) = powers.getAdoptedMandate(1);
        assertEq(mandate, address(registeredMandate));
        assertTrue(active);
    }
}
