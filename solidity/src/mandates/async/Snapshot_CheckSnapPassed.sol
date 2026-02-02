// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

// @notice A base contract that executes a bespoke action.
// TBI: Basic logic sho
//
// @author 7Cedars,

// import { Mandate } from "../../Mandate.sol";
// import { MandateUtilities } from "../../libraries/MandateUtilities.sol";
// import { Powers } from "../../Powers.sol";
// import { IPowers } from "../../interfaces/IPowers.sol";
// import { Governor } from "@openzeppelin/contracts/governance/Governor.sol";
// import { IGovernor } from "@openzeppelin/contracts/governance/IGovernor.sol";
// import { Strings } from "@openzeppelin/contracts/utils/Strings.sol";
// // Chainlink Functions Oracle
// import { FunctionsClient } from "@chainlink/contracts/src/v0.8/functions/v1_0_0/FunctionsClient.sol";
// import { ConfirmedOwner } from "@chainlink/contracts/src/v0.8/shared/access/ConfirmedOwner.sol";
// import { FunctionsRequest } from "@chainlink/contracts/src/v0.8/functions/v1_0_0/libraries/FunctionsRequest.sol";

// // @notice A contract that checks if a snapshot proposal passed.
// // It uses the Chainlink Functions Oracle to call snapshots API to check if a snapshot proposal passed.
// // @author 7Cedars

// // See remix example of how to use the Chainlink Functions Oracle: https://remix.ethereum.org/#url=https://docs.chain.link/samples/ChainlinkFunctions/FunctionsConsumerExample.sol&autoCompile=true&lang=en&optimize=false&runs=200&evmVersion=null&version=soljson-v0.8.19+commit.7dd6d404.js

// // import { console2 } from "forge-std/console2.sol"; // remove before deploying.

// contract SnapToGov_CheckSnapPassed is Mandate, FunctionsClient, ConfirmedOwner {
//     error UnexpectedRequestID(bytes32 requestId);

//     using FunctionsRequest for FunctionsRequest.Request;

//     struct Data {
//         string spaceId;
//         uint64 subscriptionId;
//         uint32 gasLimit;
//         bytes32 donID;
//     }

//     struct Request {
//         bytes32 mandateHash;
//         string choice;
//         address powers;
//         uint16 mandateId;
//         uint256 actionId;
//     }

//     bytes32 public sLastRequestId;
//     string public sLastProposalId;
//     bytes public sLastResponse;
//     bytes public sLastError;
//     mapping(bytes32 mandateHash => Data) public data;
//     mapping(string proposalId => Request) public requests;

//     // see the example here: https://github.com/smartcontractkit/smart-contract-examples/blob/main/functions-examples/examples/4-post-data/source.js
//     // see the script in chainlinkFunctionScript.js. It can be tried at https://functions.chain.link/playground. It works at time of writing.
//     // I used this website https://www.espruino.com/File%20Converter to convert the source code to a string.
//     string internal constant source =
//         "const proposalId = args[0];\nconst choice = args[1]; \n\nconst url = 'https://hub.snapshot.org/graphql/';\nconst gqlRequest = Functions.makeHttpRequest({\n  url: url,\n  method: \"POST\",\n  headers: {\n    \"Content-Type\": \"application/json\",\n  },\n  data: {\n    query: `{\\\n        proposal(id: \"${proposalId}\") { \\\n          choices \\\n          state \\\n          scores \\\n        } \\\n      }`,\n  },\n});\n\nconst gqlResponse = await gqlRequest;\nif (gqlResponse.error) throw Error(\"Request failed\");\n\nconst snapshotData = gqlResponse[\"data\"][\"data\"];\nif (snapshotData.proposal.state.length == 0) return Functions.encodeString(\"Proposal not recognised.\");\nif (snapshotData.proposal.state != \"closed\") return Functions.encodeString(\"Vote not closed.\"); \n\nconst index = snapshotData.proposal.choices.indexOf(choice) \nif (index == -1) return Functions.encodeString(\"Choice not present.\");\n\nconst maxScore = Math.max(...snapshotData.proposal.scores)\nif (maxScore != snapshotData.proposal.scores[index]) return Functions.encodeString(\"Choice did not pass.\");\n\nreturn Functions.encodeString(\"true\");";

//     /// @notice constructor of the mandate.
//     constructor(address router) FunctionsClient(router) ConfirmedOwner(msg.sender) {
//         // if I can take owner out - do so. checks are handled through the Powers protocol.
//         bytes memory configParams =
//             abi.encode("string SpaceId", "uint64 SubscriptionId", "uint32 GasLimit", "bytes32 DonID");
//         emit Mandate__Deployed(configParams);
//     }

//     function initializeMandate(
//         uint16 index,
//         string memory nameDescription,
//         bytes memory inputParams,
//         Conditions memory conditions,
//         bytes memory config
//     ) public override {
//         bytes32 mandateHash = MandateUtilities.hashMandate(msg.sender, index);

//         (string memory spaceId, uint64 subscriptionId, uint32 gasLimit, bytes32 donID) =
//             abi.decode(config, (string, uint64, uint32, bytes32));
//         data[mandateHash] = Data({ spaceId: spaceId, subscriptionId: subscriptionId, gasLimit: gasLimit, donID: donID });

