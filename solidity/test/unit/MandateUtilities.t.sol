// SPDX-License-Identifier: MIT

/// @title MandateUtilitiesTest - Unit tests for MandateUtilities library
/// @notice Tests the MandateUtilities library functions
/// @dev Provides comprehensive coverage of all MandateUtilities functions
/// @author 7Cedars

pragma solidity 0.8.26;

import { Test } from "forge-std/Test.sol";
import { MandateUtilities } from "../../src/libraries/MandateUtilities.sol";
import { TestSetupMandate } from "../TestSetup.t.sol";
import { IMandate } from "../../src/interfaces/IMandate.sol";
import { Mandate } from "../../src/Mandate.sol";

import { SimpleErc1155 } from "@mocks/SimpleErc1155.sol";

contract MandateUtilitiesTest is TestSetupMandate {
    //////////////////////////////////////////////////////////////
    //                  STRING VALIDATION                       //
    //////////////////////////////////////////////////////////////
    function testCheckStringLengthAcceptsValidName() public pure {
        // Should not revert with valid name
        MandateUtilities.checkStringLength("Valid Mandate Name", 1, 31);
    }

    function testCheckStringLengthRevertsWithEmptyName() public {
        // Should revert with empty name
        vm.expectRevert("String too short");
        MandateUtilities.checkStringLength("", 1, 31);
    }

    function testCheckStringLengthRevertsWithTooLongName() public {
        // Should revert with name longer than 31 characters
        vm.expectRevert("String too long");
        MandateUtilities.checkStringLength("ThisNameIsWaaaaaayTooLongForAMandateName", 1, 31);
    }

    //////////////////////////////////////////////////////////////
    //                  ROLE CHECKS                              //
    //////////////////////////////////////////////////////////////
    function testHasRoleCheckPassesWithValidRole() public view {
        uint256[] memory roles = new uint256[](1);
        roles[0] = ROLE_ONE;

        // Should not revert when alice has ROLE_ONE
        MandateUtilities.hasRoleCheck(alice, roles, address(daoMock));
    }

    function testHasRoleCheckRevertsWithoutRole() public {
        uint256[] memory roles = new uint256[](1);
        roles[0] = ROLE_ONE;
        address userWithoutRole = makeAddr("userWithoutRole");

        // Should revert when user doesn't have the role
        vm.expectRevert("Does not have role.");
        MandateUtilities.hasRoleCheck(userWithoutRole, roles, address(daoMock));
    }

    function testHasNotRoleCheckPassesWithoutRole() public {
        uint256[] memory roles = new uint256[](1);
        roles[0] = uint256(ROLE_THREE);
        address userWithoutRole = makeAddr("userWithoutRole");

        // Should not revert when user doesn't have the role
        MandateUtilities.hasNotRoleCheck(userWithoutRole, roles, address(daoMock));
    }

    function testHasNotRoleCheckRevertsWithRole() public {
        uint256[] memory roles = new uint256[](1);
        roles[0] = ROLE_ONE;

        // Should revert when alice has the role
        vm.expectRevert("Has role.");
        MandateUtilities.hasNotRoleCheck(alice, roles, address(daoMock));
    }

    //////////////////////////////////////////////////////////////
    //                  HELPER FUNCTIONS                        //
    //////////////////////////////////////////////////////////////
    function testHashActionId() public {
        mandateId = 1;
        mandateCalldata = abi.encode(true);
        nonce = 123;

        actionId = MandateUtilities.computeActionId(mandateId, mandateCalldata, nonce);
        assertEq(actionId, uint256(keccak256(abi.encode(mandateId, mandateCalldata, nonce))));
    }

    function testHashMandate() public {
        mandateId = 1;
        mandateHash = MandateUtilities.hashMandate(address(daoMock), mandateId);
        assertEq(mandateHash, keccak256(abi.encode(address(daoMock), mandateId)));
    }

    function testCreateEmptyArrays() public {
        uint256 length = 3;
        (targets, values, calldatas) = MandateUtilities.createEmptyArrays(length);

        assertEq(targets.length, length);
        assertEq(values.length, length);
        assertEq(calldatas.length, length);
    }

    //////////////////////////////////////////////////////////////
    //                  ARRAY UTILITIES                         //
    //////////////////////////////////////////////////////////////

    function testArrayifyBoolsEmptyArrayPasses(uint256 numBools) public pure {
        numBools = bound(numBools, 0, 1000);
        // Test with zero booleans
        bool[] memory result = MandateUtilities.arrayifyBools(numBools);

        assertEq(result.length, numBools);
    }

    function testArrayifyBoolsFailsWhenTooLarge(uint256 numBools) public {
        vm.assume(numBools > 1000);

        vm.expectRevert("Num bools too large");
        MandateUtilities.arrayifyBools(numBools);
    }

    function testArrayifyBoolsAssemblyBehavior() public {
        // Test the assembly code's behavior with different input sizes
        for (i = 0; i <= 5; i++) {
            bool[] memory result = MandateUtilities.arrayifyBools(i);
            assertEq(result.length, i);
        }
    }
}
