// SPDX-License-Identifier: MIT

/// @notice A base contract that executes a bespoke action.
///
/// Note 1: as of now, it only allows for a single function to be called.
/// Note 2: as of now, it does not allow sending of ether values to the target function.
///
/// @author 7Cedars,

pragma solidity 0.8.26;

import { Mandate } from "../../Mandate.sol";
import { MandateUtilities } from "../../libraries/MandateUtilities.sol";

contract BespokeAction_Simple is Mandate {
    /// @notice Constructor of the BespokeAction_Simple mandate
    constructor() {
        bytes memory configParams = abi.encode("address TargetContract", "bytes4 FunctionSelector", "string[] Params");
        emit Mandate__Deployed(configParams);
    }

    function initializeMandate(
        uint16 index,
        string memory nameDescription,
        bytes memory inputParams,
        bytes memory config
    ) public override {
        (,, string[] memory params_) = abi.decode(config, (address, bytes4, string[]));
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
        (address targetContract, bytes4 targetFunction,) =
            abi.decode(getConfig(powers, mandateId), (address, bytes4, string[]));
        actionId = MandateUtilities.computeActionId(mandateId, mandateCalldata, nonce);

        // Send the calldata to the target function
        (targets, values, calldatas) = MandateUtilities.createEmptyArrays(1);
        targets[0] = targetContract;
        calldatas[0] = abi.encodePacked(targetFunction, mandateCalldata);

        return (actionId, targets, values, calldatas);
    }
}
