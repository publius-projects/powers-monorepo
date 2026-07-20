// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.26;

import {
    TestSetupElectoral,
    TestSetupDelegateTokenFlow,
    TestSetupAssignExternalRoleParentFlow,
    TestSetupRevokeInactiveAccounts,
    TestSetupRevokeAccountsRoleId
} from "../../TestSetup.t.sol";
import { Checks } from "@src/libraries/Checks.sol";

import { PeerSelect } from "@src/core/mandates/electoral/PeerSelect.sol";
import { RoleByRoles } from "@src/addons/mandates/electoral/RoleByRoles.sol";
import { SelfSelect } from "@src/core/mandates/electoral/SelfSelect.sol";
import { RenounceRole } from "@src/core/mandates/electoral/RenounceRole.sol";
import { PowersTypes } from "@src/interfaces/PowersTypes.sol";
import { Nominees } from "@src/core/helpers/Nominees.sol";
import { RevokeInactiveAccounts } from "@src/addons/mandates/electoral/RevokeInactiveAccounts.sol";
import { PowersErrors } from "@src/interfaces/PowersErrors.sol";
import { AssignExternalRole } from "@src/addons/mandates/electoral/AssignExternalRole.sol";
import { RevokeAccountsRoleId } from "@src/addons/mandates/electoral/RevokeAccountsRoleId.sol";
import { Strings } from "@lib/openzeppelin-contracts/contracts/utils/Strings.sol";

/// @notice Comprehensive unit tests for all electoral mandates
/// @dev Tests all functionality of electoral mandates including initialization, execution, and edge cases

//////////////////////////////////////////////////
//              PEER SELECT TESTS              //
//////////////////////////////////////////////////
contract PeerSelectTest is TestSetupElectoral {
    PeerSelect peerSelect;
    Nominees nomineesContract;

    function setUp() public override {
        super.setUp();
        peerSelect = PeerSelect(findMandateAddress("PeerSelect"));
        nomineesContract = nominees; // inherited from TestSetupElectoral -> TestVariables
        mandateId = findMandateIdInOrg("PeerSelect: A mandate to select roles by peer votes from nominees.", daoMock);
    }

    function testPeerSelectInitialization() public {
        (uint8 numberToSelect, uint256 roleId, address configuredNominees) =
            abi.decode(peerSelect.getConfig(address(daoMock), mandateId), (uint8, uint256, address));

        assertEq(numberToSelect, 2);
        assertEq(roleId, 4);
        assertEq(configuredNominees, address(nomineesContract));
    }

    /// @notice The input fields must be derived from the *current* nominees, not snapshotted at
    ///         constitution time (when the nominee pool is empty). Regression test for the UI
    ///         showing no checkboxes on "Elect ..." mandates.
    function testPeerSelectDynamicInputParams() public {
        // Before anyone nominates, there are no input fields.
        string[] memory paramsBefore = abi.decode(peerSelect.getInputParams(address(daoMock), mandateId), (string[]));
        assertEq(paramsBefore.length, 0);

        // Nominate three candidates.
        vm.startPrank(address(daoMock));
        nomineesContract.nominate(charlotte, true);
        nomineesContract.nominate(david, true);
        nomineesContract.nominate(eve, true);
        vm.stopPrank();

        // getInputParams now reflects the live nominee pool: one `bool <address>` field each.
        string[] memory paramsAfter = abi.decode(peerSelect.getInputParams(address(daoMock), mandateId), (string[]));
        address[] memory currentNominees = nomineesContract.getNominees();
        assertEq(paramsAfter.length, 3);
        assertEq(paramsAfter.length, currentNominees.length);
        for (uint256 i = 0; i < currentNominees.length; i++) {
            assertEq(paramsAfter[i], string.concat("bool ", Strings.toHexString(currentNominees[i])));
        }
    }

    function testPeerSelectExecution() public {
        // Nominate 3 candidates
        vm.startPrank(address(daoMock));
        nomineesContract.nominate(charlotte, true);
        nomineesContract.nominate(david, true);
        nomineesContract.nominate(eve, true);
        vm.stopPrank();
        // Verify nominees are registered
        address[] memory currentNominees = nomineesContract.getNominees();
        assertEq(currentNominees.length, 3);

        // Prepare selection matching the nominees array length
        // We select the first two: charlotte and david
        bytes memory selectionCalldata;
        selectionCalldata = abi.encode(true, true, false);

        // Execute mandate (allowedRole = 1, alice has role 1)
        vm.prank(alice);
        daoMock.request(mandateId, selectionCalldata, nonce, "Test peer select execution");

        // Verify the action was fulfilled
        actionId = uint256(keccak256(abi.encode(mandateId, selectionCalldata, nonce)));
        assertTrue(daoMock.getActionState(actionId) == PowersTypes.ActionState.Fulfilled);

        // Verify roles were assigned to charlotte and david, but not eve
        assertEq(daoMock.hasRoleSince(charlotte, 4) > 0, true);
        assertEq(daoMock.hasRoleSince(david, 4) > 0, true);
        assertEq(daoMock.hasRoleSince(eve, 4) > 0, false);
    }

    function testPeerSelectRevertsNotEnoughNominees() public {
        // Nominate only 1 candidate (we need 2)
        vm.startPrank(address(daoMock));
        nomineesContract.nominate(charlotte, true);
        vm.stopPrank();

        bytes memory selectionCalldata;
        selectionCalldata = abi.encode(true);

        vm.prank(alice);
        vm.expectRevert("Not enough nominees to fill the seats.");
        daoMock.request(mandateId, selectionCalldata, nonce, "Test peer select not enough nominees");
    }

    function testPeerSelectRevertsIncorrectSelections() public {
        // Nominate 3 candidates
        vm.startPrank(address(daoMock));
        nomineesContract.nominate(charlotte, true);
        nomineesContract.nominate(david, true);
        nomineesContract.nominate(eve, true);
        vm.stopPrank();

        // Prepare selection with 1 choice (we need exactly 2)
        bytes memory selectionCalldata;
        selectionCalldata = abi.encode(true, false, false);

        vm.prank(alice);
        vm.expectRevert("Must select exactly numberToSelect options.");
        daoMock.request(mandateId, selectionCalldata, nonce, "Test peer select invalid selection");

        // Prepare selection with 3 choices (we need exactly 2)
        selectionCalldata = abi.encode(true, true, true);

        vm.prank(alice);
        vm.expectRevert("Must select exactly numberToSelect options.");
        daoMock.request(mandateId, selectionCalldata, nonce, "Test peer select invalid selection too many");
    }

    function testPeerSelectRevertsInvalidCalldataLength() public {
        // Nominate 3 candidates
        vm.startPrank(address(daoMock));
        nomineesContract.nominate(charlotte, true);
        nomineesContract.nominate(david, true);
        nomineesContract.nominate(eve, true);
        vm.stopPrank();
        // Pass 2 bools instead of 3
        bytes memory selectionCalldata = abi.encode(true, true);

        vm.prank(alice);
        vm.expectRevert("Invalid selection length.");
        daoMock.request(mandateId, selectionCalldata, nonce, "Test peer select length mismatch");
    }

    function testPeerSelectOneTimeExecution() public {
        // Nominate 3 candidates
        vm.startPrank(address(daoMock));
        nomineesContract.nominate(charlotte, true);
        nomineesContract.nominate(david, true);
        nomineesContract.nominate(eve, true);
        vm.stopPrank();

        bytes memory selectionCalldata = abi.encode(true, true, false);

        // First execution succeeds
        vm.prank(alice);
        daoMock.request(mandateId, selectionCalldata, nonce, "Test peer select first execution");

        // Mandate should be revoked
        (,, bool active) = daoMock.getAdoptedMandate(mandateId);
        assertEq(active, false);

        // Second execution should fail because mandate is inactive
        vm.prank(alice);
        vm.expectRevert(PowersErrors.Powers__MandateNotActive.selector);
        daoMock.request(mandateId, selectionCalldata, nonce + 1, "Test peer select second execution");
    }
}

