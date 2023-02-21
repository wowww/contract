// SPDX-License-Identifier: MIT
pragma solidity 0.8.10;

import "./ISpell.sol";
import "../Station/IStationView.sol";
import "../Common/Queue.sol";
import "./Payment/IPayment.sol";
import "./IGovernance.sol";
import "../Role/Upgradeable/RouterRoleUpgradeable.sol";
import "../Registry/ISpellRegistry.sol";
import "../Token/IGovernanceToken.sol";
import "../../../../contracts/openzeppelin-contracts/utils/Counters.sol";
import "../../../../contracts/openzeppelin-contracts/proxy/utils/UUPSUpgradeable.sol";

contract Governance is UUPSUpgradeable, IGovernance, IPaymentStruct, RouterRoleUpgradeable {
    using Queue for Queue.queue;
    using Counters for Counters.Counter;

    ISpellRegistry private _spellRegistry;
    IPayment private _payment;
    address private _station;
    address private _stakingPool;
    uint private DEFAULTSPELL;
    uint private TREASURYSPELL;
    uint private LIQUIDATIONSPELL;
    uint private UNIT;
    
    // DAO id to mapping data
    mapping(uint => Counters.Counter) private _ids;                                        // agneda ids
    mapping(uint => mapping(uint => Agenda)) private _agendas;
    mapping(uint => mapping(uint => Queue.queue[2])) private _steps;                       // daoId => (spell type => (status => queue)), queue for steps (consensus, proposal)
    mapping(uint => Policy) private _policys;                                              // daoId => (spellType => (Status => policy)), vote policy per spell type
    mapping(address => mapping(uint => mapping(uint => VoteInfo[2]))) private _voters;     // user => (dao id => (agendaId => vote type)), voter info
    mapping(uint => Policy) private _defaultPolicies;                                      // daoId => Policy, default vote policy
    mapping(uint => mapping(address => uint)) public totalObligation;                      // daoId => user => amount

    event AgendaCreated(uint indexed daoId, uint indexed id, uint indexed spellType);
    event Voted(uint indexed daoId, uint indexed id, VoteType indexed opinion, uint num);
    event Canceled(uint indexed daoId, uint indexed agendaId, address indexed user, uint amount);
    event Permited(uint indexed daoId, uint indexed id);
    event Rejected(uint indexed daoId, uint indexed id);
    event Excuted(uint indexed daoId, uint indexed id, uint indexed spellType);
    event ExcutedFail(uint indexed daoId, uint indexed agendaId, uint indexed spellType);

    constructor(){
        _disableInitializers();
    }

    modifier onlySpell() {
        require(_spellRegistry.isSpell(_msgSender()), "GV0-MDF-520");
        _;
    }

    modifier onlyStation() {
        require(_msgSender() == _station, "GV0-MDF-521");
        _;
    }

    /**
     * @dev init function running when GovernanceProxy contract is deploying
     * @param station address of station view contract
     * @param payment address of payment contract
     * @param spellRegistry spellRegistry address
     * @param router dao router address
     * @param stakingPool stakingPool address
     */
    function initProxy(
        address station,
        address payment,
        address spellRegistry,
        address router,
        address stakingPool
    )
        external
        initializer
    {
        __AccessControl_init();

        _payment = IPayment(payment);
        _spellRegistry = ISpellRegistry(spellRegistry);
        _station = station;
        _stakingPool = stakingPool;

        addRouter(router);
        
        TREASURYSPELL = 0;
        LIQUIDATIONSPELL = 1;
        DEFAULTSPELL = 0;
        UNIT = 1 ether;
    }

    /**
     * @dev create governance agenda
     * @param creator user address who suggest agenda
     * @param daoId target dao id
     * @param spellType agenda spell type
     * @param start vote start timestamp
     * @param totalVote total number of votes
     * @param cObligation obligate amount of consensus step
     * @param pObligation obligate amount of proposal step
     * @param params agenda spell params
     */
    function createAgenda(
        address creator,
        uint daoId, 
        uint spellType, 
        uint start, 
        uint totalVote,
        uint cObligation,
        uint pObligation,     
        bytes memory params
    )
        external
        override
        onlyRouter
    {
        //create == temperature proposal
        _ids[daoId].increment();
        uint id = _ids[daoId].current();

        if(spellType == TREASURYSPELL) {
            _payment.setInfo(params, daoId, id);
        }

        Info memory info = Info({
            creator: creator,
            blockNum: block.number,
            start: start,
            totalVote: totalVote,
            spellType: spellType,
            params: params
        });

        _createAgenda(daoId, id, info, Status.CONSENSUS, cObligation, pObligation);

        emit AgendaCreated(daoId, id, spellType);
    }

    /**
     * @dev vote agenda 
     * @param daoId target dao id
     * @param agendaId agenda id
     * @param user vote user
     * @param opinion GT holder's opinion [none, agreement, opposite]
     * @param num vote number
     */
    function vote(uint daoId, uint agendaId, address user, VoteType opinion, uint num) external override onlyRouter {
        _vote(daoId, agendaId, user, opinion, num);
    }

    /**
     *  @dev cancel vote
     *  @param daoId target dao id
     *  @param agendaId agenda id
     *  @param user calcel user
     */
    function cancel(uint daoId, uint agendaId, address user) external override onlyRouter returns (uint) {
        return _cancel(daoId, agendaId, user);
    }

    /**
     * @dev change voting policy by each dao
     * @param daoId target dao id
     * @param spellType target spell type
     * @param basePolicy new basePolicy
     * @param subPolicy new subPolicys
     */
    function setPolicy(uint daoId, uint spellType, BasePolicy memory basePolicy, SubPolicy[2] memory subPolicy) external override onlySpell {
        _policys[daoId].basePolicy = basePolicy;
        // consensus
        _policys[daoId].subPolicy[spellType][0] = subPolicy[0]; 
        // proposal
        _policys[daoId].subPolicy[spellType][1] = subPolicy[1]; 
    }

    /**
     *  @dev set default vote policy
     *  @param daoId target dao id
     *  @param promulgationPeriod can not unstake period
     *  @param quorum create agenda quorum percentage
     *  @param consensusObligation creator's must vote ratio for consensus steps 
     *  @param proposalObligation creator's must vote ratio for proposal steps 
     */
    function setDefaultPolicy(
        uint daoId,
        uint promulgationPeriod,
        uint quorum,
        uint consensusObligation,
        uint proposalObligation
    ) 
        external
        override
        onlyStation
    {
        _defaultPolicies[daoId].basePolicy = BasePolicy(quorum, promulgationPeriod);
        // consensus step policy
        // 110%
        _defaultPolicies[daoId].subPolicy[DEFAULTSPELL][0] = SubPolicy(UNIT / 2, (quorum * 11) / 10, 3 days, consensusObligation);
        // proposal step policy
        // 120%
        _defaultPolicies[daoId].subPolicy[DEFAULTSPELL][1] = SubPolicy(UNIT / 2, (quorum * 12) / 10, 5 days, proposalObligation);
    }

    /**
     *  @dev renew queues
     */
    function renew(uint daoId, uint spellType) external override onlyRouter { 
        _renew(daoId, spellType, Status.CONSENSUS);
        _renew(daoId, spellType, Status.PROPOSAL);
    }

    /**
     *  @dev reclaimGT for closed vote step
     *  @param daoId target dao id
     *  @param agendaId target agenda id
     *  @param user user address
     */
    function reclaimGT(uint daoId, uint agendaId, address user) external override onlyRouter returns (uint) {
        Agenda memory agenda = _agendas[daoId][agendaId];

        if(uint(agenda.status) == 1) {
            // proposal
            return _refund(daoId, agendaId, user, Status.CONSENSUS, Request.RECLAIM);
        }else if(uint(agenda.status) > 1) {
            // others
            return _refund(daoId, agendaId, user, Status.CONSENSUS, Request.RECLAIM) + _refund(daoId, agendaId, user, Status.PROPOSAL, Request.RECLAIM);
        }else {
            // consensus
            return 0;
        }
    }

    function getAgenda(uint daoId, uint agendaId) external view override returns (Agenda memory) {
        return _agendas[daoId][agendaId];
    }

    function getInfo(uint daoId, uint agendaId) external view override returns(Info memory) {
       return _agendas[daoId][agendaId].info;
    }

    function getCurrentId(uint daoId) external view override returns(uint) {
       return _ids[daoId].current();
    }

    function getBoard(uint daoId, uint agendaId) external view override returns (VoteStatus[2] memory) {
        return _agendas[daoId][agendaId].board;
    }

    function getPolicy(uint daoId, uint spellType) external view override returns(BasePolicy memory, SubPolicy[2] memory) {
        return _getPolicy(daoId, spellType);
    }

    /**
     *  @dev get number of vote that user can use
     */
    function getAvailableNum(uint daoId, uint agendaId, address user, address gtAddress) external override view returns (uint) {
        Agenda memory agenda = _agendas[daoId][agendaId];
        uint agendaBlock = agenda.info.blockNum;
        // blocknumber User GT Amount
        uint gBlockAmount = IGovernanceToken(gtAddress).getPastVotes(user, agendaBlock);
        // current User GT Amount
        uint gCurrentAmount = IGovernanceToken(gtAddress).getVotes(user);
        uint availableNum = gCurrentAmount < gBlockAmount ? gCurrentAmount : gBlockAmount;

        return availableNum - totalObligation[daoId][user];
    }


    function getVoterInfo(uint daoId, uint agendaId, address user) public override view returns(VoteInfo[2] memory) {
        return _voters[user][daoId][agendaId];
    }

    /**
     * @dev check agendaId is valid
     */
    function isValidId(uint daoId, uint agendaId) external view override returns (bool) {
        Agenda memory agenda = _agendas[daoId][agendaId];
        Status status = agenda.status;

        if(status != Status.CONSENSUS && status != Status.PROPOSAL) {
            return false;
        }

        uint aliveTime = agenda.subPolicy[uint(status)].deadLine;

        return agendaId != 0 
            && agendaId <= _ids[daoId].current()
            && block.timestamp < agenda.permitedTime + aliveTime;
    }

    /**
     * @dev check user already voted
     */
    function isVoted(uint daoId, uint agendaId, address user) external override view returns (bool) {
        Status status = _agendas[daoId][agendaId].status;
        VoteInfo[2] memory voter = getVoterInfo(daoId, agendaId, user);

        return voter[uint(status)].num != 0;
    }

    /**
     *  @dev check opinion is same when revoted
     */
    function isSameVote(uint daoId, uint agendaId, address user, VoteType opinion) external override view returns (bool) {
        Agenda memory agenda = _agendas[daoId][agendaId];
        Status status = agenda.status;

        VoteInfo[2] memory voter = getVoterInfo(daoId, agendaId, user);

        return voter[uint(status)].num == 0 || voter[uint(status)].vote == opinion;
    }

     /**
     * @dev execute agenda when all process was permited
     * @param daoId target dao id
     */
    function _execute(uint daoId, uint agendaId) private {
        Info memory info = _agendas[daoId][agendaId].info;
        address spellAddr = _spellRegistry.getSpell(info.spellType);
        
        (bool resStatus, bytes memory res) = address(spellAddr).call(info.params);
        (bool status) = abi.decode(res, (bool));
        
        if(resStatus && status) {
            _agendas[daoId][agendaId].status = Status.DONE;

            emit Excuted(daoId, agendaId, info.spellType);
        }else{
            _agendas[daoId][agendaId].status = Status.FAIL;

            emit ExcutedFail(daoId, agendaId, info.spellType);
        }
    }
    
    function _permit(uint daoId, uint agendaId) private {
        Agenda storage agenda = _agendas[daoId][agendaId];
        uint spellType = agenda.info.spellType;
        Status status =  agenda.status;

        totalObligation[daoId][agenda.info.creator] -= agenda.board[uint(status)].obligationAmount;

        if(status == Status.PROPOSAL) {
            // updateLockupByPromulgation
            ILockUp(_stakingPool).updateLockupByPromulgation(daoId, block.timestamp + agenda.basePolicy.promulgationPeriod);
            _execute(daoId, agendaId);
        }else {
            // append new queue
            status = Status(uint(status) + 1);
            agenda.status = status;

            _steps[daoId][spellType][uint(status)].append(agendaId);
            address gtAddress =  IStationView(_station).getDAOContractInfo(daoId).gtInfo.cAddress;
            agenda.info.totalVote = IERC20(gtAddress).totalSupply();
        }
        
        // renew permited time
        agenda.permitedTime = block.timestamp;
        
        emit Permited(daoId, agendaId);
    }

    function _reject(uint daoId, uint agendaId) private {
        Agenda storage agenda = _agendas[daoId][agendaId];

        totalObligation[daoId][agenda.info.creator] -= agenda.board[uint(Status.CONSENSUS)].obligationAmount;
        
        if(agenda.status == Status.CONSENSUS) {
            totalObligation[daoId][agenda.info.creator] -= agenda.board[uint(Status.PROPOSAL)].obligationAmount;
        }

        agenda.status = Status.REJECT;

        emit Rejected(daoId, agendaId);
    }

    function _createAgenda(uint daoId, uint agendaId, Info memory info, Status initStatus, uint cObligation, uint pObligation) private {
       
        Agenda storage newAgenda = _agendas[daoId][agendaId];
        uint spellType = info.spellType;
        uint start = info.start;
        address creator = info.creator;

        newAgenda.permitedTime = start;
        newAgenda.status = initStatus;
        (BasePolicy memory basePolicy, SubPolicy[2] memory subPolicy) = _getPolicy(daoId, spellType);

        newAgenda.basePolicy = basePolicy;
        newAgenda.subPolicy[0] = subPolicy[0];
        newAgenda.subPolicy[1] = subPolicy[1];

        newAgenda.info = info;

        newAgenda.board[0].obligationAmount = cObligation;
        newAgenda.board[1].obligationAmount = pObligation;

        totalObligation[daoId][creator] += (cObligation + pObligation);

        // consensus
        _vote(daoId, agendaId, creator, Status.CONSENSUS, VoteType.AGREEMENT, cObligation);
        // proposal
        _vote(daoId, agendaId, creator, Status.PROPOSAL, VoteType.AGREEMENT, pObligation);

        // append queue
        _steps[daoId][spellType][uint(initStatus)].append(agendaId);
    }

    function _isPassed(uint daoId, uint agendaId, Status status) private view returns(bool) {
        Agenda memory agenda = _agendas[daoId][agendaId];
        uint totalVote = agenda.info.totalVote;
        VoteStatus memory board = agenda.board[uint(status)];

        // immediately
        if(_isImmediatelyDecide(daoId, agendaId, status, VoteType.AGREEMENT)) {
            return true;
        }
       
        (, SubPolicy[2] memory subPolicy) = _getPolicy(daoId, agenda.info.spellType);

        uint totalVoter = board.total;
        uint quorum = (totalVote * subPolicy[uint(status)].quorum) / UNIT;

        if(totalVoter >= quorum) {
            uint cutOff = (quorum * subPolicy[uint(status)].permitCutOff) / UNIT;
            
            if(board.voteBox[uint(VoteType.AGREEMENT)] > cutOff) {
                return true;
            }
        }

        return false;
    }

    function _isImmediatelyDecide(uint daoId, uint agendaId, Status status, VoteType opinion) private view returns (bool) {
        Agenda memory agenda = _agendas[daoId][agendaId];
        VoteStatus memory board = agenda.board[uint(status)];
        (, SubPolicy[2] memory subPolicy) = _getPolicy(daoId, agenda.info.spellType);

        uint totalVote = agenda.info.totalVote;
        uint half = totalVote / 2;
        uint voteAmount = board.voteBox[uint(opinion)];
        uint quorum = (board.total * subPolicy[uint(status)].quorum) / UNIT;
        uint cutOff = (quorum * subPolicy[uint(status)].permitCutOff) / UNIT;

        uint conditionAmount = half >= cutOff ? half : cutOff;
        
        return voteAmount > conditionAmount;
    }

    function _renew(uint daoId, uint spellType, Status status) private {
        Queue.queue storage queue = _steps[daoId][spellType][uint(status)];
        uint length = queue.getLength();
        uint point = block.timestamp;
        uint begin = queue.begin;
        for(; begin < length;) {
            uint agendaId = queue.data[begin];
            Agenda memory agenda = _agendas[daoId][agendaId];
            
            if(agenda.status != status){
                // already decided
                queue.popLeft();
                begin = queue.begin;
                continue;
            }

            uint aliveTime = agenda.subPolicy[uint(agenda.status)].deadLine;
            if(point > agenda.permitedTime + aliveTime) {
                queue.popLeft();
                begin = queue.begin;
                
                if(_isPassed(daoId, agendaId, status)) {
                    _permit(daoId, agendaId);
                }else {
                    _reject(daoId, agendaId);
                }
            }else {
                break;
            }
        }
    }

    function _vote(uint daoId, uint agendaId, address user, VoteType opinion, uint num) private {
        Agenda memory agenda = _agendas[daoId][agendaId];
        _vote(daoId, agendaId, user, agenda.status, opinion, num);
    }

    function _vote(uint daoId, uint agendaId, address user, Status status, VoteType opinion, uint num) private {
        VoteStatus storage board = _agendas[daoId][agendaId].board[uint(status)];

        board.total += num;
        board.voteBox[uint(opinion)] += num;

        VoteInfo storage voteInfo =  _voters[user][daoId][agendaId][uint(status)];
        voteInfo.vote = opinion;
        voteInfo.num += num;

        // check permit/reject immediately
        if(_agendas[daoId][agendaId].status == status && _isImmediatelyDecide(daoId, agendaId, status, opinion)) {
            if(opinion == VoteType.AGREEMENT) {
                // permit immediately
                _permit(daoId, agendaId);
            }else {
                // reject immediately
                _reject(daoId, agendaId);
            }
        }

        address gtAddress = IStationView(_station).getDAOContractInfo(daoId).gtInfo.cAddress;
        IGovernanceToken(gtAddress).increaseAllowance(_msgSender(), num);

        emit Voted(daoId, agendaId, opinion, num);
    }

    function _cancel(uint daoId, uint agendaId, address user) private returns (uint) {
        Agenda memory agenda = _agendas[daoId][agendaId];
        
        uint canceledAmount = _refund(daoId, agendaId, user, agenda.status, Request.CANCEL);

        emit Canceled(daoId, agendaId, user, canceledAmount);

        return canceledAmount;
    }

    function _refund(uint daoId, uint agendaId, address user, Status status, Request request) private returns (uint) {
        uint voteStatus = uint(status);
        VoteStatus storage board = _agendas[daoId][agendaId].board[voteStatus];

        VoteInfo storage voter = _voters[user][daoId][agendaId][voteStatus];
        
        VoteType opinion = voter.vote;
        uint num = voter.num;

        if(request == Request.CANCEL) {
            if(_agendas[daoId][agendaId].info.creator == user) {
                num = voter.num - board.obligationAmount;
            }
            board.total -= num;
            board.voteBox[uint(opinion)] -= num;
            voter.num -= num;

            if(voter.num == 0) {
                voter.vote = VoteType.NONE;
            }
        }else {
            if(voter.isReclaimed) {
                num = 0;
            }else {
                voter.isReclaimed = true;
            }
        }

        return num;
    }

    function _getPolicy(uint daoId, uint spellType) private view returns(BasePolicy memory basePolicy, SubPolicy[2] memory subPolicy) {
        basePolicy = _policys[daoId].basePolicy;
        subPolicy = _policys[daoId].subPolicy[spellType];
        if(subPolicy[uint(Status.CONSENSUS)].permitCutOff == 0 && subPolicy[uint(Status.PROPOSAL)].permitCutOff == 0) {
            BasePolicy memory defaultBasePolicy = _defaultPolicies[daoId].basePolicy;
            SubPolicy[2] memory defaultSubPolicy = _defaultPolicies[daoId].subPolicy[DEFAULTSPELL];

            if (spellType == LIQUIDATIONSPELL) {
                defaultSubPolicy[0].deadLine = 5 days;
                defaultSubPolicy[1].deadLine = 10 days;
            }

            basePolicy = defaultBasePolicy;
            subPolicy = defaultSubPolicy;
        }
    }

    function _authorizeUpgrade(address newImplementation) internal virtual override onlyEditor {}
}