// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import { Mandate } from "../../Mandate.sol";
import { IPowers } from "../../interfaces/IPowers.sol";
import { IERC1155 } from "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";
import { Strings } from "@openzeppelin/contracts/utils/Strings.sol";
import { MandateUtilities } from "../../libraries/MandateUtilities.sol";

// import { console2 } from "forge-std/console2.sol"; // remove before deploying.

/**
 * @title Soulbound1155_GatedAccess
 * @notice Mandate to gate access to a role based on Soulbound1155 tokens.
 * @dev Integrates with Soulbound1155.sol to create flexible gated access to roleId in Powers organisations.
 */
contract Soulbound1155_GatedAccess is Mandate {
    using Strings for uint256;

    struct Mem {
        bytes config;
        address soulbound1155Address;
        uint256 assignRoleId;
        uint256 checkRoleId;
        uint48 blocksThreshold;
        uint48 tokensThreshold;
        uint256 i;
        uint256[] tokenIds;
        uint256 tokenId;
        uint256 actionId;
        address minter;
        uint48 mintBlock;
    }

    constructor() {
        bytes memory configParams = abi.encode(
            "address soulbound1155",
            "uint256 assignRoleId", // the role Id to assign if checks pass
            "uint256 checkRoleId", // the role Id the encoded address needs to have to pass check.
            "uint48 blocksThreshold",
            "uint48 tokensThreshold"
        );
        emit Mandate__Deployed(configParams);
    }

    function initializeMandate(
        uint16 index,
        string memory nameDescription,
        bytes memory inputParams,
        bytes memory config
    ) public override {
        inputParams = abi.encode("uint256[] tokenIds");
        super.initializeMandate(index, nameDescription, inputParams, config);
    }

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
        Mem memory mem;
        actionId = MandateUtilities.computeActionId(mandateId, mandateCalldata, nonce);

        // 1. Get config
        mem.config = getConfig(powers, mandateId);
        (mem.soulbound1155Address, mem.assignRoleId, mem.checkRoleId, mem.blocksThreshold, mem.tokensThreshold) =
            abi.decode(mem.config, (address, uint256, uint256, uint48, uint48));

        // 2. Decode input params
        mem.tokenIds = abi.decode(mandateCalldata, (uint256[]));
        IERC1155 sb1155 = IERC1155(mem.soulbound1155Address);

        uint256 validTokenCount = 0;
        for (mem.i = 0; mem.i < mem.tokenIds.length; mem.i++) {
            mem.tokenId = mem.tokenIds[mem.i];

            // Check 1: checks if caller balance of tokenIds is > 0
            if (sb1155.balanceOf(caller, mem.tokenId) == 0) {
                continue;
            }

            // Check 2: Check if tokens are within block threshold.
            mem.mintBlock = uint48(mem.tokenId);
            if (block.number > mem.mintBlock + mem.blocksThreshold) {
                continue;
            }

            // Check 3: check if token is from the correct roleId.
            mem.minter = address(uint160(mem.tokenId >> 48));
            if (IPowers(powers).hasRoleSince(mem.minter, mem.checkRoleId) != 0) {
                validTokenCount++;
            }
        }

        if (validTokenCount < mem.tokensThreshold) {
            revert("Insuffiicent valid tokens provided");
        }

        // Check 4: if everything passes, assign roleId to caller.
        (targets, values, calldatas) = MandateUtilities.createEmptyArrays(1);
        targets[0] = powers;
        calldatas[0] = abi.encodeWithSelector(IPowers.assignRole.selector, mem.assignRoleId, caller);

        return (actionId, targets, values, calldatas);
    }
}
