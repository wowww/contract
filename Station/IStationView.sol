// SPDX-License-Identifier: MIT
pragma solidity 0.8.10;

import "./IStation.sol";
/**
 * @title IStationView
 * @author Wemade Pte, Ltd
 *
 */

interface IStationView is IStationStruct {

    function getDAOContractInfo(uint id) external view returns (ContractInfo memory);
    function getRealTimeInfo(uint id) external view returns(RealTimeInfo memory);
    function getDAOBaseInfo(uint id) external view returns (BaseInfo memory);
    function getDAOStatus(uint id) external view returns( DAOStatus);
    function isCoin(uint id) external view returns(bool);    
    function getUserInfo(uint id, address user) external view returns (UserInfo memory);
    function getTokenAddress(uint id) external view returns (address);
    function getStakeRatio(uint id, address user) external view returns (uint);
    function isValidDAO(uint id) external view returns(bool);
    function getTokenCollection(uint id) external view returns (address[] memory, uint[] memory);
    function getMelter(uint id) external view returns (address);
    function getReceiverType(address receiver) external view returns (uint); // 0:pte, 1:melter
        
}