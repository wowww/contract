// SPDX-License-Identifier: MIT
pragma solidity 0.8.10;

import "./IDAORouter.sol";
import "../Registry/ISpellRegistry.sol";
import "../Registry/IPteRegistry.sol";
import "../Role/EditorRole.sol";
import "../Token/IGovernanceToken.sol";
import "../Token/IDAOToken.sol";
import "../StakingPool/IStakingPool.sol";
import "../Station/IStationView.sol";
import "../Station/IStation.sol";
import "../Station/IReOpen.sol";
import "../Components/Trust/ITrust.sol";
import "../Governance/ISpell.sol";
import "../Governance/IGovernance.sol";
import "../Governance/Payment/IPayment.sol";
import "../Common/DAOPausable.sol";
import "../../../../contracts/openzeppelin-contracts/security/Pausable.sol";
import "../../../../contracts/openzeppelin-contracts/utils/Address.sol";
import "../../../../contracts/openzeppelin-contracts/token/ERC20/utils/SafeERC20.sol";

/**
 * @title DAORouter 
 * Corresponds to the Router of Contracts.
 * Users receive stake, unstake, agenda creation, voting, execution, and DAOToken, and the logic is in the contract.
 * @author Wemade Pte, Ltd
 *
 */

contract DAORouter is IDAORouter, IReOpentruct, EditorRole, DAOPausable {

    using Address for address;
    using SafeERC20 for IERC20;

    address private _station;
    address private _incinerator;
    address private _stakingPool;
    address private _governance;
    address private _spellRegistry;
    address private _pteRegistry;
    address private _payment;
    address private _trust;
    address private _reopen;

    uint public denominator = 1 ether;           // denominator
    bool public isInit;

    event ReceivedDT(uint indexed id, uint amount);
    event ReceivedReOpenDT(uint indexed id, uint amount);
    event ReClaimedGT(uint indexed id, uint agendaId, uint amount);
    event ChangedOption(bytes32 indexed option, uint data);

    receive() external payable {}
    
    fallback() external payable {}

    modifier onlyStation() {
        require(msg.sender == _station || isEditor(msg.sender) , "DR0-MDF-520");
        _;
    }

    modifier onlyIncinerator() {
        require(msg.sender == _incinerator, "DR0-MDF-521");
        _;
    }

    modifier isValidDAO(uint id) {
        require(IStationView(_station).isValidDAO(id), "DR0-MDF-510");
        _;
    }

    modifier isValidReOpen(uint reOpenID) {
        require(IReOpen(_reopen).isValidReOpen(reOpenID), "DR0-MDF-511");
        _;
    }

    function init(
        address station, 
        address incinerator, 
        address stakingPool,
        address governance, 
        address spellRegistry, 
        address pteRegistry, 
        address payment, 
        address trust, 
        address reopen 
    )   
        external 
        onlyEditor 
    {
        require(!isInit, "DR0-IN0-500");
        require(station.isContract() && incinerator.isContract() && stakingPool.isContract() 
           && spellRegistry.isContract() && pteRegistry.isContract() && payment.isContract()
           && trust.isContract() && reopen.isContract()
           , "DR0-IN0-520" 
        );

        _station = station;
        _incinerator = incinerator;
        _stakingPool = stakingPool;
        _governance = governance;
        _spellRegistry = spellRegistry;
        _pteRegistry = pteRegistry;
        _payment = payment;
        _trust = trust;
        _reopen = reopen;

        isInit = true;
    }

    /** @dev Users receive tokens as much as their stake ratio
     * @param id  DAO ID
     */
    function receiveDT(uint id) external whenNotPaused(id) isValidDAO(id) { 
        address user = msg.sender;

        UserInfo memory userInfo =  IStationView(_station).getUserInfo(id, user);
        DAOStatus status = IStationView(_station).getDAOStatus(id);

        require(userInfo.status == UserStatus.ENTER, "DR0-RD0-520");
        require(status == DAOStatus.CONFIRM, "DR0-RD0-510");
        require(!userInfo.isDTReceive, "DR0-RD0-500");

        address dtAddress = getDTAddress(id);
        uint dtTotalSupply = IDAOToken(dtAddress).totalSupply();
        uint userDTAmount = (dtTotalSupply * userInfo.stakeRatio) / denominator;

        IDAOToken(dtAddress).transferFrom(dtAddress, user, userDTAmount);
        IStation(_station).refund(id, user);
        
        emit ReceivedDT(id, userDTAmount);
    }

    /** @dev After reopen confirm, Users receive tokens as much as their stake ratio
     * @param reOpenId  reopen ID
     */
    function receiveReOpenDT(uint reOpenId) external whenNotPaused(reOpenId) isValidReOpen(reOpenId) { 
        address user = msg.sender;

        UserInfo memory userInfo =  IReOpen(_reopen).getUserInfo(reOpenId, user);

        require(userInfo.status == UserStatus.ENTER, "DR0-RR0-520");
        require(!userInfo.isDTReceive, "DR0-RR0-500");

        uint DAOID = IReOpen(_reopen).getDAOID(reOpenId);
        address dtAddress = getDTAddress(DAOID);

        uint addDTAmount = IReOpen(_reopen).getMintAmount(reOpenId);
        uint userDTAmount = (addDTAmount * userInfo.stakeRatio) / denominator;

        IDAOToken(dtAddress).transferFrom(dtAddress, user, userDTAmount);
        IReOpen(_reopen).refund(reOpenId, user);

        emit ReceivedReOpenDT(reOpenId, addDTAmount);
    }

    /** @dev Users can stake DAO Tokens in the StakingPool.
     * @param id  DAO ID
     * @param amount stake amount
     */
    function stake(uint id, uint amount) external whenNotPaused(id) isValidDAO(id) {
        address user = msg.sender;
        require(amount > 0, "DR0-ST0-110");
        
        address daoToken =  IStationView(_station).getDAOContractInfo(id).dtInfo.cAddress;
        uint dtAmount = IStakingPool(_stakingPool).beforeStake(id);
        if (dtAmount > 0) {
            IDAOToken(daoToken).burn(_stakingPool, dtAmount);
        }

        require(IDAOToken(daoToken).allowance(user, address(this)) > 0 , "DR0-ST0-111");
        uint gtAmount = IStakingPool(_stakingPool).calSwapAmount(id, 0, amount);
        require(IDAOToken(daoToken).transferFrom(user, _stakingPool, amount), "DR0-ST0-390");
        
        IStakingPool(_stakingPool).stake(id, user, amount, gtAmount);
    }

    /** @dev Users can unstake DAO Tokens in the StakingPool.
     * @param id  DAO ID
     * @param amount  untake amount     
     */
    function unstake(uint id, uint amount) external isValidDAO(id) {
        address user = msg.sender;
        require(amount > 0, "DR0-US0-110");

        address gtAddress =  IStationView(_station).getDAOContractInfo(id).gtInfo.cAddress;
        uint gtAmount = IGovernanceToken(gtAddress).balanceOf(user);

        require(gtAmount >= amount, "DR0-US0-210");
        require(IStakingPool(_stakingPool).isUnstakeable(id, user), "DR0-US0-500");

        uint dtAmount = IStakingPool(_stakingPool).calSwapAmount(id, 1, amount);
        address daoToken =  IStationView(_station).getDAOContractInfo(id).dtInfo.cAddress;
        IStakingPool(_stakingPool).unstake(id, user, dtAmount, amount);

        require(IDAOToken(daoToken).transferFrom(_stakingPool, user, dtAmount), "DR0-US0-390");
    }

    /** @dev Users can create governance agendas, and certain conditions must be met
     * @param id  DAO ID
     * @param spellType  spell type
     * @param params spell params
     */
    function createAgenda(
        uint id, 
        uint spellType,
        bytes memory params
    ) 
        external 
        whenNotPaused(id) 
        isValidDAO(id)
    {
        // Preventate Stack too deep
        address user = msg.sender;
        uint _id = id;
        uint _spellType = spellType;
        bytes memory _params = params;
        uint gTotalVote;
        uint obligation;
        uint cObligation;
        uint pObligation;
        address gtAddress =  IStationView(_station).getDAOContractInfo(_id).gtInfo.cAddress;
        
        {
            uint gUserVote = IGovernanceToken(gtAddress).balanceOf(user);
            gTotalVote = IGovernanceToken(gtAddress).totalSupply();
            (BasePolicy memory basePolicy, SubPolicy[2] memory subPolicy) = IGovernance(_governance).getPolicy(_id, _spellType);
            uint quorumRatio = basePolicy.baseRatio;
            require(quorumRatio <= (gUserVote * denominator) / gTotalVote, "DR0-CA0-510");

            uint userThreshold = (gTotalVote *  quorumRatio) / denominator;
            cObligation = (userThreshold * subPolicy[0].obligation) / denominator;
            pObligation = (userThreshold * subPolicy[1].obligation) / denominator;
            obligation = cObligation + pObligation;

        }

        require(ISpellRegistry(_spellRegistry).isValidSpellType(_spellType), "DR0-CA0-010");

        address spell = ISpellRegistry(_spellRegistry).getSpell(_spellType);
        require(ISpell(spell).isValidParams(_params, _id), "DR0-CA0-030");

        IGovernance(_governance).createAgenda(user, _id, _spellType, block.timestamp, gTotalVote, cObligation, pObligation, _params);
        IGovernanceToken(gtAddress).transferFrom(user, _governance, obligation);
        renew(id, spellType);
    }

    /** @dev Users can vote on the created agenda.
     * @param id  DAO ID
     * @param agendaId  agenda ID
     * @param amount  agenda ID
     * @param answer  answer of agenda
     */
    function vote(
        uint id, 
        uint agendaId, 
        uint amount, 
        VoteType answer
    ) 
        external 
        whenNotPaused(id)
        isValidDAO(id) 
    {
        address user = msg.sender;

        address gtAddress =  IStationView(_station).getDAOContractInfo(id).gtInfo.cAddress;
        uint blockNumber = IGovernance(_governance).getInfo(id, agendaId).blockNum;
        uint spellType = IGovernance(_governance).getInfo(id, agendaId).spellType;
        require(IGovernance(_governance).isValidId(id, agendaId), "DR0-VT0-010");

        uint gAmount = IGovernance(_governance).getAvailableNum(id, agendaId, user, gtAddress);
        require(block.number > blockNumber, "DR0-VT0-110");
        require(amount <= gAmount && amount > 0, "DR0-VT0-410");
        require(answer == VoteType.AGREEMENT || answer == VoteType.OPPOSITE, "DR0-VT0-510"); 
        require(IGovernance(_governance).isSameVote(id, agendaId, user, answer), "DR0-VT0-511");
        
        IGovernance(_governance).vote(id, agendaId, user, answer, amount);
        IGovernanceToken(gtAddress).transferFrom(user, _governance, amount);
        renew(id, spellType);

    }

    function renew(uint id, uint spellType) public whenNotPaused(id) isValidDAO(id) {
        IGovernance(_governance).renew(id, spellType);
    }

    /** @dev Cancellation of voted items
     * @param id  DAO ID
     * @param agendaId  ID of the created agenda
     */
    function cancel(uint id, uint agendaId) external isValidDAO(id) whenNotPaused(8) {
        require(IGovernance(_governance).isValidId(id, agendaId), "DR0-CC0-010");
        require(IGovernance(_governance).isVoted(id, agendaId, msg.sender),  "DR0-CC0-520");
        
        uint amount = IGovernance(_governance).cancel(id, agendaId, msg.sender);
        address gtAddress =  IStationView(_station).getDAOContractInfo(id).gtInfo.cAddress;
        require(IGovernanceToken(gtAddress).transferFrom(_governance, msg.sender, amount), "DR0-CC0-390");

        uint spellType = IGovernance(_governance).getInfo(id, agendaId).spellType;
        renew(id, spellType);
    }

    /** @dev Part of the DT purchased in the Incinerator Contract is incinerated and sent to the StakingPool
     * @param id  DAO ID
     * @param dt  DAO Token Address
     * @param toBurn  DAO Token burn amount
     * @param toReward DAO Token reward amount
     */
    function disposeDT(
        uint id, 
        address dt, 
        uint toBurn, 
        uint toReward
    ) 
        external 
        override 
        whenNotPaused(id) 
        onlyIncinerator 
    {
        if(toBurn > 0) {
            IDAOToken(dt).burn(msg.sender, toBurn);
        }

        if(toReward > 0) {
            IDAOToken(dt).transferFrom(msg.sender, _stakingPool, toReward);
        }
    }

    /** @dev Part of the DT purchased in the Incinerator Contract is incinerated and sent to the StakingPool
     * @param daoId  DAO ID
     * @param agendaId  Agenda ID
     */
    function reclaimGT(uint daoId, uint agendaId) external whenNotPaused(daoId) isValidDAO(daoId) {
        address user = msg.sender;
        address gtAddress =  IStationView(_station).getDAOContractInfo(daoId).gtInfo.cAddress;
        uint reclaimAmount = IGovernance(_governance).reclaimGT(daoId, agendaId, user);
        IERC20(gtAddress).safeTransferFrom(_governance, user, reclaimAmount);

        emit ReClaimedGT(daoId, agendaId, reclaimAmount);
    }

    /**
    * @dev Change Denominator
    * @param _denominator number of decimal places
    */
    function changeDenominator(uint _denominator) external onlyEditor {
        denominator = _denominator;
        emit ChangedOption("Denominator", denominator);
    }

    function getDTAddress(uint id) internal view returns (address) {
        return IStationView(_station).getDAOContractInfo(id).dtInfo.cAddress;
    }

    function pause(uint id) external override onlyStation {
        super._pause(id);
    }

    function unpause(uint id) external onlyEditor {
        super._unpause(id);
    }

    function pauseAll() external onlyEditor {
        super._pauseAll();
    }

    function unpauseAll() external onlyEditor {
        super._unpauseAll();
    }        
}