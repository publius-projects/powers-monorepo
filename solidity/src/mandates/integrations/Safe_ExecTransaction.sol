// SPDX-License-Identifier: MIT
/// @notice A mandate to execute a transaction on a Gnosis Safe, assuming the Powers contract is an owner.
/// @dev This mandate uses the v=1 signature type, where the transaction executor (`msg.sender` to the Safe)
///      is an owner, thus providing its own approval by making the call.
/// @author 7Cedars

pragma solidity 0.8.26;

import { Mandate } from "../../Mandate.sol";
import { MandateUtilities } from "../../libraries/MandateUtilities.sol";
import { Safe } from "lib/safe-smart-account/contracts/Safe.sol";
import { Enum } from "lib/safe-smart-account/contracts/common/Enum.sol";
import { IPowers } from "../../interfaces/IPowers.sol";

contract Safe_ExecTransaction is Mandate {
    struct Mem {
        bytes data;
        address to;
        address target;
        bytes4 functionSelector;
        bytes configBytes;
        address safeAddress;
        bytes powersSignature;
    }

    // abi.encode("address TargetContract", "bytes4 FunctionSelector", "bytes paramsBefore", "string[] Params", "uint16 parentMandateId", "bytes paramsAfter");

    /// @notice Exposes the expected input parameters for UIs during deployment.
    constructor() {
        bytes memory configParams = abi.encode("string[] InputParams", "bytes4 FunctionSelector", "address Target");
        emit Mandate__Deployed(configParams);
    }

    function initializeMandate(uint16 index, string memory nameDescription, bytes memory, bytes memory config)
        public
        override
    {
        (string[] memory inputParamsRaw,,) = abi.decode(config, (string[], bytes4, address));
        super.initializeMandate(index, nameDescription, abi.encode(inputParamsRaw), config);
    }

    /// @notice Prepares a transaction to be executed by the configured Gnosis Safe.
    /// @dev This function decodes the internal transaction parameters from `mandateCalldata` and
    ///      constructs a `v=1` signature where `powers` is the designated signer.
    ///      This is valid only if the `powers` contract is an owner of the target Safe.
    /// @param mandateCalldata The ABI-encoded parameters for the internal Safe transaction:
    ///                    (address to, uint256 value, bytes data, Enum.Operation operation).
    /// @return actionId The unique action identifier.
    /// @return targets An array containing the Safe contract address.
    /// @return values An array containing 0, as no ETH is sent to the Safe directly.
    /// @return calldatas An array with the encoded `execTransaction` call for the Safe.
    function handleRequest(
        address, /*caller*/
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
        (, mem.functionSelector, mem.target) = abi.decode(getConfig(powers, mandateId), (string[], bytes4, address));
        mem.safeAddress = IPowers(powers).getTreasury();
        if (mem.safeAddress == address(0)) {
            revert("No Safe treasury set");
        }
        // Construct the `v=1` signature.
        // This is not a cryptographic signature but a signal to the Safe contract.
        // It indicates that the `msg.sender` of this transaction (the `powers` contract)
        // is an owner and is providing its own approval by executing the transaction.
        // r = address of the signer (powers contract)
        // s = 0
        // v = 1
        mem.powersSignature = abi.encodePacked(uint256(uint160(powers)), uint256(0), uint8(1));

        // Create the calldata for the `execTransaction` call that `Powers.fulfill` will execute.
        (targets, values, calldatas) = MandateUtilities.createEmptyArrays(1);
        targets[0] = mem.safeAddress;
        calldatas[0] = abi.encodeWithSelector(
            Safe.execTransaction.selector,
            mem.target, // The internal transaction's destination
            0, // The internal transaction's value in this mandate is always 0. To tansfer Eth use a different mandate.
            abi.encodePacked(mem.functionSelector, mandateCalldata), // The internal transaction's data
            Enum.Operation.Call, // The internal transaction's operation type
            0, // safeTxGas
            0, // baseGas
            0, // gasPrice
            address(0), // gasToken
            payable(0), // refundReceiver
            mem.powersSignature // The `v=1` signature
        );

        return (actionId, targets, values, calldatas);
    }
}
