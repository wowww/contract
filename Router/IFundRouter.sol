// SPDX-License-Identifier: MIT
import "../Station/IStation.sol";

pragma solidity 0.8.10;

interface IFundRouter is IStationStruct {
    // station
    function transferToTreasury(uint id, address token, uint amount, RecruitType recruitType) external payable;

    // spell
    function transferToReceiver(uint id, bytes32 business) external;
    function swap(uint id, uint amountIn, uint amountOutMin, address[] calldata path) external;
    function liquidate(uint id) external;

    function components() external view returns(address[] memory);
}