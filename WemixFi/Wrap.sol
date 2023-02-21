// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

import "../../../../contracts/openzeppelin-contracts/token/ERC20/ERC20.sol";

contract Wrap is ERC20 {
    constructor(string memory name, string memory symbol) ERC20(name, symbol){}

    function mint() external payable {
        super._mint(msg.sender, msg.value);
    }

    function burn(uint amount) external payable returns(bool) {
        super._burn(msg.sender, amount);
        (bool status, ) = payable(msg.sender).call{value: amount}("");
        return status;
    }
}