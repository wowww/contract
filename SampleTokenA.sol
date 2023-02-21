// SPDX-License-Identifier: MIT

pragma solidity 0.8.10;

import "../../../contracts/openzeppelin-contracts/token/ERC20/ERC20.sol";

/**
 * This smart contract code is Copyright 2020 WEMADETREE Ltd. For more information see https://wemixnetwork.com/
 *  
 */

contract SampleTokenA is ERC20 {
    event caller(address sender);
    constructor(string memory name, string memory symbol, uint256 initialSupply, address owner) ERC20(name, symbol) {
        super._mint(owner, initialSupply);
        emit caller(owner);
    }

    //token transfer between EOA is blocked. however, it is possible if from, to, or sender are has a signer-role.
    function _transfer(address from, address to, uint256 value) internal override{
        super._transfer(from, to, value);
    }

    //only minter
    function mint(address to, uint256 value) public returns(bool){
        super._mint(to, value);
        return true;
    }
}

