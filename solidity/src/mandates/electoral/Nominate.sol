// SPDX-License-Identifier: MIT

/// @notice Allows a caller to nominate or revoke their nomination in a Nominees contract.
/// @dev The deployer configures the Nominees contract address. The caller provides a boolean
/// to either nominate themselves (true) or revoke their nomination (false).
/// @author 7Cedars

pragma solidity 0.8.26;

import { Mandate } from "../../Mandate.sol";
import { MandateUtilities } from "../../libraries/MandateUtilities.sol";
import { Nominees } from "../../helpers/Nominees.sol";

contract Nominate is Mandate {
    /// @notice Constructor for Nominate mandate
    constructor() {
        bytes memory configParams = abi.encode("address NomineesContract");
        emit Mandate__Deployed(configParams);
    }

    function initializeMandate(
        uint16 index,
        string memory nameDescription,
        bytes memory inputParams,
        bytes memory config
    ) public override {
        inputParams = abi.encode("bool shouldNominate");
        super.initializeMandate(index, nameDescription, inputParams, config);
    }

    /// @notice Build a call to nominate or revoke nomination for the caller
    /// @param caller The transaction originator (will be nominated/revoked)
    /// @param powers The Powers contract address
    /// @param mandateId The mandate identifier
    /// @param mandateCalldata Encoded boolean (true = nominate, false = revoke)
    /// @param nonce Unique nonce to build the action id
    function handleRequest(
        address caller,
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
        (bool shouldNominate) = abi.decode(mandateCalldata, (bool));
        actionId = MandateUtilities.computeActionId(mandateId, mandateCalldata, nonce);

        (targets, values, calldatas) = MandateUtilities.createEmptyArrays(1);
        targets[0] = abi.decode(getConfig(powers, mandateId), (address)); // Nominees contract address
        calldatas[0] = abi.encodeWithSelector(Nominees.nominate.selector, caller, shouldNominate);

        return (actionId, targets, values, calldatas);
    }
}
