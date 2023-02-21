// SPDX-License-Identifier: MIT

pragma solidity 0.8.10;

interface ISpellRegistry {
    function isSpell(address) external view returns (bool);
    function addSpell(address) external;
    function removeSpell(uint) external;
    function changeSpell(uint, address) external;
    function getSpell(uint) external view returns (address);
    function isValidSpellType(uint) external view returns (bool);
}