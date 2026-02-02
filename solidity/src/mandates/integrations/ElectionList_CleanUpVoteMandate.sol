// SPDX-License-Identifier: MIT

/// NB! I think I can do this using bespoke action on return value. Try out in a bit!

/// @notice Starts an election by calling openElection on the ElectionList contract
/// and deploys an ElectionList_Vote contract for voting.
///
/// This mandate:
/// - Takes electionContract address, roleId, and maxRoleHolders at initialization
/// - Deploys an ElectionList_Vote contract during initialization
/// - Calls openElection on the ElectionList contract when executed
///
/// @author 7Cedars

pragma solidity 0.8.26;

import { Mandate } from "../../Mandate.sol";
import { IPowers } from "../../interfaces/IPowers.sol";
import { PowersTypes } from "../../interfaces/PowersTypes.sol";
import { MandateUtilities } from "../../libraries/MandateUtilities.sol";
import { ElectionList } from "../../helpers/ElectionList.sol";

contract ElectionList_CleanUpVoteMandate is Mandate {
    struct Mem {
        string title;
        uint48 startBlock;
        uint48 endBlock;
        uint256 electionId;
        uint16 createVoteMandate_Id;
        bytes returnData;
        uint16 voteMandate_Id;
    }

    /// @notice Constructor for OpenVote mandate
    constructor() {
        bytes memory configParams = abi.encode("uint16 CreateVoteMandate_Id");
        emit Mandate__Deployed(configParams);
    }

    function initializeMandate(
        uint16 index,
        string memory nameDescription,
        bytes memory inputParams,
        bytes memory config
    ) public override {
        inputParams = abi.encode("string Title", "uint48 StartBlock", "uint48 EndBlock");
        super.initializeMandate(index, nameDescription, inputParams, config);
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
        bytes memory mandateCalldata,
        uint256 nonce
    )
        public
        view
        override
        returns (uint256 actionId, address[] memory targets, uint256[] memory values, bytes[] memory calldatas)
    {
        Mem memory mem;

        actionId = MandateUtilities.computeActionId(mandateId, mandateCalldata, nonce);
        (mem.title, mem.startBlock, mem.endBlock) = abi.decode(mandateCalldata, (string, uint48, uint48));
        mem.electionId = uint256(keccak256(abi.encodePacked(powers, mem.title, mem.startBlock, mem.endBlock)));
        (mem.createVoteMandate_Id) = abi.decode(getConfig(powers, mandateId), (uint16)); // ElectionList contract address

        // retrieve the ElectionList_Vote mandate address from the return value of the Open Vote mandate
        mem.returnData = IPowers(powers)
            .getActionReturnData(MandateUtilities.computeActionId(mem.createVoteMandate_Id, mandateCalldata, nonce), 0);
        mem.voteMandate_Id = abi.decode(mem.returnData, (uint16));

        (targets, values, calldatas) = MandateUtilities.createEmptyArrays(1);
        targets[0] = powers;
        calldatas[0] = abi.encodeWithSelector(
            IPowers.revokeMandate.selector, mem.voteMandate_Id, nonce, "Cleaning up vote mandate."
        );

        return (actionId, targets, values, calldatas);
    }
}