//////////////////////////////////////////////////
//              ROLE BY ROLES TESTS            //
//////////////////////////////////////////////////
contract RoleByRolesTest is TestSetupElectoral {
    RoleByRoles roleByRoles;

    function setUp() public override {
        super.setUp();
        mandateId =
            findMandateIdInOrg("RoleByRoles: A mandate to assign roles based on existing role holders.", daoMock);
        roleByRoles = RoleByRoles(findMandateAddress("RoleByRoles"));
    }

    function testRoleByRolesInitialization() public {
        // Verify mandate data is stored correctly
        (uint256 newRoleId, uint256[] memory roleIdsNeeded) =
            abi.decode(roleByRoles.getConfig(address(daoMock), mandateId), (uint256, uint256[]));
        assertEq(newRoleId, 4);
        assertEq(roleIdsNeeded.length, 2);
    }

    function testRoleByRolesAssignRole() public {
        // Execute with account that has needed role
        vm.prank(alice);
        daoMock.request(mandateId, abi.encode(alice), nonce, "Test role by roles");

        // Should succeed
        actionId = uint256(keccak256(abi.encode(mandateId, abi.encode(alice), nonce)));
        assertTrue(daoMock.getActionState(actionId) == PowersTypes.ActionState.Fulfilled);
    }

    function testRoleByRolesRevokeRole() public {
        // Give alice the new role first
        vm.prank(address(daoMock));
        daoMock.assignRole(4, alice);

        // Remove alice's needed role
        vm.prank(address(daoMock));
        daoMock.revokeRole(1, alice);

        // Execute with account that no longer has needed role
        vm.prank(alice);
        daoMock.request(mandateId, abi.encode(alice), nonce, "Test role by roles");

        // Should succeed
        actionId = uint256(keccak256(abi.encode(mandateId, abi.encode(alice), nonce)));
        assertTrue(daoMock.getActionState(actionId) == PowersTypes.ActionState.Fulfilled);
    }
}

//////////////////////////////////////////////////
//              SELF SELECT TESTS              //
//////////////////////////////////////////////////
contract SelfSelectTest is TestSetupElectoral {
    SelfSelect selfSelect;

    function setUp() public override {
        super.setUp();
        mandateId = findMandateIdInOrg("SelfSelect: A mandate to self-assign a role.", daoMock);
        selfSelect = SelfSelect(findMandateAddress("SelfSelect"));
    }

    function testSelfSelectInitialization() public {
        // Verify mandate data is stored correctly
        (uint256 roleId) = abi.decode(selfSelect.getConfig(address(daoMock), mandateId), (uint256));
        assertEq(roleId, 4);
    }

    function testSelfSelectAssignRole() public {
        // Execute with account that doesn't have role
        vm.prank(alice);
        daoMock.request(mandateId, abi.encode(), nonce, "Test self select");

        // Should succeed
        actionId = uint256(keccak256(abi.encode(mandateId, abi.encode(), nonce)));
        assertTrue(daoMock.getActionState(actionId) == PowersTypes.ActionState.Fulfilled);
    }

    function testSelfSelectRevertsWithExistingRole() public {
        // Give alice the role first
        vm.prank(address(daoMock));
        daoMock.assignRole(4, alice);

        // Execute with account that already has role
        vm.prank(alice);
        vm.expectRevert("Account already has role.");
        daoMock.request(mandateId, abi.encode(), nonce, "Test self select");
    }
}

