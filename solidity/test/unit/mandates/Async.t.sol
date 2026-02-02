// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.26;

// import { TestSetupPowers } from "../../TestSetup.t.sol";
// // import { console2 } from "forge-std/console2.sol";

// import { MandateUtilities } from "../../../src/libraries/MandateUtilities.sol";
// import { MessageHashUtils } from "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";
// import { ECDSA } from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";

// /// @notice Comprehensive unit tests for all electoral mandates
// /// @dev Tests all functionality of electoral mandates including initialization, execution, and edge cases

// //////////////////////////////////////////////////
// //              ELECTION SELECT TESTS          //
// //////////////////////////////////////////////////
// contract RoleByGitCommitTest is TestSetupPowers {
//     using ECDSA for bytes32;

//     function setUp() public override {
//         super.setUp();
//     }

//     function testFullfillRequest() public {
//         // copied from chainlink log.
//         string memory response =
//             "0x72eec3da415fe93d0a35eab27ac32c82079fca90daeca49700c023aa2adee5ad5ee705a4c106cc3f4aed424fda12d7fb23c215a85641db8b8b638abb3c19816e1c";
//         string memory signatureString = "signed";
//         bytes32 messageHash = MessageHashUtils.toEthSignedMessageHash(bytes(signatureString));

//         // --- Signature Verification ---
//         // 1. Decode the signature (returned as a hex string "0x...")
//         bytes memory signatureBytes = MandateUtilities.hexStringToBytes(abi.decode(abi.encode(response), (string)));

//         // 2. Recover the signer's address using message Hash (calculated at initialisaiton of mandate)
//         address sSigner = messageHash.recover(signatureBytes);

//         // console2.log(sSigner);
//     }
// }
