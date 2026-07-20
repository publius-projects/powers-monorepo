// SPDX-License-Identifier: MIT

/// @notice Allows members of a role to select from nominated addresses for their own role.
///
/// The logic:
/// - Members can assign or revoke roles from nominated addresses.
/// - The inputParams are dynamic - as many bool options will appear as there are nominees.
/// - Members can select multiple nominees up to the numberToSelect limit.
/// - Role assignment/revocation is handled through the Powers contract.
///
/// @author 7Cedars

pragma solidity ^0.8.26;

import { Mandate } from "@src/Mandate.sol";
import { IPowers } from "@src/interfaces/IPowers.sol";
import { Nominees } from "@src/core/helpers/Nominees.sol";
import { MandateUtilities } from "@src/libraries/MandateUtilities.sol";
import { Strings } from "@lib/openzeppelin-contracts/contracts/utils/Strings.sol";

contract PeerSelect is Mandate {
    struct Mem {
        address[] nominees;
        bool[] selection;
        uint256 numSelections;
        uint256 i;
        uint256 currentRoleHolders;
        uint256 roleId;
        uint8 numberToSelect;
        address nomineesContract;
    }

    /// @notice Constructor for PeerSelect mandate
    constructor(address registry_) Mandate(registry_) {
        bytes memory configParams = abi.encode("uint8 numberToSelect", "uint256 roleId", "address NomineesContract");
        emit Mandate__Deployed(configParams);
    }

    /// @notice Build the input fields dynamically from the *current* nominees.
    /// @dev One `bool <address>` field per nominee. Computed on read (not snapshotted at
    ///      initialization) because nominations happen after the constitution is deployed —
    ///      snapshotting at init would freeze an empty list and the UI would show no inputs.
    function getInputParams(address powers, uint16 mandateId) public view override returns (bytes memory inputParams) {
        (,, address nomineesContract) = abi.decode(getConfig(powers, mandateId), (uint8, uint256, address));

        address[] memory nominees = Nominees(nomineesContract).getNominees();
        string[] memory nomineeList = new string[](nominees.length);
        for (uint256 i = 0; i < nominees.length; i++) {
            nomineeList[i] = string.concat("bool ", Strings.toHexString(nominees[i]));
        }

        return abi.encode(nomineeList);
    }

    /// @notice Build calls to assign or revoke roles for selected nominees
    /// @param powers The Powers contract address
    /// @param mandateId The mandate identifier
    /// @param mandateCalldata Encoded bool[] selections matching current nominees from Nominees contract
    /// @param nonce Unique nonce to build the action id
    function handleRequest(
        address, /* caller */
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

        (mem.numberToSelect, mem.roleId, mem.nomineesContract) =
            abi.decode(getConfig(powers, mandateId), (uint8, uint256, address));

        // Get current nominees from Nominees contract
        mem.nominees = Nominees(mem.nomineesContract).getNominees();

        // Manual decoding of calldata which consists of multiple bools (ABI encoded as 32-byte words)
        if (mandateCalldata.length != mem.nominees.length * 32) {
            revert("Invalid selection length.");
        }

        mem.selection = new bool[](mem.nominees.length);
        for (uint256 i = 0; i < mem.nominees.length; i++) {
            bool val;
            assembly {
                val := calldataload(add(mandateCalldata.offset, mul(i, 32)))
            }
            mem.selection[i] = val;
        }

        // Count selections
        mem.numSelections = 0;
        // Check if we have enough nominees to fill the seats
        if (mem.nominees.length < mem.numberToSelect) {
            revert("Not enough nominees to fill the seats.");
        }

        for (mem.i = 0; mem.i < mem.selection.length; mem.i++) {
            if (mem.selection[mem.i]) {
                mem.numSelections++;
            }
        }

        // We must select exactly numberToSelect (seats)
        if (mem.numSelections != mem.numberToSelect) {
            revert("Must select exactly numberToSelect options.");
        }

        // 1. Remove all existing role holders
        mem.currentRoleHolders = IPowers(payable(powers)).getAmountRoleHolders(mem.roleId);

        // We need to fetch all current holders first because we can't iterate and revoke (indices shift)
        // effectively without multiple calls.
        // We will generate `revokeRole` calls for all current holders.
        address[] memory currentHolders = new address[](mem.currentRoleHolders);
        for (mem.i = 0; mem.i < mem.currentRoleHolders; mem.i++) {
            currentHolders[mem.i] = IPowers(payable(powers)).getRoleHolderAtIndex(mem.roleId, mem.i);
        }

        // 2. Assign selected accounts
        uint256 totalCalls = mem.currentRoleHolders + mem.numSelections + 1;

        (targets, values, calldatas) = MandateUtilities.createEmptyArrays(totalCalls);

        // Revoke calls
        for (mem.i = 0; mem.i < mem.currentRoleHolders; mem.i++) {
            targets[mem.i] = powers;
            calldatas[mem.i] = abi.encodeWithSelector(IPowers.revokeRole.selector, mem.roleId, currentHolders[mem.i]);
        }

        // Assign calls
        uint256 currentCallIndex = mem.currentRoleHolders;
        for (mem.i = 0; mem.i < mem.selection.length; mem.i++) {
            if (mem.selection[mem.i]) {
                targets[currentCallIndex] = powers;
                calldatas[currentCallIndex] =
                    abi.encodeWithSelector(IPowers.assignRole.selector, mem.roleId, mem.nominees[mem.i]);
                currentCallIndex++;
            }
        }

        // Finally, revoke this mandate itself so it can't be executed again (since it's meant to be a one-time selection)
        targets[currentCallIndex] = powers;
        calldatas[currentCallIndex] = abi.encodeWithSelector(IPowers.revokeMandate.selector, mandateId);

        return (actionId, targets, values, calldatas);
    }
}
