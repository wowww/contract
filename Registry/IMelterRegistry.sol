// SPDX-License-Identifier: MIT

pragma solidity 0.8.10;

/**
 * @title IMelterRegistry
 * @author Wemade Pte, Ltd
 * @dev interface of the MelterRegistry
 */
interface IMelterRegistry {
    function regist(address melter) external;
    function deleteMelter(address melter) external;
    function getAllMelter() external view returns (address[] memory);
    function isMelter(address melter) external view returns (bool);
}