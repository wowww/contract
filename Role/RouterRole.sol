// SPDX-License-Identifier: MIT

pragma solidity 0.8.10;

import "../Role/EditorRole.sol";
import "../../../../contracts/openzeppelin-contracts/utils/Address.sol";

/**
 * This smart contract code is Copyright 2020 WEMADETREE Ltd. For more information see https://wemixnetwork.com/
 *  
 */

// RouterRole has the authority to change the storage of a contract that inherits it
// owner has admin role

contract RouterRole is EditorRole {
    using Address for address;

    mapping(address => bool) private routers;
    
    modifier onlyRouter() {
        require(isRouter(_msgSender()), "RR-MDF-520");
        _;
    }

    function addRouter(address router) public onlyEditor {
        require(router.isContract(), "RR-MDF-020");
        _addRouter(router);
    }

    function removeRouter(address router) public onlyEditor {
        routers[router] = false;
    }

    function isRouter(address router) public view returns (bool) {
        return (routers[router] || _msgSender() == owner());
    }

    function _addRouter(address router) internal {
        routers[router] = true;
    }
}