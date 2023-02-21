// SPDX-License-Identifier: MIT
pragma solidity 0.8.10;

import "./ISpell.sol";
import "../Role/EditorRole.sol";
import "../Station/IStationView.sol";
import "../Registry/ISpellRegistry.sol";
import "./IGovernance.sol";
import "../../../../contracts/openzeppelin-contracts/utils/Context.sol";

abstract contract SpellBase is ISpell, Context, EditorRole {
    address immutable internal _governance;
    IStationView immutable internal _station;
    ISpellRegistry immutable private _spellRegistry;

    uint internal _baseUnit = 1 ether;

    uint[] private _deadline;   // idx = 0 => consensus, idx = 1 => proposal

    constructor(
        address governance,
        address station,
        address spellRegistry
    )
    {
        _governance = governance;
        _station = IStationView(station);
        _spellRegistry = ISpellRegistry(spellRegistry);
    }

    modifier onlyGovernance() {
        require(_msgSender() == _governance, "SB0-MDF-520");
        _;
    }

    /**
     *  @dev check param is valid before create agenda
        current solidity version does not support error handling for abi.decode() function
        it must upgrade when solidity support error hadling
     */
    function isValidParams(bytes calldata, uint) external view virtual override returns (bool) {}

    function _getGovernance() internal view returns (address) {
        return _governance;
    }

    function _isValidDaoId(uint daoId, uint compareId) internal view returns (bool) {
        return _station.isValidDAO(daoId) && daoId == compareId;
    }

    function _isValidSpellType(uint spellType) internal view returns (bool) {
        return _spellRegistry.isValidSpellType(spellType);
    }
}