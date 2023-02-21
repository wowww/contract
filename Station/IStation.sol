// SPDX-License-Identifier: MIT
pragma solidity 0.8.10;

/**
 * @title IStation
 * @author Wemade Pte, Ltd
 *
 */
interface IStationStruct {

    enum CurrencyType{COIN, TOKEN}
    enum RecruitType{DAO, REOPEN}
    enum DAOStatus{READY, OPEN, CLOSE, FAIL, CONFIRM, DISSOLVE}
    enum UserStatus{NONE, ENTER, REFUND}

    struct DAO {
        uint ID;                                        // DAO ID
        RealTimeInfo realTimeInfo;                      // DAO realTime info
        BaseInfo baseInfo;                              // DAO base info
        ContractInfo contractInfo;                      // DAO token, staking contract address info
        DAOStatus status;                               // DAO current status
        mapping(address => UserInfo) userInfos;         // DAO enter user infos
    }

    struct RealTimeInfo {
        uint totalEnterAmount;                          // accumulate total enter amount
        uint totalRemainAmount;                         // remain total enter amount
        uint totalRefundAmount;                         // after DAO success, total refund amount to user
        uint enterCount;                                // number of user multiple enter DAO
        uint txCount;                                   // number of transaction count
        uint Price;                                     // price per DT
    }

    struct BaseInfo {
        bytes32 name;                                   // DAO name
        address maker;                                  // DAO maker
        address melter;                                 // DAO systemWallet
        address token;                                  // Token Address of DAO fund
        uint start;                                     // DAO open start time
        uint end;                                       // DAO open end time
        uint minEnterAmount;                            // Minimum enter amount
        uint purposeAmount;                             // For DAO make, minimum purpose amount
        uint businessAmount;                            // In purpose amount, business amount
        uint unit;                                      // Enter amount unit
        uint promulgationPeriod;                        // Lock-up period after passing the agenda
        uint consensusObligation;                       // In consensus proccess, The amount by which proposers of the agenda are obligated to vote
        uint proposalObligation;                        // In Proposal proccess, The amount by which proposers of the agenda are obligated to vote 
        uint dtLockupTime;                              // stakingPool Lockup Time
        CurrencyType currencyType;                      // DAO currency type for open
    }

    struct ContractInfo {
        DTInfo dtInfo;
        GTInfo gtInfo;
    }

    struct DTInfo {
        address cAddress;                               // DAO token contract address
        string name;                                    // token name
        string symbol;                                  // token symbol
        uint totalSupply;                               // token supply amount
    }

    struct GTInfo {
        address cAddress;                               // Governance token contract address
    }

    struct UserInfo {
        uint amount;                                    // user enter amount
        uint stakeRatio;                                // user stake ratio
        bool isDTReceive;
        UserStatus status;
    }

}

interface IStation is IStationStruct {

    event Created(uint indexed DAOID, bytes32 name, address maker, CurrencyType currencyType);
    event Entered(uint indexed DAOID, address user, uint amount);
    event Canceled(uint indexed DAOID, address user, uint amount);
    event Confirmed(uint indexed DAOID, address user, DAOStatus status);
    event Deployed(uint indexed DAOID, address token, address staking, address user);
    event Refunded(uint indexed DAOID, address user, uint amount, bytes32 column);
    event DisSolved(uint indexed DAOID, address user);
    event Removed(uint indexed DAOID, address user);
    event TransferedToTreasury(uint indexed DAOID, RecruitType recruitType);
    event Liquidated(uint indexed DAOID, address user);
    event UpdatedUserInfo(uint indexed DAOID, address user, UserInfo userInfo);
    event FundTransferred(uint indexed id, bytes32 indexed column, address indexed token, address to, uint amount);
    event ChangedOption(bytes32 indexed option, uint data);
    event ChangedPolicy(uint indexed DAOID, uint agendaID, bytes data);
    event RouterChanged(bytes32 indexed column, address indexed router);
    event SetTokenCollection(uint indexed DAOID, address[] tokenlist, uint[] amounts);

    function changeCurrencyType(
        uint id, 
        CurrencyType currencyType
    ) 
        external;
        
    function dissolve(uint id) external;
    function refund(uint id, address user) external;
    function setTokenCollection(uint id, address[] memory tokenlist, uint[] memory amounts) external;
    function updateUserInfo(uint id, address user, UserInfo memory userInfo) external;
}