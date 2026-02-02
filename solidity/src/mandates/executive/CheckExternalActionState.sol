// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import { Mandate } from "../../Mandate.sol";
import { MandateUtilities } from "../../libraries/MandateUtilities.sol";
import { PowersTypes } from "../../interfaces/PowersTypes.sol";
import { IPowers } from "../../interfaces/IPowers.sol";

contract CheckExternalActionState is Mandate {
    struct Mem {
        bytes configBytes;
        address parentPowers;
        uint16 configMandateId;
        uint256 remoteActionId;
    }

    constructor() {
        bytes memory configParams = abi.encode("address parentPowers", "uint16 mandateId", "string[] inputParams");
        emit Mandate__Deployed(configParams);
    }

    function initializeMandate(uint16 index, string memory nameDescription, bytes memory, bytes memory config)
        public
        override
    {
        (,, string[] memory inputParams_) = abi.decode(config, (address, uint16, string[]));
        super.initializeMandate(index, nameDescription, abi.encode(inputParams_), config);
    }

    function handleRequest(
        address, /*caller*/
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
        Mem memory mem;
        mem.configBytes = getConfig(powers, mandateId);
        (mem.parentPowers, mem.configMandateId,) = abi.decode(mem.configBytes, (address, uint16, string[]));

        mem.remoteActionId = MandateUtilities.computeActionId(mem.configMandateId, mandateCalldata, nonce);
        PowersTypes.ActionState state = IPowers(mem.parentPowers).getActionState(mem.remoteActionId);
        if (state != PowersTypes.ActionState.Fulfilled) {
            revert("Action not fulfilled");
        }

        (targets, values, calldatas) = MandateUtilities.createEmptyArrays(1);
        return (actionId, targets, values, calldatas);
    }
}
