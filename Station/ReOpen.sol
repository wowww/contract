// SPDX-License-Identifier: MIT
pragma solidity 0.8.10;

import "./IStationView.sol";
import "./IReOpen.sol";
import "../Registry/ISpellRegistry.sol";
import "../Registry/IPteRegistry.sol";
import "../Role/MakerRole.sol";
import "../Components/NILEComponent.sol";
import "../Token/IDAOToken.sol";
import "../Router/IFundRouter.sol";
import "../../../../contracts/openzeppelin-contracts/utils/Counters.sol";
import "../../../../contracts/openzeppelin-contracts/token/ERC20/IERC20.sol";
import "../../../../contracts/openzeppelin-contracts/token/ERC20/utils/SafeERC20.sol";
import "../../../../contracts/openzeppelin-contracts/security/ReentrancyGuard.sol";

/**
 * @title ReOpen
 * After successful creation of the DAO, a contract to collect additional funds
 * @author Wemade Pte, Ltd
 *
 */

contract ReOpen is IReOpen, IPaymentStruct, ReentrancyGuard, MakerRole {
    using Counters for Counters.Counter;
    using SafeERC20 for IERC20;

    address private _spellRegistry;
    address private _daoRouter;
    uint private denominator = 1 ether;                                   // denominator

    IStationView private _station;
    IFundRouter private _fundRouter;
    Counters.Counter public reOpenID;

    mapping(uint => ReOpenInfo) private _reOpenInfos;

    constructor(
        address station, 
        address spellRegistry,
        address fundRouter,
        address daoRouter
    ) {
        _station = IStationView(station); 
        _spellRegistry = spellRegistry;
        _daoRouter = daoRouter;
        _fundRouter = IFundRouter(fundRouter);
        reOpenID.increment();
    }

    /**
    * @dev By Governance program, 
        only Spell Contract execute this function reopen DAO recruitment.
    * @param id DAO ID
    * @param period ReOpen DAO recruit period
    * @param purposeAmount ReOpen DAO // For reopen make, minimum purpose amount
    * @param minEnterAmount ReOpen DAO Minimum enter amount
    * @param addMintAmount ReOpen add DAO Token amount
    * @param unit ReOpen DAO Enter amount unit
    */
    function reOpen(
        uint id, 
        uint period, 
        uint purposeAmount, 
        uint minEnterAmount, 
        uint addMintAmount, 
        uint unit
    ) 
        external 
    {
        require(ISpellRegistry(_spellRegistry).isSpell(_msgSender()), "RO0-RO0-520");
        _reOpen(id, period, purposeAmount, minEnterAmount, addMintAmount, unit);
    }

    /**
    * @dev By Governance program, 
        only Spell Contract execute this function re open DAO recruitment.
    * @param reOpenId reopen ID
    * @param amount enter Amount
    */
    function enter(uint reOpenId, uint amount) external payable nonReentrant {        
        ReOpenInfo storage reOpenInfo = _reOpenInfos[reOpenId];
        require(_station.isValidDAO(reOpenInfo.DAOID) , "RO0-EN0-510");
        require(reOpenId == reOpenInfo.ID, "RO0-EN0-511");
        _enter(reOpenId, amount, msg.sender, reOpenInfo);
    }

    /** @dev Cancel participation in DAO reopen
     * @param reOpenId reOpen ID
     */
    function cancel(uint reOpenId) external payable nonReentrant {
        ReOpenInfo storage reOpenInfo = _reOpenInfos[reOpenId];
        require(_station.isValidDAO(reOpenInfo.DAOID) , "RO0-CC0-510");
        require(reOpenId == reOpenInfo.ID, "RO0-CC0-511");
        _cancel(reOpenId, msg.sender, reOpenInfo);
    }

    /**
    * @dev After DAO reopen recruitment fund end, Check the success of fail.
    *       Only business funds are transferred to Treasury.
    * @param reOpenId reOpen ID
    */
    function confirm(uint reOpenId) external onlyMaker {
        ReOpenInfo storage reOpenInfo = _reOpenInfos[reOpenId];
        require(_station.isValidDAO(reOpenInfo.DAOID) , "RO0-CF0-510");
        require(reOpenId == reOpenInfo.ID, "RO0-CF0-511");        
        _confirm(reOpenInfo.purposeAmount, reOpenInfo);
    }

    /**
    * @dev After DAO reopen recruitment fail, Users can refund fund
    * and After DAO reopen confirm success, User get a refund exceeded recruitment amount.
    * @param reOpenId reOpen ID
    * @param user DAO useraddress
    */
    function refund(uint reOpenId, address user) external nonReentrant {
        ReOpenInfo storage reOpenInfo = _reOpenInfos[reOpenId];
        require(_station.isValidDAO(reOpenInfo.DAOID) , "RO0-RF0-510");
        require(reOpenId == reOpenInfo.ID, "RO0-RF0-511D");        
        _refund(reOpenId, user, reOpenInfo);
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
     * @dev change address of FundRouter
     * @param router new address of FundRouter
     */
    function changeFundRouter(address router) external onlyEditor {

        _fundRouter = IFundRouter(router);

        emit RouterChanged("FundRouter", router);
    }

    function getReOpenStatus(uint reOpenId) external view returns(ReOpenStatus status) {
        if (_isClose(_reOpenInfos[reOpenId].end) && _reOpenInfos[reOpenId].status == ReOpenStatus.OPEN) {
            status = ReOpenStatus.CLOSE;
        } else {
            status = _reOpenInfos[reOpenId].status;
        }
    }

    function getReOpenInfo(
        uint reOpenId
    ) 
        external 
        view 
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
        ) 
    {
        
        uint _reopenID = reOpenId;
        ReOpenInfo storage reOpenInfo = _reOpenInfos[_reopenID];
        
        ID = reOpenInfo.ID;
        totalEnterAmount = reOpenInfo.totalEnterAmount;
        totalRemainAmount = reOpenInfo.totalRemainAmount;
        totalRefundAmount = reOpenInfo.totalRefundAmount;
        enterCount = reOpenInfo.enterCount;
        start = reOpenInfo.start;
        period = reOpenInfo.period;
        end = reOpenInfo.end;
        purposeAmount = reOpenInfo.purposeAmount;
        minEnterAmount = reOpenInfo.minEnterAmount;
        addMintAmount = reOpenInfo.addMintAmount;
        price = reOpenInfo.price;
        unit = reOpenInfo.unit;
    }

    function getUserInfo(
        uint reOpenId, 
        address user
    ) 
        public 
        view 
        returns (UserInfo memory userInfoView) 
    {

        UserInfo memory userInfo = _reOpenInfos[reOpenId].userInfos[user];
        uint amount = userInfo.amount;

        userInfoView.amount = amount;
        userInfoView.stakeRatio = getStakeRatio(reOpenId, user);
        userInfoView.isDTReceive = userInfo.isDTReceive;
        userInfoView.status = userInfo.status;
    }

    function isValidReOpen(uint reopenID) external view returns(bool) {
        return _reOpenInfos[reopenID].ID == reopenID;
    }

    function getMintAmount(
        uint reOpenId
    ) 
        external 
        view 
        returns (
            uint addMintAmount
        ) 
    {
        ReOpenInfo storage reOpenInfo = _reOpenInfos[reOpenId];
        addMintAmount = reOpenInfo.addMintAmount;
    } 

    function getDAOID(
        uint reOpenId
    ) 
        external 
        view 
        returns (
            uint DAOID
        ) 
    {
        ReOpenInfo storage reOpenInfo = _reOpenInfos[reOpenId];
        DAOID = reOpenInfo.DAOID;
    }

    function getStakeRatio(
        uint reOpenId, 
        address user
    ) 
        public 
        view 
        returns (uint ratio) 
    {
        uint totalEnterAmount = _reOpenInfos[reOpenId].totalEnterAmount;
        uint userAmount = _reOpenInfos[reOpenId].userInfos[user].amount;
        if (totalEnterAmount > 0) {
            ratio = (userAmount * denominator) / totalEnterAmount;
        }
    }

    function _reOpen(
        uint id, 
        uint period, 
        uint purposeAmount, 
        uint minEnterAmount, 
        uint addMintAmount, 
        uint unit
    ) 
        internal 
        
    {
        uint currentId = reOpenID.current();
        ReOpenInfo storage _reOpenInfo = _reOpenInfos[currentId];


        _reOpenInfo.ID = currentId;
        _reOpenInfo.DAOID = id;
        _reOpenInfo.start = block.timestamp;
        _reOpenInfo.end = _reOpenInfo.start + period;
        _reOpenInfo.purposeAmount = purposeAmount;
        _reOpenInfo.minEnterAmount = minEnterAmount;
        _reOpenInfo.addMintAmount = addMintAmount;
        _reOpenInfo.unit = unit;
        _reOpenInfo.maker = msg.sender;
        _reOpenInfo.status = ReOpenStatus.READY;
        
        reOpenID.increment();
        emit ReOpened(id, "reOpen");
    }

    function _enter(
        uint reOpenId, 
        uint amount, 
        address user, 
        ReOpenInfo storage reOpenInfo
    ) 
        internal 
    {

        if (block.timestamp >= reOpenInfo.start && 
            block.timestamp <= reOpenInfo.end && 
            reOpenInfo.status == ReOpenStatus.READY) 
        {
            reOpenInfo.status = ReOpenStatus.OPEN;
        } 
        uint DAOID = reOpenInfo.DAOID;
        _checkEnter(amount, reOpenInfo);

        if (_station.isCoin(DAOID)) {
            amount = msg.value;
        }

        UserInfo storage userInfo = reOpenInfo.userInfos[user];

        if (userInfo.status == UserStatus.NONE || userInfo.status == UserStatus.REFUND) {
            userInfo.status = UserStatus.ENTER;
            reOpenInfo.enterCount++;
        }

        userInfo.amount = userInfo.amount + amount;
        reOpenInfo.totalEnterAmount += amount;
        reOpenInfo.totalRemainAmount += amount;

        if(!_station.isCoin(DAOID)) {
            address token = _station.getTokenAddress(DAOID);
            IERC20(token).safeTransferFrom(user, address(this), amount);
        }

        emit ReOpenEntered(DAOID, reOpenId, user, amount);
    }

    function _cancel(
        uint reOpenId, 
        address user, 
        ReOpenInfo storage reOpenInfo
    ) 
        internal 
    {
        _checkCancel(user, reOpenInfo);
        uint DAOID = reOpenInfo.DAOID;
        uint amount = reOpenInfo.userInfos[user].amount;
        reOpenInfo.totalEnterAmount -= amount;
        reOpenInfo.totalRemainAmount -= amount;
        reOpenInfo.enterCount -= 1;

        UserInfo storage userInfo = reOpenInfo.userInfos[user];
        userInfo.amount = 0;
        userInfo.status = UserStatus.NONE;
        
        if(_station.isCoin(DAOID)) {
            payable(user).transfer(amount);    
        } else {
            address token = _station.getTokenAddress(DAOID);
            IERC20(token).safeTransfer(user, amount);
        }

        emit ReOpenCanceled(DAOID, reOpenId, user, amount);
    }

    function _confirm(
        uint amount, 
        ReOpenInfo storage reOpenInfo
    ) 
        internal 
    {
        _checkConfirm(reOpenInfo);

        uint DAOID = reOpenInfo.DAOID;
        if (_isSuccessReOpen(reOpenInfo)) {
            reOpenInfo.status = ReOpenStatus.CONFIRM;
            
            if (_station.isCoin(DAOID)) {
                _fundRouter.transferToTreasury{value:amount}(DAOID, address(0), amount, RecruitType.REOPEN);
            } else {
                address token = _station.getTokenAddress(DAOID);    
                IERC20(token).safeApprove(address(_fundRouter), amount);
                _fundRouter.transferToTreasury(DAOID, token, amount, RecruitType.REOPEN);
            }
            address dtToken = _station.getDAOContractInfo(DAOID).dtInfo.cAddress;
            IDAOToken(dtToken).mint(reOpenInfo.addMintAmount);

            // price per DT
            reOpenInfo.price = (reOpenInfo.purposeAmount * denominator) / reOpenInfo.addMintAmount;
            reOpenInfo.totalRefundAmount = reOpenInfo.totalEnterAmount - reOpenInfo.purposeAmount;

        } else {
            reOpenInfo.status = ReOpenStatus.FAIL;
        }

        emit ReOpenConfirmed(DAOID, reOpenInfo.ID, msg.sender, reOpenInfo.status);
    }

    function _refund(
        uint reOpenId, 
        address user, 
        ReOpenInfo storage reOpenInfo
    ) 
        internal 
    {
        uint userRefundAmount;
        bytes32 column;
        uint DAOID = reOpenInfo.DAOID;
        address token = _station.getTokenAddress(DAOID);
        UserInfo storage userInfo = reOpenInfo.userInfos[user];

        if (reOpenInfo.status == ReOpenStatus.FAIL) {
            _checkRefund(reOpenId, user, reOpenInfo);
            userRefundAmount = userInfo.amount;
            reOpenInfo.totalRemainAmount -= userRefundAmount;
            userInfo.amount = 0;
            userInfo.status = UserStatus.REFUND;
            column = "REFUND";

        } else if(reOpenInfo.status == ReOpenStatus.CONFIRM) {
            require(_daoRouter == _msgSender(), "RO0-RF1-520");
            userInfo.isDTReceive = true;

            uint stakeRatio = getStakeRatio(reOpenId, user);
            userRefundAmount = (reOpenInfo.totalRefundAmount * stakeRatio) / denominator;            
            reOpenInfo.totalRemainAmount -= userRefundAmount;
            userInfo.amount -= userRefundAmount;
            column = "AFTER_REFUND";
        } else {
            require(false, "RO0-RF1-010");
        }

        _transferFund(DAOID, column, token, user, userRefundAmount);
        emit ReOpenRefunded(DAOID, reOpenId, user, userRefundAmount, column);
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
            require(success, "RO0-TF0-310");
        } else {
            require(IERC20(token).transfer(to, amount),"RO0-TF0-390");
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

    function _checkEnter(
        uint amount, 
        ReOpenInfo storage reOpenInfo
    ) 
        internal 
        view 
    {

        require(!_isClose(reOpenInfo.end) , "RO0-CE0-210");
        require(reOpenInfo.status == ReOpenStatus.OPEN , "RO0-CE0-510");
        if(_station.isCoin(reOpenInfo.DAOID)) {
            require(amount == 0, "RO0-CE0-410");
            require(msg.value >= reOpenInfo.minEnterAmount, "RO0-CE0-411");
            require((msg.value % reOpenInfo.unit) == 0, "RO0-CE0-412");
        } else {
            require(msg.value == 0, "RO0-CE0-413");
            require(amount >= reOpenInfo.minEnterAmount, "RO0-CE0-414");
            require((amount % reOpenInfo.unit) == 0, "RO0-CE0-415");
        }
    }

    function _checkCancel(
        address user, 
        ReOpenInfo storage reOpenInfo
    ) 
        internal 
        view 
    {
        UserStatus status = reOpenInfo.userInfos[user].status;

        require(!_isClose(reOpenInfo.end), "RO0-CC1-210");
        require(status == UserStatus.ENTER, "RO0-CC1-510");
    }

    function _checkConfirm(
        ReOpenInfo storage reOpenInfo
    ) 
        internal 
        view 
    {
        require(_isClose(reOpenInfo.end), "RO0-CC2-110");
        require(reOpenInfo.status == ReOpenStatus.OPEN, "RO0-CC2-510");
    }

    function _checkRefund(
        uint reOpenId, 
        address user, 
        ReOpenInfo storage reOpenInfo
    ) 
        internal 
        view 
    {
        UserStatus status = _reOpenInfos[reOpenId].userInfos[user].status;

        require(reOpenInfo.status == ReOpenStatus.FAIL, "RO0-CR0-510");
        require(status == UserStatus.ENTER, "RO0-CR0-511");
    }


    function _isSuccessReOpen(ReOpenInfo storage reOpenInfo) internal view returns (bool) {
        return reOpenInfo.totalEnterAmount >= reOpenInfo.purposeAmount;
    }

    function _isClose(uint time) internal view  returns (bool) {
        return block.timestamp > time;
    }
}