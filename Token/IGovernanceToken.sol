// SPDX-License-Identifier: MIT
pragma solidity 0.8.10;
import "../../../../contracts/openzeppelin-contracts/token/ERC20/IERC20.sol";
import "../../../../contracts/openzeppelin-contracts/governance/utils/IVotes.sol";
interface IGovernanceToken is IVotes, IERC20 {
    function mint(address, uint) external;
    function burn(address, uint) external;
    function increaseAllowance(address, uint256) external returns (bool);
}