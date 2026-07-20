// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import { Mandate } from "@src/Mandate.sol";
import { IERC1155 } from "@lib/openzeppelin-contracts/contracts/token/ERC1155/IERC1155.sol";
import { ISoulbound1155 } from "@mocks/Soulbound1155.sol";
import { IGoverned721 } from "@src/addons/helpers/Governed721.sol";
import { IERC721 } from "@lib/openzeppelin-contracts/contracts/token/ERC721/IERC721.sol";
import { IERC165 } from "@lib/openzeppelin-contracts/contracts/utils/introspection/IERC165.sol";
import { MandateUtilities } from "@src/libraries/MandateUtilities.sol";

// import { console2 } from "forge-std/console2.sol"; // remove before deploying.

/**
 * @title GovernedToken_BurnToAccess
 * @notice A mandate in which a user has to burn a token to pass the mandate checks and gain access to a subsequent mandate. It can be used to throttle access to any kind of action.
 * @dev Integrates with Soulbound1155.sol and Governed721.sol to create flexible gated access to roleId in Powers organisations.
 */
contract GovernedToken_BurnToAccess is Mandate {
    constructor(address registry_) Mandate(registry_) {
        bytes memory configParams = abi.encode("string[] inputParams", "address governedTokenAddress");
        emit Mandate__Deployed(configParams);
    }

    function initializeMandate(uint16 index, string memory nameDescription, bytes memory, bytes memory config)
        public
        override
    {
        // console2.log("waypoint 1");
        (string[] memory params,) = abi.decode(config, (string[], address));
        // console2.log("waypoint 2");
        string[] memory newParams = new string[](params.length + 1);
        // console2.log("waypoint 3");
        for (uint256 i = 0; i < params.length; i++) {
            newParams[i] = params[i];
        }
        // console2.log("waypoint 4");
        newParams[params.length] = "uint256 tokenId";
        // console2.log("waypoint 5");
        super.initializeMandate(index, nameDescription, abi.encode(newParams), config);
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
        (, address governedTokenAddress) = abi.decode(getConfig(powers, mandateId), (string[], address));

        // 2. Decode input params
        uint256 tokenId = abi.decode(mandateCalldata, (uint256));

        // 3. Determine if ERC1155 or ERC721
        bool is1155;
        try IERC165(governedTokenAddress).supportsInterface(type(IERC1155).interfaceId) returns (bool result) {
            is1155 = result;
        } catch {
            is1155 = false;
        }

        // 4. Check ownership and burn
        (targets, values, calldatas) = MandateUtilities.createEmptyArrays(1);
        targets[0] = governedTokenAddress;

        if (is1155) {
            if (IERC1155(governedTokenAddress).balanceOf(caller, tokenId) == 0) revert("Insufficient balance");
            calldatas[0] = abi.encodeWithSelector(ISoulbound1155.burn.selector, caller, tokenId, 1);
        } else {
            // Assume ERC721 if not 1155, or fail if neither
            try IERC721(governedTokenAddress).ownerOf(tokenId) returns (address owner) {
                if (owner != caller) revert("Not token owner");
                calldatas[0] = abi.encodeWithSelector(IGoverned721.burn.selector, tokenId);
            } catch {
                revert("Invalid token contract");
            }
        }

        return (actionId, targets, values, calldatas);
    }
}
