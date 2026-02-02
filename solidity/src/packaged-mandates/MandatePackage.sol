// SPDX-License-Identifier: MIT

/// @notice An example implementation of a Mandate Package that adopts multiple mandates into the Powers protocol.
/// @dev It is meant to be adopted through the Mandates_Adopt mandate, and then be executed to adopt multiple mandates in a single transaction.
/// @dev The mandate self-destructs after execution.
///
/// @author 7Cedars

// £todo: make this package more generic, allowing for any set of mandates to be adopted in a package.
// make configParams accept raw mandate Initdatas. That is the easiest way to set it up.
// But watch out : the mandateCounter needs to be passed correctly to the getNewMandates function.
// maybe the approach below is the only possible one?

pragma solidity 0.8.26;

import { Mandate } from "../Mandate.sol";
import { MandateUtilities } from "../libraries/MandateUtilities.sol";
import { IPowers } from "../interfaces/IPowers.sol";
import { Powers } from "../Powers.sol";
import { PowersTypes } from "../interfaces/PowersTypes.sol";

contract MandatePackage is Mandate {
    address[] private sMandateAddresses;

    // in this case mandateAddresses should be [openAction, statementOfIntent] -- we only need those two mandates for this package.
    constructor(address[] memory mandateAddresses) {
        sMandateAddresses = mandateAddresses;
        emit Mandate__Deployed(abi.encode());
    }

    function initializeMandate(
        uint16 index,
        string memory nameDescription,
        bytes memory inputParams,
        bytes memory config
    ) public override {
        inputParams = abi.encode();
        super.initializeMandate(index, nameDescription, inputParams, config);
    }

    /// @notice Build calls to adopt the configured mandates
    /// @param mandateCalldata Unused for this mandate
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
        actionId = MandateUtilities.computeActionId(mandateId, mandateCalldata, nonce);
        uint16 mandateCount = Powers(powers).mandateCounter();
        PowersTypes.MandateInitData[] memory smandateInitData = getNewMandates(sMandateAddresses, powers, mandateCount);

        // Create arrays for the calls to adoptMandate
        uint256 length = smandateInitData.length;
        (targets, values, calldatas) = MandateUtilities.createEmptyArrays(length + 1);
        for (uint256 i; i < length; i++) {
            targets[i] = powers;
            calldatas[i] = abi.encodeWithSelector(IPowers.adoptMandate.selector, smandateInitData[i]);
        }
        // Final call to self-destruct the MandatePackage after adopting the mandates
        targets[length] = powers;
        calldatas[length] = abi.encodeWithSelector(IPowers.revokeMandate.selector, mandateId);
        return (actionId, targets, values, calldatas);
    }

    /// @notice Generates MandateInitData for a set of new mandates to be adopted.
    /// @param mandateAddresses The addresses of the mandates to be adopted.
    // / @param powers The address of the Powers contract.
    /// @return mandateInitData An array of MandateInitData structs for the new mandates.
    /// @dev the function follows the same pattern as TestConstitutions.sol
    /// this function can be overwritten to create different mandate packages.
    function getNewMandates(
        address[] memory mandateAddresses,
        address,
        /* powers */
        uint16 mandateCount
    )
        public
        view
        virtual
        returns (PowersTypes.MandateInitData[] memory mandateInitData)
    {
        mandateInitData = new PowersTypes.MandateInitData[](3);
        PowersTypes.Conditions memory conditions;

        // statementOfIntent params
        string[] memory inputParams = new string[](3);
        inputParams[0] = "address[] Targets";
        inputParams[1] = "uint256[] Values";
        inputParams[2] = "bytes[] Calldatas";

        conditions.allowedRole = 1; // = role that can call this mandate.
        conditions.quorum = 20; // = 30% quorum needed
        conditions.succeedAt = 66; // = 51% simple majority needed for assigning and revoking members.
        conditions.votingPeriod = 1200; // = number of blocks
        mandateInitData[0] = PowersTypes.MandateInitData({
            nameDescription: "StatementOfIntent: Propose any kind of action.",
            targetMandate: mandateAddresses[1], // statementOfIntent
            config: abi.encode(inputParams),
            conditions: conditions
        });
        delete conditions;

        conditions.allowedRole = 0; // = admin.
        conditions.needFulfilled = mandateCount; // = mandate that must be completed before this one.
        mandateInitData[1] = PowersTypes.MandateInitData({
            nameDescription: "Veto an action: Veto an action that has been proposed by the community.",
            targetMandate: mandateAddresses[1], // statementOfIntent
            config: abi.encode(inputParams),
            conditions: conditions
        });
        delete conditions;

        conditions.allowedRole = 2; // = role that can call this mandate.
        conditions.votingPeriod = 1200; // = number of blocks
        conditions.succeedAt = 66; // = 51% simple majority needed for executing an action.
        conditions.quorum = 20; // = 30% quorum needed
        conditions.needFulfilled = mandateCount; // = mandate that must be completed before this one.
        conditions.needNotFulfilled = mandateCount + 1; // = mandate that must not be completed before this one.
        mandateInitData[2] = PowersTypes.MandateInitData({
            nameDescription: "Execute an action: Execute an action that has been proposed by the community and should not have been vetoed by an admin.",
            targetMandate: mandateAddresses[0], // openAction.
            config: abi.encode(), // empty config.
            conditions: conditions
        });
        delete conditions;
    }
}
