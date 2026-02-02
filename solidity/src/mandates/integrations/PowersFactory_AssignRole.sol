// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import { Mandate } from "../../Mandate.sol";
import { MandateUtilities } from "../../libraries/MandateUtilities.sol";
import { IPowers } from "../../interfaces/IPowers.sol";
import { PowersTypes } from "../../interfaces/PowersTypes.sol";

contract PowersFactory_AssignRole is Mandate {
    struct Mem {
        bytes config;
        uint16 factoryMandateId;
        uint256 parentActionId;
        uint256 roleIdNewOrg;
        bytes returnData;
        address decodedAddress;
    }

    constructor() {
        bytes memory configParams =
            abi.encode("uint16 factoryMandateId", "uint256 roleIdNewOrg", "string[] inputParams");
        emit Mandate__Deployed(configParams);
    }

    function initializeMandate(
        uint16 index,
        string memory nameDescription,
        bytes memory inputParams,
        bytes memory config
    ) public override {
        // Decode the config to get the input params description string
        (,, string[] memory inputParamsDescription) = abi.decode(config, (uint16, uint256, string[]));

        super.initializeMandate(index, nameDescription, abi.encode(inputParamsDescription), config);
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
        Mem memory mem;

        // 1. Get config
        mem.config = getConfig(powers, mandateId);
        (mem.factoryMandateId, mem.roleIdNewOrg,) = abi.decode(mem.config, (uint16, uint256, string[]));

        // 2. Compute current actionId
        actionId = MandateUtilities.computeActionId(mandateId, mandateCalldata, nonce);
        mem.parentActionId = MandateUtilities.computeActionId(mem.factoryMandateId, mandateCalldata, nonce);

        if (IPowers(powers).getActionState(mem.parentActionId) != PowersTypes.ActionState.Fulfilled) {
            revert("Invalid parent action state");
        }

        // 5. Check return value in Powers
        // If the action hasn't been fulfilled or has no return data, this will revert (index out of bounds)
        // or return empty bytes if that was the return value.
        try IPowers(powers).getActionReturnData(mem.parentActionId, 0) returns (bytes memory returnData_) {
            mem.returnData = returnData_;
        } catch {
            revert("Error fetching return data for parent action");
        }
        if (mem.returnData.length == 0) {
            revert("Empty return data from parent action");
        }

        // 6. Decode address from return data
        mem.decodedAddress = abi.decode(mem.returnData, (address));

        (targets, values, calldatas) = MandateUtilities.createEmptyArrays(1);
        targets[0] = powers;
        calldatas[0] = abi.encodeWithSelector(IPowers.assignRole.selector, mem.roleIdNewOrg, mem.decodedAddress);

        return (actionId, targets, values, calldatas);
    }
}
