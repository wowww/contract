// SPDX-License-Identifier: MIT

pragma solidity 0.8.10;

import "../../../../../contracts/openzeppelin-upgradeable/utils/AddressUpgradeable.sol";
import "../../../../../contracts/openzeppelin-upgradeable/access/AccessControlUpgradeable.sol";


/**
 * This smart contract code is Copyright 2022 WEMADETREE Ltd. For more information see https://wemixnetwork.com/
 *  
 */

contract OwnerRoleUpgradeable is AccessControlUpgradeable {
    bytes32 constant OWNER = "Owner";
    address public owner;

    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    modifier onlyOwner() {
        _checkRole(OWNER);
        _;
    }

    function __AccessControl_init() virtual override internal onlyInitializing {
        _setRoleAdmin(OWNER, OWNER);
        _grantRole(OWNER, _msgSender());
        owner = _msgSender();
    } 

    function renounceOwnership() public virtual onlyOwner {
        _revokeRole(OWNER, owner);
    }

    function transferOwnership(address newOwner) public virtual onlyOwner {
        require(newOwner != address(0), "OU0-TO0-020");
        _transferOwnership(newOwner);
    }

    function _checkOwner() internal view virtual {
        _checkRole(OWNER);
    }

    function _transferOwnership(address newOwner) internal virtual {
        address oldOwner = owner;
        _revokeRole(OWNER, owner);
        _grantRole(OWNER, newOwner);
        owner = newOwner;
        emit OwnershipTransferred(oldOwner, newOwner);
    }

     function _revokeRole(bytes32 role, address account) internal virtual override {
        if(role == OWNER) {
            require(owner == account, "OU0-RR0-520");
            owner = address(0);
        }
        super._revokeRole(role, account);
    }

    function _grantRole(bytes32 role, address account) internal virtual override {
        if(role == OWNER) {
            require(owner == address(0), "OU0-GR0-520");
        }
        super._grantRole(role, account);
    }

    /**
     * @dev This empty reserved space is put in place to allow future versions to add new
     * variables without shifting down storage in the inheritance chain.
     * See https://docs.openzeppelin.com/contracts/4.x/upgradeable#storage_gaps
     */
    uint256[50] private __gap;
}