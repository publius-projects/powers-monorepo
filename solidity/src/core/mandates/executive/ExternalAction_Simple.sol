// SPDX-License-Identifier: MIT

/// @notice A base contract that executes a bespoke call to the powers contract's request function.
/// Especially useful if one Powers instance has to call a law at another powers instance.

pragma solidity ^0.8.26;

import { Mandate } from "@src/Mandate.sol";
import { MandateUtilities } from "@src/libraries/MandateUtilities.sol";
import { IPowers } from "@src/interfaces/IPowers.sol";

contract ExternalAction_Simple is Mandate {
    /// @notice Constructor of the BespokeAction_Simple mandate
    constructor(address registry_) Mandate(registry_) {
        bytes memory configParams =
            abi.encode("address PowersTarget", "uint16 MandateIdTarget", "string Description", "string[] Params");
        emit Mandate__Deployed(configParams);
    }

    function initializeMandate(uint16 index, string memory nameDescription, bytes memory, bytes memory config)
        public
        override
    {
        (,,, string[] memory params_) = abi.decode(config, (address, uint16, string, string[]));
        super.initializeMandate(index, nameDescription, abi.encode(params_), config);
    }

    /// @notice Execute the mandate by calling the configured target function
    /// @param mandateCalldata the calldata _without function signature_ to send to the function
    function handleRequest(
        address, /*caller*/
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
        (address powersTarget, uint16 mandateIdTarget, string memory description,) =
            abi.decode(getConfig(powers, mandateId), (address, uint16, string, string[]));
        actionId = MandateUtilities.computeActionId(mandateId, mandateCalldata, nonce);

        // Send the calldata to the target function
        (targets, values, calldatas) = MandateUtilities.createEmptyArrays(1);
        targets[0] = powersTarget;
        calldatas[0] = abi.encodeWithSelector(
            IPowers.request.selector,
            mandateIdTarget,
            mandateCalldata,
            nonce,
            description // this can be filled out at a later stage.
        );

        return (actionId, targets, values, calldatas);
    }
}