//////////////////////////////////////////////////
//              RENOUNCE ROLE TESTS            //
//////////////////////////////////////////////////
contract RenounceRoleTest is TestSetupElectoral {
    RenounceRole renounceRole;

    function setUp() public override {
        super.setUp();
        mandateId = findMandateIdInOrg("RenounceRole: A mandate to renounce specific roles.", daoMock);
        renounceRole = RenounceRole(findMandateAddress("RenounceRole"));
    }

    function testRenounceRoleInitialization() public {
        // Verify mandate data is stored correctly
        mandateHash = keccak256(abi.encode(address(daoMock), mandateId));
        uint256[] memory storedRoleIds = renounceRole.getAllowedRoleIds(mandateHash);
        assertEq(storedRoleIds.length, 2);
    }

    function testRenounceRoleWithValidRole() public {
        // Execute with valid role
        vm.prank(alice);
        daoMock.request(mandateId, abi.encode(1), nonce, "Test renounce role");

        // Should succeed
        actionId = uint256(keccak256(abi.encode(mandateId, abi.encode(1), nonce)));
        assertTrue(daoMock.getActionState(actionId) == PowersTypes.ActionState.Fulfilled);
    }

    function testRenounceRoleRevertsWithoutRole() public {
        // Execute with account that doesn't have role
        vm.prank(alice);
        vm.expectRevert("Account does not have role.");
        daoMock.request(mandateId, abi.encode(2), nonce, "Test renounce role");
    }

    function testRenounceRoleRevertsWithDisallowedRole() public {
        vm.prank(address(daoMock));
        daoMock.assignRole(3, alice);

        // Execute with disallowed role
        vm.prank(alice);
        vm.expectRevert("Role not allowed to be renounced.");
        daoMock.request(mandateId, abi.encode(3), nonce, "Test renounce role");
    }
}

// ─────────────────────────────────────────────
//         REVOKE INACTIVE ACCOUNTS
// ─────────────────────────────────────────────

// ─────────────────────────────────────────────
//               BASIC BEHAVIOUR
// ─────────────────────────────────────────────
contract RevokeInactiveAccountsBasicTest is TestSetupRevokeInactiveAccounts {
    RevokeInactiveAccounts revokeInactiveAccounts;
    uint16 riaId;
    uint16 selfSelectId;
    uint16 soiId;

    function setUp() public override {
        super.setUp();
        revokeInactiveAccounts = RevokeInactiveAccounts(findMandateAddress("RevokeInactiveAccounts"));
        riaId = findMandateIdInOrg("RevokeInactiveAccounts: monitor role 3.", daoMock);
        selfSelectId = findMandateIdInOrg("SelfSelect: self-assign role 5 (role 3 required).", daoMock);
        soiId = findMandateIdInOrg("StatementOfIntent: proposal voteable by role 3.", daoMock);
    }

    function testRevokeInactiveAccountsInitialization() public {
        (uint256 roleId, uint256 minimumActionsNeeded, uint256 numberActionsToCheck) =
            abi.decode(revokeInactiveAccounts.getConfig(address(daoMock), riaId), (uint256, uint256, uint256));
        assertEq(roleId, 3);
        assertEq(minimumActionsNeeded, 1);
        assertEq(numberActionsToCheck, 5);
    }

    function testRevokeInactiveAccountsRevokesAllInactiveAccounts() public {
        // alice and bob have role 3 but no actions on any role-3 mandate yet
        assertGt(daoMock.hasRoleSince(alice, ROLE_THREE), 0);
        assertGt(daoMock.hasRoleSince(bob, ROLE_THREE), 0);

        vm.prank(alice);
        daoMock.request(riaId, abi.encode(), nonce, "revoke inactive");

        actionId = uint256(keccak256(abi.encode(riaId, abi.encode(), nonce)));
        assertEq(uint8(daoMock.getActionState(actionId)), uint8(PowersTypes.ActionState.Fulfilled));
        assertEq(daoMock.hasRoleSince(alice, ROLE_THREE), 0);
        assertEq(daoMock.hasRoleSince(bob, ROLE_THREE), 0);
    }

    function testRevokeInactiveAccountsKeepsActiveCallers() public {
        // alice calls a role-3 mandate → recorded as the caller of a fulfilled action
        vm.prank(alice);
        daoMock.request(selfSelectId, abi.encode(), nonce, "alice self-selects role 5");

        // RIA: alice has 1 action (≥1 minimum) → kept; bob has 0 → revoked
        vm.prank(alice);
        daoMock.request(riaId, abi.encode(), nonce + 1, "revoke inactive");

        actionId = uint256(keccak256(abi.encode(riaId, abi.encode(), nonce + 1)));
        assertEq(uint8(daoMock.getActionState(actionId)), uint8(PowersTypes.ActionState.Fulfilled));
        assertGt(daoMock.hasRoleSince(alice, ROLE_THREE), 0);
        assertEq(daoMock.hasRoleSince(bob, ROLE_THREE), 0);
    }

    // function testRevokeInactiveAccountsKeepsActiveVoters() public {
    //     // alice proposes a StatementOfIntent, bob votes FOR, alice executes → fulfilled action
    //     mandateCalldata = abi.encode();
    //     vm.prank(alice);
    //     actionId1 = daoMock.propose(soiId, mandateCalldata, nonce, "alice proposes");

    //     vm.roll(block.number + 1);
    //     vm.prank(bob);
    //     daoMock.castVote(actionId1, FOR);

    //     // roll past votingPeriod(100) + timelock(0)
    //     vm.roll(block.number + 100 + 1);
    //     vm.prank(alice);
    //     daoMock.request(soiId, mandateCalldata, nonce, "alice executes");

    //     // RIA: alice = actionCaller (+1), bob = voter via hasVoted (+1); both ≥ 1 → none revoked
    //     vm.prank(alice);
    //     daoMock.request(riaId, abi.encode(), nonce + 1, "revoke inactive");

    //     actionId = uint256(keccak256(abi.encode(riaId, abi.encode(), nonce + 1)));
    //     assertEq(uint8(daoMock.getActionState(actionId)), uint8(PowersTypes.ActionState.Fulfilled));
    //     assertGt(daoMock.hasRoleSince(alice, ROLE_THREE), 0);
    //     assertGt(daoMock.hasRoleSince(bob, ROLE_THREE), 0);
    // }
}

