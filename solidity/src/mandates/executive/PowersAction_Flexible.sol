// SPDX-License-Identifier: MIT

/// @notice This mandate allows for flexible execution of any target mandate at another Powers instance.
/// Note that Powers needs to have to correct roleID to be allowed to call the target mandate at the target Powers instance. 
/// Also note that the params are set, as such the mandate can only be used to call target functions with the same params.

pragma solidity 0.8.26;

import { Mandate } from "../../Mandate.sol";
import { MandateUtilities } from "../../libraries/MandateUtilities.sol";
import { IPowers } from "../../interfaces/IPowers.sol";

contract PowersAction_Flexible is Mandate {
    /// @notice Constructor of the BespokeAction_Simple mandate
    constructor() {
        bytes memory configParams = abi.encode("string[] Params");
        emit Mandate__Deployed(configParams);
    }

    function initializeMandate(
        uint16 index,
        string memory nameDescription,
        bytes memory inputParams,
        bytes memory config
    ) public override {
        (string[] memory params_) = abi.decode(config, (string[]));
        string[] memory newParams_ = new string[](params_.length + 2);
        newParams_[0] = "address PowersTarget";
        newParams_[1] = "uint16 MandateIdTarget";
        for (uint256 i = 0; i < params_.length; i++) {
            newParams_[i + 2] = params_[i];
        }
        super.initializeMandate(index, nameDescription, abi.encode(newParams_), config);
    }

    /// @notice Execute the mandate by calling the configured target function
    /// @param mandateCalldata the calldata _without function signature_ to send to the function
    function handleRequest(
        address, /*caller*/
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
        (address powersTarget, uint16 mandateIdTarget, bytes memory callData) =
            abi.decode(mandateCalldata, (address, uint16, bytes));
        actionId = MandateUtilities.computeActionId(mandateId, mandateCalldata, nonce);

        // Send the calldata to the target function
        (targets, values, calldatas) = MandateUtilities.createEmptyArrays(1);
        targets[0] = powersTarget;
        calldatas[0] = abi.encodeWithSelector(
            IPowers.request.selector,
            mandateIdTarget,
            callData,
            nonce,
            "" // this can be filled out at a later stage.
        );

        return (actionId, targets, values, calldatas);
    }
}
