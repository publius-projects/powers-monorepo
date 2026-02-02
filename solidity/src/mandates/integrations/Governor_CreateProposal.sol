// SPDX-License-Identifier: MIT

/// @notice Create proposals on a configured Governor contract.
///
/// This mandate allows creating governance proposals by calling the propose function
/// on a configured Governor contract (e.g., SimpleGovernor).
///
/// @author 7Cedars,

pragma solidity 0.8.26;

import { Mandate } from "../../Mandate.sol";
import { MandateUtilities } from "../../libraries/MandateUtilities.sol";
import { Governor } from "@openzeppelin/contracts/governance/Governor.sol";

contract Governor_CreateProposal is Mandate {
    struct Mem {
        address payable governorContract;
        address[] proposalTargets;
        uint256[] proposalValues;
        bytes[] proposalCalldatas;
        string description;
    }

    /// @notice Constructor for Governor_CreateProposal mandate
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

    /// @notice Build a call to the Governor.propose function
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
        actionId = MandateUtilities.computeActionId(mandateId, mandateCalldata, nonce);

        // Validate that governor contract is configured
        mem.governorContract = payable(abi.decode(getConfig(powers, mandateId), (address)));
        if (mem.governorContract == address(0)) revert("Governor_CreateProposal: Governor contract not configured");

        // Decode proposal parameters
        (mem.proposalTargets, mem.proposalValues, mem.proposalCalldatas, mem.description) =
            abi.decode(mandateCalldata, (address[], uint256[], bytes[], string));

        // Validate proposal parameters
        if (mem.proposalTargets.length == 0) revert("Governor_CreateProposal: No targets provided");
        if (mem.proposalTargets.length != mem.proposalValues.length) {
            revert("Governor_CreateProposal: Targets and values length mismatch");
        }
        if (mem.proposalTargets.length != mem.proposalCalldatas.length) {
            revert("Governor_CreateProposal: Targets and calldatas length mismatch");
        }
        if (bytes(mem.description).length == 0) revert("Governor_CreateProposal: Description cannot be empty");

        // Create arrays for the call to propose
        (targets, values, calldatas) = MandateUtilities.createEmptyArrays(1);
        targets[0] = mem.governorContract;
        calldatas[0] = abi.encodeWithSelector(
            Governor.propose.selector, mem.proposalTargets, mem.proposalValues, mem.proposalCalldatas, mem.description
        );

        return (actionId, targets, values, calldatas);
    }
}
