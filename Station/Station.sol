// SPDX-License-Identifier: MIT
pragma solidity 0.8.10;

import "./IStation.sol";
import "../Registry/ISpellRegistry.sol";
import "../Registry/IPteRegistry.sol";
import "../Registry/IMelterRegistry.sol";
import "../Role/MakerRole.sol";
import "../Token/IDAOToken.sol";
import "../StakingPool/IStakingPool.sol";
import "../ContractFactory/IContractFactory.sol";
import "../Router/IDAORouter.sol";
import "../Router/IFundRouter.sol";
import "../Governance/IGovernance.sol";
import "../Governance/Payment/IPayment.sol";
import "../../../../contracts/openzeppelin-contracts/utils/Counters.sol";
import "../../../../contracts/openzeppelin-contracts/token/ERC20/IERC20.sol";
import "../../../../contracts/openzeppelin-contracts/token/ERC20/utils/SafeERC20.sol";
import "../../../../contracts/openzeppelin-contracts/security/ReentrancyGuard.sol";

/**
 * @title Station
 * @author Wemade Pte, Ltd
 * Recruitment funds are collected for DAO creation, and if successful, the recruitment funds will be transferred to the Treasury Contract.
 * There are DAO participation, participation cancellation, confirmation, refund, and liquidation functions.
 *
 */

