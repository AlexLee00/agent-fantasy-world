// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "../core/AFWToken.sol";

contract AFWTokenV2Mock is AFWToken {
    function version() external pure returns (uint256) {
        return 2;
    }
}
