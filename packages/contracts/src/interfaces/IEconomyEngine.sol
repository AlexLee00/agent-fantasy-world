// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IEconomyEngine {
    function burnMarketFee(address from, uint256 tradeAmount) external;
}
