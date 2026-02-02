// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import { Mandate } from "../../Mandate.sol";
import { MandateUtilities } from "../../libraries/MandateUtilities.sol";
import { Safe } from "lib/safe-smart-account/contracts/Safe.sol";
import { IPowers } from "../../interfaces/IPowers.sol";

// import { console2 } from "forge-std/console2.sol"; // only for testing/debugging

contract SafeAllowance_Action is Mandate {
    /// @dev Configurations for this mandate adoption.
    struct ConfigData {
        bytes4 functionSelector;
        address allowanceModule;
    }

    /// @dev Mapping mandate hash => configuration.
    mapping(bytes32 mandateHash => ConfigData data) public mandateConfig;

    /// @notice Constructor function
    constructor() {
        // Expose expected input parameters for UIs.
        bytes memory configParams =
            abi.encode("string[] inputParams", "bytes4 functionSelector", "address allowanceModule");
        emit Mandate__Deployed(configParams);
    }

    function initializeMandate(
        uint16 index,
        string memory nameDescription,
        bytes memory inputParams,
        bytes memory config
    ) public override {
        bytes32 mandateHash_ = MandateUtilities.hashMandate(msg.sender, index);
        string[] memory inputParamsArray;

        (
            inputParamsArray, mandateConfig[mandateHash_].functionSelector, mandateConfig[mandateHash_].allowanceModule
        ) = abi.decode(config, (string[], bytes4, address));

        // Overwrite inputParams with the specific structure expected by handleRequest
        inputParams = abi.encode(inputParamsArray);

        super.initializeMandate(index, nameDescription, inputParams, config);
    }

    /// @notice Prepares the call to the Allowance Module
    /// @param mandateCalldata The calldata containing token, to, amount, delegate
    /// @return actionId The unique action identifier
    /// @return targets Array of target contract addresses
    /// @return values Array of ETH values to send
    /// @return calldatas Array of calldata for each call
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
        actionId = MandateUtilities.computeActionId(mandateId, mandateCalldata, nonce);
        bytes32 mandateHash_ = MandateUtilities.hashMandate(powers, mandateId);
        ConfigData memory config = mandateConfig[mandateHash_];
        address safeProxyAddress = IPowers(powers).getTreasury();
        if (safeProxyAddress == address(0)) {
            revert("SafeAllowance_Action: Treasury not set in Powers");
        }

        // (address delegateAddress) = abi.decode(mandateCalldata, (address));

        // Construct the `v=1` signature.
        // This indicatesa) = abi.decode(mandateCalldata) = abi.decode(mandateCalldat that the `msg.sender` of this transaction (the `powers` contract)
        // is the delegate providing the approval by executing the transaction.
        // r = address of the signer (powers contract)
        // s = 0
        // v = 1
        bytes memory powersSignature = abi.encodePacked(uint256(uint160(powers)), uint256(0), uint8(1));

        (targets, values, calldatas) = MandateUtilities.createEmptyArrays(1);
        // NB: We call the execTransaction function in our SafeL2 proxy to make the call to the Allowance Module.
        targets[0] = safeProxyAddress;
        calldatas[0] = abi.encodeWithSelector(
            Safe.execTransaction.selector,
            config.allowanceModule, // The internal transaction's destination: the Allowance Module.
            0, // The internal transaction's value in this mandate is always 0. To transfer Eth use a different mandate.
            abi.encodePacked(config.functionSelector, mandateCalldata),
            0, // operation = Call
            0, // safeTxGas
            0, // baseGas
            0, // gasPrice
            address(0), // gasToken
            address(0), // refundReceiver
            powersSignature // the signature constructed above
        );

        return (actionId, targets, values, calldatas);
    }
}
