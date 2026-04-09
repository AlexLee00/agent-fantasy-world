// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IItemRegistry {
    function mint(address to, uint256 itemId, uint256 amount) external;
    function burn(address from, uint256 itemId, uint256 amount) external;
}
