// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

contract ReturnDataMock {
    event Consumed(uint256 value);

    function getValue() public pure returns (uint256) {
        return 42;
    }

    function consume(uint256 value) public {
        emit Consumed(value);
    }
}
