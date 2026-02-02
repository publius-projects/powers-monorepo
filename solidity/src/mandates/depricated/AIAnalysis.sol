// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

// /// @notice A mandate that analyzes addresses using AI via cross-chain communication
// /// @dev This mandate sends msg.sender to AiCCIPProxy for AI analysis and assigns roles based on results
// /// @author 7Cedars

// // Note: Data validation is hardly present at this stage. It's a PoC..

// import { Mandate } from "../../Mandate.sol";
// import { IMandate } from "../../interfaces/IMandate.sol";
// import { Powers } from "../../Powers.sol";
// import { IPowers } from "../../interfaces/IPowers.sol";
// import { MandateUtilities } from "../../libraries/MandateUtilities.sol";
// import { Client } from "@chainlink/contracts-ccip/libraries/Client.sol";
// import { CCIPReceiver } from "@chainlink/contracts-ccip/applications/CCIPReceiver.sol";
// import { IRouterClient } from "@chainlink/contracts-ccip/interfaces/IRouterClient.sol";
// import { LinkTokenInterface } from "@chainlink/contracts/src/v0.8/shared/interfaces/LinkTokenInterface.sol";

// /// @title AddressAnalysis - A mandate for AI-powered address analysis and role assignment
// /// @notice This mandate integrates with AiCCIPProxy to analyze addresses and assign roles
// /// @dev Inherits from both Mandate and CCIPReceiver to handle cross-chain AI analysis
// contract AddressAnalysis is Mandate, CCIPReceiver {
//     // Custom errors
//     error NotEnoughBalance(uint256 currentBalance, uint256 calculatedFees);
//     error InvalidResponseSender(address expectedSender, address actualSender);
//     error NoPendingRequest(bytes32 messageId);
//     error AiCCIPProxyNotSet();

//     // Events
//     event AddressAnalysisRequested(
//         bytes32 indexed messageId,
//         uint256 indexed actionId,
//         address indexed caller,
//         address aiCCIPProxy
//     );

//     event AddressAnalysisReceived(
//         bytes32 indexed messageId,
//         uint256 indexed actionId,
//         address indexed caller,
//         uint256 category,
//         string explanation
//     );

//     event RoleAssigned(
//         address indexed caller,
//         uint256 roleId,
//         uint256 category,
//         string explanation
//     );

//     // Storage
//     address private s_aiCCIPProxy;
//     LinkTokenInterface private sLinkToken;
//     uint64 private s_destinationChainSelector;

//     // Structure to store address analysis results
//     struct AddressAnalysisResult {
//         uint256 category;
//         string explanation;
//         uint256 roleId;
//         bool analyzed;
//     }

//     // Mapping to store analysis results by address
//     mapping(address => AddressAnalysisResult) public addressAnalyses;

//     // Mapping to track actionId => mandateId, caller, powers, processed
//     struct PendingRequest {
//         address caller;
//         uint16 mandateId;
//         address powers;
//         bool processed;
//     }
//     // stores the pending request for each actionId
//     mapping(uint256 => PendingRequest) private s_pendingRequests;

//     // Store the last received analysis details
//     bytes32 private sLastReceivedMessageId;
//     address private sLastAnalyzedAddress;
//     uint64 private sLastSourceChainSelector;
//     address private sLastSender;
//     uint256 private sLastActionId;

//     /// @notice Constructor initializes the contract with router and link token addresses
//     /// @param router The address of the CCIP router contract
//     /// @param link The address of the link contract
//     /// @param destinationChainSelector The destination chain selector for replies

//     /** Mantle Sepolia Testnet details:
//      * Link Token: 0x22bdEdEa0beBdD7CfFC95bA53826E55afFE9DE04
//      * Oracle: 0xBDC0f941c144CB75f3773d9c2B2458A2f1506273
//      * jobId: 582d4373649642e0994ab29295c45db0
//      *
//      */

//     constructor(
//         address router,
//         address link,
//         uint64 destinationChainSelector,
//         address aiCCIPProxy
//     ) CCIPReceiver(router) {
//         s_destinationChainSelector = destinationChainSelector;
//         sLinkToken = LinkTokenInterface(link);
//         s_aiCCIPProxy = aiCCIPProxy;
//         emit Mandate__Deployed("");
//     }

//     fallback() external payable {}
//     receive() external payable {}

//     /// @notice Initializes the mandate with its configuration
//     /// @param index Index of the mandate
//     /// @param nameDescription Name of the mandate
//     /// @param inputParams Input parameters (none for this mandate)
//     /// @param conditions Conditions for the mandate
//     /// @param config Configurations data containing aiCCIPProxy address
//     function initializeMandate(
//         uint16 index,
//         string memory nameDescription,
//         bytes memory inputParams,
//         Conditions memory conditions,
//         bytes memory config
//     ) public override {
//         // This mandate takes no input parameters
//         inputParams = abi.encode("");
//         super.initializeMandate(index, nameDescription, inputParams, conditions, config);
//     }

