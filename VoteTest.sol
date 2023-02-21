// SPDX-License-Identifier: MIT
pragma solidity 0.8.10;

import "../../../contracts/openzeppelin-contracts/token/ERC20/extensions/ERC20Votes.sol";
contract VoteTest is ERC20Votes {

    constructor(string memory name, string memory symbol) ERC20Permit(name) ERC20(name, symbol){}

    function mint(address account, uint amount) external {
        delegate(account);
        super._mint(account,amount);
    }
}