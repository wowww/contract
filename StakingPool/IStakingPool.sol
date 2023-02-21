// SPDX-License-Identifier: MIT
pragma solidity 0.8.10;

interface IStakingPool {
    function stake(uint, address, uint, uint) external;
    function unstake(uint, address, uint, uint) external;
    function liquidation(uint) external;
    function initialize(uint, address, address, uint) external;
    function updateLockupByPromulgation(uint, uint) external;
    function beforeStake(uint) external returns(uint);

    function isRegisteredDaoId(uint) external view returns (bool);
    function isUnstakeable(uint, address) external view returns (bool);
    function calSwapAmount(uint, uint, uint) external view returns (uint);
    function getStakeAmount(uint, address) external view returns (uint);
}