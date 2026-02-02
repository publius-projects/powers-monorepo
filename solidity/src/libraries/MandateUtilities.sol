// SPDX-License-Identifier: MIT

/// @title MandateUtilities - Utility Functions for Powers Protocol Mandates
/// @notice A library of helper functions used across Mandate contracts
/// @dev Provides common functionality for Mandate implementation and validation
/// @author 7Cedars

pragma solidity 0.8.26;

import { ERC721 } from "../../lib/openzeppelin-contracts/contracts/token/ERC721/ERC721.sol";
import { Powers } from "../Powers.sol";

// import "forge-std/Test.sol"; // for testing only. remove before deployment.

library MandateUtilities {
    /////////////////////////////////////////////////////////////
    //                  CHECKS                                 //
    /////////////////////////////////////////////////////////////
    function checkStringLength(string memory name_, uint256 minLength, uint256 maxLength) external pure {
        if (bytes(name_).length < minLength) {
            revert("String too short");
        }
        if (bytes(name_).length > maxLength) {
            revert("String too long");
        }
    }

    /// @notice Verifies if an address has all specified roles
    /// @dev Checks each role against the Powers contract's role system
    /// @param caller Address to check roles for
    /// @param roles Array of role IDs to check
    function hasRoleCheck(address caller, uint256[] memory roles, address powers) external view {
        for (uint32 i = 0; i < roles.length; i++) {
            uint48 since = Powers(payable(powers)).hasRoleSince(caller, roles[i]);
            if (since == 0) {
                revert("Does not have role.");
            }
        }
    }

    /// @notice Verifies if an address does not have any of the specified roles
    /// @dev Checks each role against the Powers contract's role system
    /// @param caller Address to check roles for
    /// @param roles Array of role IDs to check
    function hasNotRoleCheck(address caller, uint256[] memory roles, address powers) external view {
        for (uint32 i = 0; i < roles.length; i++) {
            uint48 since = Powers(payable(powers)).hasRoleSince(caller, roles[i]);
            if (since != 0) {
                revert("Has role.");
            }
        }
    }

    //////////////////////////////////////////////////////////////
    //                      HELPER FUNCTIONS                    //
    //////////////////////////////////////////////////////////////
    /// @notice Creates a unique identifier for an action
    /// @dev Hashes the combination of mandate address, calldata, and nonce
    /// @param mandateId Address of the mandate contract being called
    /// @param mandateCalldata Encoded function call data
    /// @param nonce The nonce for the action
    /// @return actionId Unique identifier for the action
    function computeActionId(uint16 mandateId, bytes memory mandateCalldata, uint256 nonce)
        public
        pure
        returns (uint256 actionId)
    {
        actionId = uint256(keccak256(abi.encode(mandateId, mandateCalldata, nonce)));
    }

    /// @notice Creates a unique identifier for a mandate, used for sandboxing executions of mandates.
    /// @dev Hashes the combination of mandate address and index
    /// @param powers Address of the Powers contract
    /// @param index Index of the mandate
    /// @return mandateHash Unique identifier for the mandate
    function hashMandate(address powers, uint16 index) public pure returns (bytes32 mandateHash) {
        mandateHash = keccak256(abi.encode(powers, index));
    }

    /// @notice Creates empty arrays for storing transaction data
    /// @dev Initializes three arrays of the same length for targets, values, and calldata
    /// @param length The desired length of the arrays
    /// @return targets Array of target addresses
    /// @return values Array of ETH values
    /// @return calldatas Array of encoded function calls
    function createEmptyArrays(uint256 length)
        public
        pure
        returns (address[] memory targets, uint256[] memory values, bytes[] memory calldatas)
    {
        targets = new address[](length);
        values = new uint256[](length);
        calldatas = new bytes[](length);
    }

    /// @notice Converts a boolean array from calldata to a memory array
    /// @dev Uses assembly to efficiently decode the boolean array from calldata
    /// @param numBools The number of booleans to decode
    /// @return boolArray The decoded boolean array
    /// Note: written by Cursor AI.
    function arrayifyBools(uint256 numBools) public pure returns (bool[] memory boolArray) {
        if (numBools == 0) return new bool[](0);
        if (numBools > 1000) revert("Num bools too large");

        assembly {
            // Allocate memory for the array
            boolArray := mload(0x40)
            mstore(boolArray, numBools) // set array length
            let dataOffset := 0x24 // skip 4 bytes selector, start at 0x04, but arrays start at 0x20
            for { let i := 0 } lt(i, numBools) { i := add(i, 1) } {
                // Each bool is 32 bytes
                let value := calldataload(add(4, mul(i, 32)))
                mstore(add(add(boolArray, 0x20), mul(i, 0x20)), iszero(iszero(value)))
            }
            // Update free memory pointer
            mstore(0x40, add(add(boolArray, 0x20), mul(numBools, 0x20)))
        }
    }

    /**
     * @notice Converts a hex string (e.g., "0x1a2b...") to bytes.
     * @dev From https://ethereum.stackexchange.com/a/8171
     */
    function hexStringToBytes(string memory hexString) internal pure returns (bytes memory) {
        bytes memory bts = new bytes(bytes(hexString).length / 2 - 1);
        for (uint256 i = 0; i < bts.length; i++) {
            bts[i] = bytes1((hexToByte(bytes(hexString)[i * 2 + 2]) << 4) | hexToByte(bytes(hexString)[i * 2 + 3]));
        }
        return bts;
    }

    function hexToByte(bytes1 b) internal pure returns (uint8) {
        if (b >= bytes1(uint8(48)) && b <= bytes1(uint8(57))) {
            // 0-9
            return uint8(b) - 48;
        }
        if (b >= bytes1(uint8(97)) && b <= bytes1(uint8(102))) {
            // a-f
            return uint8(b) - 87;
        }
        if (b >= bytes1(uint8(65)) && b <= bytes1(uint8(70))) {
            // A-F
            return uint8(b) - 55;
        }
        revert("Invalid hex character");
    }
 
}
