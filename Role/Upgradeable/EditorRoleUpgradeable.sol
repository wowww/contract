// SPDX-License-Identifier: MIT

pragma solidity 0.8.10;

import "./OwnerRoleUpgradeable.sol";


/**
 * This smart contract code is Copyright 2022 WEMADETREE Ltd. For more information see https://wemixnetwork.com/
 *  
 */

// EditorRole has the authority to change the storage of a contract that inherits it
// owner has admin role

contract EditorRoleUpgradeable is OwnerRoleUpgradeable {
    bytes32 constant EDITOR = "Editor";

    function __AccessControl_init() virtual override internal onlyInitializing {
        _setRoleAdmin(EDITOR, OWNER);
        _grantRole(EDITOR, _msgSender());
        super.__AccessControl_init();
    }
    
    modifier onlyEditor() {
        _checkRole(EDITOR);
        _;
    }

    function addEditor(address account) public onlyOwner {
        require(account != address(0), "EU0-AE0-020");
        _grantRole(EDITOR, account);
    }

    function removeEditor(address account) public onlyOwner {
        _revokeRole(EDITOR, account);
    }

    function isEditor(address account) public view returns (bool) {
        return hasRole(EDITOR, account);
    }

    /**
     * @dev This empty reserved space is put in place to allow future versions to add new
     * variables without shifting down storage in the inheritance chain.
     * See https://docs.openzeppelin.com/contracts/4.x/upgradeable#storage_gaps
     */
    uint256[50] private __gap;
}