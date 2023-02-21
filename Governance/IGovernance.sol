// SPDX-License-Identifier: MIT
pragma solidity 0.8.10;

import "../Station/IStation.sol";

interface IGovernanceStruct is IStationStruct {
    enum Status {CONSENSUS, PROPOSAL, DONE, REJECT, FAIL}
    enum VoteType {NONE, AGREEMENT, OPPOSITE}
    enum Request {CANCEL, RECLAIM}

    struct Info {
        address creator;                // agenda creator address
        uint blockNum;                  // Creation time block number
        uint start;                     // agenda voting start time. Creation time
        uint totalVote;                 // snap shot of gt totalsupply
        uint spellType;                 // spell type that this agenda will use
        bytes params;                   // abi.encdeWithSelector(bytes4(keccak256("cast(Params)")), params)
    }

    struct Agenda {
        uint permitedTime;              // last permited time. created time => permit consensus step time => permit proposal step time
        Status status;                  // current status
        BasePolicy basePolicy;          // basepolicy for agende
        SubPolicy[2] subPolicy;         // subpolicy for agenda
        Info info;                      // agenda info 
        VoteStatus[2] board;            // vote status per steps, [CONSENSUS, PROPOSAL]
    }

    struct VoteStatus {
        uint total;                     // total vote num
        uint obligationAmount;          // creator obligation amount. not ratio
        uint[3] voteBox;                // sum of num per vote type, [NONE, AGREEMENT, OPPOSITE]
    }

    struct VoteInfo {
        bool isReclaimed;               // check user reclaimed
        VoteType vote;                  // vote type
        uint num;                       // number of vote
    }

    struct Policy {
        BasePolicy basePolicy;                          // base policy per dao
        mapping(uint => SubPolicy[2]) subPolicy;        // spellType => steps, [CONSENSUS, PROPOSAL]
    }

    struct BasePolicy {
        uint baseRatio;                 // rate of gt that needs to create agenda
        uint promulgationPeriod;        // unstake lock time for 
    }

    struct SubPolicy {
        uint permitCutOff;              // rate of votes to permit the agenda
        uint quorum;                    // rate of quorum
        uint deadLine;                  // step deadline
        uint obligation;                // proposer's obligation vote ratio
    }
}
interface IGovernance is IGovernanceStruct {
    // creator, daoId, spellType, start, totalVote, bytes memory params
    function createAgenda(address, uint, uint, uint, uint, uint, uint, bytes memory) external;
    // daoId, agendaId, user, agreement, num
    function vote(uint, uint, address, VoteType, uint) external;
    // daoId, agendaId, user
    function cancel(uint, uint, address) external returns (uint);
    // daoId, spellType, purpose, Policy memory policy
    function setPolicy(uint, uint, BasePolicy memory, SubPolicy[2] memory) external;
    // daoId, promulgationPeriod, unit, quorum, consensusObligation, proposalObligation
    function setDefaultPolicy(uint, uint, uint, uint, uint) external;
    // daoId, agendaId, user
    function reclaimGT(uint, uint, address) external returns (uint);
    // daoId, spellType
    function renew(uint, uint) external;
    
    // daoId, agendaId
    function getInfo(uint, uint) external view returns(Info memory);
    // daoId
    function getCurrentId(uint) external view returns(uint);
    // daoId spellType user status
    function getVoterInfo(uint, uint, address) external view returns(VoteInfo[2] memory);
    // daoId spellType status
    function getPolicy(uint, uint) external view returns(BasePolicy memory, SubPolicy[2] memory);
    // daoId agendaId
    function isValidId(uint, uint) external view returns (bool);
    // daoId agendaId user
    function isVoted(uint, uint, address) external view returns (bool);
    // daoId agendaId user opinion
    function isSameVote(uint, uint, address, VoteType) external view returns (bool);
    // daoId agendaId user opinion
    function getAvailableNum(uint, uint, address, address) external view returns (uint);
    // daoId, agendaId
    function getBoard(uint, uint) external view returns (VoteStatus[2] memory);
    // daoId, agendaId
    function getAgenda(uint, uint) external view returns (Agenda memory);
}

interface ILockUp {
    function updateLockupByPromulgation(uint, uint) external;
}