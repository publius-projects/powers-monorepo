// SPDX-License-Identifier: MIT

/// @notice A base contract that executes a preset action.
///
/// The logic:
/// - the mandateCalldata includes an array of arrays of descriptions, targets, values and calldatas to be used in the calls.
/// - the mandateCalldata is decoded into an array of arrays of descriptions, targets, values and calldatas.
/// - the mandate shows an array of bool and their descriptions. Which ever one is set to true, will be executed.
///
/// @author 7Cedars,

pragma solidity 0.8.26;

import { Mandate } from "../../Mandate.sol";
import { MandateUtilities } from "../../libraries/MandateUtilities.sol";

contract PresetActions_OnOwnPowers is Mandate {
    struct Mem {
        uint256 i;
        uint256 j;
        bytes4[] functionSelectors;
        bytes[] callDatas;
        uint256[] valuesConfig;
        bytes[] calldatasConfig;
        uint256 length;
        bool[] bools;
    }

    /// @notice Constructor of the PresetActions_Multiple mandate
    constructor() {
        bytes memory configParams =
            abi.encode("bytes4 FunctionSelectors[]", "bytes[] callDatas[]");
        emit Mandate__Deployed(configParams);
    }

    function initializeMandate(
        uint16 index,
        string memory nameDescription,
        bytes memory inputParams,
        bytes memory config
    ) public override {
        // quick validation of config
        Mem memory mem;
        (mem.functionSelectors, mem.callDatas) = abi.decode(config, (bytes4[], bytes[]));
        if (mem.functionSelectors.length != mem.callDatas.length) {
            revert ("PresetActions_OnOwnPowers: invalid Config");
        }
 
        super.initializeMandate(index, nameDescription, inputParams, config);
    }

    /// @notice Execute the mandate by executing selected preset actions
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
        actionId = MandateUtilities.computeActionId(mandateId, mandateCalldata, nonce);
        (mem.functionSelectors, mem.callDatas) = abi.decode(getConfig(powers, mandateId), (bytes4[], bytes[]));

        (targets, values, calldatas) = MandateUtilities.createEmptyArrays(mem.callDatas.length);

        for (mem.i = 0; mem.i < mem.callDatas.length; mem.i++) {
            targets[mem.i] = powers;    
            calldatas[mem.i] = mem.callDatas[mem.i];
        }

        return (actionId, targets, values, calldatas);
    }
}
