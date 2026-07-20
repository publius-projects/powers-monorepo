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
import { IPowers } from "@src/interfaces/IPowers.sol";
import { PowersTypes } from "@src/interfaces/PowersTypes.sol";
import { MandateUtilities } from "@src/libraries/MandateUtilities.sol";

contract ElectionRegistry_CreateVoteMandate is Mandate {
    struct Mem {
        address electionRegistry;
        address electionRegistryVote;
        uint256 maxVotes;
        uint256 voterRoleId;
        uint48 nominationDuration;
        uint48 votingDuration;
        string title;
        uint256 electionId;
    }

    /// @notice Constructor for OpenVote mandate
    constructor(address registry_) Mandate(registry_) {
        bytes memory configParams = abi.encode(
            "address ElectionRegistry", "address ElectionRegistry_Vote", "uint256 maxVotes", "uint256 voterRoleId"
        );
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
    /// @param powers The Powers contract address
    /// @param mandateId The mandate identifier
    /// @param mandateCalldata Encoded boolean (true = nominate, false = revoke)
    /// @param nonce Unique nonce to build the action id
    function handleRequest(
        address,
        /* caller */
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
        (mem.title) = abi.decode(mandateCalldata, (string));
        mem.electionId = uint256(keccak256(abi.encodePacked(powers, mem.title)));
        (mem.electionRegistry, mem.electionRegistryVote, mem.maxVotes, mem.voterRoleId) =
            abi.decode(getConfig(powers, mandateId), (address, address, uint256, uint256)); // ElectionRegistry contract address

        PowersTypes.MandateInitData memory initData = PowersTypes.MandateInitData({
            nameDescription: "Vote in election",
            targetMandate: mem.electionRegistryVote,
            config: abi.encode(mem.electionRegistry, mem.maxVotes, mem.electionId),
            conditions: PowersTypes.Conditions({
                allowedRole: mem.voterRoleId,
                votingPeriod: 0,
                timelock: 0,
                throttleExecution: 0,
                needFulfilled: 0,
                needNotFulfilled: 0,
                quorum: 0,
                succeedAt: 0,
                maxExecutionDelay: 0
            })
        });

        (targets, values, calldatas) = MandateUtilities.createEmptyArrays(1);
        targets[0] = powers;
        calldatas[0] = abi.encodeWithSelector(
            IPowers.adoptMandate.selector, initData, nonce, "Creating vote mandate for election."
        );

        return (actionId, targets, values, calldatas);
    }
}
