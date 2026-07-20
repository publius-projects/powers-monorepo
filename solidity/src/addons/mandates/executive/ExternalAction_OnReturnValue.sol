// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

/// @notice A mandate that retrieves return data of a previous mandate call and uses it to
/// flexibly call a mandate at an external Powers instance. PowersTarget and MandateIdTarget
/// are provided at execution time; paramsBefore/paramsAfter are set in config.
/// @author 7Cedars

import { Mandate } from "@src/Mandate.sol";
import { MandateUtilities } from "@src/libraries/MandateUtilities.sol";
import { IPowers } from "@src/interfaces/IPowers.sol";

contract ExternalAction_OnReturnValue is Mandate {
    constructor(address registry_) Mandate(registry_) {
        bytes memory configParams =
            abi.encode("bytes paramsBefore", "string[] Params", "uint16 parentMandateId", "bytes paramsAfter");
        emit Mandate__Deployed(configParams);
    }

    function initializeMandate(uint16 index, string memory nameDescription, bytes memory, bytes memory config)
        public
        override
    {
        (, string[] memory params_,,) = abi.decode(config, (bytes, string[], uint16, bytes));
        string[] memory newParams_ = new string[](params_.length + 2);
        newParams_[0] = "address PowersTarget";
        newParams_[1] = "uint16 MandateIdTarget";
        for (uint256 i = 0; i < params_.length; i++) {
            newParams_[i + 2] = params_[i];
        }
        super.initializeMandate(index, nameDescription, abi.encode(newParams_), config);
    }

    /// @notice Execute the mandate by forwarding the parent mandate's return value to an external Powers instance
    /// @param mandateCalldata abi.encoded (address PowersTarget, uint16 MandateIdTarget)
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
        (bytes memory paramsBefore,, uint16 parentMandateId, bytes memory paramsAfter) =
            abi.decode(getConfig(powers, mandateId), (bytes, string[], uint16, bytes));

        (address powersTarget, uint16 mandateIdTarget) = abi.decode(mandateCalldata, (address, uint16));

        actionId = MandateUtilities.computeActionId(mandateId, mandateCalldata, nonce);
        uint256 parentActionId = MandateUtilities.computeActionId(parentMandateId, mandateCalldata, nonce);
        bytes memory returnData = IPowers(payable(powers)).getActionReturnData(parentActionId, 0);

        (targets, values, calldatas) = MandateUtilities.createEmptyArrays(1);
        targets[0] = powersTarget;
        calldatas[0] = abi.encodeWithSelector(
            IPowers.request.selector,
            mandateIdTarget,
            abi.encodePacked(paramsBefore, returnData, paramsAfter),
            nonce,
            "" // description can be filled in at a later stage
        );

        return (actionId, targets, values, calldatas);
    }
}
