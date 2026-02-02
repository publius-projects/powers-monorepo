// SPDX-License-Identifier: MIT

/// @notice End open elections and assign roles based on election results.
///
/// This mandate:
/// - Checks if the election is closed (reverts if still open)
/// - Fetches current role holders from Powers
/// - Retrieves election results from ElectionList contract
/// - Revokes the ElectionList_Vote mandate
/// - Revokes roles from all current holders
/// - Assigns roles to newly elected accounts
///
/// @author 7Cedars

pragma solidity 0.8.26;

import { Mandate } from "../../Mandate.sol";
import { IPowers } from "../../interfaces/IPowers.sol";
import { MandateUtilities } from "../../libraries/MandateUtilities.sol";
import { ElectionList } from "../../helpers/ElectionList.sol";

contract ElectionList_Tally is Mandate {
    struct Mem {
        uint16 voteContractId;
        uint256 amountRoleHolders;
        address[] currentRoleHolders;
        address[] rankedNominees;
        uint256 numNominees;
        uint256 maxN;
        uint256 numToElect;
        address[] elected;
        uint256 totalOperations;
        uint256 operationIndex;
        uint256 i;
        address electionContract;
        uint256 roleId;
        uint256 maxRoleHolders;
        string title;
        uint48 startBlock;
        uint48 endBlock;
        uint256 electionId;
    }

    /// @notice Constructor for ElectionList_Tally mandate
    constructor() {
        bytes memory configParams = abi.encode("address electionContract", "uint256 RoleId", "uint256 MaxRoleHolders");
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

    /// @notice Execute the mandate by ending the election, revoking the vote mandate,
    /// revoking current role holders, and assigning newly elected accounts
    /// @param mandateCalldata The calldata (empty for this mandate)
    function handleRequest(
        address,
        /*caller*/
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
        (mem.electionContract, mem.roleId, mem.maxRoleHolders) =
            abi.decode(getConfig(powers, mandateId), (address, uint256, uint256));
        (mem.title, mem.startBlock, mem.endBlock) = abi.decode(mandateCalldata, (string, uint48, uint48));
        mem.electionId = uint256(keccak256(abi.encodePacked(powers, mem.title, mem.startBlock, mem.endBlock)));
        actionId = MandateUtilities.computeActionId(mandateId, mandateCalldata, nonce);

        // Step 1: Check if election is closed - revert if still open
        if (ElectionList(mem.electionContract).isElectionOpen(mem.electionId)) {
            revert("Election is still open");
        }

        // Step 2: Get amount of current role holders
        mem.amountRoleHolders = IPowers(payable(powers)).getAmountRoleHolders(mem.roleId);

        // Get current role holders from Powers
        mem.currentRoleHolders = new address[](mem.amountRoleHolders);
        for (mem.i = 0; mem.i < mem.amountRoleHolders; mem.i++) {
            mem.currentRoleHolders[mem.i] = IPowers(payable(powers)).getRoleHolderAtIndex(mem.roleId, mem.i);
        }

        // Step 4: Get nominee ranking and select top candidates
        (mem.rankedNominees,) = ElectionList(mem.electionContract).getNomineeRanking(mem.electionId);
        // Select top candidates based on maxRoleHolders
        mem.numNominees = mem.rankedNominees.length;
        mem.maxN = mem.maxRoleHolders;
        mem.numToElect = mem.numNominees <= mem.maxN ? mem.numNominees : mem.maxN;

        mem.elected = new address[](mem.numToElect);
        for (mem.i = 0; mem.i < mem.numToElect; mem.i++) {
            mem.elected[mem.i] = mem.rankedNominees[mem.i];
        }

        // Calculate total number of operations needed:
        // - Revoke all current role holders
        // - Assign role to all newly elected accounts
        // - NB: revoking the vote mandate should be handled through another mandate (not here)
        mem.totalOperations = mem.amountRoleHolders + mem.elected.length;
        (targets, values, calldatas) = MandateUtilities.createEmptyArrays(mem.totalOperations);
        mem.operationIndex = 0;

        // Step 6: Revoke roles from all current holders
        for (mem.i = 0; mem.i < mem.currentRoleHolders.length; mem.i++) {
            targets[mem.operationIndex] = powers;
            calldatas[mem.operationIndex] =
                abi.encodeWithSelector(IPowers.revokeRole.selector, mem.roleId, mem.currentRoleHolders[mem.i]);
            mem.operationIndex++;
        }

        // Step 7: Assign roles to newly elected accounts
        for (mem.i = 0; mem.i < mem.elected.length; mem.i++) {
            targets[mem.operationIndex] = powers;
            calldatas[mem.operationIndex] =
                abi.encodeWithSelector(IPowers.assignRole.selector, mem.roleId, mem.elected[mem.i]);
            mem.operationIndex++;
        }

        return (actionId, targets, values, calldatas);
    }
}
