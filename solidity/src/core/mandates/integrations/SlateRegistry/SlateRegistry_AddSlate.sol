// SPDX-License-Identifier: MIT

/// @notice A mandate to add a slate (PresetActions) to a SlateRegistry election.
///
/// This mandate:
/// - Takes SlateRegistry and PresetActions contract addresses at initialization
/// - Creates a PresetActions mandate with the provided targets, values, and calldatas
/// - Adds the new mandate to the election's flow at the first empty slot
///
/// @author 7Cedars

pragma solidity ^0.8.26;

import { Mandate } from "@src/Mandate.sol";
import { IPowers } from "@src/interfaces/IPowers.sol";
import { PowersTypes } from "@src/interfaces/PowersTypes.sol";
import { MandateUtilities } from "@src/libraries/MandateUtilities.sol";
import { SlateRegistry } from "@src/core/helpers/SlateRegistry.sol";

contract SlateRegistry_AddSlate is Mandate {
    struct Mem {
        address slateRegistry;
        address presetActions;
        uint256 electionId;
        uint8 flowIndex;
        uint256 roleId;
        uint16 newMandateId;
        uint8 emptySlotIndex;
        string slateNameDescription;
        address[] slateTargets;
        uint256[] slateValues;
        bytes[] slateCalldatas;
    }

    /// @notice Constructor for SlateRegistry_AddSlate mandate
    constructor(address registry_) Mandate(registry_) {
        bytes memory configParams = abi.encode("address SlateRegistry", "address PresetActions");
        emit Mandate__Deployed(configParams);
    }

    function initializeMandate(
        uint16 index,
        string memory nameDescription,
        bytes memory inputParams,
        bytes memory config
    ) public override {
        inputParams = abi.encode(
            "string ElectionTitle",
            "string NameDescription",
            "address[] Targets",
            "uint256[] Values",
            "bytes[] Calldatas"
        );
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

    /// @notice Build calls to adopt a PresetActions mandate and add it to the election flow
    /// @param powers The Powers contract address
    /// @param mandateId The mandate identifier
    /// @param mandateCalldata Encoded input parameters
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

        // Decode input parameters into struct to reduce stack usage
        {
            string memory electionTitle;
            (electionTitle, mem.slateNameDescription, mem.slateTargets, mem.slateValues, mem.slateCalldatas) =
                abi.decode(mandateCalldata, (string, string, address[], uint256[], bytes[]));

            // Decode config parameters
            (mem.slateRegistry, mem.presetActions) = abi.decode(getConfig(powers, mandateId), (address, address));

            // Compute electionId from the electionTitle (same as SlateRegistry does)
            mem.electionId = uint256(keccak256(abi.encodePacked(powers, electionTitle)));
        }

        // Get election info from SlateRegistry to retrieve flowIndex
        (mem.flowIndex,,,,,) = SlateRegistry(mem.slateRegistry).elections(mem.electionId);

        // Get roleId from SlateRegistry
        mem.roleId = SlateRegistry(mem.slateRegistry).roleId();

        // Get the current mandateCounter - this will be the mandateId of the new mandate
        mem.newMandateId = IPowers(powers).getMandateCounter();

        // Find the first empty slot (mandateId == 0) in the flow
        mem.emptySlotIndex = _findEmptySlot(powers, mem.flowIndex);

        // Build and return the calls
        return _buildCalls(powers, mem, actionId);
    }

    /// @dev Find the first empty slot in the flow
    function _findEmptySlot(address powers, uint8 flowIndex) internal view returns (uint8) {
        uint16[] memory flowMandateIds = IPowers(powers).getFlowMandatesAtIndex(flowIndex);
        for (uint8 i = 0; i < flowMandateIds.length; i++) {
            if (flowMandateIds[i] == 0) {
                return i;
            }
        }
        revert("No empty slot in flow");
    }

    /// @dev Build the target calls for adoptMandate and editFlowByIndex
    function _buildCalls(address powers, Mem memory mem, uint256 actionId)
        internal
        pure
        returns (uint256, address[] memory targets, uint256[] memory values, bytes[] memory calldatas)
    {
        // Create MandateInitData for the PresetActions mandate
        PowersTypes.MandateInitData memory initData = PowersTypes.MandateInitData({
            nameDescription: mem.slateNameDescription,
            targetMandate: mem.presetActions,
            config: abi.encode(mem.slateTargets, mem.slateValues, mem.slateCalldatas),
            conditions: PowersTypes.Conditions({
                allowedRole: mem.roleId,
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

        // Create arrays for 3 calls: adoptMandate, editFlowByIndex, registerSlate
        (targets, values, calldatas) = MandateUtilities.createEmptyArrays(3);

        // Call 1: Adopt the PresetActions mandate
        targets[0] = powers;
        calldatas[0] = abi.encodeWithSelector(IPowers.adoptMandate.selector, initData);

        // Call 2: Add the new mandate to the flow at the empty slot
        targets[1] = powers;
        calldatas[1] = abi.encodeWithSelector(
            IPowers.editFlowByIndex.selector, mem.flowIndex, mem.emptySlotIndex, mem.newMandateId
        );

        // Call 3: Register the slate in SlateRegistry so it appears in vote tallying
        targets[2] = mem.slateRegistry;
        calldatas[2] = abi.encodeWithSelector(SlateRegistry.registerSlate.selector, mem.electionId, mem.newMandateId);

        return (actionId, targets, values, calldatas);
    }
}
