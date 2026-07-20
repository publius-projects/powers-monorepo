// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import { Mandate } from "@src/Mandate.sol";
import { IPowers } from "@src/interfaces/IPowers.sol";
import { IERC1155 } from "@lib/openzeppelin-contracts/contracts/token/ERC1155/IERC1155.sol";
import { IERC721 } from "@lib/openzeppelin-contracts/contracts/token/ERC721/IERC721.sol";
import { Strings } from "@lib/openzeppelin-contracts/contracts/utils/Strings.sol";
import { MandateUtilities } from "@src/libraries/MandateUtilities.sol";

// import { console2 } from "forge-std/console2.sol"; // remove before deploying.

/**
 * @title GovernedToken_GatedAccess
 * @notice Mandate to gate access to a role based on Soulbound1155 or Governed721 tokens.
 * @dev Integrates with Soulbound1155.sol and Governed721.sol to create flexible gated access to roleId in Powers organisations.
 */
contract GovernedToken_GatedAccess is Mandate {
    using Strings for uint256;

    struct Mem {
        bytes config;
        address governedTokenAddress;
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

    constructor(address registry_) Mandate(registry_) {
        bytes memory configParams = abi.encode(
            "address governedTokenAddress",
            "uint256 assignRoleId", // the role Id to assign if checks pass
            "uint256 checkRoleId", // the role Id the encoded address needs to have to pass check.
            "uint48 blocksThreshold",
            "uint48 tokensThreshold"
        );
        emit Mandate__Deployed(configParams);
    }

    function initializeMandate(uint16 index, string memory nameDescription, bytes memory, bytes memory config)
        public
        override
    {
        string[] memory params = new string[](1);
        params[0] = "uint256[] tokenIds";
        super.initializeMandate(index, nameDescription, abi.encode(params), config);
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
        Mem memory mem;
        actionId = MandateUtilities.computeActionId(mandateId, mandateCalldata, nonce);

        // 1. Get config
        mem.config = getConfig(powers, mandateId);
        (mem.governedTokenAddress, mem.assignRoleId, mem.checkRoleId, mem.blocksThreshold, mem.tokensThreshold) =
            abi.decode(mem.config, (address, uint256, uint256, uint48, uint48));

        // 2. Decode input params
        mem.tokenIds = abi.decode(mandateCalldata, (uint256[]));

        uint256 validTokenCount = 0;
        for (mem.i = 0; mem.i < mem.tokenIds.length; mem.i++) {
            mem.tokenId = mem.tokenIds[mem.i];

            // Check 1: checks if caller owns tokenIds (compatible with ERC1155 and ERC721)
            bool isOwner = false;
            try IERC1155(mem.governedTokenAddress).balanceOf(caller, mem.tokenId) returns (uint256 balance) {
                if (balance > 0) isOwner = true;
            } catch {
                try IERC721(mem.governedTokenAddress).ownerOf(mem.tokenId) returns (address owner) {
                    if (owner == caller) isOwner = true;
                } catch {
                    revert("Invalid token address or tokenId"); // Token not supported or doesn't exist
                }
            }

            if (!isOwner) {
                continue;
            }

            // Check 2: Optional check if tokens are within block threshold.
            if (mem.blocksThreshold == 0) {
                validTokenCount++;
                continue;
            }
            mem.mintBlock = uint48(mem.tokenId);
            if (block.number > mem.mintBlock + mem.blocksThreshold) {
                continue;
            }

            // Check 3: Optional check if token is from the correct roleId.
            if (mem.checkRoleId == 0) {
                validTokenCount++;
                continue;
            }
            mem.minter = address(uint160(mem.tokenId >> 48));
            if (IPowers(payable(powers)).hasRoleSince(mem.minter, mem.checkRoleId) != 0) {
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