// ─────────────────────────────────────────────
//               EDGE CASES
// ─────────────────────────────────────────────
contract RevokeInactiveAccountsEdgeCaseTest is TestSetupRevokeInactiveAccounts {
    uint16 riaId;
    uint16 selfSelectId;

    function setUp() public override {
        super.setUp();
        riaId = findMandateIdInOrg("RevokeInactiveAccounts: monitor role 3.", daoMock);
        selfSelectId = findMandateIdInOrg("SelfSelect: self-assign role 5 (role 3 required).", daoMock);
    }

    function testRevokeInactiveAccountsEarlyReturnWhenNoRoleHolders() public {
        // Revoke role 3 from all holders before calling
        vm.startPrank(address(daoMock));
        daoMock.revokeRole(ROLE_THREE, alice);
        daoMock.revokeRole(ROLE_THREE, bob);
        vm.stopPrank();

        vm.prank(alice);
        daoMock.request(riaId, abi.encode(), nonce, "no role holders");

        // Mandate fulfills with empty execution (early return path in handleRequest)
        actionId = uint256(keccak256(abi.encode(riaId, abi.encode(), nonce)));
        assertEq(uint8(daoMock.getActionState(actionId)), uint8(PowersTypes.ActionState.Fulfilled));
    }

    function testRevokeInactiveAccountsEmptyCalldataWhenNoneToRevoke() public {
        // alice and bob each call selfSelectId → each is the caller of one fulfilled action
        vm.prank(alice);
        daoMock.request(selfSelectId, abi.encode(), nonce, "alice active");
        vm.prank(bob);
        daoMock.request(selfSelectId, abi.encode(), nonce + 1, "bob active");

        // Both have 1 action ≥ 1 minimum → revokeCount = 0 → fulfilled with empty execution
        vm.prank(alice);
        daoMock.request(riaId, abi.encode(), nonce + 2, "revoke inactive");

        actionId = uint256(keccak256(abi.encode(riaId, abi.encode(), nonce + 2)));
        assertEq(uint8(daoMock.getActionState(actionId)), uint8(PowersTypes.ActionState.Fulfilled));
        assertGt(daoMock.hasRoleSince(alice, ROLE_THREE), 0);
        assertGt(daoMock.hasRoleSince(bob, ROLE_THREE), 0);
    }
}

// ─────────────────────────────────────────────
//               ACCESS CONTROL
// ─────────────────────────────────────────────
contract RevokeInactiveAccountsAccessTest is TestSetupRevokeInactiveAccounts {
    uint16 riaId;

    function setUp() public override {
        super.setUp();
        riaId = findMandateIdInOrg("RevokeInactiveAccounts: monitor role 3.", daoMock);
    }

    function testRevokeInactiveAccountsPublicRoleAnyoneCanCall() public {
        // jacob has no assigned roles; mandate has allowedRole = PUBLIC_ROLE (type(uint256).max)
        mandateCalldata = abi.encode();
        vm.prank(jacob);
        daoMock.request(riaId, mandateCalldata, nonce, "jacob triggers RIA");

        actionId = uint256(keccak256(abi.encode(riaId, mandateCalldata, nonce)));
        assertEq(uint8(daoMock.getActionState(actionId)), uint8(PowersTypes.ActionState.Fulfilled));
        // alice and bob were inactive → both revoked
        assertEq(daoMock.hasRoleSince(alice, ROLE_THREE), 0);
        assertEq(daoMock.hasRoleSince(bob, ROLE_THREE), 0);
    }
}

// ─────────────────────────────────────────────
//                NOMINATE TESTS
// ─────────────────────────────────────────────

// ─────────────────────────────────────────────
//               BASIC BEHAVIOUR
// ─────────────────────────────────────────────
contract NominateBasicTest is TestSetupElectoral {
    function setUp() public override {
        super.setUp();
        mandateId = findMandateIdInOrg("Nominate: Nominate yourself for a role.", daoMock);
    }

    function testNominateAddsSelfToNominees() public {
        mandateCalldata = abi.encode(true);
        vm.prank(alice);
        daoMock.request(mandateId, mandateCalldata, nonce, "Nominate alice");

        actionId = uint256(keccak256(abi.encode(mandateId, mandateCalldata, nonce)));
        assertEq(uint8(daoMock.getActionState(actionId)), uint8(PowersTypes.ActionState.Fulfilled));
        assertTrue(nominees.isNominee(alice));
        assertEq(nominees.nomineesCount(), 1);
    }

    function testRevokeNominationRemovesSelfFromNominees() public {
        vm.prank(alice);
        daoMock.request(mandateId, abi.encode(true), nonce, "Nominate alice first");
        assertTrue(nominees.isNominee(alice));

        mandateCalldata = abi.encode(false);
        vm.prank(alice);
        daoMock.request(mandateId, mandateCalldata, nonce + 1, "Revoke alice nomination");

        actionId = uint256(keccak256(abi.encode(mandateId, mandateCalldata, nonce + 1)));
        assertEq(uint8(daoMock.getActionState(actionId)), uint8(PowersTypes.ActionState.Fulfilled));
        assertFalse(nominees.isNominee(alice));
        assertEq(nominees.nomineesCount(), 0);
    }
}

