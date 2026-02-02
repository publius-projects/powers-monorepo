// SPDX-License-Identifier: MIT

/// @notice A package mandate that adopts multiple mandates into the Powers protocol.
/// mandateInitData for the new mandates is defined at cons
/// @author 7Cedars

pragma solidity 0.8.26;

import { Mandate } from "../Mandate.sol";
import { MandateUtilities } from "../libraries/MandateUtilities.sol";
import { IPowers } from "../interfaces/IPowers.sol";
import { Powers } from "../Powers.sol";
import { PowersTypes } from "../interfaces/PowersTypes.sol";

contract ReformMandate_Static is Mandate {
    PowersTypes.MandateInitData[] smandateInitData;

    // in this case mandateAddresses should be [openAction, statementOfIntent] -- we only need those two mandates for this package.
    constructor(PowersTypes.MandateInitData[] memory mandateInitData) {
        for (uint256 i = 0; i < mandateInitData.length; i++) {
            smandateInitData.push(mandateInitData[i]);
        }
        emit Mandate__Deployed(abi.encode());
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
}
