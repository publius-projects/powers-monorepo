// SPDX-License-Identifier: MIT

/// @notice A base contract that takes an input but does not execute any logic.
///
/// The logic:
/// - the mandateCalldata includes targets[], values[], calldatas[] - that are sent straight to the Powers protocol without any checks.
/// - the mandateCalldata is not executed.
///
/// @author 7Cedars,

pragma solidity 0.8.26;

// import { Mandate } from "../../Mandate.sol";
// import { MandateUtilities } from "../../libraries/MandateUtilities.sol";
// import { TreasuryPools } from "../../helpers/TreasuryPools.sol";

// contract TreasuryPoolTransfer is Mandate {
//     /// @dev Mapping from mandate hash to target contract address for each mandate instance
//     mapping(bytes32 mandateHash => address targetContract) public targetContract;
//     /// @dev Mapping from mandate hash to target function selector for each mandate instance
//     mapping(bytes32 mandateHash => uint256 poolId) internal poolIds;

//     /// @notice Constructor
//     constructor() {
//         bytes memory configParams = abi.encode("address TargetContract", "uint256 PoolId");
//         emit Mandate__Deployed(configParams);
//     }

//     function initializeMandate(uint16 index, string memory nameDescription, bytes memory inputParams, bytes memory config)
//         public
//         override
//     {
//         (address targetContract_, uint256 poolId_) = abi.decode(config, (address, uint256));
//         bytes32 mandateHash = MandateUtilities.hashMandate(msg.sender, index);

//         poolIds[mandateHash] = poolId_;
//         targetContract[mandateHash] = targetContract_;

//         inputParams = abi.encode("uint256 PoolId", "address payableTo", "uint256 Amount");

//         super.initializeMandate(index, nameDescription, inputParams, config);
//     }

//     /// @notice Return calls provided by the user without modification
//     /// @param mandateCalldata The calldata containing targets, values, and calldatas arrays
//     /// @return actionId The unique action identifier
//     /// @return targets Array of target contract addresses
//     /// @return values Array of ETH values to send
//     /// @return calldatas Array of calldata for each call
//     function handleRequest(
//         address, /*caller*/
//         address powers,
//         uint16 mandateId,
//         bytes memory mandateCalldata,
//         uint256 nonce
//     )
//         public
//         view
//         override
//         returns (uint256 actionId, address[] memory targets, uint256[] memory values, bytes[] memory calldatas)
//     {
//         actionId = MandateUtilities.computeActionId(mandateId, mandateCalldata, nonce);
//         bytes32 mandateHash = MandateUtilities.hashMandate(powers, mandateId);

//         uint256 poolId = poolIds[mandateHash];

//         (uint256 poolIdInput,,) = abi.decode(mandateCalldata, (uint256, address, uint256));

//         if (poolIdInput != poolId) {
//             revert("INVALID_POOL_ID");
//         }

//         // Send the calldata to the target function
//         (targets, values, calldatas) = MandateUtilities.createEmptyArrays(1);
//         targets[0] = targetContract[mandateHash];
//         calldatas[0] = abi.encodePacked(TreasuryPools.poolTransfer.selector, mandateCalldata);

//         return (actionId, targets, values, calldatas);
//     }
// }
