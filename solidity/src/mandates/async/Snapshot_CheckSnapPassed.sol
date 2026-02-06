// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import { Mandate } from "../../Mandate.sol";
import { MandateUtilities } from "../../libraries/MandateUtilities.sol";
import { IPowers } from "../../interfaces/IPowers.sol";
// Chainlink Functions Oracle
import { FunctionsClient } from "@chainlink/contracts/src/v0.8/functions/v1_0_0/FunctionsClient.sol";
import { ConfirmedOwner } from "@chainlink/contracts/src/v0.8/shared/access/ConfirmedOwner.sol";
import { FunctionsRequest } from "@chainlink/contracts/src/v0.8/functions/v1_0_0/libraries/FunctionsRequest.sol";

/**
 * @title SnapToGov_CheckSnapPassed
 * @notice An async mandate that verifies if a Snapshot proposal has passed.
 *
 * This mandate queries the Snapshot GraphQL API to verify that:
 * 1. A proposal with the given ID exists.
 * 2. The proposal is in the "closed" state.
 * 3. The proposal includes a specific choice.
 * 4. The specific choice has the highest score (won the vote).
 *
 * If the verification is successful, the mandate fulfills the request on the Powers contract.
 * Note: Currently, this mandate does not execute any actions upon fulfillment (it returns empty arrays).
 * It serves primarily as an oracle to confirm off-chain state.
 */
