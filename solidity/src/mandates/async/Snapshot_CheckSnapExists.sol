// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

// // @notice A base contract that executes a bespoke action.
// // TBI: Basic logic sho
// //
// // @author 7Cedars,

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

// // @notice A contract that checks if a snapshot proposal exists.
// // It uses the Chainlink Functions Oracle to call snapshots API to check if a snapshot proposal exists.
// // @author 7Cedars

// // See remix example of how to use the Chainlink Functions Oracle: https://remix.ethereum.org/#url=https://docs.chain.link/samples/ChainlinkFunctions/FunctionsConsumerExample.sol&autoCompile=true&lang=en&optimize=false&runs=200&evmVersion=null&version=soljson-v0.8.19+commit.7dd6d404.js
// //

// // import { console2 } from "forge-std/console2.sol"; // remove before deploying.

// contract SnapToGov_CheckSnapExists is Mandate, FunctionsClient, ConfirmedOwner {
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

//     struct Mem {
//         bytes32 mandateHash;
//         Data data;
//         string proposalId;
//         string choice;
//         address[] targets;
//         uint256[] values;
//         bytes[] calldatas;
//         string govDescription;
//         string[] args;
//     }

//     bytes32 public sLastRequestId;
//     string public sLastProposalId;
//     bytes public sLastResponse;
//     bytes public sLastError;
//     mapping(bytes32 mandateHash => Data) internal data;
//     mapping(string proposalId => Request) public requests;
//     mapping(bytes32 requestId => string) public requestToProposalId;

//     // see the example here: https://github.com/smartcontractkit/smart-contract-examples/blob/main/functions-examples/examples/4-post-data/source.js
//     // see the script in chainlinkFunctionScript.js. It can be tried at https://functions.chain.link/playground. It works at time of writing.
//     // I used this website https://www.espruino.com/File%20Converter to convert the source code to a string.
//     string internal constant source =
//         "const proposalId = args[0];\nconst choice = args[1]; \n\nconst url = 'https://hub.snapshot.org/graphql/';\nconst gqlRequest = Functions.makeHttpRequest({\n  url: url,\n  method: \"POST\",\n  headers: {\n    \"Content-Type\": \"application/json\",\n  },\n  data: {\n    query: `{\\\n        proposal(id: \"${proposalId}\") { \\\n          choices \\\n          state \\\n        } \\\n      }`,\n  },\n});\n\nconst gqlResponse = await gqlRequest;\nif (gqlResponse.error) throw Error(\"Request failed\");\n\nconst snapshotData = gqlResponse[\"data\"][\"data\"];\nif (snapshotData.proposal.state.length == 0) return Functions.encodeString(\"Proposal not recognised.\");\nif (snapshotData.proposal.state != \"pending\") return Functions.encodeString(\"Proposal not pending.\");\nif (!snapshotData.proposal.choices.includes(choice)) return Functions.encodeString(\"Choice not present.\");\nreturn Functions.encodeString(\"true\");\n";

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
//         bytes memory config
//     ) public override {
//         (string memory spaceId, uint64 subscriptionId, uint32 gasLimit, bytes32 donID) =
//             abi.decode(config, (string, uint64, uint32, bytes32));

//         bytes32 mandateHash = MandateUtilities.hashMandate(msg.sender, index);
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
//         super.initializeMandate(index, nameDescription, inputParams, config);
//     }

//     // @notice execute the mandate.
//     // @param mandateCalldata the calldata _without function signature_ to send to the function.
//     function handleRequest(address /*caller*/, address powers, uint16 mandateId, bytes memory mandateCalldata, uint256 nonce)
//         public
//         view
//         override
//         returns (
//             uint256 actionId,
//             address[] memory targets,
//             uint256[] memory values,
//             bytes[] memory calldatas
//         )
//     {
//         Mem memory mem;
//         mem.mandateHash = MandateUtilities.hashMandate(powers, mandateId);
//         mem.data = data[mem.mandateHash];

//         actionId = MandateUtilities.computeActionId(mandateId, mandateCalldata, nonce);
//         (mem.proposalId, mem.choice, mem.targets, mem.values, mem.calldatas, mem.govDescription) =
//             abi.decode(mandateCalldata, (string, string, address[], uint256[], bytes[], string));

//         // Prepare arguments for Chainlink Functions
//         mem.args = new string[](2);
//         mem.args[0] = mem.proposalId;
//         mem.args[1] = mem.choice;

//         // Create arrays for execution - actual Chainlink Functions call happens in _externalCall
//         (targets, values, calldatas) = MandateUtilities.createEmptyArrays(1);
//         calldatas[0] = abi.encode(mem.proposalId, mem.choice, powers, mem.targets, mem.values, mem.calldatas, mem.govDescription, mem.args);

//         return (actionId, targets, values, calldatas);
//     }

//     function _externalCall(
//         uint16 mandateId,
//         uint256 actionId,
//         address[] memory /* targets */,
//         uint256[] memory /* values */,
//         bytes[] memory calldatas
//     ) internal override {
//         // Initiate Chainlink Functions request
//         bytes memory callData = calldatas[0];
//         (string memory proposalId, string memory choice, address powers,,,,, string[] memory args) =
//             abi.decode(callData, (string, string, address, address[], uint256[], bytes[], string, string[]));

//         // Call Chainlink Functions oracle
//         bytes32 requestId = sendRequest(args, powers, mandateId);
//         requests[proposalId] = Request({
//             mandateHash: MandateUtilities.hashMandate(powers, mandateId),
//             powers: powers,
//             mandateId: mandateId,
//             actionId: actionId,
//             choice: choice
//         });
//         requestToProposalId[requestId] = proposalId;
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

//         // console2.log("sendRequest: waypoint 0");

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
//         // console2.log("sendRequest: waypoint 1");
//         sLastRequestId = _sendRequest(req.encodeCBOR(), data_.subscriptionId, data_.gasLimit, data_.donID);
//         // console2.log("sendRequest: waypoint 2");
//         return sLastRequestId;
//     }

//     /**
//      * @notice When oracle replies, we send data to Powers contract.
//      * @param requestId The request ID, returned by sendRequest()
//      * @param response Aggregated response from the user code
//      * @param err Aggregated error from the user code or from the execution pipeline
//      * Either response or error parameter will be set, but never both.
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

//         (string memory reply) = abi.decode(abi.encode(sLastResponse), (string));

//         if (keccak256(abi.encodePacked(reply)) != keccak256(abi.encodePacked("true"))) {
//             revert(reply);
//         }

//         // Get the proposal ID from the request ID
//         string memory proposalId = requestToProposalId[requestId];
//         if (bytes(proposalId).length == 0) {
//             revert("Request not found");
//         }

//         Request memory request_ = requests[proposalId];

//         (address[] memory targets, uint256[] memory values, bytes[] memory calldatas) =
//             MandateUtilities.createEmptyArrays(1);
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
