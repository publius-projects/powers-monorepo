// SPDX-License-Identifier: MIT

/// @notice This contract assigns accounts to roles based on their tax payments in a specified ERC20 token.
/// - At construction time, the following is set:
///    - the ERC20 taxed token address to be assessed
///    - the threshold amount of tax that needs to be paid
///    - the roleId to be assigned
///
/// - The logic:
///    - The calldata holds the account that needs to be assessed.
///    - If the account has paid more tax than the threshold in the previous epoch, it is assigned the role.
///    - If the account has paid less tax than the threshold in the previous epoch, its role is revoked.
///    - If there is no previous epoch, the operation reverts.
///
/// @dev The contract is an example of a mandate that:
/// - does not need a proposal to be voted through; it can be called directly
/// - has a simple tax-based role assignment mechanism
/// - does not have to be role-restricted
/// - translates tax payments to role assignments
/// - can be extended to include more complex tax-based role assignment mechanisms

/// @author 7Cedars
pragma solidity 0.8.26;

import { Mandate } from "../../Mandate.sol"; 
import { IPowers } from "../../interfaces/IPowers.sol";
import { MandateUtilities } from "../../libraries/MandateUtilities.sol";
import { Erc20Taxed } from "@mocks/Erc20Taxed.sol";

// import "forge-std/Test.sol"; // only for testing

contract TaxSelect is Mandate {
    struct Mem {
        // address erc20Taxed;
        // uint256 thresholdTaxPaid;
        // uint256 roleIdToSet;
        bytes configBytes;
        address account;
        uint48 epochDuration;
        uint48 currentEpoch;
        bool hasRole;
        uint256 taxPaid;
        address erc20TaxedMock;
        uint256 thresholdTaxPaid;
        uint256 roleIdToSet;
    }

    /// @notice Constructor for TaxSelect mandate
    constructor() {
        bytes memory configParams =
            abi.encode("address erc20TaxedMock", "uint256 thresholdTaxPaid", "uint256 roleIdToSet");
        emit Mandate__Deployed(configParams);
    }

    /// @notice Initializes the mandate with its configuration parameters
    /// @param index The index of the mandate in the DAO
    /// @param nameDescription The description of the mandate
    /// @param config The configuration parameters (erc20Taxed, thresholdTaxPaid, roleIdToSet)
    function initializeMandate(
        uint16 index,
        string memory nameDescription,
        bytes memory inputParams,
        bytes memory config
    ) public override {
        inputParams = abi.encode("address Account");
        super.initializeMandate(index, nameDescription, inputParams, config);
    }

    /// @notice Handles the request to assign or revoke a role based on tax payments
    //
    /// @param powers The address of the Powers contract
    /// @param mandateId The ID of the mandate
    /// @param mandateCalldata The calldata containing the account to assess
    /// @param nonce The nonce for the action
    /// @return actionId The ID of the action
    /// @return targets The target addresses for the action
    /// @return values The values for the action
    /// @return calldatas The calldatas for the action
    function handleRequest(
        address,
        /* caller */
        address powers,
        uint16 mandateId,
        bytes memory mandateCalldata,
        uint256 nonce
    )
        public
        view
        virtual
        override
        returns (uint256 actionId, address[] memory targets, uint256[] memory values, bytes[] memory calldatas)
    {
        Mem memory mem;
        mem.configBytes = getConfig(powers, mandateId);
        // step 0: create actionId & decode the calldata
        actionId = MandateUtilities.computeActionId(mandateId, mandateCalldata, nonce);
        (mem.account) = abi.decode(mandateCalldata, (address));
        (mem.erc20TaxedMock, mem.thresholdTaxPaid, mem.roleIdToSet) =
            abi.decode(getConfig(powers, mandateId), (address, uint256, uint256)); // silence solc warning

        // step 1: retrieve data
        mem.epochDuration = Erc20Taxed(mem.erc20TaxedMock).EPOCH_DURATION();
        mem.currentEpoch = uint48(block.number) / mem.epochDuration;

        if (mem.currentEpoch == 0) {
            revert("No finished epoch yet.");
        }

        // step 2: retrieve data on tax paid and role
        mem.hasRole = IPowers(payable(powers)).hasRoleSince(mem.account, mem.roleIdToSet) > 0;
        // console.log("mem.hasRole", mem.hasRole);
        mem.taxPaid = Erc20Taxed(mem.erc20TaxedMock).getTaxLogs(uint48(block.number) - mem.epochDuration, mem.account);
        // console.log("mem.taxPaid", mem.taxPaid);

        (targets, values, calldatas) = MandateUtilities.createEmptyArrays(1);
        targets[0] = powers;

        // step 3: create arrays
        if (mem.hasRole && mem.taxPaid < mem.thresholdTaxPaid) {
            // console.log("revoking role");
            calldatas[0] = abi.encodeWithSelector(IPowers.revokeRole.selector, mem.roleIdToSet, mem.account);
        } else if (!mem.hasRole && mem.taxPaid >= mem.thresholdTaxPaid) {
            // console.log("assigning role");
            calldatas[0] = abi.encodeWithSelector(IPowers.assignRole.selector, mem.roleIdToSet, mem.account);
        }

        // step 4: return data
        return (actionId, targets, values, calldatas);
    }
}