contract SnapToGov_CheckSnapPassed is Mandate, FunctionsClient, ConfirmedOwner {
    error UnexpectedRequestID(bytes32 requestId);

    using FunctionsRequest for FunctionsRequest.Request;

    struct Data {
        string spaceId;
        uint64 subscriptionId;
        uint32 gasLimit;
        bytes32 donID;
    }

    struct Request {
        bytes32 mandateHash;
        string choice;
        address powers;
        uint16 mandateId;
        uint256 actionId;
    }

    struct Mem {
        bytes32 mandateHash;
        Data data;
        string proposalId;
        string choice;
        address[] targets;
        uint256[] values;
        bytes[] calldatas;
        string govDescription;
        string[] args;
    }

    bytes32 public sLastRequestId;
    bytes public sLastResponse;
    bytes public sLastError;
    mapping(bytes32 mandateHash => Data) internal data;
    mapping(string proposalId => Request) public requests;
    mapping(bytes32 requestId => string) public requestToProposalId;

    // Chainlink Functions Source Code (JavaScript)
    // Checks if proposal is closed, choice exists, and choice has max score.
    string internal constant source =
        "const proposalId = args[0];\nconst choice = args[1]; \n\nconst url = 'https://hub.snapshot.org/graphql/';\nconst gqlRequest = Functions.makeHttpRequest({\n  url: url,\n  method: \"POST\",\n  headers: {\n    \"Content-Type\": \"application/json\",\n  },\n  data: {\n    query: `{\\\n        proposal(id: \"${proposalId}\") { \\\n          choices \\\n          state \\\n          scores \\\n        } \\\n      }`,\n  },\n});\n\nconst gqlResponse = await gqlRequest;\nif (gqlResponse.error) throw Error(\"Request failed\");\n\nconst snapshotData = gqlResponse[\"data\"][\"data\"];\nif (snapshotData.proposal.state.length == 0) return Functions.encodeString(\"Proposal not recognised.\");\nif (snapshotData.proposal.state != \"closed\") return Functions.encodeString(\"Vote not closed.\"); \n\nconst index = snapshotData.proposal.choices.indexOf(choice) \nif (index == -1) return Functions.encodeString(\"Choice not present.\");\n\nconst maxScore = Math.max(...snapshotData.proposal.scores)\nif (maxScore != snapshotData.proposal.scores[index]) return Functions.encodeString(\"Choice did not pass.\");\n\nreturn Functions.encodeString(\"true\");";

    /// @notice Constructor
    /// @param router The Chainlink Functions Router address
    constructor(address router) FunctionsClient(router) ConfirmedOwner(msg.sender) {
        bytes memory configParams =
            abi.encode("string SpaceId", "uint64 SubscriptionId", "uint32 GasLimit", "bytes32 DonID");
        emit Mandate__Deployed(configParams);
    }

    /// @notice Initialize the mandate
    /// @param index The index of the mandate in the Powers contract
    /// @param nameDescription Name and description
    /// @param inputParams Input parameters for UI
    /// @param config Configuration bytes
    function initializeMandate(
        uint16 index,
        string memory nameDescription,
        bytes memory inputParams,
        bytes memory config
    ) public override {
        (string memory spaceId, uint64 subscriptionId, uint32 gasLimit, bytes32 donID) =
            abi.decode(config, (string, uint64, uint32, bytes32));

        bytes32 mandateHash = MandateUtilities.hashMandate(msg.sender, index);
        data[mandateHash] = Data({ spaceId: spaceId, subscriptionId: subscriptionId, gasLimit: gasLimit, donID: donID });

        inputParams = abi.encode(
            "string ProposalId",
            "string Choice",
            "address[] Targets",
            "uint256[] Values",
            "bytes[] CallDatas",
            "string GovDescription"
        );
        super.initializeMandate(index, nameDescription, inputParams, config);
    }

    /// @notice Process a request to verify a snapshot proposal result
    function handleRequest(
        address /*caller*/,
        address powers,
        uint16 mandateId,
        bytes memory mandateCalldata,
        uint256 nonce
    )
        public
        view
        override
        returns (
            uint256 actionId,
            address[] memory targets,
            uint256[] memory values,
            bytes[] memory calldatas
        )
    {
        Mem memory mem;
        mem.mandateHash = MandateUtilities.hashMandate(powers, mandateId);
        mem.data = data[mem.mandateHash];

        actionId = MandateUtilities.computeActionId(mandateId, mandateCalldata, nonce);
        (mem.proposalId, mem.choice, mem.targets, mem.values, mem.calldatas, mem.govDescription) =
            abi.decode(mandateCalldata, (string, string, address[], uint256[], bytes[], string));

        // Prepare arguments for Chainlink Functions
        mem.args = new string[](2);
        mem.args[0] = mem.proposalId;
        mem.args[1] = mem.choice;

        // Create arrays for execution - actual Chainlink Functions call happens in _externalCall
        (targets, values, calldatas) = MandateUtilities.createEmptyArrays(1);
        calldatas[0] = abi.encode(mem.proposalId, mem.choice, powers, mem.targets, mem.values, mem.calldatas, mem.govDescription, mem.args);

        return (actionId, targets, values, calldatas);
    }

    /// @notice Initiates the Chainlink Functions request
    function _externalCall(
        uint16 mandateId,
        uint256 actionId,
        address[] memory /* targets */,
        uint256[] memory /* values */,
        bytes[] memory calldatas
    ) internal override {
        // Initiate Chainlink Functions request
        bytes memory callData = calldatas[0];
        (string memory proposalId, string memory choice, address powers,,,,, string[] memory args) =
            abi.decode(callData, (string, string, address, address[], uint256[], bytes[], string, string[]));

        // Call Chainlink Functions oracle
        bytes32 requestId = sendRequest(args, powers, mandateId);
        requests[proposalId] = Request({
            mandateHash: MandateUtilities.hashMandate(powers, mandateId),
            powers: powers,
            mandateId: mandateId,
            actionId: actionId,
            choice: choice
        });
        requestToProposalId[requestId] = proposalId;
    }

    ///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
    //      Chainlink Functions Oracle                                                                                   //
    ///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

    /**
     * @notice Send a request to Chainlink Functions
     */
    function sendRequest(
        string[] memory args,
        address powers,
        uint16 mandateId
    ) internal returns (bytes32 requestId) {
        bytes32 mandateHash = MandateUtilities.hashMandate(powers, mandateId);
        Data memory data_ = data[mandateHash];

        FunctionsRequest.Request memory req;
        req.initializeRequestForInlineJavaScript(source);
        if (args.length > 0) req.setArgs(args);
        sLastRequestId = _sendRequest(req.encodeCBOR(), data_.subscriptionId, data_.gasLimit, data_.donID);
        return sLastRequestId;
    }

    /**
     * @notice Handle Chainlink Functions response
     */
    function fulfillRequest(bytes32 requestId, bytes memory response, bytes memory err) internal override {
        if (sLastRequestId != requestId) {
            revert UnexpectedRequestID(requestId);
        }
        sLastResponse = response;
        sLastError = err;

        if (err.length > 0) {
            revert(string(err));
        }

        if (sLastResponse.length == 0) {
            revert("No response from the API");
        }

        (string memory reply) = abi.decode(abi.encode(sLastResponse), (string));

        if (keccak256(abi.encodePacked(reply)) != keccak256(abi.encodePacked("true"))) {
            revert(reply);
        }

        // Get the proposal ID from the request ID
        string memory proposalId = requestToProposalId[requestId];
        if (bytes(proposalId).length == 0) {
            revert("Request not found");
        }

        Request memory request_ = requests[proposalId];

        // Currently returns empty arrays, meaning no action is executed on Powers upon fulfillment.
        (address[] memory targets, uint256[] memory values, bytes[] memory calldatas) =
            MandateUtilities.createEmptyArrays(1);
        IPowers(payable(request_.powers)).fulfill(request_.mandateId, request_.actionId, targets, values, calldatas);
    }

    /////////////////////////////////
    //      Helper Functions       //
    /////////////////////////////////
    function getData(bytes32 mandateHash) public view returns (Data memory data_) {
        data_ = data[mandateHash];
    }

    function getRouter() public view returns (address) {
        return address(i_router);
    }
}
