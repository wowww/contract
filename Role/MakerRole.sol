// SPDX-License-Identifier: MIT

pragma solidity 0.8.10;

import "../Role/EditorRole.sol";
import "../../../../contracts/openzeppelin-contracts/utils/Address.sol";

/**
 * This smart contract code is Copyright 2020 WEMADETREE Ltd. For more information see https://wemixnetwork.com/
 *  
 */

// MakerRole has the authority to change the storage of a contract that inherits it
// owner has admin role

contract MakerRole is EditorRole {
    using Address for address;

    mapping(address => bool) private makers;
    
    modifier onlyMaker() {
        require(isMaker(msg.sender), "MR-MDF-520");
        _;
    }

    function addMaker(address maker) external onlyEditor{
        require(maker != address(0), "MR-MDF-020");
        makers[maker] = true;
    }

    function removeMaker(address maker) external onlyEditor {
        makers[maker] = false;
    }

    function isMaker(address maker) public view returns (bool) {
        return (makers[maker] || _msgSender() == owner());
    }
}