// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import { Mandate } from "../../Mandate.sol";
import { IPowers } from "../../interfaces/IPowers.sol";
import { IERC1155 } from "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";
import { Strings } from "@openzeppelin/contracts/utils/Strings.sol";
import { MandateUtilities } from "../../libraries/MandateUtilities.sol";
import { ISoulbound1155 } from "../../helpers/Soulbound1155.sol";

// import { console2 } from "forge-std/console2.sol"; // remove before deploying.

/**
 * @title Soulbound1155_EncodedToken
 * @notice Mandate to gate access to a role based on Soulbound1155 tokens.
 * @dev Integrates with Soulbound1155.sol to create flexible gated access to roleId in Powers organisations.
 */
contract Soulbound1155_MintEncodedToken is Mandate {
    using Strings for uint256;

    struct Mem {
        address soulbound1155;
        address to;
        uint48 blockNumber;
        uint256 tokenId;
    }

    constructor() {
        bytes memory configParams = abi.encode("address soulbound1155");
        emit Mandate__Deployed(configParams);
    }

    function initializeMandate(
        uint16 index,
        string memory nameDescription,
        bytes memory inputParams,
        bytes memory config
    ) public override {
        inputParams = abi.encode("address to");
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
        mem.soulbound1155 = abi.decode(getConfig(powers, mandateId), (address));
        mem.to = abi.decode(mandateCalldata, (address));

        mem.blockNumber = uint48(block.number);
        mem.tokenId = (uint256(uint160(caller)) << 48) | uint256(mem.blockNumber);

        (targets, values, calldatas) = MandateUtilities.createEmptyArrays(1);
        targets[0] = mem.soulbound1155;
        calldatas[0] = abi.encodeWithSelector(ISoulbound1155.mintTokenId.selector, mem.to, mem.tokenId);

        return (actionId, targets, values, calldatas);
    }
}
