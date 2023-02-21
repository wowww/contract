// SPDX-License-Identifier: MIT

pragma solidity 0.8.10;

import "./IPteRegistry.sol";
import "../Role/EditorRole.sol";
import "../../../../contracts/openzeppelin-contracts/utils/Address.sol";

/**
 * @title PteRegistry
 * @author Wemade Pte, Ltd
 * @dev Register the EOA of Trust Pte to be received from Trust
 */
contract PteRegistry is IPteRegistry, EditorRole {
    
    using Address for address;

    Pte[] private _ptes;

    mapping(address => bool) public override isPte;
    mapping(bytes32 => bool) public override isRegistered;
    mapping(bytes32 => address) private _pte; // bytes32 : Pte name

    event Registered(bytes32 indexed name, address indexed pte);
    event Changed(bytes32 indexed name, address indexed pte);
    event Deleted(bytes32 indexed name, address indexed pte);

    /**
     * @dev Regist address of Pte
     * @param name Pte name (ex.WEMADE)
     * @param pte Pte address
     */
    function regist(bytes32 name, address pte) external override onlyEditor {
        require(pte != address(0), "PR0-RG0-020");
        require(!isRegistered[name], "PR0-RG0-520");

        _ptes.push(Pte({
            name: name,
            addr: pte
        }));

        _pte[name] = pte;
        isPte[pte] = true;
        isRegistered[name] = true;

        emit Registered(name, pte);
    }

    /**
     * @dev Change or delete address of Pte
     * @param name Pte name (ex.WEMADE)
     * @param pte Pte address
     */
    function editPte(bytes32 name, address pte) external override onlyEditor {
        require(isRegistered[name], "PR0-EP0-520");
        require(_pte[name] != pte, "PR0-EP0-540");
        
        isPte[_pte[name]] = false;
        isRegistered[name] = false;
        
        if(pte == address(0)) {
            for(uint i = 0; i < _ptes.length; i++) {
                if(_ptes[i].name == name) {
                    _ptes[i] = _ptes[_ptes.length - 1];
                    _ptes.pop();
                }
            }
            emit Deleted(name, _pte[name]);
            delete _pte[name];
        }
        _pte[name] = pte;

        for(uint i = 0; i < _ptes.length; i++) {
            if(_ptes[i].name == name) {
                _ptes[i].addr = pte;
            }
        }

        isPte[pte] = true;
        isRegistered[name] = true;

        emit Changed(name, pte);
    }

    /**
     * @dev To get the address of registered Pte
     */
    function getRegisteredPte(bytes32 name) external view override returns (address) {
        return _pte[name];
    }

    /**
     * @dev To get all list of Pte
     */
    function getAllPte() external view override returns (Pte[] memory) {
        return _ptes;
    }
}