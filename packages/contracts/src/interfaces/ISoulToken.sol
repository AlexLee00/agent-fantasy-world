// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface ISoulToken {
    function mint(address to, uint256 amount, string calldata reason, uint256 refId) external;
    function burn(address from, uint256 amount, string calldata reason) external;
    function balanceOf(address account) external view returns (uint256);
}
