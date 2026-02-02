// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

/// @notice A mandate that retrieves return data of a previous mandate call, and uses the return value for its own call.
/// parameters set before and after the return data can be specified.
/// @author 7Cedars,

import { Mandate } from "../../Mandate.sol";
import { MandateUtilities } from "../../libraries/MandateUtilities.sol";
import { IPowers } from "../../interfaces/IPowers.sol";

contract BespokeAction_OnReturnValue is Mandate {
    /// @notice Constructor of the BespokeAction_Simple mandate
    constructor() {
        bytes memory configParams = abi.encode(
            "address TargetContract",
            "bytes4 FunctionSelector",
            "bytes paramsBefore",
            "string[] Params",
            "uint16 parentMandateId",
            "bytes paramsAfter"
        );
        emit Mandate__Deployed(configParams);
    }

    function initializeMandate(
        uint16 index,
        string memory nameDescription,
        bytes memory inputParams,
        bytes memory config
    ) public override {
        (,,, string[] memory params_,,) = abi.decode(config, (address, bytes4, bytes, string[], uint16, bytes));
        super.initializeMandate(index, nameDescription, abi.encode(params_), config);
    }

    /// @notice Execute the mandate by calling the configured target function
    /// @param mandateCalldata the calldata _without function signature_ to send to the function
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
        virtual
        override
        returns (uint256 actionId, address[] memory targets, uint256[] memory values, bytes[] memory calldatas)
    {
        (
            address targetContract,
            bytes4 targetFunction,
            bytes memory paramsBefore,,
            uint16 parentMandateId,
            bytes memory paramsAfter
        ) = abi.decode(getConfig(powers, mandateId), (address, bytes4, bytes, string[], uint16, bytes));
        actionId = MandateUtilities.computeActionId(mandateId, mandateCalldata, nonce);
        uint256 parentActionId = MandateUtilities.computeActionId(parentMandateId, mandateCalldata, nonce);
        bytes memory returnData = IPowers(powers).getActionReturnData(parentActionId, 0);

        // Send the calldata to the target function
        (targets, values, calldatas) = MandateUtilities.createEmptyArrays(1);
        targets[0] = targetContract;
        calldatas[0] = abi.encodePacked(targetFunction, paramsBefore, returnData, paramsAfter);

        return (actionId, targets, values, calldatas);
    }
}
