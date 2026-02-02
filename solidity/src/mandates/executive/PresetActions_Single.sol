// SPDX-License-Identifier: MIT

/// @notice A base contract that executes a preset action.
///
/// The logic:
/// - the mandateCalldata includes a single bool. If the bool is set to true, it will send the preset calldatas to the execute function of the Powers protocol.
///
/// @author 7Cedars,

pragma solidity 0.8.26;

import { Mandate } from "../../Mandate.sol";
import { MandateUtilities } from "../../libraries/MandateUtilities.sol";

contract PresetActions_Single is Mandate {
    /// @notice Constructor of the PresetActions_Single mandate
    constructor() {
        bytes memory configParams = abi.encode("address[] targets", "uint256[] values", "bytes[] calldatas");
        emit Mandate__Deployed(configParams);
    }

    /// @notice Execute the mandate by returning the preset action data
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
        (targets, values, calldatas) = abi.decode(getConfig(powers, mandateId), (address[], uint256[], bytes[]));
        actionId = MandateUtilities.computeActionId(mandateId, mandateCalldata, nonce);

        return (actionId, targets, values, calldatas);
    }
}
