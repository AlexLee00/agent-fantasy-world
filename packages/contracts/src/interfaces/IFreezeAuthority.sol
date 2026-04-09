// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IFreezeAuthority {
    function isWalletFrozen(address wallet) external view returns (bool);
}
