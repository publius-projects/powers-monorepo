// SPDX-License-Identifier: MIT

/// @notice A mandate to execute the result of a SlateRegistry election.
///
/// This mandate:
/// - Takes SlateRegistry contract address at initialization
/// - Decodes electionTitle from calldata and derives electionId
/// - Reverts if voting has not yet closed
/// - Calls executeResults on SlateRegistry, which tallies votes and calls
///   Powers.request for each winning slate — from the SlateRegistry address,
///   satisfying the allowedRole check on those mandates
///
/// @author 7Cedars

pragma solidity ^0.8.26;

import { Mandate } from "@src/Mandate.sol";
import { MandateUtilities } from "@src/libraries/MandateUtilities.sol";
import { SlateRegistry } from "@src/core/helpers/SlateRegistry.sol";

contract SlateRegistry_ExecuteResult is Mandate {
    struct Mem {
        address slateRegistry;
        uint256 electionId;
        uint48 endBlock;
    }

    constructor(address registry_) Mandate(registry_) {
        bytes memory configParams = abi.encode("address SlateRegistry");
        emit Mandate__Deployed(configParams);
    }

    function initializeMandate(uint16 index, string memory nameDescription, bytes memory, bytes memory config)
        public
        override
    {
        bytes memory inputParams = abi.encode("string ElectionTitle");
        super.initializeMandate(index, nameDescription, inputParams, config);
    }

    /// @notice Adoption price: 2 credits.
    function priceInCredits() public pure override returns (uint256) {
        return 2;
    }

    /// @notice Developer payees for the paid adoption.
    function devs() public pure override returns (address[] memory payees) {
        payees = new address[](2);
        payees[0] = 0xEA223f81D7E74321370a77f1e44067bE8738B627;
        payees[1] = 0x328735d26e5Ada93610F0006c32abE2278c46211;
    }

    /// @notice Build a call to execute the results of a completed SlateRegistry election
    /// @param powers The Powers contract address
    /// @param mandateId The mandate identifier
    /// @param mandateCalldata Encoded election title
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

        string memory electionTitle = abi.decode(mandateCalldata, (string));
        mem.electionId = uint256(keccak256(abi.encodePacked(powers, electionTitle)));
        mem.slateRegistry = abi.decode(getConfig(powers, mandateId), (address));

        // Check that voting has ended
        (,,,, mem.endBlock,) = SlateRegistry(mem.slateRegistry).elections(mem.electionId);
        if (block.number <= mem.endBlock) revert("vote not yet closed");

        (targets, values, calldatas) = MandateUtilities.createEmptyArrays(1);
        targets[0] = mem.slateRegistry;
        calldatas[0] = abi.encodeWithSelector(SlateRegistry.executeResults.selector, mem.electionId);

        return (actionId, targets, values, calldatas);
    }
}
