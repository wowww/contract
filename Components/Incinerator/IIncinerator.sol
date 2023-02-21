// SPDX-License-Identifier: MIT
pragma solidity 0.8.10;

/**
 * @title IIncinerator
 * @author Wemade Pte, Ltd
 * @dev interface of the Incinerator
 */
interface IIncinerator{
    event Burned(uint id, address dt, uint amount);
    event Saved(uint id, address dt, uint amount);
    
    // Only Fund Router can call
    function disposeDT(uint id, address dt, uint usedFund, uint amountBurn, uint amountSave) external;
    function amountPurchase() external view returns (uint);
    function purchaseCriteria() external view returns (uint);
    function unit() external view returns (uint);    
}