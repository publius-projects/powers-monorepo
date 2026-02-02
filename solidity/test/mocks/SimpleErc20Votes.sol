// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import { ERC20Votes } from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Votes.sol";
import { ERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import { EIP712 } from "@openzeppelin/contracts/utils/cryptography/EIP712.sol";

contract SimpleErc20Votes is ERC20Votes {
    error Erc20Votes__NoZeroAmount();
    error Erc20Votes__NoZeroAddress();
    error Erc20Votes__AmountExceedsMax(uint256 amount, uint256 maxAmount);

    uint256 constant MAX_AMOUNT_VOTES_TO_MINT = 100 * 10 ** 18;

    constructor() ERC20("Votes", "VTS") EIP712("Votes", "0.2") { }

    // a public non-restricted function that allows anyone to mint coins. Only restricted by max allowed coins to mint.
    function mint(uint256 amount) public {
        if (amount == 0) {
            revert Erc20Votes__NoZeroAmount();
        }
        if (amount > MAX_AMOUNT_VOTES_TO_MINT) {
            revert Erc20Votes__AmountExceedsMax(amount, MAX_AMOUNT_VOTES_TO_MINT);
        }
        _mint(msg.sender, amount);
    }

    // a public non-restricted function that allows anyone to mint coins. Only restricted by max allowed coins to mint.
    function mint(address to, uint256 amount) public {
        if (to == address(0)) {
            revert Erc20Votes__NoZeroAddress();
        }
        if (amount == 0) {
            revert Erc20Votes__NoZeroAmount();
        }
        if (amount > MAX_AMOUNT_VOTES_TO_MINT) {
            revert Erc20Votes__AmountExceedsMax(amount, MAX_AMOUNT_VOTES_TO_MINT);
        }
        _mint(to, amount);
    }
}
