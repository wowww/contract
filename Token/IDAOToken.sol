// SPDX-License-Identifier: MIT
pragma solidity 0.8.10;

import "../../../../contracts/openzeppelin-contracts/token/ERC20/IERC20.sol";

interface IDAOToken is IERC20 {
    function mint(uint) external;
    function burn(address, uint) external;
}