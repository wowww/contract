// SPDX-License-Identifier: MIT
pragma solidity 0.8.10;

/**
 * @title IContractFactory
 * @author Wemade Pte, Ltd
 *
 */

interface IContractFactory  {

    function deployDT(
        string memory name, 
        string memory symbol, 
        address stakingPool, 
        address incinerator, 
        uint id, 
        uint totalSupply
    ) 
        external 
        returns(address);

    function deployGT(
        string memory name, 
        string memory symbol, 
        address stakingPool
    ) 
        external 
        returns(address);
}