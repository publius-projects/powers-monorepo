// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title AllowedTokens
 * @notice Registry of allowed ERC20 tokens managed by the owner
 * It works on the basis of an array (not mapping) to facilitate looping through allowed tokens.
 * @author 7Cedars
 */
contract AllowedTokens is Ownable {
    address[] private _allowedTokens;
    // NB: Check out @AllowanceModule for an example of how to loop through allowed tokens using a mapping not list.
    uint256 private _allowedTokensCount;
    mapping(address => bool) private _isAllowed;

    event TokenAdded(address indexed token);
    event TokenRemoved(address indexed token);

    constructor() Ownable(msg.sender) { }

    /**
     * @notice Sets the allowed status of a token
     * @param token The address of the token
     */
    function addToken(address token) external onlyOwner {
        if (_isAllowed[token]) {
            revert("Token already allowed");
        }
        _allowedTokens.push(token);
        _isAllowed[token] = true;
        _allowedTokensCount++;

        emit TokenAdded(token);
    }

    /**
     * @notice Removes a token from the allowed list
     * @param token The address of the token to remove
     */
    function removeToken(address token) external onlyOwner {
        if (!_isAllowed[token]) {
            revert("Token not allowed");
        }

        for (uint256 i = 0; i < _allowedTokens.length; i++) {
            if (_allowedTokens[i] == token) {
                _allowedTokens[i] = _allowedTokens[_allowedTokens.length - 1];
                _allowedTokens.pop();
                emit TokenRemoved(token);
                _allowedTokensCount--;
                _isAllowed[token] = false;
                return;
            }
        }
    }

    /**
     * @notice Checks if a token is allowed
     * @param token The address of the token to check
     */
    function isTokenAllowed(address token) external view returns (bool) {
        return _isAllowed[token];
    }

    /**
     * @notice Returns the count of allowed tokens
     * @return uint256 The number of allowed tokens
     */
    function getAllowedTokensCount() external view returns (uint256) {
        return _allowedTokensCount;
    }

    /**
     * @notice Returns the count of allowed tokens
     * @return uint256 The number of allowed tokens
     */
    function getAllowedToken(uint256 index) external view returns (address) {
        return _allowedTokens[index];
    }
}
