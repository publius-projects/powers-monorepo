// SPDX-License-Identifier: MIT

/// @notice A simple mandate that assigns a role after a succesful transaction of a specific token and preset amount.
// It is a simple threshold logic. If the transfer is of sufficient size & succesful, the role is granted.
/// @author 7Cedars

pragma solidity 0.8.26;

import { Mandate } from "../../Mandate.sol";
import { IPowers } from "../../interfaces/IPowers.sol";
import { MandateUtilities } from "../../libraries/MandateUtilities.sol";

// import "forge-std/Test.sol"; // for testing only. remove before deployment.

contract RoleByTransaction is Mandate {
    struct Mem {
        address token;
        uint256 amount;
        uint256 thresholdAmount;
        uint256 newRoleId;
        address safeProxy;
        address account;
        bool success;
    }

    /// @notice Constructor for RoleByRoles mandate
    constructor() {
        bytes memory configParams =
            abi.encode("address Token", "uint256 ThresholdAmount", "uint256 NewRoleId", "address SafeProxy");
        emit Mandate__Deployed(configParams);
    }

    function initializeMandate(
        uint16 index,
        string memory nameDescription,
        bytes memory inputParams,
        bytes memory config
    ) public override {
        (address token,,,) = abi.decode(config, (address, uint256, uint256, address));
        if (token == address(0)) revert("Native token transfers not supported");

        inputParams = abi.encode("uint256 Amount");
        super.initializeMandate(index, nameDescription, inputParams, config);
    }

    function handleRequest(
        address caller,
        address,
        /*powers*/
        uint16 mandateId,
        bytes memory mandateCalldata,
        uint256 nonce
    )
        public
        view
        virtual
        override
        returns (uint256 actionId, address[] memory targets, uint256[] memory values, bytes[] memory calldatas)
    {
        // step 1: decode the calldata & create hashes
        actionId = MandateUtilities.computeActionId(mandateId, mandateCalldata, nonce);

        calldatas = new bytes[](2);
        calldatas[0] = mandateCalldata;
        calldatas[1] = abi.encode(caller);
    }

    function _externalCall(
        uint16 mandateId,
        uint256 actionId,
        address[] memory targets,
        uint256[] memory values,
        bytes[] memory calldatas
    ) internal override {
        Mem memory mem;
        (mem.token, mem.thresholdAmount, mem.newRoleId, mem.safeProxy) =
            abi.decode(getConfig(msg.sender, mandateId), (address, uint256, uint256, address));
        mem.amount = abi.decode(calldatas[0], (uint256));
        mem.account = abi.decode(calldatas[1], (address));
        mem.success;

        require(mem.amount >= mem.thresholdAmount, "Amount below threshold");

        if (mem.token == address(0)) {
            (mem.success,) = mem.safeProxy.call{ value: mem.amount }("");
        } else {
            (mem.success,) = mem.token
                .call(
                    abi.encodeWithSignature(
                        "transferFrom(address,address,uint256)", mem.account, mem.safeProxy, mem.amount
                    )
                );
        }
        require(mem.success, "Transaction failed");

        (targets, values, calldatas) = MandateUtilities.createEmptyArrays(1);
        targets[0] = msg.sender;
        calldatas[0] = abi.encodeWithSelector(IPowers.assignRole.selector, mem.newRoleId, mem.account);

        // step 2: execute the role assignment if the amount threshold is met
        _replyPowers(mandateId, actionId, targets, values, calldatas);
    }
}
