// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import { Mandate } from "@src/Mandate.sol";
import { IPowers } from "@src/interfaces/IPowers.sol";
import { IERC721 } from "@lib/openzeppelin-contracts/contracts/token/ERC721/IERC721.sol";
import { MandateUtilities } from "@src/libraries/MandateUtilities.sol";

/**
 * @title ERC721_GatedAccess
 * @notice Mandate to gate access to a role based on ERC721 token ownership.
 * @dev Checks if caller holds a minimum balance of ERC721 tokens and assigns a role.
 */
contract ERC721_GatedAccess is Mandate {
    struct Config {
        address erc721Address;
        uint256 assignRoleId;
        uint256 minBalance;
    }

    constructor(address registry_) Mandate(registry_) {
        bytes memory configParams = abi.encode(
            "address erc721Address", // The ERC721 contract address
            "uint256 assignRoleId", // The role Id to assign if checks pass
            "uint256 minBalance" // Minimum balance required
        );
        emit Mandate__Deployed(configParams);
    }

    function initializeMandate(
        uint16 index,
        string memory nameDescription,
        bytes memory inputParams,
        bytes memory config
    ) public override {
        inputParams = ""; // No input params needed from user, just calling the function
        super.initializeMandate(index, nameDescription, inputParams, config);
    }

    function handleRequest(
        address caller,
        address powers,
        uint16 mandateId,
        bytes calldata mandateCalldata,
        uint256 nonce
    )
        public
        view
        override
        returns (uint256 actionId, address[] memory targets, uint256[] memory values, bytes[] memory calldatas)
    {
        actionId = MandateUtilities.computeActionId(mandateId, mandateCalldata, nonce);

        // 1. Get config
        bytes memory configBytes = getConfig(powers, mandateId);
        Config memory config = abi.decode(configBytes, (Config));

        // 2. Check balance
        IERC721 nft = IERC721(config.erc721Address);
        if (nft.balanceOf(caller) < config.minBalance) {
            revert("Insufficient ERC721 balance");
        }

        // 3. Assign role
        (targets, values, calldatas) = MandateUtilities.createEmptyArrays(1);
        targets[0] = powers;
        calldatas[0] = abi.encodeWithSelector(IPowers.assignRole.selector, config.assignRoleId, caller);

        return (actionId, targets, values, calldatas);
    }
}