//         // Note how snapshotProposalId and a choice is linked to Targets, Values and CallDatas.
//         inputParams = abi.encode(
//             "string ProposalId",
//             "string Choice",
//             "address[] Targets",
//             "uint256[] Values",
//             "bytes[] CallDatas",
//             "string GovDescription"
//         );
//         super.initializeMandate(index, nameDescription, inputParams, conditions, config);
//     }

//     // @notice execute the mandate.
//     // @param mandateCalldata the calldata _without function signature_ to send to the function.
//     function handleRequest(address caller, address powers, uint16 mandateId, bytes memory mandateCalldata, uint256 nonce)
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
//         actionId = MandateUtilities.computeActionId(mandateId, mandateCalldata, nonce);
//         (string memory proposalId, string memory choice,,,,) =
//             abi.decode(mandateCalldata, (string, string, address[], uint256[], bytes[], string));

//         (targets, values, calldatas) = MandateUtilities.createEmptyArrays(0);
//         calldatas[0] = abi.encode(proposalId, powers, choice);
//         stateChange = abi.encode(proposalId, powers, mandateId, actionId, choice);

//         return (actionId, targets, values, calldatas, stateChange);
//     }

//     function _replyPowers(
//         uint16 mandateId,
//         uint256 actionId,
//         address[] memory targets,
//         uint256[] memory values,
//         bytes[] memory calldatas
//     ) internal override {
//         // NB! Naming is confusing here, because we are NOT replying to the Powers contract: we are sending a request to an oracle.
//         (string memory proposalId, address powers, string memory choice) =
//             abi.decode(calldatas[0], (string, address, string));
//         string[] memory args = new string[](2);
//         args[0] = proposalId;
//         args[1] = choice;

//         // call to the oracle.
//         sendRequest(args, powers, mandateId);
//     }

//     function _changeState(bytes32 mandateHash, bytes memory stateChange) internal override {
//         (string memory proposalId, address powers, uint16 mandateId, uint256 actionId, string memory choice) =
//             abi.decode(stateChange, (string, address, uint16, uint256, string));
//         sLastProposalId = proposalId;
//         requests[proposalId] = Request({
//             mandateHash: MandateUtilities.hashMandate(powers, mandateId),
//             powers: powers,
//             mandateId: mandateId,
//             actionId: actionId,
//             choice: choice
//         });
//     }

//     ///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
//     //      Chainlink Functions Oracle: https://docs.chain.link/chainlink-functions/tutorials/api-query-parameters       //
//     ///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

//     /**
//      * @notice Send a simple request
//      * @param args List of arguments accessible from within the source code
//      * @param powers The address of the Powers contract
//      * @param mandateId The id of the mandate
//      */
//     function sendRequest(
//         string[] memory args, // = List of arguments accessible from within the source code
//         address powers,
//         uint16 mandateId
//     ) internal returns (bytes32 requestId) {
//         bytes32 mandateHash = MandateUtilities.hashMandate(powers, mandateId);
//         Data memory data_ = data[mandateHash];

//         FunctionsRequest.Request memory req;
//         req.initializeRequestForInlineJavaScript(source);
//         // if (encryptedSecretsUrls.length > 0)
//         //     req.addSecretsReference(encryptedSecretsUrls);
//         // else if (donHostedSecretsVersion > 0) {
//         //     req.addDONHostedSecrets(
//         //         donHostedSecretsSlotID,
//         //         donHostedSecretsVersion
//         //     );
//         // }
//         if (args.length > 0) req.setArgs(args);
//         // if (bytesArgs.length > 0) req.setBytesArgs(bytesArgs);
//         sLastRequestId = _sendRequest(req.encodeCBOR(), data_.subscriptionId, data_.gasLimit, data_.donID);
//         return sLastRequestId;
//     }

//     /**
//      * @notice When oracle replies, we send data to Powers contract.
//      * @param requestId The request ID, returned by sendRequest()
//      * @param response Aggregated response from the user code
//      * @param err Aggregated error from the user code or from the execution pipeline
//      * Either response or error parameter will be set, but never both
//      */
//     function fulfillRequest(bytes32 requestId, bytes memory response, bytes memory err) internal override {
//         if (sLastRequestId != requestId) {
//             revert UnexpectedRequestID(requestId);
//         }
//         sLastResponse = response;
//         sLastError = err;

//         if (err.length > 0) {
//             revert(string(err));
//         }

//         if (sLastResponse.length == 0) {
//             revert("No response from the API");
//         }

//         // (string[] memory choices, uint256[] memory scores, string memory state) = abi.decode(sLastResponse, (string[], uint256[], string));
//         (string memory reply) = abi.decode(abi.encode(sLastResponse), (string));

//         if (keccak256(abi.encodePacked(reply)) != keccak256(abi.encodePacked("true"))) {
//             revert(reply);
//         }

//         (address[] memory targets, uint256[] memory values, bytes[] memory calldatas) =
//             MandateUtilities.createEmptyArrays(1);
//         Request memory request_ = requests[sLastProposalId];
//         IPowers(payable(request_.powers)).fulfill(request_.mandateId, request_.actionId, targets, values, calldatas);
//     }

//     /////////////////////////////////
//     //      Helper Functions       //
//     /////////////////////////////////
//     function getData(bytes32 mandateHash) public view returns (Data memory data_) {
//         data_ = data[mandateHash];
//     }

//     function getRouter() public view returns (address) {
//         return address(i_router);
//     }
// }