// ─────────────────────────────────────────────
//               EDGE CASES
// ─────────────────────────────────────────────
contract NominateEdgeCaseTest is TestSetupElectoral {
    function setUp() public override {
        super.setUp();
        mandateId = findMandateIdInOrg("Nominate: Nominate yourself for a role.", daoMock);
    }

    function testNominateRevertsWhenAlreadyNominated() public {
        vm.prank(alice);
        daoMock.request(mandateId, abi.encode(true), nonce, "First nomination");

        vm.prank(alice);
        vm.expectRevert("already nominated");
        daoMock.request(mandateId, abi.encode(true), nonce + 1, "Duplicate nomination");
    }

    function testRevokeRevertsWhenNotNominated() public {
        vm.prank(alice);
        vm.expectRevert("not nominated");
        daoMock.request(mandateId, abi.encode(false), nonce, "Revoke without prior nomination");
    }
}

// ─────────────────────────────────────────────
//               ACCESS CONTROL
// ─────────────────────────────────────────────
contract NominateAccessTest is TestSetupElectoral {
    function setUp() public override {
        super.setUp();
        mandateId = findMandateIdInOrg("Nominate: Nominate yourself for a role.", daoMock);
    }

    function testNominatePublicRoleAnyoneCanCall() public {
        // jacob has no assigned role; mandate allowedRole = PUBLIC_ROLE (type(uint256).max)
        mandateCalldata = abi.encode(true);
        vm.prank(jacob);
        daoMock.request(mandateId, mandateCalldata, nonce, "Jacob nominates himself");

        actionId = uint256(keccak256(abi.encode(mandateId, mandateCalldata, nonce)));
        assertEq(uint8(daoMock.getActionState(actionId)), uint8(PowersTypes.ActionState.Fulfilled));
        assertTrue(nominees.isNominee(jacob));
    }
}

// ─────────────────────────────────────────────
//           ASSIGN EXTERNAL ROLE TESTS
// ─────────────────────────────────────────────

// ─────────────────────────────────────────────
//               BASIC BEHAVIOUR
// ─────────────────────────────────────────────
contract AssignExternalRoleBasicTest is TestSetupAssignExternalRoleParentFlow {
    AssignExternalRole assignExternalRole;

    function setUp() public override {
        super.setUp();
        assignExternalRole = AssignExternalRole(findMandateAddress("AssignExternalRole"));
        mandateId = findMandateIdInOrg(
            "Adopt Role 1: Anyone that has role 1 at the parent organization can adopt the same role here.",
            daoMockChild1
        );
    }

    function testInitializationStoresConfig() public {
        (address externalPowersAddress, uint256 roleId) =
            abi.decode(assignExternalRole.getConfig(address(daoMockChild1), mandateId), (address, uint256));
        assertEq(externalPowersAddress, address(daoMock));
        assertEq(roleId, ROLE_ONE);
    }

    function testAssignRoleWhenParentHasChildDoesNot() public {
        // alice has role 1 at parent (assigned in setUp) but not at child
        assertGt(daoMock.hasRoleSince(alice, ROLE_ONE), 0);
        assertEq(daoMockChild1.hasRoleSince(alice, ROLE_ONE), 0);

        mandateCalldata = abi.encode(alice);
        vm.prank(alice);
        daoMockChild1.request(mandateId, mandateCalldata, nonce, "Sync role: assign alice in child");

        actionId = uint256(keccak256(abi.encode(mandateId, mandateCalldata, nonce)));
        assertTrue(daoMockChild1.getActionState(actionId) == PowersTypes.ActionState.Fulfilled);
        assertGt(daoMockChild1.hasRoleSince(alice, ROLE_ONE), 0);
    }

    function testRevokeRoleWhenChildHasParentDoesNot() public {
        // Give alice role 1 at child, then remove it from parent
        vm.prank(address(daoMockChild1));
        daoMockChild1.assignRole(ROLE_ONE, alice);
        vm.prank(address(daoMock));
        daoMock.revokeRole(ROLE_ONE, alice);

        assertEq(daoMock.hasRoleSince(alice, ROLE_ONE), 0);
        assertGt(daoMockChild1.hasRoleSince(alice, ROLE_ONE), 0);

        mandateCalldata = abi.encode(alice);
        vm.prank(alice);
        daoMockChild1.request(mandateId, mandateCalldata, nonce, "Sync role: revoke alice from child");

        actionId = uint256(keccak256(abi.encode(mandateId, mandateCalldata, nonce)));
        assertTrue(daoMockChild1.getActionState(actionId) == PowersTypes.ActionState.Fulfilled);
        assertEq(daoMockChild1.hasRoleSince(alice, ROLE_ONE), 0);
    }
}

