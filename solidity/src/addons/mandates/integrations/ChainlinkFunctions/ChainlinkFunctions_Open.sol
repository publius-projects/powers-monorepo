// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

// Base contracts
import { AsyncMandate } from "@src/AsyncMandate.sol";
import { MandateUtilities } from "@src/libraries/MandateUtilities.sol";

// Chainlink Functions
import { FunctionsClient } from "@lib/chainlink-evm/contracts/src/v0.8/functions/v1_0_0/FunctionsClient.sol";
import {
    FunctionsRequest
} from "@lib/chainlink-evm/contracts/src/v0.8/functions/v1_0_0/libraries/FunctionsRequest.sol";

/**
 * @title ChainlinkFunctions_Open
 * @notice A generic mandate that takes any number of string inputs and forwards them
 * to a Chainlink Functions Oracle request, executing the provided source code.
 */
contract ChainlinkFunctions_Open is AsyncMandate, FunctionsClient {
    using FunctionsRequest for FunctionsRequest.Request;

    error UnexpectedRequestID(bytes32 requestId);

    // @notice Configurations data for each instance of the mandate
    struct Data {
        string source;
        string[] inputParams;
        uint64 subscriptionId;
        uint32 gasLimit;
        bytes32 donId;
    }

    struct Request {
        address caller;
        address powers;
        uint16 mandateId;
        uint256 actionId;
    }

    // --- State Variables ---
    bytes32 public sLastRequestId;
    bytes public sLastResponse;
    bytes public sLastError;

    mapping(bytes32 mandateHash => mapping(address => bytes errorMessage)) internal chainlinkErrors;
    mapping(bytes32 mandateHash => mapping(address => bytes responseData)) internal chainlinkReplies;
    mapping(bytes32 mandateHash => Data) internal data;
    mapping(bytes32 requestId => Request) public requests;

    // --- Constructor ---

    constructor(address router, address registry_) FunctionsClient(router) AsyncMandate(registry_) {
        // Define the parameters required to configure this mandate
        bytes memory configParams = abi.encode(
            "string source", "string[] inputParams", "uint64 subscriptionId", "uint32 gasLimit", "bytes32 donID"
        );
        emit Mandate__Deployed(configParams);
    }

    // --- Mandate Initialization ---

    function initializeMandate(
        uint16 index,
        string memory nameDescription,
        bytes memory,
        /* inputParams */
        // Ignored, as we construct it from config
        bytes memory config
    )
        public
        override
    {
        bytes32 mandateHash = MandateUtilities.hashMandate(msg.sender, index);

        (string memory source, string[] memory inputParams, uint64 subscriptionId, uint32 gasLimit, bytes32 donId) =
            abi.decode(config, (string, string[], uint64, uint32, bytes32));

        // Check if all inputParams are strings (meaning they start with "string ")
        for (uint256 i = 0; i < inputParams.length; i++) {
            bytes memory paramBytes = bytes(inputParams[i]);
            if (
                paramBytes.length < 7 || paramBytes[0] != "s" || paramBytes[1] != "t" || paramBytes[2] != "r"
                    || paramBytes[3] != "i" || paramBytes[4] != "n" || paramBytes[5] != "g" || paramBytes[6] != " "
            ) {
                revert("All input parameters must be of type string");
            }
        }

        // Store configuration
        data[mandateHash].source = source;
        data[mandateHash].inputParams = inputParams;
        data[mandateHash].subscriptionId = subscriptionId;
        data[mandateHash].gasLimit = gasLimit;
        data[mandateHash].donId = donId;

        // Set input parameters for UI using custom tuple encoder
        bytes memory generatedInputParams = _encodeStringTuple(inputParams);
        super.initializeMandate(index, nameDescription, generatedInputParams, config);
    }

    // --- Mandate Execution (Request) ---

    function handleRequest(
        address caller,
        address powers,
        uint16 mandateId,
        bytes calldata mandateCalldata,
        uint256 nonce
    )
        public
        view
        override
        returns (uint256 actionId, address[] memory targets, uint256[] memory values, bytes[] memory calldatas)
    {
        bytes32 mandateHash = MandateUtilities.hashMandate(powers, mandateId);
        Data memory data_ = data[mandateHash];

        // Hash the action
        actionId = MandateUtilities.computeActionId(mandateId, mandateCalldata, nonce);

        // Copy to memory to use our assembly decoder
        bytes memory calldataMem = mandateCalldata;

        // Decode the tuple of strings from mandateCalldata dynamically
        string[] memory args = _decodeStringTuple(calldataMem, data_.inputParams.length);

        calldatas = new bytes[](1);
        calldatas[0] = abi.encode(caller, powers, args);

        return (actionId, targets, values, calldatas);
    }

    // --- Mandate Execution (Callback) ---

    function _callOracle(
        uint16 mandateId,
        uint256 actionId,
        address[] memory,
        /*targets*/
        uint256[] memory,
        /*values*/
        bytes[] memory calldatas
    ) internal override {
        (address caller, address powers, string[] memory args) = abi.decode(calldatas[0], (address, address, string[]));

        bytes32 mandateHash = MandateUtilities.hashMandate(powers, mandateId);

        // Call Chainlink Functions oracle
        bytes32 requestId = sendRequest(args, mandateHash);

        // Store the request details for fulfillment
        requests[requestId] = Request({ caller: caller, powers: powers, mandateId: mandateId, actionId: actionId });
    }

    // --- Chainlink Functions ---

    function sendRequest(string[] memory args, bytes32 mandateHash) internal returns (bytes32 requestId) {
        Data memory data_ = data[mandateHash];

        FunctionsRequest.Request memory req;
        req.initializeRequestForInlineJavaScript(data_.source);
        if (args.length > 0) req.setArgs(args);

        sLastRequestId = _sendRequest(req.encodeCBOR(), data_.subscriptionId, data_.gasLimit, data_.donId);
        return sLastRequestId;
    }

    function fulfillRequest(bytes32 requestId, bytes memory response, bytes memory err) internal override {
        if (sLastRequestId != requestId) {
            revert UnexpectedRequestID(requestId);
        }

        Request memory request = requests[requestId];
        bytes32 mandateHash = MandateUtilities.hashMandate(request.powers, request.mandateId);

        if (err.length > 0) {
            chainlinkErrors[mandateHash][request.caller] = err;
            return;
        }

        // Save the abi.encoded response
        chainlinkReplies[mandateHash][request.caller] = abi.encode(response);

        // Complete the action in Powers without executing any targets
        (address[] memory targets, uint256[] memory values, bytes[] memory calldatas) =
            MandateUtilities.createEmptyArrays(1);

        _replyPowers(request.powers, request.mandateId, request.actionId, targets, values, calldatas);
    }

    // --- View Functions ---

    function getData(bytes32 mandateHash) external view returns (Data memory) {
        return data[mandateHash];
    }

    function getLatestReply(bytes32 mandateHash, address caller)
        external
        view
        returns (bytes memory errorMessage, bytes memory responseData)
    {
        return (chainlinkErrors[mandateHash][caller], chainlinkReplies[mandateHash][caller]);
    }

    function resetReply(address powers, uint16 mandateId, address caller) external returns (bool success) {
        if (msg.sender != powers) {
            revert("Unauthorised call");
        }

        bytes32 mandateHash = MandateUtilities.hashMandate(powers, mandateId);
        chainlinkErrors[mandateHash][caller] = "";
        chainlinkReplies[mandateHash][caller] = "";

        return true;
    }

    function getRouter() external view returns (address) {
        return address(i_router);
    }

    // --- Utility Functions ---

    /**
     * @notice Dynamically decodes a tuple of strings from calldata into a string[] array.
     */
    function _decodeStringTuple(bytes memory inputData, uint256 numStrings) internal pure returns (string[] memory) {
        string[] memory args = new string[](numStrings);
        for (uint256 i = 0; i < numStrings; i++) {
            uint256 offset;
            assembly {
                // Read the offset for the string at index i.
                // inputData points to the length of the bytes array.
                // Actual data starts at inputData + 32.
                offset := mload(add(add(inputData, 32), mul(i, 32)))
            }
            string memory str;
            assembly {
                // The offset is relative to the start of the encoded tuple (inputData + 32).
                str := add(add(inputData, 32), offset)
            }
            args[i] = str;
        }
        return args;
    }

    /**
     * @notice Encodes a dynamic array of strings into a standard ABI tuple byte format.
     */
    function _encodeStringTuple(string[] memory strings) internal pure returns (bytes memory) {
        uint256 numStrings = strings.length;
        if (numStrings == 0) return new bytes(0);

        uint256 dataSize = 0;
        for (uint256 i = 0; i < numStrings; i++) {
            uint256 len = bytes(strings[i]).length;
            dataSize += 32 + ((len + 31) / 32) * 32;
        }

        bytes memory result = new bytes(numStrings * 32 + dataSize);
        uint256 currentDataOffset = numStrings * 32;

        for (uint256 i = 0; i < numStrings; i++) {
            // Write the offset
            assembly {
                mstore(add(add(result, 32), mul(i, 32)), currentDataOffset)
            }

            string memory str = strings[i];
            uint256 len = bytes(str).length;

            // Write the string length and contents
            assembly {
                mstore(add(add(result, 32), currentDataOffset), len)

                let src := add(str, 32)
                let dest := add(add(add(result, 32), currentDataOffset), 32)
                for { let j := 0 } lt(j, len) { j := add(j, 32) } {
                    mstore(add(dest, j), mload(add(src, j)))
                }
            }

            currentDataOffset += 32 + ((len + 31) / 32) * 32;
        }

        return result;
    }
}
