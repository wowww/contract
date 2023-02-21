// SPDX-License-Identifier: MIT
pragma solidity 0.8.10;

import "./IStation.sol";

/**
 * @title IReOpen
 * @author Wemade Pte, Ltd
 *
 */
interface IReOpentruct is IStationStruct {

    enum ReOpenStatus{READY, OPEN, CLOSE, FAIL, CONFIRM}

    struct ReOpenInfo {
        uint ID;                                                // reopen ID
        uint DAOID;                                             // DAO ID
        uint totalEnterAmount;                                  // accumulate total enter amount
        uint totalRemainAmount;                                 // remain total enter amount
        uint totalRefundAmount;                                 // after reopen success, total refund amount to user
        uint enterCount;                                        // number of user _checkReOpenreopen DAO enter
        uint start;                                             // DAO reopen start time
        uint period;                                            // DAO reopen recruit period
        uint end;                                               // DAO reopen endtime
        uint purposeAmount;                                     // For reopen make, minimum purpose amount
        uint minEnterAmount;                                    // Minimum enter amount
        uint addMintAmount;                                     // add DAO Token amount
        uint unit;                                              // Enter amount unit
        uint price;                                             // price per DT
        address maker;                                          // DAO Reopen maker
        ReOpenStatus status;                                    // reOpen status
        mapping(address => UserInfo) userInfos;           // DAO enter user infos
    }
}

interface IReOpen is IReOpentruct {

    event ChangedOption(bytes32 indexed option, uint data);
    event ChangedPolicy(uint indexed DAOID, uint agendaID, bytes data);
    event ReOpened(uint indexed reOpenID, bytes32 data);
    event ReOpenEntered(uint indexed DAOID, uint indexed reOpenID, address user, uint amount);
    event ReOpenAddEntered(uint indexed DAOID, uint indexed reOpenID, address user, uint amount);
    event ReOpenCanceled(uint indexed DAOID, uint indexed reOpenID, address user, uint amount);
    event ReOpenConfirmed(uint indexed DAOID, uint indexed reOpenID, address user, ReOpenStatus status);
    event ReOpenRefunded(uint indexed DAOID, uint indexed reOpenID, address user, uint amount, bytes32 column);
    event ReOpenRemoved(uint indexed DAOID, uint indexed reOpenID, address user);
    event FundTransferred(uint indexed id, bytes32 indexed column, address indexed token, address to, uint amount);
    event RouterChanged(bytes32 indexed column, address indexed router);
    
    function reOpen(
        uint id, 
        uint period, 
        uint purposeAmount, 
        uint minEnterAmount, 
        uint addMintAmount, 
        uint unit
    ) 
        external;

    function refund(uint reOpenId, address user) external;

    function getReOpenInfo(
        uint reOpenId
    ) 
        view 
        external 
        returns (
            uint ID,
            uint totalEnterAmount,
            uint totalRemainAmount,
            uint totalRefundAmount,            
            uint enterCount,
            uint start,
            uint period,
            uint end,
            uint purposeAmount,
            uint minEnterAmount,
            uint addMintAmount,
            uint unit,
            uint price
        );

    function getUserInfo(uint reopenID, address user) external view returns (UserInfo memory);
    function isValidReOpen(uint reopenID) external view returns (bool);
    function getMintAmount(uint reopenID) external view returns (uint);
    function getDAOID(uint reopenID) external view returns (uint);
    function getReOpenStatus(uint reOpenId) external view returns(ReOpenStatus status);
}