// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

// Base contracts
import { IPowers } from "../../interfaces/IPowers.sol";
import { Mandate } from "../../Mandate.sol";
import { MandateUtilities } from "../../libraries/MandateUtilities.sol";

// Chainlink Functions
import { FunctionsClient } from "@chainlink/contracts/src/v0.8/functions/v1_0_0/FunctionsClient.sol";
import { FunctionsRequest } from "@chainlink/contracts/src/v0.8/functions/v1_0_0/libraries/FunctionsRequest.sol";

// OpenZeppelin for signature verification
import { MessageHashUtils } from "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";
import { ECDSA } from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";

/**
 * @title Github_ClaimRoleWithSig
 * @notice A mandate that assigns a role to a user if they can prove ownership
 * of a specific GitHub commit via a signed message.
 *
 * The logic:
 * - Takes a roleId and commitHash as input.
 * - Calls Chainlink Functions (executing the `githubSigs.js` script) to:
 * 1. Verify the commit exists on the repo/branch.
 * 2. Verify the commit modified the correct folder (`paths[roleId]`).
 * 3. Verify the commit is recent (e.g., < 90 days).
 * 4. Extract an ETH signature ("0x...") from the commit message.
 * - The `fulfillRequest` callback receives this signature.
 * - It recovers the signer's address from the signature using a pre-defined `signatureString`.
 * - If the recovered address matches the original `caller`, the mandate grants them the role.
 */
