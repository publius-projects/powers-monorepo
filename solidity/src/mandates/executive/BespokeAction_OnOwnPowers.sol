// SPDX-License-Identifier: MIT

/// @notice A base contract that executes a bespoke action on its own powers contract.
/// @author 7Cedars,

pragma solidity 0.8.26;

import { Mandate } from "../../Mandate.sol";
import { MandateUtilities } from "../../libraries/MandateUtilities.sol";

contract BespokeAction_OnOwnPowers is Mandate {
    /// @notice Constructor of the BespokeAction_OnOwnPowers mandate
    constructor() {
        bytes memory configParams = abi.encode("bytes4 FunctionSelector", "string[] Params");
        emit Mandate__Deployed(configParams);
    }

    function initializeMandate(
        uint16 index,
        string memory nameDescription,
        bytes memory inputParams,
        bytes memory config
    ) public override {
        (, string[] memory params_) = abi.decode(config, (bytes4, string[]));
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
        (bytes4 targetFunction,) = abi.decode(getConfig(powers, mandateId), (bytes4, string[]));
        actionId = MandateUtilities.computeActionId(mandateId, mandateCalldata, nonce);

        // Send the calldata to the target function
        (targets, values, calldatas) = MandateUtilities.createEmptyArrays(1);
        targets[0] = powers;
        calldatas[0] = abi.encodePacked(targetFunction, mandateCalldata);

        return (actionId, targets, values, calldatas);
    }
}
