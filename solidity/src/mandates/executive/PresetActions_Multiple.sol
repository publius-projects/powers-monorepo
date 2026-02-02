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

contract PresetActions_Multiple is Mandate {
    struct Mem {
        uint256 i;
        uint256 j;
        bytes configBytes;
        address[] targetsConfig;
        uint256[] valuesConfig;
        bytes[] calldatasConfig;
        uint256 length;
        bool[] bools;
    }

    /// @notice Constructor of the PresetActions_Multiple mandate
    constructor() {
        bytes memory configParams =
            abi.encode("string[] descriptions", "address[] targets", "uint256[] values", "bytes[] calldatas");
        emit Mandate__Deployed(configParams);
    }

    function initializeMandate(
        uint16 index,
        string memory nameDescription,
        bytes memory inputParams,
        bytes memory config
    ) public override {
        (string[] memory descriptions,,,) = abi.decode(config, (string[], address[], uint256[], bytes[]));

        string[] memory parameters = new string[](descriptions.length);
        for (uint256 i = 0; i < parameters.length; i++) {
            parameters[i] = string.concat("bool ", descriptions[i]);
        }

        super.initializeMandate(index, nameDescription, abi.encode(parameters), config);
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
        mem.configBytes = getConfig(powers, mandateId);
        (, mem.targetsConfig, mem.valuesConfig, mem.calldatasConfig) =
            abi.decode(mem.configBytes, (string[], address[], uint256[], bytes[]));

        mem.bools = abi.decode(mandateCalldata, (bool[]));
        mem.length = 0;
        for (mem.i = 0; mem.i < mem.bools.length; mem.i++) {
            if (mem.bools[mem.i]) {
                mem.length++;
            }
        }
        if (mem.length == 0) {
            (targets, values, calldatas) = MandateUtilities.createEmptyArrays(1);
            return (actionId, targets, values, calldatas);
        }

        (targets, values, calldatas) = MandateUtilities.createEmptyArrays(mem.length);
        mem.j = 0;
        for (mem.i = 0; mem.i < mem.bools.length; mem.i++) {
            if (mem.bools[mem.i]) {
                targets[mem.j] = mem.targetsConfig[mem.i];
                values[mem.j] = mem.valuesConfig[mem.i];
                calldatas[mem.j] = mem.calldatasConfig[mem.i];
                mem.j++;
            }
        }

        return (actionId, targets, values, calldatas);
    }
}