// ─────────────────────────────────────────────
//               EDGE CASES
// ─────────────────────────────────────────────
contract AssignExternalRoleEdgeCaseTest is TestSetupAssignExternalRoleParentFlow {
    function setUp() public override {
        super.setUp();
        mandateId = findMandateIdInOrg(
            "Adopt Role 1: Anyone that has role 1 at the parent organization can adopt the same role here.",
            daoMockChild1
        );
    }

    function testRevertsWhenNeitherHasRole() public {
        // charlotte has no role 1 at parent or child
        assertEq(daoMock.hasRoleSince(charlotte, ROLE_ONE), 0);
        assertEq(daoMockChild1.hasRoleSince(charlotte, ROLE_ONE), 0);

        mandateCalldata = abi.encode(charlotte);
        vm.prank(charlotte);
        vm.expectRevert("Account does not have role at parent");
        daoMockChild1.request(mandateId, mandateCalldata, nonce, "Sync role: no role anywhere");
    }

    function testRevertsWhenBothHaveRole() public {
        // alice has role 1 at parent; give her role 1 at child too
        vm.prank(address(daoMockChild1));
        daoMockChild1.assignRole(ROLE_ONE, alice);

        assertGt(daoMock.hasRoleSince(alice, ROLE_ONE), 0);
        assertGt(daoMockChild1.hasRoleSince(alice, ROLE_ONE), 0);

        mandateCalldata = abi.encode(alice);
        vm.prank(alice);
        vm.expectRevert("Account already has role at parent");
        daoMockChild1.request(mandateId, mandateCalldata, nonce, "Sync role: already in sync");
    }
}

// ─────────────────────────────────────────────
//               ACCESS CONTROL
// ─────────────────────────────────────────────
contract AssignExternalRoleAccessTest is TestSetupAssignExternalRoleParentFlow {
    function setUp() public override {
        super.setUp();
        mandateId = findMandateIdInOrg(
            "Adopt Role 1: Anyone that has role 1 at the parent organization can adopt the same role here.",
            daoMockChild1
        );
    }

    function testAnyoneCanCallMandate() public {
        // eve has no roles anywhere, but the mandate is public (allowedRole = type(uint256).max)
        // she can still trigger a sync for alice's account
        assertEq(daoMockChild1.hasRoleSince(eve, ROLE_ONE), 0);

        mandateCalldata = abi.encode(alice);
        vm.prank(eve);
        daoMockChild1.request(mandateId, mandateCalldata, nonce, "Eve triggers role sync for alice");

        actionId = uint256(keccak256(abi.encode(mandateId, mandateCalldata, nonce)));
        assertTrue(daoMockChild1.getActionState(actionId) == PowersTypes.ActionState.Fulfilled);
        assertGt(daoMockChild1.hasRoleSince(alice, ROLE_ONE), 0);
    }
}

