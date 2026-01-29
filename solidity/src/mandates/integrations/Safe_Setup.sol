// SPDX-License-Identifier: MIT
/// @notice A mandate to execute that creates a SafeProxy, setting Powers as owner and registring it as its treasury.
/// @dev This mandate uses the v=1 signature type, where the transaction executor (`msg.sender` to the Safe)
///      is an owner, thus providing its own approval by making the call.
/// @author 7Cedars
// £todo: this mandate should be split in two: 1 setup safe 2: setup config in powers (using return data from first mandate). This will allow each call to be made directly.
pragma solidity 0.8.26;

import { Mandate } from "../../Mandate.sol";
import { MandateUtilities } from "../../libraries/MandateUtilities.sol";
import { Safe } from "lib/safe-smart-account/contracts/Safe.sol";
import { ModuleManager } from "lib/safe-smart-account/contracts/base/ModuleManager.sol";
import { SafeProxyFactory } from "lib/safe-smart-account/contracts/proxies/SafeProxyFactory.sol";
import { IPowers } from "../../interfaces/IPowers.sol";

// import { console2 } from "lib/forge-std/src/console2.sol"; // REMOVE AFTER TESTING

contract Safe_Setup is Mandate {
    struct Mem {
        bytes configBytes;
        address safeProxyFactory;
        address safeL2Singleton;
        address allowanceModule;
        address powers;
        address safeProxyAddress;
    }

    /// @notice Exposes the expected input parameters for UIs during deployment.
    constructor() {
        bytes memory configParams =
            abi.encode("address safeProxyFactory", "address safeL2Singleton", "address allowanceModule");
        emit Mandate__Deployed(configParams);
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
        pure
        override
        returns (uint256 actionId, address[] memory targets, uint256[] memory values, bytes[] memory calldatas)
    {
        // console2.log("Waypoint 1");
        actionId = MandateUtilities.computeActionId(mandateId, mandateCalldata, nonce);

        // NB! No transaction is sent to Powers here, so the action remains unfulfilled.
        // console2.log("Waypoint 2");
        calldatas = new bytes[](1);
        calldatas[0] = abi.encode(powers);

        return (actionId, targets, values, calldatas);
    }

    function _externalCall(
        uint16 mandateId,
        uint256 actionId,
        address[] memory targets,
        uint256[] memory values,
        bytes[] memory calldatas
    ) internal virtual override {
        Mem memory mem;

        // step 1: decoding data
        // console2.log("Waypoint 3");
        mem.powers = abi.decode(calldatas[0], (address));
        // console2.log("Waypoint 4");
        (mem.safeProxyFactory, mem.safeL2Singleton, mem.allowanceModule) =
            abi.decode(getConfig(mem.powers, mandateId), (address, address, address));

        // console2.log("Safe_Setup: deploying SafeProxy via factory:", mem.safeProxyFactory);

        address[] memory owners = new address[](1);
        owners[0] = mem.powers;
        bytes memory signature = abi.encodePacked(
            uint256(uint160(mem.powers)), // r = address of the signer (powers contract)
            uint256(0), // s = 0
            uint8(1) // v = 1 This is a type 1 call. See Safe.sol for details.
        );

        mem.safeProxyAddress = address(
            SafeProxyFactory(mem.safeProxyFactory)
                .createProxyWithNonce(
                    mem.safeL2Singleton,
                    abi.encodeWithSelector(
                        Safe.setup.selector,
                        owners,
                        1, // threshold
                        address(0), // to
                        "", // data
                        address(0), // fallbackHandler
                        address(0), // paymentToken
                        0, // payment
                        address(0) // paymentReceiver
                    ),
                    1 // = nonce
                )
        );

        // step 2: create array for callback to powers
        (targets, values, calldatas) = MandateUtilities.createEmptyArrays(3);

        // call 2a: enable allowance module on the SafeProxy
        targets[0] = mem.safeProxyAddress; // Safe contract
        calldatas[0] = abi.encodeWithSelector(
            Safe.execTransaction.selector,
            mem.safeProxyAddress, // The internal transaction's destination
            0, // The internal transaction's value in this mandate is always 0. To transfer Eth use a different mandate.
            abi.encodeWithSelector( // the call to be executed by the Safe: enabling the module.
                ModuleManager.enableModule.selector,
                mem.allowanceModule
            ),
            0, // operation = Call
            0, // safeTxGas
            0, // baseGas
            0, // gasPrice
            address(0), // gasToken
            address(0), // refundReceiver
            signature // the signature constructed above
        );

        // call 2b: set the SafeProxy as the treasury in Powers
        targets[1] = mem.powers;
        calldatas[1] = abi.encodeWithSelector(IPowers.setTreasury.selector, mem.safeProxyAddress);

        // call 2c: revoke this mandate from Powers
        targets[2] = mem.powers;
        calldatas[2] = abi.encodeWithSelector(IPowers.revokeMandate.selector, mandateId);

        IPowers(mem.powers).fulfill(mandateId, actionId, targets, values, calldatas);
    }
}
