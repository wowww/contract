// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

interface IUniswapV2Migrator {
    function migrate(address token, uint amountTokenMin, uint amountETHMin, address to, uint deadline) external;
}