// ─────────────────────────────────────────────
//   DELEGATE TOKEN SELECT — BASIC BEHAVIOUR
// ─────────────────────────────────────────────
contract DelegateTokenSelectBasicTest is TestSetupDelegateTokenFlow {
    function setUp() public override {
        super.setUp();
        mandateId = findMandateIdInOrg(
            "Elect Delegates: Run the election for delegates. In this demo, the top 3 nominees by token delegation of token VOTES_TOKEN become Delegates.",
            daoMock
        );
    }

    function testDelegateTokenSelectFastPathElectsAllNominees() public {
        // 2 nominees < maxRoleHolders=3 → fast path (line 85), all elected; previous holders revoked
        vm.startPrank(address(daoMock));
        nominees.nominate(eve, true);
        nominees.nominate(frank, true);
        vm.stopPrank();

        vm.prank(alice);
        daoMock.request(mandateId, abi.encode(), nonce, "fast path election");

        actionId = uint256(keccak256(abi.encode(mandateId, abi.encode(), nonce)));
        assertEq(uint8(daoMock.getActionState(actionId)), uint8(PowersTypes.ActionState.Fulfilled));

        assertGt(daoMock.hasRoleSince(eve, ROLE_TWO), 0);
        assertGt(daoMock.hasRoleSince(frank, ROLE_TWO), 0);
        assertEq(daoMock.hasRoleSince(charlotte, ROLE_TWO), 0);
        assertEq(daoMock.hasRoleSince(david, ROLE_TWO), 0);
    }

    function testDelegateTokenSelectExactMaxNomineesFastPath() public {
        // exactly maxRoleHolders=3 nominees → fast path, all three elected
        vm.startPrank(address(daoMock));
        nominees.nominate(eve, true);
        nominees.nominate(frank, true);
        nominees.nominate(gary, true);
        vm.stopPrank();

        vm.prank(alice);
        daoMock.request(mandateId, abi.encode(), nonce, "exact max nominees");

        actionId = uint256(keccak256(abi.encode(mandateId, abi.encode(), nonce)));
        assertEq(uint8(daoMock.getActionState(actionId)), uint8(PowersTypes.ActionState.Fulfilled));

        assertGt(daoMock.hasRoleSince(eve, ROLE_TWO), 0);
        assertGt(daoMock.hasRoleSince(frank, ROLE_TWO), 0);
        assertGt(daoMock.hasRoleSince(gary, ROLE_TWO), 0);
    }

    function testDelegateTokenSelectRanksByDelegatedVotes() public {
        // 4 nominees > maxRoleHolders=3 → bubble sort runs, top 3 by votes elected.
        // Nominate order (eve, frank, gary, helen) is deliberately the *reverse* of the vote order
        // so the ranking genuinely reorders the array rather than passing on insertion order.
        vm.startPrank(address(daoMock));
        nominees.nominate(eve, true);
        nominees.nominate(frank, true);
        nominees.nominate(gary, true);
        nominees.nominate(helen, true);
        vm.stopPrank();

        vm.startPrank(eve);
        simpleErc20Votes.mint(40 ether);
        simpleErc20Votes.delegate(eve);
        vm.stopPrank();

        vm.startPrank(frank);
        simpleErc20Votes.mint(60 ether);
        simpleErc20Votes.delegate(frank);
        vm.stopPrank();

        vm.startPrank(gary);
        simpleErc20Votes.mint(80 ether);
        simpleErc20Votes.delegate(gary);
        vm.stopPrank();

        vm.startPrank(helen);
        simpleErc20Votes.mint(100 ether);
        simpleErc20Votes.delegate(helen);
        vm.stopPrank();

        // Ranking reads a *past* snapshot (getPastVotes), so the delegations above must be in a
        // block strictly before request(); advance one block. Otherwise all nominees read 0.
        vm.roll(block.number + 1);

        vm.prank(alice);
        daoMock.request(mandateId, abi.encode(), nonce, "ranked election");

        actionId = uint256(keccak256(abi.encode(mandateId, abi.encode(), nonce)));
        assertEq(uint8(daoMock.getActionState(actionId)), uint8(PowersTypes.ActionState.Fulfilled));

        // Top 3 by delegated votes: helen(100), gary(80), frank(60). eve(40) is excluded.
        assertGt(daoMock.hasRoleSince(helen, ROLE_TWO), 0);
        assertGt(daoMock.hasRoleSince(gary, ROLE_TWO), 0);
        assertGt(daoMock.hasRoleSince(frank, ROLE_TWO), 0);
        assertEq(daoMock.hasRoleSince(eve, ROLE_TWO), 0);
    }

    function testDelegateTokenSelectIgnoresSameBlockDelegation() public {
        // C-03 regression: delegated voting power is read from a past snapshot, so a nominee cannot
        // capture a seat by acquiring/borrowing delegation in the execution block (flash-loan style).
        vm.startPrank(address(daoMock));
        nominees.nominate(eve, true);
        nominees.nominate(frank, true);
        nominees.nominate(gary, true);
        nominees.nominate(helen, true);
        vm.stopPrank();

        // Snapshot state: eve/frank/gary hold delegation; helen holds none.
        vm.startPrank(eve);
        simpleErc20Votes.mint(100 ether);
        simpleErc20Votes.delegate(eve);
        vm.stopPrank();

        vm.startPrank(frank);
        simpleErc20Votes.mint(80 ether);
        simpleErc20Votes.delegate(frank);
        vm.stopPrank();

        vm.startPrank(gary);
        simpleErc20Votes.mint(60 ether);
        simpleErc20Votes.delegate(gary);
        vm.stopPrank();

        // Advance so the delegations above form the past snapshot the ranking reads.
        vm.roll(block.number + 1);

        // In the execution block, helen tries to just-in-time delegate a large balance to herself.
        vm.startPrank(helen);
        simpleErc20Votes.mint(100 ether);
        simpleErc20Votes.delegate(helen);
        vm.stopPrank();

        vm.prank(alice);
        daoMock.request(mandateId, abi.encode(), nonce, "same-block delegation ignored");

        actionId = uint256(keccak256(abi.encode(mandateId, abi.encode(), nonce)));
        assertEq(uint8(daoMock.getActionState(actionId)), uint8(PowersTypes.ActionState.Fulfilled));

        // helen's same-block delegation is ignored; the snapshot top 3 (eve/frank/gary) win.
        assertGt(daoMock.hasRoleSince(eve, ROLE_TWO), 0);
        assertGt(daoMock.hasRoleSince(frank, ROLE_TWO), 0);
        assertGt(daoMock.hasRoleSince(gary, ROLE_TWO), 0);
        assertEq(daoMock.hasRoleSince(helen, ROLE_TWO), 0);
    }
}

// ─────────────────────────────────────────────
//     DELEGATE TOKEN SELECT — EDGE CASES
// ─────────────────────────────────────────────
contract DelegateTokenSelectEdgeCaseTest is TestSetupDelegateTokenFlow {
    function setUp() public override {
        super.setUp();
        mandateId = findMandateIdInOrg(
            "Elect Delegates: Run the election for delegates. In this demo, the top 3 nominees by token delegation of token VOTES_TOKEN become Delegates.",
            daoMock
        );
    }

    function testDelegateTokenSelectRevokesAllWhenNoNominees() public {
        // no nominees; charlotte and david hold ROLE_TWO from setup → both revoked
        vm.prank(alice);
        daoMock.request(mandateId, abi.encode(), nonce, "no nominees revoke all");

        actionId = uint256(keccak256(abi.encode(mandateId, abi.encode(), nonce)));
        assertEq(uint8(daoMock.getActionState(actionId)), uint8(PowersTypes.ActionState.Fulfilled));

        assertEq(daoMock.hasRoleSince(charlotte, ROLE_TWO), 0);
        assertEq(daoMock.hasRoleSince(david, ROLE_TWO), 0);
    }

    function testDelegateTokenSelectEmptyStateReturnsEmptyArray() public {
        // revoke setup roles so amountRoleHolders=0; no nominees → totalOperations=0 early return
        vm.startPrank(address(daoMock));
        daoMock.revokeRole(ROLE_TWO, charlotte);
        daoMock.revokeRole(ROLE_TWO, david);
        vm.stopPrank();

        vm.prank(alice);
        daoMock.request(mandateId, abi.encode(), nonce, "empty state");

        actionId = uint256(keccak256(abi.encode(mandateId, abi.encode(), nonce)));
        assertEq(uint8(daoMock.getActionState(actionId)), uint8(PowersTypes.ActionState.Fulfilled));
    }
}

