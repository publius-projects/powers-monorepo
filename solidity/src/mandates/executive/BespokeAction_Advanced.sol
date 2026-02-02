// SPDX-License-Identifier: MIT

/// @notice A base contract that executes a bespoke action with a single function call.
/// @author 7Cedars,

pragma solidity 0.8.26;

import { Mandate } from "../../Mandate.sol";
import { MandateUtilities } from "../../libraries/MandateUtilities.sol";

// import { console } from "forge-std/console.sol"; // only for testing purposes.

contract BespokeAction_Advanced is Mandate {
    struct Mem {
        address targetContract;
        bytes4 targetFunction;
        bytes staticParamsBefore;
        string[] dynamicParams;
        bytes staticParamsAfter;
        uint256 staticLen;
        bytes packedParams;
    }

    /// @notice Constructor of the BespokeAction_Advanced mandate
    constructor() {
        bytes memory configParams = abi.encode(
            "address TargetContract",
            "bytes4 TargetFunction",
            "bytes staticParamsBefore",
            "string[] dynamicParams",
            "bytes staticParamsAfter"
        );
        emit Mandate__Deployed(configParams);
    }

    function initializeMandate(
        uint16 index,
        string memory nameDescription,
        bytes memory inputParams,
        bytes memory config
    ) public override {
        Mem memory mem;
        (,,, mem.dynamicParams,) = abi.decode(config, (address, bytes4, bytes, string[], bytes));
        super.initializeMandate(index, nameDescription, abi.encode(mem.dynamicParams), config);
    }

    /// @notice Execute the mandate by calling the configured target function with mixed static/dynamic parameters
    /// @param mandateCalldata the calldata containing dynamic parameters to insert into the function call
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
        Mem memory mem;

        (mem.targetContract, mem.targetFunction, mem.staticParamsBefore,, mem.staticParamsAfter) =
            abi.decode(getConfig(powers, mandateId), (address, bytes4, bytes, string[], bytes));
        actionId = MandateUtilities.computeActionId(mandateId, mandateCalldata, nonce);

        // Send the calldata to the target function
        (targets, values, calldatas) = MandateUtilities.createEmptyArrays(1);
        targets[0] = mem.targetContract;
        calldatas[0] =
            abi.encodePacked(mem.targetFunction, mem.staticParamsBefore, mandateCalldata, mem.staticParamsAfter);

        return (actionId, targets, values, calldatas);
    }
}
