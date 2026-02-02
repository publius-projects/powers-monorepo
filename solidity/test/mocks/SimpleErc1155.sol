// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import { ERC1155 } from "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";

/**
 * @dev Mock ERC1155 contract for use in DAO example implementations of the Powers protocol.
 *
 */
contract SimpleErc1155 is ERC1155 {
    error SimpleErc1155__NoZeroAddress();
    error SimpleErc1155__NoZeroAmount();
    error SimpleErc1155__AmountExceedsMax(uint256 amount, uint256 maxAmount);

    uint256 constant MAX_AMOUNT_COINS_TO_MINT = 100 * 10 ** 18;
    uint256 constant COIN_ID = 0;

    // the dao address receives half of mintable coins.
    constructor()
        ERC1155("https://aqua-famous-sailfish-288.mypinata.cloud/ipfs/bafkreighx6axdemwbjara3xhhfn5yaiktidgljykzx3vsrqtymicxxtgvi")
    { }

    function mint(uint256 amount) public {
        if (amount == 0) {
            revert SimpleErc1155__NoZeroAmount();
        }
        if (amount > MAX_AMOUNT_COINS_TO_MINT) {
            revert SimpleErc1155__AmountExceedsMax(amount, MAX_AMOUNT_COINS_TO_MINT);
        }
        _mint(msg.sender, COIN_ID, amount, "");
    }

    // a public non-restricted function that allows anyone to mint coins. Only restricted by max allowed coins to mint.
    function mint(uint256 amount, address to) public {
        if (to == address(0)) {
            revert SimpleErc1155__NoZeroAddress();
        }
        if (amount == 0) {
            revert SimpleErc1155__NoZeroAmount();
        }
        if (amount > MAX_AMOUNT_COINS_TO_MINT) {
            revert SimpleErc1155__AmountExceedsMax(amount, MAX_AMOUNT_COINS_TO_MINT);
        }
        _mint(to, COIN_ID, amount, "");
    }
}
