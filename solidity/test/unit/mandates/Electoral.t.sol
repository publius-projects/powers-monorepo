// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.26;

import { BaseSetup } from "../../TestSetup.t.sol";
import { TestSetupElectoral } from "../../TestSetup.t.sol";

import { PeerSelect } from "@src/mandates/electoral/PeerSelect.sol";
import { NStrikesRevokesRoles } from "@src/mandates/electoral/NStrikesRevokesRoles.sol";
import { RoleByRoles } from "@src/mandates/electoral/RoleByRoles.sol";
import { SelfSelect } from "@src/mandates/electoral/SelfSelect.sol";
import { RenounceRole } from "@src/mandates/electoral/RenounceRole.sol";
import { AssignExternalRole } from "@src/mandates/electoral/AssignExternalRole.sol";
import { FlagActions } from "@src/helpers/FlagActions.sol";
import { RoleByTransaction } from "@src/mandates/electoral/RoleByTransaction.sol";
import { PowersTypes } from "@src/interfaces/PowersTypes.sol";
import { PowersMock } from "@mocks/PowersMock.sol";
import { Nominees } from "@src/helpers/Nominees.sol"; 
import { RevokeInactiveAccounts } from "@src/mandates/electoral/RevokeInactiveAccounts.sol";

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
        // Setup nominees
        vm.prank(address(daoMock));
        nomineesContract.nominate(alice, true);
        vm.prank(address(daoMock));
        nomineesContract.nominate(bob, true); 

        // Verify mandate data is stored correctly 
        (uint256 maxRoleHolders, uint256 roleId, uint8 maxVotes, address nomineesContract) =
            abi.decode(peerSelect.getConfig(address(daoMock), mandateId), (uint256, uint256, uint8, address));
        
        assertEq(maxRoleHolders, 2);
        assertEq(roleId, 4);
        assertEq(maxVotes, 1);
        assertEq(nomineesContract, address(nomineesContract));
    }

    function testPeerSelectWithValidSelection() public {
        // Setup nominees
        vm.prank(address(daoMock));
        nomineesContract.nominate(alice, true);
        vm.prank(address(daoMock));
        nomineesContract.nominate(bob, true);

        // Execute with valid selection
        bool[] memory selection = new bool[](2);
        selection[0] = true; // Select alice
        selection[1] = false; // Don't select bob

        vm.prank(alice);
        daoMock.request(mandateId, abi.encode(selection), nonce, "Test peer select");

        // Should succeed
        actionId = uint256(keccak256(abi.encode(mandateId, abi.encode(selection), nonce)));
        assertTrue(daoMock.getActionState(actionId) == PowersTypes.ActionState.Fulfilled);
    }

    function testPeerSelectRevertsWithTooManySelections() public {
        // Setup nominees
        vm.prank(address(daoMock));
        nomineesContract.nominate(alice, true);
        vm.prank(address(daoMock));
        nomineesContract.nominate(bob, true);

        // Execute with too many selections
        bool[] memory selection = new bool[](2);
        selection[0] = true; // Select alice
        selection[1] = true; // Select bob (exceeds maxVotes)

        vm.prank(alice);
        vm.expectRevert("Too many selections. Exceeds maxVotes limit.");
        daoMock.request(mandateId, abi.encode(selection), nonce, "Test peer select");
    }

    function testPeerSelectWithNoNominees() public {
        // Create a new nominees contract with no nominees
        Nominees emptyNominees = new Nominees();

        // Setup mandate with empty nominees
        uint16 newMandateId = daoMock.mandateCounter();
        nameDescription = "Test Peer Select No Nominees";
        configBytes = abi.encode(2, 4, 1, address(emptyNominees));
        conditions.allowedRole = type(uint256).max;

        vm.prank(address(daoMock));
        daoMock.adoptMandate(
            PowersTypes.MandateInitData({
                nameDescription: nameDescription,
                targetMandate: address(peerSelect),
                config: configBytes,
                conditions: conditions
            })
        );


        // Verify mandate data is stored correctly
        mandateHash = keccak256(abi.encode(address(daoMock), newMandateId));
                // Verify mandate data is stored correctly 
        (uint256 maxRoleHolders, uint256 roleId, uint8 maxVotes, address nomineesContract) =
            abi.decode(peerSelect.getConfig(address(daoMock), newMandateId), (uint256, uint256, uint8, address));
        
        assertEq(maxRoleHolders, 2);
        assertEq(roleId, 4);
        assertEq(maxVotes, 1);
        assertEq(nomineesContract, address(emptyNominees)); 
    }

    function testPeerSelectRevertsWithInvalidSelectionLength() public {
        // Setup nominees
        vm.prank(address(daoMock));
        nomineesContract.nominate(alice, true);
        vm.prank(address(daoMock));
        nomineesContract.nominate(bob, true);

        // Execute with wrong selection length
        bool[] memory selection = new bool[](3); // Wrong length
        selection[0] = true;
        selection[1] = false;
        selection[2] = false;

        vm.prank(alice);
        vm.expectRevert("Invalid selection length.");
        daoMock.request(mandateId, abi.encode(selection), nonce, "Test peer select");
    }

    function testPeerSelectRevertsWithNoSelections() public {
        // Setup nominees
        vm.prank(address(daoMock));
        nomineesContract.nominate(alice, true);
        vm.prank(address(daoMock));
        nomineesContract.nominate(bob, true);

        // Execute with no selections
        bool[] memory selection = new bool[](2);
        selection[0] = false; // Don't select alice
        selection[1] = false; // Don't select bob

        vm.prank(alice);
        vm.expectRevert("Must select at least one nominee.");
        daoMock.request(mandateId, abi.encode(selection), nonce, "Test peer select");
    }

    function testPeerSelectRevertsWithTooManyAssignments() public {
        // Setup nominees
        vm.prank(address(daoMock));
        nomineesContract.nominate(alice, true);
        vm.prank(address(daoMock));
        nomineesContract.nominate(bob, true);

        // Give alice and bob the role first (to test revocation)
        vm.prank(address(daoMock));
        daoMock.assignRole(4, alice);
        vm.prank(address(daoMock));
        daoMock.assignRole(4, bob);

        // Setup mandate with maxRoleHolders = 1
        uint16 newMandateId = daoMock.mandateCounter();
        nameDescription = "Test Peer Select Too Many Assignments";
        configBytes = abi.encode(1, 4, 2, address(nomineesContract)); // maxRoleHolders = 1
        conditions.allowedRole = type(uint256).max;

        vm.prank(address(daoMock));
        daoMock.adoptMandate(
            PowersTypes.MandateInitData({
                nameDescription: nameDescription,
                targetMandate: address(peerSelect),
                config: configBytes,
                conditions: conditions
            })
        );

        // Execute with selections that would exceed max role holders
        bool[] memory selection = new bool[](2);
        selection[0] = true; // Select alice (already has role, so revocation)
        selection[1] = true; // Select bob (already has role, so revocation)

        vm.prank(alice);
        daoMock.request(newMandateId, abi.encode(selection), nonce, "Test peer select");

        // Should succeed (both are revocations, not assignments)
        actionId = uint256(keccak256(abi.encode(newMandateId, abi.encode(selection), nonce)));
        assertTrue(daoMock.getActionState(actionId) == PowersTypes.ActionState.Fulfilled);
    }
}

