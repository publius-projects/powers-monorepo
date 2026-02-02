// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

// import { Mandate } from "../../Mandate.sol";
// import { MandateUtilities } from "../../libraries/MandateUtilities.sol";
// import { PowersTypes } from "../../interfaces/PowersTypes.sol";
// import { IPowers } from "../../interfaces/IPowers.sol";
// import { Client } from "@chainlink/contracts-ccip/libraries/Client.sol";
// import { CCIPReceiver } from "@chainlink/contracts-ccip/applications/CCIPReceiver.sol";
// import { IRouterClient } from "@chainlink/contracts-ccip/interfaces/IRouterClient.sol";

// contract CheckActionState is Mandate, CCIPReceiver {
//     // Custom errors
//     error ActionNotFulfilled();
//     error NotEnoughBalance(uint256 currentBalance, uint256 calculatedFees);
//     error InvalidSender(address sender, address expected);

//     // State variables
//     IRouterClient private sRouter;
//     address private sCcipHelper;

//     // Mapping from CCIP message ID to the local action ID that needs fulfilling
//     mapping(bytes32 => uint256) public s_pendingRequests;

//     struct RemoteActionData {
//         address remotePowersAddress;
//         address originalPowersAddress;
//         uint16 originalMandateId;
//         uint64 destinationChainSelector;
//     }
//     mapping(uint256 localActionId => RemoteActionData) public sRemoteActions;

//     event CrossChainCheckTriggered(
//         uint256 indexed localActionId,
//         uint256 indexed remoteActionId,
//         uint64 destinationChainSelector,
//         address remotePowers,
//         bytes32 messageId
//     );

//     event CrossChainCheckFulfilled(
//         bytes32 indexed messageId,
//         uint256 indexed localActionId,
//         uint256 remoteActionId,
//         PowersTypes.ActionState remoteState
//     );

//     constructor(address router, address ccipHelper) CCIPReceiver(router) {
//         sRouter = IRouterClient(router);
//         sCcipHelper = ccipHelper;

//         bytes memory configParams = abi.encode("string[] inputParams");
//         emit Mandate__Deployed(configParams);
//     }

//     function initializeMandate(uint16 index, string memory nameDescription, bytes memory, bytes memory config)
//         public
//         override
//     {
//         bytes memory finalInputParams =
//             abi.encodePacked(config, abi.encode("address powersAddress", "uint16 mandateId", "uint64 chainId"));
//         super.initializeMandate(index, nameDescription, finalInputParams, config);
//     }

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
//         // Decode parameters
//         (bytes memory userCalldata, address remotePowersAddress, uint16 remoteMandateId, uint64 remoteChainId) =
//             abi.decode(mandateCalldata, (bytes, address, uint16, uint64));

//         actionId = MandateUtilities.computeActionId(mandateId, mandateCalldata, nonce);
//         uint256 remoteActionId = MandateUtilities.computeActionId(remoteMandateId, userCalldata, nonce);

//         if (remoteChainId == block.chainid) {
//             // Scenario 1: Same chain
//             PowersTypes.ActionState state = IPowers(remotePowersAddress).getActionState(remoteActionId);
//             if (state != PowersTypes.ActionState.Fulfilled) {
//                 revert("Action Not Fulfilled");
//             }
//             (targets, values, calldatas) = MandateUtilities.createEmptyArrays(0);
//         } else {
//             calldatas = new bytes[](1);
//             calldatas[0] = abi.encode(remoteActionId, remotePowersAddress, remoteChainId, powers);
//         }

//         return (actionId, targets, values, calldatas);
//     }

//     function _externalCall(
//         uint16 mandateId,
//         uint256 actionId,
//         address[] memory targets,
//         uint256[] memory, /*values*/
//         bytes[] memory calldatas
//     ) internal override {
//         if (targets.length == 0) {
//             return; // Not a cross-chain call
//         }

//         (
//             uint256 remoteActionId,
//             address remotePowersAddress,
//             uint64 destinationChainSelector,
//             address originalPowersAddress
//         ) = abi.decode(calldatas[0], (uint256, address, uint64, address));

//         sRemoteActions[remoteActionId] = RemoteActionData({
//             remotePowersAddress: remotePowersAddress,
//             destinationChainSelector: destinationChainSelector,
//             originalPowersAddress: originalPowersAddress,
//             originalMandateId: mandateId
//         });

//         Client.EVM2AnyMessage memory message = Client.EVM2AnyMessage({
//             receiver: abi.encode(sCcipHelper),
//             data: abi.encode(remoteActionId, remotePowersAddress),
//             tokenAmounts: new Client.EVMTokenAmount[](0),
//             extraArgs: Client._argsToBytes(
//                 Client.GenericExtraArgsV2({
//                     gasLimit: 2_000_000, // these should not be hard coded. To do.
//                     allowOutOfOrderExecution: true // see: https://docs.chain.link/ccip/tutorials/evm/transfer-tokens-from-contract#transfer-tokens-and-pay-in-native
//                 })
//             ),
//             feeToken: address(0)
//         });

//         uint256 fees = sRouter.getFee(destinationChainSelector, message);
//         if (fees > address(this).balance) revert NotEnoughBalance(address(this).balance, fees); // is this not taken from msg.sender?

//         bytes32 messageId = sRouter.ccipSend{ value: fees }(destinationChainSelector, message);

//         s_pendingRequests[messageId] = actionId;

//         emit CrossChainCheckTriggered(
//             actionId, remoteActionId, destinationChainSelector, remotePowersAddress, messageId
//         );
//     }

//     function _ccipReceive(Client.Any2EVMMessage memory any2EvmMessage) internal override {
//         (uint256 remoteActionId, PowersTypes.ActionState state) =
//             abi.decode(any2EvmMessage.data, (uint256, PowersTypes.ActionState));
//         RemoteActionData memory remoteData = sRemoteActions[remoteActionId];
//         if (any2EvmMessage.sourceChainSelector != remoteData.destinationChainSelector) {
//             revert("Invalid source chain");
//         }

//         // check state
//         if (state != PowersTypes.ActionState.Fulfilled) {
//             revert("Action Not Fulfilled");
//         }

//         // delete pending requests
//         uint256 localActionId = s_pendingRequests[any2EvmMessage.messageId];
//         delete s_pendingRequests[any2EvmMessage.messageId];

//         // Fulfill the original local action
//         (address[] memory targets, uint256[] memory values, bytes[] memory calldatas) =
//             MandateUtilities.createEmptyArrays(1);
//         IPowers(remoteData.originalPowersAddress)
//             .fulfill(remoteData.originalMandateId, localActionId, targets, values, calldatas);
//     }

//     //////////////////////////////////////////////////////////////
//     //                      UTILITIES                           //
//     //////////////////////////////////////////////////////////////
//     function supportsInterface(bytes4 interfaceId) public view virtual override(Mandate, CCIPReceiver) returns (bool) {
//         return super.supportsInterface(interfaceId);
//     }

//     receive() external payable { }
// }