contract Github_ClaimRoleWithSig is Mandate, FunctionsClient {
    using FunctionsRequest for FunctionsRequest.Request;
    using ECDSA for bytes32;

    error UnexpectedRequestID(bytes32 requestId);
    error InvalidSignature();

    struct Reply {
        uint16 roleId;
        string errorMessage;
    }

    // @notice Configurations data for each instance of the mandate
    struct Data {
        string repo;
        string branch;
        string[] paths; // Folder paths, indexed by roleId
        uint256[] roleIds;
        string signatureString; // The message that must be signed
        bytes32 messageHash; // the hash of the message that must be signed.
        uint64 subscriptionId;
        uint32 gasLimit;
        bytes32 donId;
        // string source; // The Chainlink Functions source code
    }

    // --- Mem struct for handleRequest ---
    // (This is just to avoid "stack too deep" errors)
    struct Mem {
        bytes32 mandateHash;
        bytes32 messageHash;
        address powers;
        uint16 mandateId;
        uint256 actionId;
        address caller;
        uint256 roleId;
        string commitHash;
        uint256 indexPath;
        string[] args;
        bytes callData;
        bytes32 requestId;
    }

    // @notice Stores data about an in-flight request
    struct Request {
        address caller; // The address that initiated the request
        uint256 roleId;
        address powers;
        uint16 mandateId;
        uint256 actionId;
        bytes32 messageHash;
    }

    // --- State Variables ---

    bytes32 public sLastRequestId;
    bytes public sLastResponse;
    bytes public sLastError;
    address private sSigner;
    // note that the repo is hard coded in the source code of this mandate. This is to avoid having to pass it as a parameter to the mandate.
    string internal constant SOURCE =
        "const branch = args[0];\nconst commitHash = args[1];\nconst folderName = args[2]; \n\nif (!branch || !commitHash || !folderName) {\n    throw Error(\"Missing required args\");\n}\n\nconst url = `https://powers-protocol.vercel.app/api/check-commit`; \n\nconst githubRequest = Functions.makeHttpRequest({\n    url: url,\n    method: \"GET\",\n    timeout: 9000, \n    params: {\n        repo: \"7cedars/powers\",\n        branch: branch,\n        commitHash: commitHash,\n        maxAgeCommitInDays: 90,\n        folderName: folderName\n    }\n});\n\n \nconst githubResponse = await githubRequest;\nif (githubResponse.error || !githubResponse.data || !githubResponse.data.data || !githubResponse.data.data.signature) {\n    throw Error(`Request Failed: ${githubResponse.error.message}`);\n}\n\nreturn Functions.encodeString(githubResponse.data.data.signature);";

    mapping(bytes32 mandateHash => mapping(address => bytes errorMessage)) internal chainlinkErrors;
    mapping(bytes32 mandateHash => mapping(address => uint256 roleId)) internal chainlinkReplies;
    mapping(bytes32 mandateHash => Data) internal data;
    mapping(bytes32 requestId => Request) public requests;

    // --- Constructor ---

    constructor(address router) FunctionsClient(router) {
        // Define the parameters required to configure this mandate
        bytes memory configParams = abi.encode(
            "string branch",
            "string[] paths",
            "uint256[] roleIds",
            "string signatureString",
            "uint64 subscriptionId",
            "uint32 gasLimit",
            "bytes32 donID"
        );
        emit Mandate__Deployed(configParams);
    }

    // --- Mandate Initialization ---

    function initializeMandate(
        uint16 index,
        string memory nameDescription,
        bytes memory inputParams,
        bytes memory config
    ) public override {
        bytes32 mandateHash = MandateUtilities.hashMandate(msg.sender, index);

        (
            string memory branch,
            string[] memory paths,
            uint256[] memory roleIds,
            string memory signatureString,
            uint64 subscriptionId,
            uint32 gasLimit,
            bytes32 donId
        ) = abi.decode(config, (string, string[], uint256[], string, uint64, uint32, bytes32));

        // Store in separate scopes to avoid stack too deep
        {
            data[mandateHash].branch = branch;
            data[mandateHash].paths = paths;
            data[mandateHash].roleIds = roleIds;
            data[mandateHash].messageHash = MessageHashUtils.toEthSignedMessageHash(bytes(signatureString));
        }

        {
            data[mandateHash].signatureString = signatureString;
            data[mandateHash].subscriptionId = subscriptionId;
            data[mandateHash].gasLimit = gasLimit;
            data[mandateHash].donId = donId;
        }

        // Set input parameters for UI
        inputParams = abi.encode("uint256 roleId", "string commitHash");
        super.initializeMandate(index, nameDescription, inputParams, config);
    }

    // --- Mandate Execution (Request) ---

    function handleRequest(
        address caller, // The user requesting the role
        address powers,
        uint16 mandateId,
        bytes memory mandateCalldata,
        uint256 nonce
    )
        public
        view
        override
        returns (uint256 actionId, address[] memory targets, uint256[] memory values, bytes[] memory calldatas)
    {
        Mem memory mem;
        mem.mandateHash = MandateUtilities.hashMandate(powers, mandateId);
        Data memory data_ = data[mem.mandateHash];

        // Hash the action
        actionId = MandateUtilities.computeActionId(mandateId, mandateCalldata, nonce);

        // Decode input parameters: roleId and the commitHash
        (mem.roleId, mem.commitHash) = abi.decode(mandateCalldata, (uint256, string));

        // Find the folder path associated with the requested roleId
        mem.indexPath = findIndex(data_.roleIds, mem.roleId);

        // Prepare arguments for Chainlink Functions (githubSigs.js)
        mem.args = new string[](3);
        mem.args[0] = data_.branch;
        mem.args[1] = mem.commitHash;
        mem.args[2] = data_.paths[mem.indexPath];

        // Create empty arrays for the execution plan
        // if callback takes too much gas, can call fulfill here by creatng empty targets slot.
        // (targets, values, calldatas) = MandateUtilities.createEmptyArrays(1);

        // Pack data needed for the _externalCall and fulfillRequest
        calldatas = new bytes[](1);
        calldatas[0] = abi.encode(
            mem.roleId,
            caller, // Pass the original caller
            powers,
            mem.args,
            data_.messageHash
        );

        return (actionId, targets, values, calldatas);
    }

    // --- Mandate Execution (Callback) ---

    function _externalCall(
        uint16 mandateId,
        uint256 actionId,
        address[] memory,
        /*targets*/
        uint256[] memory,
        /*values*/
        bytes[] memory calldatas
    ) internal override {
        // Decode data from handleRequest
        Mem memory mem;
        mem.mandateId = mandateId;
        mem.actionId = actionId;
        mem.callData = calldatas[0];
        (mem.roleId, mem.caller, mem.powers, mem.args, mem.messageHash) =
            abi.decode(mem.callData, (uint256, address, address, string[], bytes32));

        // Get mandate hash
        mem.mandateHash = MandateUtilities.hashMandate(mem.powers, mem.mandateId);

        // Call Chainlink Functions oracle
        mem.requestId = sendRequest(mem.args, mem.mandateHash);

        // Store the request details for fulfillment
        requests[mem.requestId] = Request({
            caller: mem.caller, // Store the original caller
            roleId: mem.roleId,
            powers: mem.powers,
            mandateId: mem.mandateId,
            actionId: mem.actionId,
            messageHash: mem.messageHash
        });
    }

    // --- Chainlink Functions ---

    /**
     * @notice Send a request to Chainlink Functions
     * @dev Uses the `source` code stored in this mandate's `Data`
     */
    function sendRequest(string[] memory args, bytes32 mandateHash) internal returns (bytes32 requestId) {
        Data memory data_ = data[mandateHash];

        FunctionsRequest.Request memory req;
        // Initialize request with the source code from config
        req.initializeRequestForInlineJavaScript(SOURCE);
        if (args.length > 0) req.setArgs(args);

        // Send the request
        sLastRequestId = _sendRequest(req.encodeCBOR(), data_.subscriptionId, data_.gasLimit, data_.donId);
        return sLastRequestId;
    }

    /**
     * @notice Handle Chainlink Functions response
     * @dev This is where the signature verification happens
     */
    function fulfillRequest(bytes32 requestId, bytes memory response, bytes memory err) internal override {
        if (sLastRequestId != requestId) {
            revert UnexpectedRequestID(requestId);
        }
        // Get the pending request
        Request memory request = requests[requestId];

        bytes32 mandateHash = MandateUtilities.hashMandate(request.powers, request.mandateId);

        // if error is returned, set error
        if (err.length > 0) {
            chainlinkErrors[mandateHash][request.caller] = err;
            return;
        }

        // --- Signature Verification ---
        // 1. Decode the signature (returned as a hex string "0x...")
        bytes memory signatureBytes = MandateUtilities.hexStringToBytes(abi.decode(abi.encode(response), (string)));

        // 4. Check if the signer matches the original caller. If so, save roleId to state.
        if (request.messageHash.recover(signatureBytes) == request.caller) {
            chainlinkReplies[mandateHash][request.caller] = request.roleId;
        }

        // executing this in the callback function fails because it takes too much gas.
        // leaving it here to remember.
        (address[] memory targets, uint256[] memory values, bytes[] memory calldatas) =
            MandateUtilities.createEmptyArrays(1);

        IPowers(request.powers).fulfill(request.mandateId, request.actionId, targets, values, calldatas);
    }

    // --- View Functions ---

    function getData(bytes32 mandateHash) external view returns (Data memory) {
        return data[mandateHash];
    }

    // returns latest reply, after deleting its data. Can only be called once per chainlink call.
    // NB THIS NEEDS ANOTHER CHECK! ANYONE CAN CALL THIS!
    function getLatestReply(bytes32 mandateHash, address caller)
        external
        view
        returns (bytes memory errorMessage, uint256 roleId)
    {
        // return reply
        return (chainlinkErrors[mandateHash][caller], chainlinkReplies[mandateHash][caller]);
    }

    function resetReply(address powers, uint16 mandateId, address caller) external returns (bool success) {
        if (msg.sender != powers) {
            revert("Unauthorised call");
        }

        bytes32 mandateHash = MandateUtilities.hashMandate(powers, mandateId);
        chainlinkErrors[mandateHash][caller] = abi.encode(0);
        chainlinkReplies[mandateHash][caller] = type(uint256).max;

        return true;
    }

    function getRouter() external view returns (address) {
        return address(i_router);
    }

    function findIndex(uint256[] memory roleIds, uint256 roleId) public pure returns (uint256) {
        for (uint256 i = 0; i < roleIds.length; i++) {
            if (roleIds[i] == roleId) {
                return i;
            }
        }
        revert("RoleId not found");
    }

    // --- Utility Functions ---
}
