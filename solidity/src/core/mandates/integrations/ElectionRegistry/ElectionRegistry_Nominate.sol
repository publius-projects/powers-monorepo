// SPDX-License-Identifier: MIT

/// NB! I think I can do this using bespoke action on return value. Try out in a bit!

/// @notice Starts an election by calling openElection on the ElectionRegistry contract
/// and deploys an ElectionRegistry_Vote contract for voting.
///
/// This mandate:
/// - Takes electionContract address, roleId, and maxRoleHolders at initialization
/// - Deploys an ElectionRegistry_Vote contract during initialization
/// - Calls openElection on the ElectionRegistry contract when executed
///
/// @author 7Cedars

pragma solidity ^0.8.26;

import { Mandate } from "@src/Mandate.sol";
import { MandateUtilities } from "@src/libraries/MandateUtilities.sol";
import { ElectionRegistry } from "@src/core/helpers/ElectionRegistry.sol";

contract ElectionRegistry_Nominate is Mandate {
    struct Mem {
        address electionList;
        bool shouldNominate;
        string title;
        uint48 startBlock;
        uint48 endBlock;
        uint256 electionId;
    }

    /// @notice Constructor for Nominate mandate
    constructor(address registry_) Mandate(registry_) {
        bytes memory configParams = abi.encode("address ElectionRegistry", "bool shouldNominate");
        emit Mandate__Deployed(configParams);
    }

    function initializeMandate(uint16 index, string memory nameDescription, bytes memory, bytes memory config)
        public
        override
    {
        string[] memory params = new string[](1);
        params[0] = "string Title";
        super.initializeMandate(index, nameDescription, abi.encode(params), config);
    }

    /// @notice Build a call to nominate or revoke nomination for the caller
    /// @param caller The transaction originator (will be nominated/revoked)
    /// @param powers The Powers contract address
    /// @param mandateId The mandate identifier
    /// @param mandateCalldata Encoded boolean (true = nominate, false = revoke)
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
        override
        returns (uint256 actionId, address[] memory targets, uint256[] memory values, bytes[] memory calldatas)
    {
        Mem memory mem;
        actionId = MandateUtilities.computeActionId(mandateId, mandateCalldata, nonce);
        (mem.electionList, mem.shouldNominate) = abi.decode(getConfig(powers, mandateId), (address, bool)); // ElectionRegistry contract address
        (mem.title) = abi.decode(mandateCalldata, (string));
        mem.electionId = uint256(keccak256(abi.encodePacked(powers, mem.title)));

        (targets, values, calldatas) = MandateUtilities.createEmptyArrays(1);
        targets[0] = mem.electionList;
        if (mem.shouldNominate) {
            calldatas[0] = abi.encodeWithSelector(ElectionRegistry.nominate.selector, mem.electionId, caller);
        } else {
            calldatas[0] = abi.encodeWithSelector(ElectionRegistry.revokeNomination.selector, mem.electionId, caller);
        }

        return (actionId, targets, values, calldatas);
    }
}
