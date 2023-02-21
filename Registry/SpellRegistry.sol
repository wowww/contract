// SPDX-License-Identifier: MIT

pragma solidity 0.8.10;

import "./ISpellRegistry.sol";
import "../Role/EditorRole.sol";
import "../../../../contracts/openzeppelin-contracts/access/Ownable.sol";
import "../../../../contracts/openzeppelin-contracts/utils/Address.sol";
import "../../../../contracts/openzeppelin-contracts/utils/Counters.sol";
/**
 *  spellType => spell
 *  [Must Fixed]
 *  0 => treasurySpell
 *  2 => liquidationSpell
 */
contract SpellRegistry is EditorRole, ISpellRegistry {
    using Address for address;
    using Counters for Counters.Counter;

    Counters.Counter private _spellType;
    mapping(address => bool) private _isRegistred;
    mapping(uint => address) private _spells;

    event SpellAdded(uint spellType, address spell);
    event SpellRemoved(uint spellType, address spell);
    event SpellChanged(uint spellType, address spell);

    function isSpell(address spell) external view override returns (bool) {
        return _isRegistred[spell];
    }

    function addSpell(address spell) external override onlyEditor {
        require(spell.isContract(), "SR0-AS0-020");
        require(!_isRegistred[spell], "SR0-AS0-520");

        _spells[_spellType.current()] = spell;
        _isRegistred[spell] = true;
        _spellType.increment();

        addEditor(spell);

        emit SpellAdded(_spellType.current(), spell);
    }

    function removeSpell(uint spellType) external override onlyEditor {
        address spell = _spells[spellType];
        _isRegistred[spell] = false;
        _spells[spellType] = address(0);

        if(isEditor(spell)) {
            removeEditor(spell);
        }

        emit SpellRemoved(spellType, spell);
    }

    function changeSpell(uint spellType, address spell) external override onlyEditor {
        if (isValidSpellType(spellType) && spell.isContract()) {
            address oldSpell = _spells[spellType];
            _isRegistred[oldSpell] = false;
            _spells[spellType] = spell;
            _isRegistred[spell] = true;
            
            removeEditor(oldSpell);
            addEditor(spell);

            emit SpellChanged(spellType, spell);
        }
    }

    function getSpell(uint spellType) external view override returns (address) {
        return _spells[spellType];
    }

    function isValidSpellType(uint spellType) public view returns (bool) {
        return _spells[spellType] != address(0);
    }
}