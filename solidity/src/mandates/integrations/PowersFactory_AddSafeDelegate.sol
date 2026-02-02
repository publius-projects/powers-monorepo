// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import { Mandate } from "../../Mandate.sol";
import { MandateUtilities } from "../../libraries/MandateUtilities.sol";
import { IPowers } from "../../interfaces/IPowers.sol";
import { PowersTypes } from "../../interfaces/PowersTypes.sol";
import { Safe } from "lib/safe-smart-account/contracts/Safe.sol";

contract PowersFactory_AddSafeDelegate is Mandate {
    struct Mem {
        bytes config;
        uint16 factoryMandateId;
        address allowanceModule;
        uint256 parentActionId;
        bytes returnData;
        address decodedAddress;
    }

    constructor() {
        bytes memory configParams =
            abi.encode("uint16 factoryMandateId", "address allowanceModule", "string[] inputParams");
        emit Mandate__Deployed(configParams);
    }

    function initializeMandate(
        uint16 index,
        string memory nameDescription,
        bytes memory inputParams,
        bytes memory config
    ) public override {
        // Decode the config to get the input params description string
        (,, string[] memory inputParamsDescription) = abi.decode(config, (uint16, address, string[]));

        super.initializeMandate(index, nameDescription, abi.encode(inputParamsDescription), config);
    }

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

        // 1. Get config
        mem.config = getConfig(powers, mandateId);
        (mem.factoryMandateId, mem.allowanceModule,) = abi.decode(mem.config, (uint16, address, string[]));

        // 2. Compute current actionId
        actionId = MandateUtilities.computeActionId(mandateId, mandateCalldata, nonce);
        mem.parentActionId = MandateUtilities.computeActionId(mem.factoryMandateId, mandateCalldata, nonce);

        // 3. Check parent action state
        if (IPowers(powers).getActionState(mem.parentActionId) != PowersTypes.ActionState.Fulfilled) {
            revert("Invalid parent action state");
        }

        // 4. Check return value in Powers
        try IPowers(powers).getActionReturnData(mem.parentActionId, 0) returns (bytes memory returnData_) {
            mem.returnData = returnData_;
        } catch {
            revert("Error fetching return data for parent action");
        }
        if (mem.returnData.length == 0) {
            revert("Empty return data from parent action");
        }

        // 5. Decode address from return data (this is the new delegate address)
        mem.decodedAddress = abi.decode(mem.returnData, (address));

        // 6. Get Treasury Address
        address safeProxyAddress = IPowers(powers).getTreasury();
        if (safeProxyAddress == address(0)) {
            revert("Treasury not set in Powers");
        }

        // 7. Prepare signature
        // v = 1, r = powers address, s = 0
        bytes memory powersSignature = abi.encodePacked(uint256(uint160(powers)), uint256(0), uint8(1));

        // 8. Construct Safe Transaction
        (targets, values, calldatas) = MandateUtilities.createEmptyArrays(1);
        targets[0] = safeProxyAddress;

        // We call the execTransaction function in our SafeL2 proxy to make the call to the Allowance Module.
        // The Allowance Module has function addDelegate(address delegate)
        // selector for addDelegate(address) is 0xe71bdf41

        calldatas[0] = abi.encodeWithSelector(
            Safe.execTransaction.selector,
            mem.allowanceModule, // The internal transaction's destination: the Allowance Module.
            0, // The internal transaction's value
            abi.encodePacked(
                bytes4(0xe71bdf41), // AllowanceModule.addDelegate.selector
                mem.decodedAddress
            ),
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