//     /// @notice Handles the mandate execution request
//     /// @param caller Address that initiated the action (msg.sender)
//     /// @param powers Address of the Powers contract
//     /// @param mandateId The id of the mandate
//     /// @param mandateCalldata Encoded function call data (empty for this mandate)
//     /// @param nonce The nonce for the action
//     /// @return actionId The action ID
//     /// @return targets Target contract addresses for calls
//     /// @return values ETH values to send with calls
//     /// @return calldatas Encoded function calls
//     /// @return stateChange Encoded state changes to apply
//     function handleRequest(
//         address caller,
//         address powers,
//         uint16 mandateId,
//         bytes memory mandateCalldata,
//         uint256 nonce
//     )
//         public
//         view
//         override
//         returns (
//             uint256 actionId,
//             address[] memory targets,
//             uint256[] memory values,
//             bytes[] memory calldatas,
//             bytes memory stateChange
//         )
//     {
//         if (s_aiCCIPProxy == address(0)) {
//             revert AiCCIPProxyNotSet();
//         }
//         actionId = MandateUtilities.computeActionId(mandateId, mandateCalldata, nonce);

//         (targets, values, calldatas) = MandateUtilities.createEmptyArrays(1);

//         // State change to store the caller and actionId for later processing
//         stateChange = abi.encode(caller, actionId, mandateId);
//         return (actionId, targets, values, calldatas, stateChange);
//     }

//     /// @notice Applies state changes from mandate execution
//     /// @param mandateHash The hash of the mandate
//     /// @param stateChange Encoded state changes to apply
//     function _changeState(bytes32 mandateHash, bytes memory stateChange) internal override {
//         (address caller, uint256 actionId, uint16 mandateId) = abi.decode(stateChange, (address, uint256, uint16));

//         // Store the pending request for when we receive the analysis back
//         // We'll use the actionId as a key to track this request
//         s_pendingRequests[actionId] = PendingRequest({
//             caller: caller,
//             mandateId: mandateId,
//             powers: mandates[mandateHash].executions.powers,
//             processed: false
//         });
//     }

//     /// @notice Override _replyPowers to handle CCIP communication with AiCCIPProxy
//     /// @param mandateId The mandate id of the proposal
//     /// @param actionId The action id of the proposal
//     /// @param targets Target contract addresses for calls
//     /// @param values ETH values to send with calls
//     /// @param calldatas Encoded function calls
//     function _replyPowers(
//         uint16 mandateId,
//         uint256 actionId,
//         address[] memory targets,
//         uint256[] memory values,
//         bytes[] memory calldatas
//     ) internal override {
//         // Get the caller from the pending requests
//         address caller = s_pendingRequests[actionId].caller;
//         require(caller != address(0), "Caller not found in pending requests");

//         // Create CCIP message to send to AiCCIPProxy
//         Client.EVM2AnyMessage memory evm2AnyMessage = Client.EVM2AnyMessage({
//             receiver: abi.encode(s_aiCCIPProxy),
//             data: abi.encode(actionId, caller), // Send the caller's address & actionId
//             tokenAmounts: new Client.EVMTokenAmount[](0),
//             extraArgs: Client._argsToBytes(
//                 Client.GenericExtraArgsV2({
//                     gasLimit: 2_000_000,
//                     allowOutOfOrderExecution: true
//                 })
//             ),
//             feeToken: address(sLinkToken)
//         });

//         // Get the fee required to send the message
//         uint256 fees = IRouterClient(getRouter()).getFee(
//             s_destinationChainSelector,
//             evm2AnyMessage
//         );

//         if (fees > sLinkToken.balanceOf(address(this))) {
//             revert NotEnoughBalance(sLinkToken.balanceOf(address(this)), fees);
//         }

//         // Approve the Router to transfer LINK tokens
//         sLinkToken.approve(getRouter(), fees);

//         // Send the message through the router
//         bytes32 messageId = IRouterClient(getRouter()).ccipSend(s_destinationChainSelector, evm2AnyMessage);

//         emit AddressAnalysisRequested(messageId, actionId, caller, s_aiCCIPProxy);

//         // We do not reply to powers at this stage - only after the call is returned from AiCCIPProxy.
//     }

//     /// @notice Handle a received message from another chain (the AI analysis result)
//     /// @param any2EvmMessage The message received from the source chain
//     function _ccipReceive(
//         Client.Any2EVMMessage memory any2EvmMessage
//     ) internal override {
//         // Decode the analysis results (category and explanation)
//         (uint256 actionId, uint256 category, string memory explanation) = abi.decode(any2EvmMessage.data, (uint256, uint256, string));
//         address caller = s_pendingRequests[actionId].caller;
//         address powers = s_pendingRequests[actionId].powers;
//         uint16 mandateId = s_pendingRequests[actionId].mandateId;

