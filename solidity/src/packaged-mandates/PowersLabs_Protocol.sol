// SPDX-License-Identifier: MIT

/// @notice An example implementation of a Mandate Package that adopts multiple mandates into the Powers protocol.
/// It is meant to be adopted through the Mandates_Adopt mandate, and then be executed to adopt multiple mandates in a single transaction.
/// The mandate self-destructs after execution.
///
/// @author 7Cedars

pragma solidity 0.8.26;

import { Mandate } from "../Mandate.sol";
import { MandateUtilities } from "../libraries/MandateUtilities.sol";
import { IPowers } from "../interfaces/IPowers.sol";
import { Powers } from "../Powers.sol";

// This MandatePackage adopts the following governance paths:
// path 0 + 1: init Allowance Module.
// path 2: adopt new child.
// path 3: assign allowance to child.

contract PowerLabs_Protocol is Mandate {
    struct Mem {
        uint16 mandateCount;
        address safeProxy;
        bytes signature;
    }
    address[] private mandateAddresses;
    address private allowanceModuleAddress;
    uint16 public constant NUMBER_OF_CALLS = 7; // total number of calls in handleRequest
    uint48 public immutable BLOCKS_PER_HOUR;

    // in this case mandateAddresses should be [statementOfIntent, Safe_ExecTransaction, PresetActions_Single]
    constructor(uint48 BLOCKS_PER_HOUR_, address[] memory mandateDependencies, address allowanceModuleAddress_) {
        BLOCKS_PER_HOUR = BLOCKS_PER_HOUR_;
        mandateAddresses = mandateDependencies;
        allowanceModuleAddress = allowanceModuleAddress_;

        emit Mandate__Deployed(abi.encode());
    }

    function initializeMandate(
        uint16 index,
        string memory nameDescription,
        bytes memory inputParams,
        bytes memory config
    ) public override {
        inputParams = abi.encode("address SafeProxy");
        super.initializeMandate(index, nameDescription, inputParams, config);
    }

    /// @notice Build calls to adopt the configured mandates
    /// @param mandateCalldata Unused for this mandate
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
        mem.mandateCount = Powers(powers).mandateCounter();
        // (mem.safeProxy) = abi.decode(mandateCalldata, (address));
        mem.signature = abi.encodePacked(
            uint256(uint160(powers)), // r = address of the signer (powers contract)
            uint256(0), // s = 0
            uint8(1) // v = 1 This is a type 1 call. See Safe.sol for details.
        );

        (targets, values, calldatas) = MandateUtilities.createEmptyArrays(NUMBER_OF_CALLS);

        /////////////////////////////////////////////////////////////////////////////////////////////////////
        // DIRECT CALLS TO POWERS CONTRACT TO ADOPT THE ALLOWANCE MODULE AND SET THE SAFEPROXY AS TREASURY //
        /////////////////////////////////////////////////////////////////////////////////////////////////////

        for (uint256 i; i < NUMBER_OF_CALLS; i++) {
            targets[i] = powers;
        }

        // 1: adopt new uri.
        calldatas[0] = abi.encodeWithSelector(
            IPowers.setUri.selector,
            "https://aqua-famous-sailfish-288.mypinata.cloud/ipfs/bafkreigye2u5mzkfhxtcmxl4plrkhv2hzkvvctvcw64pc5ogkxtix35ggi"
        );

        // 2: assign labels to roles - same as in PowerLabs Constitution.
        calldatas[1] = abi.encodeWithSelector(IPowers.labelRole.selector, 1, "Funders");
        calldatas[2] = abi.encodeWithSelector(IPowers.labelRole.selector, 2, "Doc Contributors");
        calldatas[3] = abi.encodeWithSelector(IPowers.labelRole.selector, 3, "Frontend Contributors");
        calldatas[4] = abi.encodeWithSelector(IPowers.labelRole.selector, 4, "Protocol Contributors");
        calldatas[5] = abi.encodeWithSelector(IPowers.labelRole.selector, 5, "Members");

        // 3: set final call to self-destruct the MandatePackage after adopting the mandates
        calldatas[NUMBER_OF_CALLS - 1] = abi.encodeWithSelector(IPowers.revokeMandate.selector, mandateId);

        //////////////////////////////////////////////////////////////////////////
        //              GOVERNANCE FLOW FOR ADOPTING DELEGATES                  //
        //////////////////////////////////////////////////////////////////////////
    }
}