contract Station is  IStation, IPaymentStruct, ReentrancyGuard, MakerRole {
    using Counters for Counters.Counter;
    using Address for address;
    using SafeERC20 for IERC20;

    address private _spellRegistry;
    address private _incinerator;
    address private _treasury;
    address private _trust;
    address constant public DEAD_WALLET = 0x000000000000000000000000000000000000dEaD; // dead wallet

    uint public denominator = 1 ether;                                    // denominator
    bytes4 constant pInfoSelector = bytes4(0x606ed86a);                   // pInfo Selector
    bool public isInit;

    IContractFactory private _deploy;
    IDAORouter private _daoRouter;
    IFundRouter private _fundRouter;
    IPteRegistry private _pteRegistry;
    IStakingPool private _stakingPool;
    IGovernance private _governance;
    IPayment private _payment;
    IMelterRegistry private _melterRegistry;

    Counters.Counter public DAOID;

    mapping(uint => DAO) private _DAOInfos;
    mapping(uint => address[]) private _tokenList;                      // Token list information after dissolution of DAO
    mapping(uint => uint[]) private _tokenAmounts;                      // Quantity per token after dissolution of DAO

    constructor(
        address deploy, 
        address fundRouter, 
        address daoRouter, 
        address incinerator, 
        address spellRegistry,
        address payment,
        address melterRegistry
    ) {
        _deploy = IContractFactory(deploy);
        _daoRouter = IDAORouter(daoRouter);
        _fundRouter = IFundRouter(fundRouter);
        _incinerator = incinerator;
        _spellRegistry = spellRegistry;
        _payment = IPayment(payment);
        _melterRegistry = IMelterRegistry(melterRegistry);

        DAOID.increment();
    }

    receive() external payable {
        require((msg.sender == _treasury) || (msg.sender == _incinerator) || (msg.sender == _trust), "ST: Not allowed msg.sender");
    }

    function init(
        address stakingPool, 
        address pteRegistry, 
        address governance, 
        address treasury,
        address trust
    ) 
        external 
        onlyEditor  
    {

        require(!isInit, "ST0-IN0-500");
        require(stakingPool.isContract() 
            && pteRegistry.isContract() 
            && governance.isContract() 
            && treasury.isContract()
            && trust.isContract(),
            "ST0-IN0-520"
        );

        _stakingPool = IStakingPool(stakingPool);
        _pteRegistry = IPteRegistry(pteRegistry);
        _governance = IGovernance(governance);
        _treasury = treasury;
        _trust = trust;
        isInit = true;        
    }
    
    /** @dev Can create DAOs
     *  Create to configure your DAO.
     * @param baseInfo DAO base info struct(
        name, 
        maker,
        token,  
        start, 
        end, 
        minEnterAmount, 
        purposeAmount, 
        businessAmount, 
        unit, 
        currencyType
    )
     * @param contractInfo  DAO token and stakingPool contract info struct(
        DTInfo(cAddress, name, symbol, totalSupply)
        GTInfo(cAddress)
    ),
    * @param revenueRatio Treasury revenue ratio
    * @param burnRatio DAO Token burn ratio
    * @param performRatio PTE settlement fee rate
    * @param incomeRatio PTE income fee rate
    * @param name receiver name
    * @param businessHahsed Description of the business hash value
    * @param businessDesc business description
    * @param creators creators
     */
    function create(
        BaseInfo memory baseInfo, 
        ContractInfo memory contractInfo,
        uint revenueRatio,
        uint burnRatio,
        uint performRatio,
        uint incomeRatio,
        bytes32 name,
        bytes32 businessHahsed,
        bytes32 businessDesc,
        Recipient[] memory creators
    ) 
        external 
        onlyMaker 
    {
        PInfo memory pInfo = PInfo({
            fundAddr: baseInfo.token,
            receiver: address(0),
            name: name,
            hashed: businessHahsed,
            desc: businessDesc,
            daoId: 0,
            agendaId: 0,
            amount: baseInfo.businessAmount,
            revenueRatio: revenueRatio,
            burnRatio: burnRatio,
            performRatio: performRatio,
            incomeRatio: incomeRatio,
            creators: creators
        });
        _create(baseInfo, contractInfo, pInfo, msg.sender);
    }

    /** @dev Participate in the DAO
     * @param id DAO ID
     * @param amount If DAO currencyType is Wemix coin or Token, it is the enter amount
     */
    function enter(uint id, uint amount) external payable nonReentrant {
        require(isValidDAO(id),"ST0-ET0-010");
    
        DAO storage dao = _DAOInfos[id];
        _enter(id, amount, msg.sender, dao);
    }

    /** @dev Participation in DAOs can be canceled.
     * @param id DAO ID
     */
    function cancel(uint id) external payable nonReentrant {
        require(isValidDAO(id),"ST0-CC0-010");

        DAO storage dao = _DAOInfos[id];
        _cancel(id, msg.sender, dao);
    }

    /**
    * @dev After DAO recruitment end, Check the success of fail.
    * If it fails, the user can get a refund.
    * If successful, the amount raised is moved in the order of Treasury, Trust, and Pte.
    * @param id DAO ID
    * @param quorumRatio 5th DAO Token ratio
    */
    function confirm(uint id, uint quorumRatio) external onlyMaker {
        require(isValidDAO(id),"ST0-CF0-010");

        DAO storage dao = _DAOInfos[id];
        _confirm(id, msg.sender, quorumRatio, dao);
    }

    /**
    * @dev After DAO recruitment fail, Users can refund fund
    * and After DAO confirm success, User get a refund exceeded recruitment amount.
    * @param id DAO ID
    * @param user DAO useraddress
    */
    function refund(uint id, address user) external nonReentrant {
        require(isValidDAO(id),"ST0-RF0-010");

        DAO storage dao = _DAOInfos[id];
        _refund(id, user, dao);
    }

    /**
    * @dev State change to disband DAO
    * @param id DAO ID
    */
    function dissolve(uint id) external override {
        require(ISpellRegistry(_spellRegistry).isSpell(_msgSender()), "ST0-DS0-520");
        require(isValidDAO(id),"ST0-DS0-010");

        DAO storage dao = _DAOInfos[id];
        _dissolve(id, msg.sender, dao);
    }

    /**
    * @dev The user who creates the DAO can delete the DAO creation.
    * @param id DAO ID
    */
    function remove(uint id) external {
        require(isValidDAO(id),"ST0-RM0-010");

        DAO storage dao = _DAOInfos[id];
        _remove(id, msg.sender, dao);
    }

    /**
    * @dev After DAO disband, User can exchange to DAO Token to Wemix COIN and another Token
    * @param id DAO ID
    */
    function liquidate(uint id) external {
        require(isValidDAO(id),"ST0-LQ0-010");

        DAO storage dao = _DAOInfos[id];
        _liquidate(id, msg.sender, dao);
    }

    /**
    * @dev Change Unit
    * @param id DAO ID
    * @param user DAO user
    * @param userInfo userInfo struct
    */
    function updateUserInfo(uint id, address user, UserInfo memory userInfo) external {
        require(address(_daoRouter) == _msgSender(), "ST0-UU0-520");
        DAO storage dao = _DAOInfos[id];
        dao.userInfos[user] = userInfo;
        
        emit UpdatedUserInfo(id, user, userInfo);
    }

    /**
    * @dev Change Denominator
    * @param _denominator number of decimal places
    */
    function changeDenominator(uint _denominator) external onlyEditor {
        denominator = _denominator;
        emit ChangedOption("Denominator", denominator);
    }

    /**
    * @dev Change Currency Type
    * @param id DAO ID
    * @param currencyType CurrnecyType
    */
    function changeCurrencyType(uint id, CurrencyType currencyType) external override onlyMaker {
        DAO storage dao = _DAOInfos[id];
        require(block.timestamp < dao.baseInfo.start, "ST0-CC1-210");
        
        dao.baseInfo.currencyType = currencyType;
        emit ChangedOption("CurrencyType", uint8(currencyType));
    }

    /**
    * @dev After the dissolution of DAO is confirmed, 
    * you will receive a list of token addresses and token quantity to exchange tokens with Wemix Coin.
    * @param id DAO ID
    * @param tokenList token list array
    * @param tokenAmounts exchangeable token amount array
    */ 
    function setTokenCollection(uint id, address[] memory tokenList, uint[] memory tokenAmounts) external {
        require(address(_fundRouter) == _msgSender(), "ST0-ST0-520");
        require(tokenList.length == tokenAmounts.length, "ST0-ST0-510");

        for(uint i = 0; i < tokenList.length; i++) {
            _tokenList[id].push(tokenList[i]);
            _tokenAmounts[id].push(tokenAmounts[i]);
        }

        emit SetTokenCollection(id, tokenList, tokenAmounts);
    }

    /**
     * @dev change address of FundRouter
     * @param router new address of FundRouter
     */
    function changeFundRouter(address router) external onlyEditor {

        _fundRouter = IFundRouter(router);

        emit RouterChanged("FundRouter", router);
    }

    /**
     * @dev change address of FundRouter
     * @param router new address of FundRouter
     */
    function changeDaoRouter(address router) external onlyEditor {

        _daoRouter = IDAORouter(router);

        emit RouterChanged("DaodRouter", router);
    }

    function getDAOContractInfo(uint id) external view returns(ContractInfo memory contractInfo) {

        contractInfo = _DAOInfos[id].contractInfo;

    }

    function getRealTimeInfo(
        uint id
    ) 
        external 
        view 
        returns (RealTimeInfo memory realTimeInfo) 
    {

        realTimeInfo = _DAOInfos[id].realTimeInfo;
    }

    function getDAOBaseInfo(uint id) external view returns(BaseInfo memory baseInfo) {

        baseInfo = _DAOInfos[id].baseInfo;

    }

    function getDAOStatus(uint id) external view returns(DAOStatus status) {
        if (_isClose(_DAOInfos[id].baseInfo.end) && _DAOInfos[id].status == DAOStatus.OPEN) {
            status = DAOStatus.CLOSE;
        } else {
            status = _DAOInfos[id].status;
        }
    }

    function isCoin(uint id) external view returns (bool) {
        
        return _DAOInfos[id].baseInfo.currencyType == CurrencyType.COIN;
    
    }

    function getUserInfo(
        uint id, 
        address user
    ) 
        public 
        view 
        returns (UserInfo memory userInfoView) 
    {

        DAO storage dao = _DAOInfos[id];
        UserInfo memory userInfo = dao.userInfos[user];

        userInfoView.amount = userInfo.amount;
        userInfoView.stakeRatio = getStakeRatio(id, user);
        userInfoView.isDTReceive = userInfo.isDTReceive;
        userInfoView.status = userInfo.status;
        
    }

    /**
    * @dev After DAO recruitment end, recruitment fund transfer to Treasury Contract
    * @param id DAO ID
    */
    function transferToTreasury(uint id) internal {
        DAO storage dao = _DAOInfos[id];
        _transferToTreasury(id, dao.baseInfo.purposeAmount, RecruitType.DAO, dao);
    }

    function getTokenAddress(uint id) public view returns (address tokenAddress) {

        tokenAddress = _DAOInfos[id].baseInfo.token;
    }

    function getStakeRatio(
        uint id, 
        address user
    ) 
        public 
        view 
        returns (uint ratio) 
    {
        uint totalEnterAmount = _DAOInfos[id].realTimeInfo.totalEnterAmount;
        uint userAmount = _DAOInfos[id].userInfos[user].amount;
        if (totalEnterAmount > 0) {
            ratio = (userAmount * denominator) / totalEnterAmount;
        }
    }

    function isValidDAO(uint id) public view returns(bool) {
        if (id == 0) {
            return false;
        }
        return _DAOInfos[id].ID == id;
    }

    function getTokenCollection(uint id) external view returns(address[] memory tokenList, uint[] memory tokenAmounts) {
        tokenList = _tokenList[id];
        tokenAmounts = _tokenAmounts[id];
    }

    function getMelter(uint id) external view returns(address melter) {
        melter = _DAOInfos[id].baseInfo.melter;
    }

    function getReceiverType(address receiver) external view returns (uint) {
        if(_pteRegistry.isPte(receiver)) {
            return 0;
        }
        return 1;
    }

    function _create(
        BaseInfo memory baseInfo, 
        ContractInfo memory contractInfo,
        PInfo memory pInfo,
        address maker 
    ) 
        internal 
    {

        uint currentID = DAOID.current();
        _checkCreate(pInfo.revenueRatio, pInfo.burnRatio, pInfo.performRatio, pInfo.incomeRatio, baseInfo);

        require(_pteRegistry.isRegistered(pInfo.name), "ST0-CR0-540");

        DAO storage dao = _DAOInfos[currentID];
        dao.ID = currentID;
        dao.baseInfo = baseInfo;
        dao.contractInfo = contractInfo;
        dao.status = DAOStatus.READY;
        dao.baseInfo.maker = maker;

        pInfo.receiver = _pteRegistry.getRegisteredPte(pInfo.name);
        pInfo.daoId = currentID;

        bytes memory params = abi.encodeWithSelector(pInfoSelector, pInfo);
        _payment.setInfo(params, currentID, 0);

        DAOID.increment();
            
        emit Created(currentID, dao.baseInfo.name, maker, baseInfo.currencyType);
    }

    function _enter(uint id, uint amount, address user, DAO storage dao) internal  {

        if (block.timestamp >= dao.baseInfo.start && 
            block.timestamp <= dao.baseInfo.end && 
            dao.status == DAOStatus.READY) 
        {
            dao.status = DAOStatus.OPEN;
        } 

        _checkEnter(amount, dao);

        if (dao.baseInfo.currencyType == CurrencyType.COIN) {
            amount = msg.value;
        }
        
        UserInfo storage userInfo = dao.userInfos[user];

        if (userInfo.status == UserStatus.NONE || userInfo.status == UserStatus.REFUND) {
            userInfo.status = UserStatus.ENTER;
            dao.realTimeInfo.enterCount++;
            dao.realTimeInfo.txCount++;
        } else {
            dao.realTimeInfo.txCount++;

        }

        userInfo.amount += amount;
        dao.realTimeInfo.totalEnterAmount += amount;
        dao.realTimeInfo.totalRemainAmount += amount;

        if (dao.baseInfo.currencyType == CurrencyType.TOKEN) {
            address token = dao.baseInfo.token;
            IERC20(token).transferFrom(user, address(this), amount);
        }

        emit Entered(id, user, amount);
    }

    function _cancel(uint id, address user, DAO storage dao) internal {
        _checkCancel(user, dao);

        uint amount = dao.userInfos[user].amount;
        dao.realTimeInfo.totalEnterAmount -= amount;
        dao.realTimeInfo.totalRemainAmount -= amount;
        dao.realTimeInfo.enterCount -= 1;

        UserInfo storage userInfo = dao.userInfos[user];
        userInfo.amount = 0;
        userInfo.status = UserStatus.NONE;
        
        if (dao.baseInfo.currencyType == CurrencyType.COIN) {
            payable(user).transfer(amount);
        } else {
            address token = dao.baseInfo.token;
            IERC20(token).safeTransfer(user, amount);
        }

        emit Canceled(id, user, amount);
    }

    function _confirm(
        uint id, 
        address user, 
        uint quorumRatio,
        DAO storage dao
    ) 
        internal 
    {
        uint _id = id; 
        address _user = user; 


        _checkConfirm(dao);

        if (!_isSuccessDAO(dao)) {
            dao.status = DAOStatus.FAIL;
        } else {

            dao.status = DAOStatus.CONFIRM;

            // tokenContractInfo
            string memory _tokenName = dao.contractInfo.dtInfo.name;
            string memory _tokenSymbol = dao.contractInfo.dtInfo.symbol;
            uint _totalSupply = dao.contractInfo.dtInfo.totalSupply;
            uint _purposeAmount = dao.baseInfo.purposeAmount;
            address _stakingPoolAddr = address(_stakingPool);

            // price per DT
            dao.realTimeInfo.Price = (_purposeAmount * denominator) / _totalSupply;
            dao.realTimeInfo.totalRefundAmount = (dao.realTimeInfo.totalEnterAmount - _purposeAmount);

            // contract deploy
            address DTAddr = _deploy.deployDT(_tokenName, _tokenSymbol, _stakingPoolAddr, _incinerator, _id, _totalSupply);
            address GTAddr = _deploy.deployGT(_tokenName, _tokenSymbol, _stakingPoolAddr);

            dao.contractInfo.dtInfo.cAddress = DTAddr;
            dao.contractInfo.gtInfo.cAddress = GTAddr;
            IDAOToken(dao.contractInfo.dtInfo.cAddress).approve(address(_fundRouter), type(uint).max);
            
            emit Deployed(_id, DTAddr, GTAddr, _user);
            
            {
                uint _quorumRatio = quorumRatio;
                uint _dtLockupTime = dao.baseInfo.dtLockupTime;
                uint _promulgationPeriod = dao.baseInfo.promulgationPeriod;
                uint _consensusObligtion = dao.baseInfo.consensusObligation;
                uint _proposalObligation = dao.baseInfo.proposalObligation;
                _stakingPool.initialize(_id, DTAddr, GTAddr, _dtLockupTime);
                _governance.setDefaultPolicy(_id, _promulgationPeriod, _quorumRatio, _consensusObligtion, _proposalObligation);
            }

            transferToTreasury(id);
        }

        emit Confirmed(_id, _user, dao.status);
      
    }

    function _refund(uint id, address user, DAO storage dao) internal {
        uint userRefundAmount;
        bytes32 column;

        UserInfo storage userInfo = dao.userInfos[user];
        address token = dao.baseInfo.token;

        if (dao.status == DAOStatus.FAIL) {
            _checkRefund(user, dao);

            userRefundAmount = userInfo.amount;
            dao.realTimeInfo.totalRemainAmount -= userRefundAmount;
            userInfo.amount -= userRefundAmount;
            userInfo.status = UserStatus.REFUND;
            column = "REFUND";

        } else if(dao.status == DAOStatus.CONFIRM) {

            require(address(_daoRouter) == _msgSender(), "ST0-RF1-520");
            userInfo.isDTReceive = true;
            uint stakeRatio = getStakeRatio(id, user);
            userRefundAmount = (dao.realTimeInfo.totalRefundAmount * stakeRatio) / denominator;
            
            dao.realTimeInfo.totalRemainAmount -= userRefundAmount;
            userInfo.amount -= userRefundAmount;
            column = "AFTER_REFUND";
        } else {
            require(false, "ST0-RF1-010");
        }
        
        _transferFund(id, column, token, user, userRefundAmount);

        emit Refunded(id, user, userRefundAmount, column);
    }

    function _dissolve(uint id, address user, DAO storage dao) internal  {
        dao.status = DAOStatus.DISSOLVE;
        _daoRouter.pause(id);

        emit DisSolved(id, user);
    }

    function _remove(uint id, address user, DAO storage dao) internal  {
        _checkRemove(user, dao);
        dao.ID = 0;
        emit Removed(id, user);
    }

    function _liquidate(uint id, address user, DAO storage dao) internal  {
        _checkLiquidate(dao);

        address dtAddress = dao.contractInfo.dtInfo.cAddress;
        uint userDTAmount = IDAOToken(dtAddress).balanceOf(user);
        uint totalDTSupply = IDAOToken(dtAddress).totalSupply();
        uint stakeRatio = (userDTAmount * denominator) / totalDTSupply;
        address[] memory tokenlist = _tokenList[id];
        uint[] memory amounts = _tokenAmounts[id];

        for(uint i = 0; i < tokenlist.length; i++) {
            uint userAmount = (amounts[i] * stakeRatio) / denominator;
            _transferFund(id, "Liquidate", tokenlist[i], user, userAmount);
        }

        IDAOToken(dtAddress).transferFrom(user, address(this), userDTAmount);
        IDAOToken(dtAddress).transfer(DEAD_WALLET, userDTAmount);
        emit Liquidated(id, user);
    }    

    function _transferToTreasury(uint id, uint amount, RecruitType recruitType, DAO storage dao) internal virtual {
        _checkTransferToTreasury(amount, dao);
        dao.realTimeInfo.totalRemainAmount =  dao.realTimeInfo.totalRemainAmount - amount;

        if (dao.baseInfo.currencyType == CurrencyType.COIN) {
            _fundRouter.transferToTreasury{ value : amount }(id, address(0), amount, recruitType);
        } else {
            IERC20(dao.baseInfo.token).safeApprove(address(_fundRouter), amount);
            _fundRouter.transferToTreasury(id, dao.baseInfo.token, amount, recruitType);
        }

        emit TransferedToTreasury(id, recruitType);
    }

    /**
     * @dev transfer funds
     * @param id DAO ID
     * @param column a reason for the transfer of funds
     * @param token token address to transfer
     * @param to receiver address
     * @param to amount to transfer
     */
    function _transferFund(uint id, bytes32 column, address token, address to, uint amount) internal {
        if(_isCoin(token)) {
            (bool success,) = payable(to).call{value: amount}("");
            require(success, "ST0-TF0-310");
        } else {
            require(IERC20(token).transfer(to, amount),"ST0-TF0-390");
        }

        emit FundTransferred(id, column, token, to, amount);
    }

    /**
     * @dev is the address coin
     * @param token token address to transfer
     */
    function _isCoin(address token) internal virtual view returns (bool) {
        return token == address(0);
    }

     function _checkCreate(
        uint revenuRatio,
        uint burnRatio,
        uint performRatio,
        uint incomeRatio,
        BaseInfo memory baseInfo
    ) 
        internal
        view  
         
    {
        uint currentTime = block.timestamp;
        uint businessAmount = baseInfo.businessAmount;

        require(currentTime <= baseInfo.start, "ST0-CC2-210");
        require(baseInfo.start < baseInfo.end, "ST0-CC2-211");
        require(baseInfo.currencyType <= CurrencyType.TOKEN , "ST0-CC2-010");
        require(baseInfo.purposeAmount == businessAmount + ((businessAmount * performRatio) / denominator) , "ST0-CC2-510");
        if (baseInfo.currencyType == CurrencyType.TOKEN && baseInfo.token == address(0)) {
            revert("ST0-CC2-020");
        } else if(baseInfo.currencyType == CurrencyType.COIN && baseInfo.token != address(0)) {
            revert("ST0-CC2-021");
        }
        require(revenuRatio <= denominator, "ST0-CC2-212");
        require(burnRatio <= denominator, "ST0-CC2-213");
        require(performRatio <= denominator, "ST0-CC2-214");
        require(incomeRatio <= denominator, "ST0-CC2-215");
        require(baseInfo.consensusObligation + baseInfo.proposalObligation <= denominator, "ST0-CC2-216");
        require(_melterRegistry.isMelter(baseInfo.melter), "ST0-CC2-520");
    }

    function _checkEnter(uint amount, DAO storage dao) internal view {

        require(!_isClose(dao.baseInfo.end) , "ST0-CE0-210");
        require(dao.status == DAOStatus.OPEN , "ST0-CE0-510");
        if(dao.baseInfo.currencyType == CurrencyType.COIN) {
            require(amount == 0, "ST0-CE0-410");
            require(msg.value >= dao.baseInfo.minEnterAmount, "ST0-CE0-411");
            require((msg.value % dao.baseInfo.unit) == 0, "ST0-CE0-412");
        } else {
            require(msg.value == 0, "ST0-CE0-413");
            require(amount >= dao.baseInfo.minEnterAmount, "ST0-CE0-414");
            require((amount % dao.baseInfo.unit) == 0, "ST0-CE0-415");
        }
    }

    function _checkCancel(address user, DAO storage dao) internal view {
        UserStatus status = dao.userInfos[user].status;

        require(!_isClose(dao.baseInfo.end), "ST0-CC3-210");
        require(status == UserStatus.ENTER, "ST0-CC3-510");
    }

    function _checkConfirm(DAO storage dao) internal view {
        require(msg.sender == dao.baseInfo.maker , "ST0-CC4-520");
        require(_isClose(dao.baseInfo.end), "ST0-CC4-110");
        require(dao.status == DAOStatus.OPEN, "ST0-CC4-510");   
    }

    function _checkRefund(address user, DAO storage dao) internal view {
        UserStatus status = dao.userInfos[user].status;
        require(user == _msgSender(), "ST0-CR1-520");
        require(dao.status == DAOStatus.FAIL, "ST0-CR1-510");
        require(status == UserStatus.ENTER, "ST0-CR1-511");
    }

    function _checkRemove(address user, DAO storage dao) internal view {
        require(user == dao.baseInfo.maker, "ST0-CR2-520");
        require(block.timestamp < dao.baseInfo.start, "ST0-CR2-210");
    }

    function _checkLiquidate(DAO storage dao) internal view {
        require(dao.status == DAOStatus.DISSOLVE, "ST0-CL0-510");
    }

    function _checkTransferToTreasury(
        uint amount, 
        DAO storage dao
    ) 
        internal 
        view 
        virtual 
    {
        require(dao.status == DAOStatus.CONFIRM, "ST0-CT0-510");
        require(amount > 0, "ST0-CT0-110");
    }

    function _isSuccessDAO(DAO storage dao) internal view returns (bool) {
        return dao.realTimeInfo.totalEnterAmount >= dao.baseInfo.purposeAmount;
    }

    function _isClose(uint time) internal view  returns (bool) {
        return block.timestamp > time;
    }
}