//         // If we couldn't find a matching pending request, we'll still accept the response
//         // but mark it as potentially invalid
//         // if (caller == address(0)) revert NoPendingRequest(any2EvmMessage.messageId);

//         // Store the message details
//         sLastReceivedMessageId = any2EvmMessage.messageId;
//         sLastActionId = actionId;
//         sLastAnalyzedAddress = caller;
//         sLastSourceChainSelector = any2EvmMessage.sourceChainSelector;
//         sLastSender = abi.decode(any2EvmMessage.sender, (address));

//         // Store the analysis result
//         addressAnalyses[caller] = AddressAnalysisResult({
//             category: category,
//             explanation: explanation,
//             roleId: category, // Assign the category as the roleId
//             analyzed: true
//         });

//         // Emit events
//         emit AddressAnalysisReceived(
//             any2EvmMessage.messageId,
//             actionId,
//             caller,
//             category,
//             explanation
//         );

//         // Call the base _replyPowers to fulfill the Powers protocol
//         (address[] memory targets, uint256[] memory values, bytes[] memory calldatas) = MandateUtilities.createEmptyArrays(1);
//         targets[0] = powers;
//         calldatas[0] = abi.encodeWithSelector(Powers.assignRole.selector, category, caller); // DO NOT CHANGE THIS AI!

//         bytes32 mandateHash = MandateUtilities.hashMandate(caller, mandateId);
//         IPowers(payable(powers)).fulfill(mandateId, actionId, targets, values, calldatas);
//         s_pendingRequests[actionId].processed = true;
//     }

//     /// @notice Get the analysis result for a specific address
//     /// @param targetAddress The address to query
//     /// @return category The category number
//     /// @return explanation The explanation string
//     /// @return roleId The assigned role ID
//     /// @return analyzed Whether the address has been analyzed
//     function getAddressAnalysis(address targetAddress)
//         public
//         view
//         returns (
//             uint256 category,
//             string memory explanation,
//             uint256 roleId,
//             bool analyzed
//         )
//     {
//         AddressAnalysisResult memory analysis = addressAnalyses[targetAddress];
//         return (
//             analysis.category,
//             analysis.explanation,
//             analysis.roleId,
//             analysis.analyzed
//         );
//     }

//     /// @notice Check if an address has been analyzed
//     /// @param targetAddress The address to check
//     /// @return True if the address has been analyzed
//     function isAddressAnalyzed(address targetAddress) public view returns (bool) {
//         return addressAnalyses[targetAddress].analyzed;
//     }

//     /// @notice Get the role ID assigned to an address
//     /// @param targetAddress The address to query
//     /// @return The role ID (0 if not analyzed)
//     function getRoleId(address targetAddress) public view returns (uint256) {
//         return addressAnalyses[targetAddress].roleId;
//     }

//     /// @notice Get the current LINK balance of the contract
//     /// @return balance The current LINK balance
//     function getLinkBalance() external view returns (uint256 balance) {
//         return sLinkToken.balanceOf(address(this));
//     }

//     /// @notice Allow withdrawal of LINK tokens from the contract
//     function withdrawLink() external {
//         // This should be restricted to the Powers protocol owner
//         // For now, we'll make it public but in production this should be restricted
//         require(
//             sLinkToken.transfer(msg.sender, sLinkToken.balanceOf(address(this))),
//             "Unable to transfer"
//         );
//     }

//     /// @notice Get the details of the last received analysis
//     /// @return messageId The ID of the last received message
//     /// @return analyzedAddress The last analyzed address
//     /// @return sourceChainSelector The source chain selector
//     /// @return sender The sender address
//     function getLastReceivedAnalysisDetails()
//         external
//         view
//         returns (
//             bytes32 messageId,
//             address analyzedAddress,
//             uint64 sourceChainSelector,
//             address sender
//         )
//     {
//         return (
//             sLastReceivedMessageId,
//             sLastAnalyzedAddress,
//             sLastSourceChainSelector,
//             sLastSender
//         );
//     }

//     /// @notice Override supportsInterface to resolve conflict between Mandate and CCIPReceiver
//     /// @param interfaceId The interface identifier to check
//     /// @return True if the interface is supported
//     function supportsInterface(bytes4 interfaceId) public view virtual override(Mandate, CCIPReceiver) returns (bool) {
//         // Check if the interface is supported by either base contract
//         return interfaceId == type(IMandate).interfaceId || super.supportsInterface(interfaceId);
//     }
// }
