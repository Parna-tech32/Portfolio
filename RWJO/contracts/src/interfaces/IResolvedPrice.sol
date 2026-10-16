// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

interface IResolvedPrice {
    function read() external view returns (uint256 price, bool disputed);
}