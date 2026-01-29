// SPDX-License-Identifier: MIT

/// @notice Assign roles based on delegated token amounts from nominees.
///
/// This mandate:
/// - Fetches nominees from a Nominees contract
/// - Gets delegated vote amounts for each nominee from an ERC20Votes token
/// - Ranks nominees by delegated token amount
/// - Revokes roles from all current holders
/// - Assigns roles to top N nominees (based on maxRoleHolders)
///
/// @author 7Cedars

pragma solidity 0.8.26;

import { Mandate } from "../../Mandate.sol";
import { MandateUtilities } from "../../libraries/MandateUtilities.sol";
import { IPowers } from "../../interfaces/IPowers.sol";
import { Nominees } from "../../helpers/Nominees.sol";
import { ERC20Votes } from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Votes.sol";

contract DelegateTokenSelect is Mandate {
    struct Mem {
        address votesToken;
        address nomineesContract;
        uint256 roleId;
        uint256 maxRoleHolders;
        uint256 amountRoleHolders;
        address[] currentRoleHolders;
        address[] nominees;
        uint256 numNominees;
        address[] rankedNominees;
        uint256 tempVotes;
        address tempNominee;
        uint256[] delegatedVotes;
        address[] elected;
        uint256 totalOperations;
        uint256 operationIndex;
        uint256 i;
        uint256 j;
    }

    /// @notice Constructor for DelegateTokenSelect mandate
    constructor() {
        bytes memory configParams =
            abi.encode("address VotesToken", "address NomineesContract", "uint256 RoleId", "uint256 MaxRoleHolders");
        emit Mandate__Deployed(configParams);
    }

    /// @notice Execute the mandate by revoking current role holders and assigning top token holders
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
        actionId = MandateUtilities.computeActionId(mandateId, mandateCalldata, nonce);
        (mem.votesToken, mem.nomineesContract, mem.roleId, mem.maxRoleHolders) =
            abi.decode(getConfig(powers, mandateId), (address, address, uint256, uint256));

        // Step 1: Get current role holders from Powers
        mem.amountRoleHolders = IPowers(payable(powers)).getAmountRoleHolders(mem.roleId);

        mem.currentRoleHolders = new address[](mem.amountRoleHolders);
        for (mem.i = 0; mem.i < mem.amountRoleHolders; mem.i++) {
            mem.currentRoleHolders[mem.i] = IPowers(payable(powers)).getRoleHolderAtIndex(mem.roleId, mem.i);
        }

        // Step 2: Get nominees
        mem.nominees = Nominees(mem.nomineesContract).getNominees();
        mem.numNominees = mem.nominees.length;

        // Gas optimization: If all nominees will be elected, skip ranking
        if (mem.numNominees <= mem.maxRoleHolders) {
            // All nominees get elected, no need to rank by delegated tokens
            mem.elected = mem.nominees;
        } else {
            // Need to rank by delegated tokens and select top maxRoleHolders
            mem.rankedNominees = new address[](mem.numNominees);
            mem.delegatedVotes = new uint256[](mem.numNominees);

            // Get delegated votes for each nominee
            for (mem.i = 0; mem.i < mem.numNominees; mem.i++) {
                mem.rankedNominees[mem.i] = mem.nominees[mem.i];
                mem.delegatedVotes[mem.i] = ERC20Votes(mem.votesToken).getVotes(mem.nominees[mem.i]);
            }

            // Sort nominees by delegated votes (bubble sort - descending)
            for (mem.i = 0; mem.i < mem.numNominees - 1; mem.i++) {
                for (uint256 j = 0; j < mem.numNominees - mem.i - 1; j++) {
                    if (mem.delegatedVotes[j] < mem.delegatedVotes[j + 1]) {
                        // Swap votes
                        mem.tempVotes = mem.delegatedVotes[j];
                        mem.delegatedVotes[j] = mem.delegatedVotes[j + 1];
                        mem.delegatedVotes[j + 1] = mem.tempVotes;
                        // Swap nominees
                        mem.tempNominee = mem.rankedNominees[j];
                        mem.rankedNominees[j] = mem.rankedNominees[j + 1];
                        mem.rankedNominees[j + 1] = mem.tempNominee;
                    }
                }
            }

            // Select top maxRoleHolders candidates
            mem.elected = new address[](mem.maxRoleHolders);
            for (mem.i = 0; mem.i < mem.maxRoleHolders; mem.i++) {
                mem.elected[mem.i] = mem.rankedNominees[mem.i];
            }
        }

        // Step 4: Calculate total number of operations needed
        mem.totalOperations = mem.amountRoleHolders + mem.elected.length;

        if (mem.totalOperations == 0) {
            // No operations needed, but we still need to create an empty array
            (targets, values, calldatas) = MandateUtilities.createEmptyArrays(1);
            return (actionId, targets, values, calldatas);
        }

        (targets, values, calldatas) = MandateUtilities.createEmptyArrays(mem.totalOperations);

        mem.operationIndex = 0;

        // Step 5: Revoke roles from all current holders
        for (mem.i = 0; mem.i < mem.currentRoleHolders.length; mem.i++) {
            targets[mem.operationIndex] = powers;
            calldatas[mem.operationIndex] =
                abi.encodeWithSelector(IPowers.revokeRole.selector, mem.roleId, mem.currentRoleHolders[mem.i]);
            mem.operationIndex++;
        }

        // Step 6: Assign roles to newly elected accounts
        for (mem.i = 0; mem.i < mem.elected.length; mem.i++) {
            targets[mem.operationIndex] = powers;
            calldatas[mem.operationIndex] =
                abi.encodeWithSelector(IPowers.assignRole.selector, mem.roleId, mem.elected[mem.i]);
            mem.operationIndex++;
        }

        return (actionId, targets, values, calldatas);
    }
}
