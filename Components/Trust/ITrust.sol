// SPDX-License-Identifier: MIT
pragma solidity 0.8.10;

/**
 * @title ITrust
 * @author Wemade Pte, Ltd
 * @dev Interface of the Trust
 */

interface ITrust{
    event RevenueDistributed(
        uint indexed id,
        bytes32 indexed business,
        address indexed token,
        uint pteFee,
        uint purchaseFund,
        uint reserveFund,
        uint creatorFee
    );

    // Only Fund Router can call
    function transferToPte(
        uint id,
        bytes32 business,
        address token,
        address pte,
        uint businessFund,
        uint fee
    ) 
        external 
        payable;
        
    function distributeRevenue(
        uint id,
        bytes32 business,
        address token,
        address[] calldata recipients,
        uint[] calldata amounts
    )
        external
        payable;
}