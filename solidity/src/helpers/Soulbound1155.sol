// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import { ERC1155 } from "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";
import { Context } from "@openzeppelin/contracts/utils/Context.sol";

/**
 * @dev Soulbound1155 is meant as a soulbound ERC 1155 token that has a dynamic token ID, allowing for encoding data into the token ID.
 */
interface ISoulbound1155 {
    function mint(address to, uint256 tokenId) external;
    function mintTokenId(address to, uint256 tokenId) external returns (uint256);
}

contract Soulbound1155 is ERC1155, ISoulbound1155, Ownable {
    error Soulbound1155__NoZeroAmount();

    // the dao address receives half of mintable coins.
    constructor(string memory uri_) ERC1155(uri_) Ownable(msg.sender) { }

    // Mint tokenIds that encode the minter address and block number.
    function mint(address to, uint256 tokenId) public onlyOwner {
        _mint(to, tokenId, 1, "");
    }

    function mintTokenId(address to, uint256 tokenId) public onlyOwner returns (uint256) {
        _mint(to, tokenId, 1, "");
        return tokenId;
    }

    // override to prevent transfers.
    function _update(address from, address to, uint256[] memory ids, uint256[] memory values)
        internal
        virtual
        override
    {
        // allow minting and burning
        if (from != address(0) && to != address(0)) {
            revert("Soulbound1155: Transfers are disabled");
        }

        super._update(from, to, ids, values);
    }
}
