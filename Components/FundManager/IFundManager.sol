// SPDX-License-Identifier: MIT

pragma solidity 0.8.10;

/**
 * @title IFundManager
 * @author Wemade Pte, Ltd
 * @dev Interface of FundManager
 */

interface IFundManager {
    event FundReceived(uint indexed id, bytes32 indexed column, address indexed token, uint amount);

    // Only Fund Router can call
    function receiveFund(uint id, bytes32 column, address token, uint amount) external payable;
    function transferFund(uint id, bytes32 column, address token, address to, uint amount) external;
    function swap(uint id, uint amountIn, uint amountOutMin, address[] calldata path, uint deadline) external returns (uint amountOut);

    // common
    function tokenCollection(uint id) external view returns (address[] memory);
    function usableFund(uint id, address token) external view returns (uint);
    function isOwn(uint id, address token) external view returns (bool);
}