// ─────────────────────────────────────────────
//   DELEGATE TOKEN SELECT — ACCESS CONTROL
// ─────────────────────────────────────────────
contract DelegateTokenSelectAccessTest is TestSetupDelegateTokenFlow {
    function setUp() public override {
        super.setUp();
        mandateId = findMandateIdInOrg(
            "Elect Delegates: Run the election for delegates. In this demo, the top 3 nominees by token delegation of token VOTES_TOKEN become Delegates.",
            daoMock
        );
    }

    function testDelegateTokenSelectThrottleBlocksReExecution() public {
        // first execution succeeds
        vm.prank(alice);
        daoMock.request(mandateId, abi.encode(), nonce, "first execution");

        actionId = uint256(keccak256(abi.encode(mandateId, abi.encode(), nonce)));
        assertEq(uint8(daoMock.getActionState(actionId)), uint8(PowersTypes.ActionState.Fulfilled));

        // second call within throttle window (600 blocks) reverts
        vm.prank(alice);
        vm.expectRevert(Checks.Checks__ExecutionGapTooSmall.selector);
        daoMock.request(mandateId, abi.encode(), nonce + 1, "second execution throttled");
    }
}

// ─────────────────────────────────────────────
//          REVOKE ACCOUNTS ROLE ID
// ─────────────────────────────────────────────

// ─────────────────────────────────────────────
//               BASIC BEHAVIOUR
// ─────────────────────────────────────────────
contract RevokeAccountsRoleIdBasicTest is TestSetupRevokeAccountsRoleId {
    RevokeAccountsRoleId revokeAccountsRoleId;
    uint16 selfSelectId;
    uint16 rariId;

    function setUp() public override {
        super.setUp();
        revokeAccountsRoleId = RevokeAccountsRoleId(findMandateAddress("RevokeAccountsRoleId"));
        selfSelectId = findMandateIdInOrg("SelfSelect: self-assign role 3.", daoMock);
        rariId = findMandateIdInOrg("RevokeAccountsRoleId: revoke all holders of role 3.", daoMock);
    }

    function testInitializationStoresRoleId() public {
        (uint256 roleId,) = abi.decode(revokeAccountsRoleId.getConfig(address(daoMock), rariId), (uint256, string[]));
        assertEq(roleId, 3);
    }

    function testRevokeAccountsRoleIdRevokesAllHolders() public {
        vm.startPrank(address(daoMock));
        daoMock.assignRole(ROLE_THREE, alice);
        daoMock.assignRole(ROLE_THREE, bob);
        vm.stopPrank();

        assertGt(daoMock.hasRoleSince(alice, ROLE_THREE), 0);
        assertGt(daoMock.hasRoleSince(bob, ROLE_THREE), 0);

        mandateCalldata = abi.encode();
        vm.prank(alice);
        daoMock.request(rariId, mandateCalldata, nonce, "revoke all role 3 holders");

        actionId = uint256(keccak256(abi.encode(rariId, mandateCalldata, nonce)));
        assertEq(uint8(daoMock.getActionState(actionId)), uint8(PowersTypes.ActionState.Fulfilled));
        assertEq(daoMock.hasRoleSince(alice, ROLE_THREE), 0);
        assertEq(daoMock.hasRoleSince(bob, ROLE_THREE), 0);
    }

    function testRevokeAccountsRoleIdRevokesSingleHolder() public {
        vm.prank(address(daoMock));
        daoMock.assignRole(ROLE_THREE, alice);

        assertGt(daoMock.hasRoleSince(alice, ROLE_THREE), 0);
        assertEq(daoMock.hasRoleSince(bob, ROLE_THREE), 0);

        mandateCalldata = abi.encode();
        vm.prank(alice);
        daoMock.request(rariId, mandateCalldata, nonce, "revoke single role 3 holder");

        actionId = uint256(keccak256(abi.encode(rariId, mandateCalldata, nonce)));
        assertEq(uint8(daoMock.getActionState(actionId)), uint8(PowersTypes.ActionState.Fulfilled));
        assertEq(daoMock.hasRoleSince(alice, ROLE_THREE), 0);
    }
}

// ─────────────────────────────────────────────
//               EDGE CASES
// ─────────────────────────────────────────────
contract RevokeAccountsRoleIdEdgeCaseTest is TestSetupRevokeAccountsRoleId {
    uint16 rariId;

    function setUp() public override {
        super.setUp();
        rariId = findMandateIdInOrg("RevokeAccountsRoleId: revoke all holders of role 3.", daoMock);
    }

    function testRevokeAccountsRoleIdEarlyReturnWhenNoHolders() public {
        assertEq(daoMock.getAmountRoleHolders(ROLE_THREE), 0);

        mandateCalldata = abi.encode();
        vm.prank(alice);
        daoMock.request(rariId, mandateCalldata, nonce, "no holders early return");

        actionId = uint256(keccak256(abi.encode(rariId, mandateCalldata, nonce)));
        assertEq(uint8(daoMock.getActionState(actionId)), uint8(PowersTypes.ActionState.Fulfilled));
    }
}

// ─────────────────────────────────────────────
//               ACCESS CONTROL
// ─────────────────────────────────────────────
contract RevokeAccountsRoleIdAccessTest is TestSetupRevokeAccountsRoleId {
    uint16 restrictedRariId;

    function setUp() public override {
        super.setUp();
        restrictedRariId = findMandateIdInOrg("RevokeAccountsRoleId: restricted to role 1.", daoMock);
    }

    function testRevokeAccountsRoleIdRevertsCallerLacksRole() public {
        // charlotte has role 2, not role 1 — must revert
        mandateCalldata = abi.encode();
        vm.prank(charlotte);
        vm.expectRevert(PowersErrors.Powers__CannotCallMandate.selector);
        daoMock.request(restrictedRariId, mandateCalldata, nonce, "caller lacks required role");
    }
}
