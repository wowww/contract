// SPDX-License-Identifier: MIT

pragma solidity 0.8.10;

struct Pte {
    bytes32 name;
    address addr;
}

/**
 * @title IPteRegistry
 * @author Wemade Pte, Ltd
 * @dev interface of the PteRegistry
 */
interface IPteRegistry {
    function regist(bytes32 name, address pte) external;
    function editPte(bytes32 name, address pte) external;
    function getRegisteredPte(bytes32 name) external view returns (address);
    function getAllPte() external view returns (Pte[] memory);
    function isPte(address pte) external view returns (bool);
    function isRegistered(bytes32 name) external view returns (bool);
}