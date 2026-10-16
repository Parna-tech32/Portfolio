// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

contract MockOSM {
    uint256 public price = 1 ether;
    bool public valid = true;

    function setPrice(uint256 _price, bool _valid) external {
        price = _price;
        valid = _valid;
    }

    function read() external view returns (bytes32, bool) {
        return (bytes32(price), valid);
    }
}