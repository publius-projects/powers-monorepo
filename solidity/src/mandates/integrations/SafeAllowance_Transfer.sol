// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import { Mandate } from "../../Mandate.sol";
import { MandateUtilities } from "../../libraries/MandateUtilities.sol";
import { Enum } from "lib/safe-smart-account/contracts/common/Enum.sol";

// import { console2 } from "forge-std/console2.sol"; // only for testing/debugging

// The ISafe interface is declared in AllowanceModule.sol, but cannot be directly imported due to version conflicts.
interface ISafe {
    /// @dev Allows a Module to execute a Safe transaction without any further confirmations.
    /// @param to Destination address of module transaction.
    /// @param value Ether value of module transaction.
    /// @param data Data payload of module transaction.
    /// @param operation Operation type of module transaction.
    function execTransactionFromModule(address to, uint256 value, bytes calldata data, Enum.Operation operation)
        external
        returns (bool success);
}

contract SafeAllowance_Transfer is Mandate {
    struct Mem {
        bytes32 mandateHash;
        address token;
        address payableTo;
        uint256 amount;
        bytes delegateSignature;
        address allowanceModule;
        address safeProxy;
    }

    /// @notice Constructor function
    constructor() {
        // Expose expected input parameters for UIs.
        bytes memory configParams = abi.encode("address allowanceModule", "address safeProxy");
        emit Mandate__Deployed(configParams);
    }

    function initializeMandate(
        uint16 index,
        string memory nameDescription,
        bytes memory inputParams,
        bytes memory config
    ) public override {
        super.initializeMandate(
            index, nameDescription, abi.encode("address Token", "uint256 Amount", "address PayableTo"), config
        );
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
        Mem memory mem;

        actionId = MandateUtilities.computeActionId(mandateId, mandateCalldata, nonce);
        (mem.allowanceModule, mem.safeProxy) = abi.decode(getConfig(powers, mandateId), (address, address));

        (targets, values, calldatas) = MandateUtilities.createEmptyArrays(1);
        // NB: We call the allowance module directly to make the transfer. The allowance module then calls the Safe proxy.
        targets[0] = mem.allowanceModule;
        calldatas[0] = _createCalldata(powers, mandateId, mandateCalldata);

        return (actionId, targets, values, calldatas);
    }

    function _createCalldata(address powers, uint16 mandateId, bytes memory mandateCalldata)
        internal
        view
        returns (bytes memory)
    {
        Mem memory mem;
        (, mem.safeProxy) = abi.decode(getConfig(powers, mandateId), (address, address));
        (mem.token, mem.amount, mem.payableTo) = abi.decode(mandateCalldata, (address, uint256, address));

        // Construct the `v=1` signature.
        // r = address of the signer (powers contract)
        // s = 0
        // v = 1
        mem.delegateSignature = abi.encodePacked(uint256(uint160(powers)), uint256(0), uint8(1));

        return (abi.encodeWithSelector(
                bytes4(0x4515641a), // executeAllowanceTransfer(address,address,address,uint96,address,uint96,address,bytes),
                ISafe(mem.safeProxy), // The Safe proxy address
                mem.token, // The token to transfer
                mem.payableTo, // The recipient of the tokens
                uint96(mem.amount), // The amount to transfer
                address(0), // paymentToken = address(0) for ETH refund
                uint96(0), // paymentAmount = 0 for no ETH refund
                powers, // The delegate address executing the transfer
                mem.delegateSignature // the signature constructed above
            ));
    }
}
