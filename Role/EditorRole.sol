// SPDX-License-Identifier: MIT

pragma solidity 0.8.10;

import "../../../../contracts/openzeppelin-contracts/access/Ownable.sol";

/**
 * This smart contract code is Copyright 2020 WEMADETREE Ltd. For more information see https://wemixnetwork.com/
 *  
 */

// EditorRole has the authority to change the storage of a contract that inherits it
// owner has admin role

contract EditorRole is Ownable {
    mapping(address => bool) private accounts;
    
    modifier onlyEditor() {
        require(isEditor(_msgSender()), "ER-MDF-520");
        _;
    }

    function addEditor(address account) public onlyOwner {
        require(account != address(0), "ER-MDF-020");
        accounts[account] = true;
    }

    function removeEditor(address account) public onlyOwner {
        accounts[account] = false;
    }

    function isEditor(address account) public view returns (bool) {
        return (accounts[account] == true || _msgSender() == owner());
    }
}