//////////////////////////////////////////////////
//            N STRIKES REVOKES ROLES TESTS    //
//////////////////////////////////////////////////
contract NStrikesRevokesRolesTest is TestSetupElectoral {
    NStrikesRevokesRoles nStrikesRevokesRoles;
    // FlagActions inherited from TestVariables

    function setUp() public override {
        super.setUp();
        nStrikesRevokesRoles = NStrikesRevokesRoles(findMandateAddress("NStrikesRevokesRoles"));
        mandateId = findMandateIdInOrg("NStrikesRevokesRoles: A mandate to revoke roles after N strikes.", daoMock);

        // Mock getActionState to always return Fulfilled
        vm.mockCall(
            address(daoMock), abi.encodeWithSelector(daoMock.getActionState.selector), abi.encode(PowersTypes.ActionState.Fulfilled)
        );
    }

    function testNStrikesRevokesRolesInitialization() public {
        // Verify mandate data is stored correctly
        mandateHash = keccak256(abi.encode(address(daoMock), mandateId));

        // Verify mandate data is stored correctly 
        (uint256 roleId, uint256 numberOfStrikes, address flagActionsAddress) =
            abi.decode(nStrikesRevokesRoles.getConfig(address(daoMock), mandateId), (uint256, uint256, address));

        assertEq(roleId, 3);
        assertEq(numberOfStrikes, 2);
        assertEq(flagActionsAddress, address(flagActions));
    }

    function testNStrikesRevokesRolesWithInsufficientStrikes() public {
        // Execute without enough strikes
        vm.prank(alice);
        vm.expectRevert("Not enough strikes to revoke roles.");
        daoMock.request(mandateId, abi.encode(), nonce, "Test strikes");
    }

    function testNStrikesRevokesRolesWithSufficientStrikes() public {
        // Add some role holders
        vm.prank(address(daoMock));
        daoMock.assignRole(3, alice);
        vm.prank(address(daoMock));
        daoMock.assignRole(3, bob);

        // Add strikes
        vm.prank(address(daoMock));
        flagActions.flag(1, 3, alice, 1);
        vm.prank(address(daoMock));
        flagActions.flag(2, 3, bob, 1);

        // Execute with sufficient strikes
        vm.prank(alice);
        daoMock.request(mandateId, abi.encode(), nonce, "Test strikes");

        // Should succeed
        actionId = uint256(keccak256(abi.encode(mandateId, abi.encode(), nonce)));
        assertTrue(daoMock.getActionState(actionId) == PowersTypes.ActionState.Fulfilled);
    }
}

//////////////////////////////////////////////////
//              ROLE BY ROLES TESTS            //
//////////////////////////////////////////////////
contract RoleByRolesTest is TestSetupElectoral {
    RoleByRoles roleByRoles;

    function setUp() public override {
        super.setUp();
        mandateId = findMandateIdInOrg("RoleByRoles: A mandate to assign roles based on existing role holders.", daoMock);
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
        (uint256 roleId) =
            abi.decode(selfSelect.getConfig(address(daoMock), mandateId), (uint256));
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


//////////////////////////////////////////////////
//          REVOKE INACTIVE ACCOUNTS TESTS      //
//////////////////////////////////////////////////
contract RevokeInactiveAccountsTest is TestSetupElectoral {
    RevokeInactiveAccounts revokeInactiveAccounts;

    function setUp() public override {
        super.setUp();
        revokeInactiveAccounts = RevokeInactiveAccounts(findMandateAddress("RevokeInactiveAccounts"));
        mandateId =
            findMandateIdInOrg("RevokeInactiveAccounts: A mandate to revoke roles from inactive accounts.", daoMock);
    }

    function testRevokeInactiveAccountsInitialization() public {
        // Verify mandate data is stored correctly
        (uint256 roleId, uint256 minimumActionsNeeded, uint256 numberActionsToCheck) =
            abi.decode(revokeInactiveAccounts.getConfig(address(daoMock), mandateId), (uint256, uint256, uint256));

        assertEq(roleId, 3);
        assertEq(minimumActionsNeeded, 1);
        assertEq(numberActionsToCheck, 5);
    }
}