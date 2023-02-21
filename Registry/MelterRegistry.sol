// SPDX-License-Identifier: MIT

pragma solidity 0.8.10;

import "./IMelterRegistry.sol";
import "../Role/EditorRole.sol";
import "../../../../contracts/openzeppelin-contracts/utils/Address.sol";

/**
 * @title MelterRegistry
 * @author Wemade Pte, Ltd
 * @dev Register the EOA of melter who purchase and burn DT
 */
contract MelterRegistry is IMelterRegistry, EditorRole {

    using Address for address;

    address[] private _melters;
    mapping(address => bool) public override isMelter;

    event Registered(address indexed melter);
    event Deleted(address indexed melter);

    /**
     * @dev Regist address of Melter
     * @param melter Melter address
     */
    function regist(address melter) external override onlyEditor {
        require(melter != address(0), "MR0-RG0-020");
        require(!isMelter[melter], "MR0-RG0-520");

        _melters.push(melter);
        isMelter[melter] = true;

        emit Registered(melter);
    }

    /**
     * @dev Delete address of Melter
     * @param melter Melter address
     */
    function deleteMelter(address melter) external override onlyEditor {
        require(isMelter[melter], "MR0-DM0-520");
        
        for(uint i = 0; i < _melters.length; i++) {
            if(_melters[i] == melter) {
                _melters[i] = _melters[_melters.length - 1];
                _melters.pop();
            }
        }

        isMelter[melter] = false;

        emit Deleted(melter);
    }

    function getAllMelter() external view returns (address[] memory) {
        return _melters;
    }
}