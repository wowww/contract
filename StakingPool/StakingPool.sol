// SPDX-License-Identifier: MIT
pragma solidity 0.8.10;

import "../Registry/ISpellRegistry.sol";
import "./IStakingPool.sol";
import "../Token/IGovernanceToken.sol";
import "../Role/Upgradeable/RouterRoleUpgradeable.sol";
import "../../../../contracts/openzeppelin-contracts/utils/Counters.sol";
import "../../../../contracts/openzeppelin-contracts/token/ERC20/IERC20.sol";
import "../../../../contracts/openzeppelin-contracts/proxy/utils/UUPSUpgradeable.sol";

/**
    DAO Router must call initialize function when dao was created
 */

contract StakingPool is UUPSUpgradeable, IStakingPool, RouterRoleUpgradeable {
    using Counters for Counters.Counter;
    
    enum TokenType {DT, GT}

    struct DaoInfo {
        bool isAlive;           // flag that dao is alive
        address dt;             // dao token address
        address gt;             // governance token address
        uint lockup;            // unstake lockup time
    }

    struct UserInfo {
        uint stakedAmount;          // user total staked amount
        uint lastStakeBlock;        // user last stake block number
        uint unstakeableTime;       // time that user can unstake
        uint totalStakedAmount;     // Cumulative Total staked dt Amount
        uint totalUnstakedAmount;   // Cumulative Total unstaked dt Amount
    }

    ISpellRegistry private _spellRegistry;
    address private _station;
    address private _daoRouter;
    address private _governance;

    mapping(uint => mapping(address => UserInfo)) public userInfos;       // dao id => (user => userInfo)
    mapping(uint => uint) public totalStakedAmount;                       // dao id => amount
    mapping(uint => DaoInfo) public getDaoInfo;                           // dao id => daoInfo
    mapping(uint => uint) public lockupByPromulgation;                    // dao id => promulgation end time
   
    event Staked(uint indexed daoId, address indexed user, uint amount);
    event Unstaked(uint indexed daoId, address indexed user, uint amount);
    event Liquidated(uint indexed daoId);
    
    constructor() {
        _disableInitializers();
    }

    /**
     * @dev all functions execpt unStake() can work when liquidation process is not working
     */
    modifier onlyAlived(uint daoId) {
        require(getDaoInfo[daoId].isAlive, "SP0-MDF-510");
        _;
    }

    modifier onlySpell() {
        require(_spellRegistry.isSpell(_msgSender()), "SP0-MDF-520");
        _;
    }

    modifier onlyStation() {
        require(_msgSender() == _station, "SP0-MDF-521");
        _;
    }

    modifier onlyGovernance() {
        require(_msgSender() == _governance, "SP0-MDF-522");
        _;
    }

    /**
     * @dev init function running when stakingPoolProxy contract is deploying
     * @param spellRegistry address of spellRegistry
     * @param station address of station
     * @param router address of router
     * selector = bytes4(keccak256("initProxy(address, address, address, address)")) = 0xd3829134
     */
    function initProxy(address spellRegistry, address station, address router, address governance) external initializer {
        __AccessControl_init();

        _spellRegistry = ISpellRegistry(spellRegistry);
        _station = station;
        _governance = governance;
        addRouter(router);

        _daoRouter = router;
    }

    /**
     * @dev initialize token pair. dt <=> gt
     * @param daoId dao id
     * @param dt dt address
     * @param gt gt address
     */
    function initialize(uint daoId, address dt, address gt, uint lockup) external override onlyStation {
        getDaoInfo[daoId] = DaoInfo(true, dt, gt, lockup);
        IERC20(dt).approve(_daoRouter, type(uint).max);
    }
   
    /**
     * @dev stake. swap dt to gt
     * @param daoId dao id
     * @param holder dt holder
     * @param dtAmount staking amount
     * @param gtAmount receive amount
     */
    function stake(uint daoId, address holder, uint dtAmount, uint gtAmount) external override onlyRouter onlyAlived(daoId) {
        DaoInfo memory info = getDaoInfo[daoId];

        UserInfo storage userInfo = userInfos[daoId][holder];
        userInfo.lastStakeBlock = block.number;
        userInfo.unstakeableTime = block.timestamp + info.lockup;
        userInfo.stakedAmount += dtAmount;
        userInfo.totalStakedAmount += dtAmount;
        totalStakedAmount[daoId] += dtAmount;
        IGovernanceToken(info.gt).mint(holder, gtAmount);
        emit Staked(daoId, holder, dtAmount);
    }

    /**
     * @dev unstake. swap gt to dt
     * @param daoId dao id
     * @param holder gt holder
     * @param dtAmount dt amount for after unstake
     * @param gtAmount unstaking amount
     */
    function unstake(uint daoId, address holder, uint dtAmount, uint gtAmount) external override onlyRouter {
        UserInfo storage userInfo = userInfos[daoId][holder];
        DaoInfo memory info = getDaoInfo[daoId];

        uint totalProfit = IERC20(info.dt).balanceOf(address(this)) - totalStakedAmount[daoId];
        uint userTotalProfit = (userInfo.stakedAmount * totalProfit) / totalStakedAmount[daoId];
        uint pureAmount = dtAmount - (userTotalProfit * gtAmount / IGovernanceToken(info.gt).getVotes(holder));

        IGovernanceToken(info.gt).burn(holder, gtAmount);
        userInfo.stakedAmount -= pureAmount;
        userInfo.totalUnstakedAmount += dtAmount;
        totalStakedAmount[daoId] -= pureAmount;
        emit Unstaked(daoId, holder, gtAmount);
    }

    /**
     *  @dev update promulgation end time by governance
     *  @param daoId target daoId
     *  @param endTime new promulgation end time
     */
    function updateLockupByPromulgation(uint daoId, uint endTime) external override onlyGovernance {
        if(endTime >= lockupByPromulgation[daoId]) {
            lockupByPromulgation[daoId] = endTime;
        }
    }

    /**
     *  @dev reset dt balance and gt balance. when gt balance is zero.
     *  @param daoId target daoId
     */
    function beforeStake(uint daoId) external override onlyRouter returns(uint) {
        DaoInfo memory info = getDaoInfo[daoId];
        uint dtBalance = IERC20(info.dt).balanceOf(address(this));
        uint gtBalance = IERC20(info.gt).totalSupply(); 
        // 총 발행량 g.Wonder totalSupply -> 스테이킹풀에서 어드레스를 각각 받는다 => 컴포넌트로 만들기
        // totalSupply를 가져와서 내가 가져오 gt 빼고
        if (gtBalance == 0 && dtBalance != 0) {
            totalStakedAmount[daoId] = 0;
            return dtBalance;
        }
        return 0;
    }

    /**
     * @dev running liquidation process. 
     * @param daoId dao id
     */
    function liquidation(uint daoId) external override onlySpell {
        DaoInfo storage info = getDaoInfo[daoId];
        info.isAlive = false;

        emit Liquidated(daoId);
    }

    /**
     * @dev calculate swap amount. when liquidation process is running, calculate with static ratio
     *    [dt:gt = x:y]
     *
     *    dt to gt => cal y
     *    y = (gt*x)/dt
     *
     *    gt to dt => cal x
     *    x = (dt*y)/gt
     * @param daoId dao id
     * @param tokenType original token type. 0 = dt 1 =  gt
     * @param amount swap amount
    */
    function calSwapAmount(uint daoId, uint tokenType, uint amount) public override view returns (uint) {
        TokenType from = TokenType(tokenType);
      
        DaoInfo memory info = getDaoInfo[daoId];

        uint gtBalance = IERC20(info.gt).totalSupply();

        uint dtBalance = IERC20(info.dt).balanceOf(address(this));

        if(from == TokenType.DT) {
            // dt to gt
            if(gtBalance == 0) {
                return amount;
            }
            return (amount * gtBalance) / dtBalance;
        }else {
            // gt to dt
            if(gtBalance == 0) {
                return 0;
            }else {
                return (amount * dtBalance) / gtBalance;
            }
        }
    }

    function getStakeAmount(uint daoId, address user) external view override returns (uint) {
        return userInfos[daoId][user].stakedAmount;
    }

    function isRegisteredDaoId(uint daoId) external view returns (bool) {
        return getDaoInfo[daoId].dt != address(0) && getDaoInfo[daoId].gt != address(0);
    }

    function isUnstakeable(uint daoId, address holder) external view override returns (bool) {
        UserInfo memory userInfo = userInfos[daoId][holder];
        uint lockupEndTime = lockupByPromulgation[daoId] >= userInfo.unstakeableTime ? lockupByPromulgation[daoId] : userInfo.unstakeableTime;
        
        return block.number > userInfo.lastStakeBlock
        && block.timestamp > lockupEndTime;
    }

    function _authorizeUpgrade(address newImplementation) internal virtual override onlyEditor {}
}