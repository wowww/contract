// SPDX-License-Identifier: MIT
pragma solidity 0.8.10;

interface ISpell {
    function isValidParams(bytes memory, uint) external view returns(bool);
}