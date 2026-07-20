// SPDX-License-Identifier: MIT

/// @notice Allows voters to vote on nominees from a standalone ElectionRegistry contract.
///
/// The logic:
/// - The inputParams are dynamic - as many bool options will appear as there are nominees.
/// - When a voter selects more than one nominee, the mandate will revert.
/// - When a vote is cast, the mandate calls the vote function in ElectionRegistry contract.
/// - Only one vote per voter is allowed per election.
///
/// @author 7Cedars

pragma solidity ^0.8.26;

import { Mandate } from "@src/Mandate.sol";
import { MandateUtilities } from "@src/libraries/MandateUtilities.sol";
import { ElectionRegistry } from "@src/core/helpers/ElectionRegistry.sol";
import { Strings } from "@lib/openzeppelin-contracts/contracts/utils/Strings.sol";

contract ElectionRegistry_Vote is Mandate {
    struct Mem {
        address caller;
        bytes32 mandateHash;
        address[] nominees;
        bool[] vote;
        uint256 numVotes;
        uint256 i;
        address openElectionContract;
        uint256 maxVotes;
        uint256 electionId;
    }

    /// @notice Constructor for ElectionRegistry_Vote mandate
    constructor(address registry_) Mandate(registry_) {
        bytes memory configParams =
            abi.encode("address ElectionRegistryContract", "uint256 maxVotes", "uint256 electionId");
        emit Mandate__Deployed(configParams);
    }

    /// @notice Build the input fields dynamically from the *current* election nominees.
    /// @dev One `bool <address>` field per nominee. Computed on read (not snapshotted at
    ///      initialization) because nominees register after the constitution is deployed —
    ///      snapshotting at init would freeze an empty list and the UI would show no inputs.
    function getInputParams(address powers, uint16 mandateId) public view override returns (bytes memory inputParams) {
        (address openElectionContract,, uint256 electionId) =
            abi.decode(getConfig(powers, mandateId), (address, uint256, uint256));

        address[] memory nominees = ElectionRegistry(openElectionContract).getNominees(electionId);
        string[] memory nomineeList = new string[](nominees.length);
        for (uint256 i = 0; i < nominees.length; i++) {
            nomineeList[i] = string.concat("bool ", Strings.toHexString(nominees[i]));
        }

        return abi.encode(nomineeList);
    }

    /// @notice Build a call to cast a vote in the ElectionRegistry contract
    /// @param caller The voter address
    /// @param powers The Powers contract address (unused here, forwarded in action context)
    /// @param mandateId The mandate identifier
    /// @param mandateCalldata Encoded bool[] where each index corresponds to a nominee
    /// @param nonce Unique nonce to build the action id
    function handleRequest(
        address caller,
        address powers,
        uint16 mandateId,
        bytes calldata mandateCalldata,
        uint256 nonce
    )
        public
        view
        virtual
        override
        returns (uint256 actionId, address[] memory targets, uint256[] memory values, bytes[] memory calldatas)
    {
        Mem memory mem;

        actionId = MandateUtilities.computeActionId(mandateId, mandateCalldata, nonce);
        (mem.openElectionContract, mem.maxVotes, mem.electionId) =
            abi.decode(getConfig(powers, mandateId), (address, uint256, uint256));
        mem.nominees = ElectionRegistry(mem.openElectionContract).getNominees(mem.electionId);

        // Check if election is open
        if (!ElectionRegistry(mem.openElectionContract).isElectionOpen(mem.electionId)) {
            revert("Election is not open.");
        }

        // Manual decoding of calldata which consists of multiple bools (ABI encoded as 32-byte words)
        if (mandateCalldata.length != mem.nominees.length * 32) {
            revert("Invalid vote length.");
        }

        mem.vote = new bool[](mem.nominees.length);
        for (uint256 i = 0; i < mem.nominees.length; i++) {
            bool val;
            assembly {
                val := calldataload(add(mandateCalldata.offset, mul(i, 32)))
            }
            mem.vote[i] = val;
        }

        // Check if the voter has voted for more than one nominee
        mem.numVotes = 0;
        for (mem.i = 0; mem.i < mem.vote.length; mem.i++) {
            if (mem.vote[mem.i]) {
                mem.numVotes++;
                if (mem.numVotes > mem.maxVotes) {
                    revert("Voter tries to vote for more than maxVotes nominees.");
                }
            }
        }

        // create call for
        (targets, values, calldatas) = MandateUtilities.createEmptyArrays(1);
        targets[0] = mem.openElectionContract;
        calldatas[0] = abi.encodeWithSelector(ElectionRegistry.vote.selector, mem.electionId, caller, mem.vote);

        return (actionId, targets, values, calldatas);
    }
}
