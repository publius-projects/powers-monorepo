// SPDX-License-Identifier: MIT

/// @notice Execute proposals on a configured Governor contract.
///
/// This mandate allows executing governance proposals by validating their state
/// and then executing the proposal actions directly.
///
/// @author 7Cedars,

pragma solidity 0.8.26;

import { Mandate } from "../../Mandate.sol";
import { MandateUtilities } from "../../libraries/MandateUtilities.sol";
import { Governor } from "@openzeppelin/contracts/governance/Governor.sol";
import { IGovernor } from "@openzeppelin/contracts/governance/IGovernor.sol";

contract Governor_ExecuteProposal is Mandate {
    struct Mem {
        bytes32 mandateHash;
        bytes configData;
        address[] proposalTargets;
        uint256[] proposalValues;
        bytes[] proposalCalldatas;
        string description;
        address payable governorContract;
        uint256 proposalId;
    }

    /// @notice Constructor for Governor_ExecuteProposal mandate
    constructor() {
        bytes memory configParams = abi.encode("address GovernorContract");
        emit Mandate__Deployed(configParams);
    }

    function initializeMandate(
        uint16 index,
        string memory nameDescription,
        bytes memory inputParams,
        bytes memory config
    ) public override {
        super.initializeMandate(
            index,
            nameDescription,
            abi.encode("address[] targets", "uint256[] values", "bytes[] calldatas", "string description"),
            config
        );
    }

    /// @notice Build a call to execute a Governor proposal after validation
    /// @param mandateCalldata Encoded (address[] targets, uint256[] values, bytes[] calldatas, string description)
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
        mem.mandateHash = MandateUtilities.hashMandate(powers, mandateId);
        actionId = MandateUtilities.computeActionId(mandateId, mandateCalldata, nonce);

        // Validate that governor contract is configured
        mem.configData = getConfig(powers, mandateId);
        mem.governorContract = payable(abi.decode(mem.configData, (address)));
        if (mem.governorContract == address(0)) revert("Governor_ExecuteProposal: Governor contract not configured");

        // Decode proposal parameters
        (mem.proposalTargets, mem.proposalValues, mem.proposalCalldatas, mem.description) =
            abi.decode(mandateCalldata, (address[], uint256[], bytes[], string));

        // Validate proposal parameters
        if (mem.proposalTargets.length == 0) revert("Governor_ExecuteProposal: No targets provided");
        if (mem.proposalTargets.length != mem.proposalValues.length) {
            revert("Governor_ExecuteProposal: Targets and values length mismatch");
        }
        if (mem.proposalTargets.length != mem.proposalCalldatas.length) {
            revert("Governor_ExecuteProposal: Targets and calldatas length mismatch");
        }
        if (bytes(mem.description).length == 0) revert("Governor_ExecuteProposal: Description cannot be empty");

        // Get proposal ID from governor contract
        mem.proposalId = Governor(mem.governorContract)
            .hashProposal(
                mem.proposalTargets, mem.proposalValues, mem.proposalCalldatas, keccak256(bytes(mem.description))
            );

        // Check proposal state
        IGovernor.ProposalState state = Governor(mem.governorContract).state(mem.proposalId);
        if (state != IGovernor.ProposalState.Succeeded) {
            revert("Governor_ExecuteProposal: Proposal not succeeded");
        }

        // Return the proposal actions for execution
        return (actionId, mem.proposalTargets, mem.proposalValues, mem.proposalCalldatas);
    }
}
