// SPDX-License-Identifier: MIT

pragma solidity 0.8.10;

import "./EditorRoleUpgradeable.sol";

/**
 * This smart contract code is Copyright 2022 WEMADETREE Ltd. For more information see https://wemixnetwork.com/
 *  
 */

// RouterRole has the authority to change the storage of a contract that inherits it
// owner has admin role

contract RouterRoleUpgradeable is EditorRoleUpgradeable {
    using AddressUpgradeable for address;

    bytes32 constant ROUTER = "Router";

    modifier onlyRouter() {
        _checkRole(ROUTER);
        _;
    }

    function __AccessControl_init() virtual override internal onlyInitializing {
        _setRoleAdmin(ROUTER, EDITOR);
        super.__AccessControl_init();
    }

    function addRouter(address router) public onlyEditor {
        require(router.isContract(), "RU0-AR0-020");
        _grantRole(ROUTER, router);
    }

    function removeRouter(address router) public onlyEditor {
        _revokeRole(ROUTER, router);
    }

    function isRouter(address router) public view returns (bool) {
        return hasRole(ROUTER, router);
    }

     /**
     * @dev This empty reserved space is put in place to allow future versions to add new
     * variables without shifting down storage in the inheritance chain.
     * See https://docs.openzeppelin.com/contracts/4.x/upgradeable#storage_gaps
     */
    uint256[50] private __gap;
}