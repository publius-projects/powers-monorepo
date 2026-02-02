// SPDX-License-Identifier: MIT

/// @notice Assign roles based on a selected donation an account made to a Treasury contract.
/// @author 7Cedars
pragma solidity 0.8.26;

// import { Mandate } from "../../Mandate.sol";
// import { Powers } from "../../Powers.sol";
// import { MandateUtilities } from "../../libraries/MandateUtilities.sol";
// import { TreasurySimple } from "../../helpers/TreasurySimple.sol";

// // import "forge-std/Test.sol"; // only for testing

// contract TreasuryRoleWithTransfer is Mandate {
//     struct TokenConfig {
//         uint256 tokensPerBlock; // tokens per block for access duration
//         // can (and probably will add more configf here later on)
//     }

//     struct Data {
//         address treasuryContract; // TreasurySimple contract address
//         uint16 roleIdToSet; // role id to assign/revoke
//     }

//     struct Mem {
//         bytes32 mandateHash;
//         Data data;
//         address caller;
//         uint256 receiptId;
//         address account;
//         TreasurySimple.TransferLog selectedTransfer;
//         uint48 currentBlock;
//         uint256 tokensPerBlock;
//         uint256 blocksBought;
//         uint48 accessUntilBlock;
//     }

//     mapping(bytes32 mandateHash => Data) internal data;
//     mapping(bytes32 mandateHash => mapping(address => TokenConfig)) internal tokenConfigs;

//     constructor() {
//         bytes memory configParams =
//             abi.encode("address TreasuryContract", "address[] Tokens", "uint256[] TokensPerBlock", "uint16 RoleId");
//         emit Mandate__Deployed(configParams);
//     }

//     function initializeMandate(uint16 index, string memory nameDescription, bytes memory inputParams, bytes memory config)
//         public
//         override
//     {
//         (address treasuryContract_, address[] memory tokens_, uint256[] memory tokensPerBlock_, uint16 roleIdToSet_) =
//             abi.decode(config, (address, address[], uint256[], uint16));

//         // Validate that arrays have the same length
//         if (tokens_.length != tokensPerBlock_.length) {
//             revert("Tokens and TokensPerBlock arrays must have the same length");
//         }
//         if (tokens_.length == 0) {
//             revert("At least one token configuration is required");
//         }

//         bytes32 mandateHash = MandateUtilities.hashMandate(msg.sender, index);
//         data[mandateHash].treasuryContract = treasuryContract_;
//         data[mandateHash].roleIdToSet = roleIdToSet_;

//         // Store token configurations
//         for (uint256 i = 0; i < tokens_.length; i++) {
//             tokenConfigs[mandateHash][tokens_[i]] = TokenConfig({ tokensPerBlock: tokensPerBlock_[i] });
//         }

//         inputParams = abi.encode("uint256 receiptId"); // receipt of transfer to check on account sending request.

//         super.initializeMandate(index, nameDescription, inputParams, config);
//     }

//     /// @notice Handles the request to claim a role based on donations
//     /// @param powers The address of the Powers contract
//     /// @param mandateId The ID of the mandate
//     /// @param mandateCalldata The calldata containing the account to claim role for
//     /// @param nonce The nonce for the action
//     /// @return actionId The ID of the action
//     /// @return targets The target addresses for the action
//     /// @return values The values for the action
//     /// @return calldatas The calldatas for the action
//     function handleRequest(address caller, address powers, uint16 mandateId, bytes memory mandateCalldata, uint256 nonce)
//         public
//         view
//         virtual
//         override
//         returns (uint256 actionId, address[] memory targets, uint256[] memory values, bytes[] memory calldatas)
//     {
//         Mem memory mem;
//         mem.mandateHash = MandateUtilities.hashMandate(powers, mandateId);
//         mem.data = data[mem.mandateHash];

//         actionId = MandateUtilities.computeActionId(mandateId, mandateCalldata, nonce);

//         mem.caller = msg.sender;
//         (mem.receiptId) = abi.decode(mandateCalldata, (uint256));
//         mem.selectedTransfer = TreasurySimple(payable(mem.data.treasuryContract)).getTransfer(mem.receiptId);

//         // check if transfer exists
//         if (mem.selectedTransfer.amount == 0) {
//             revert("Transfer does not exist");
//         }
//         // check if transfer is from the caller
//         if (mem.selectedTransfer.from != caller) {
//             revert("Transfer not from caller");
//         }
//         // check if number of blocks bought bring it across current block.number.
//         mem.currentBlock = uint48(block.number);
//         mem.tokensPerBlock = tokenConfigs[mem.mandateHash][mem.selectedTransfer.token].tokensPerBlock;
//         if (mem.tokensPerBlock == 0) {
//             revert("Token not configured");
//         }
//         mem.blocksBought = mem.selectedTransfer.amount / mem.tokensPerBlock;
//         if (mem.blocksBought == 0) {
//             // Not enough tokens transferred for any access
//             revert("Insufficient transfer amount");
//         }
//         if (mem.currentBlock > uint48(mem.selectedTransfer.blockNumber) + uint48(mem.blocksBought)) {
//             revert("Access expired");
//         }

//         // If all checks passed: Create arrays for execution and assign role
//         (targets, values, calldatas) = MandateUtilities.createEmptyArrays(1);
//         targets[0] = powers;
//         calldatas[0] = abi.encodeWithSelector(Powers.assignRole.selector, mem.data.roleIdToSet, caller);

//         return (actionId, targets, values, calldatas);
//     }

//     function getTokenConfig(bytes32 mandateHash, address token) public view returns (TokenConfig memory) {
//         return tokenConfigs[mandateHash][token];
//     }
// }
