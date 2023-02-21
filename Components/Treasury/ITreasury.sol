// SPDX-License-Identifier: MIT

pragma solidity 0.8.10;

interface ITreasury {
    // Only Fund Router can call
    function liquidate(uint id, address station) external returns (address[] memory tokens, uint[] memory amounts);
}