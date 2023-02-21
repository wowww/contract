// SPDX-License-Identifier: MIT

pragma solidity 0.8.10;

import "./IIncinerator.sol";
import "../FundManager/FundManager.sol";
import "../../Router/IDAORouter.sol";

/**
 * @title Incinerator
 * @author Wemade Pte, Ltd
 * @dev Role in handling purchased DT
 */
contract Incinerator is IIncinerator, FundManager {

    uint public override unit = 1000;                 // unit to divide random values obtained through VRF
    uint public override purchaseCriteria = 500;      // criteria for remaining values obtained when random values for purchasing DT divided by unit
    uint public override amountPurchase = 500 ether;  // amount of coins (or tokens) to use when purchasing DT

    address private _daoRouter;   // address of DAORouter

    struct DT {
        uint totalBurnedAmount;   // amount of DT burned
        uint totalSavedAmount;    // amout of DT saved at stakingPool
    }

    // mapping structure with DAO ID
    mapping(uint => uint) public totalPurchaseFund;
    mapping(uint => DT) private _dtInfos;
    
    constructor(
        address daoRouter,
        address fundRouter,
        address weswapRouter
    ) 
        FundManager(fundRouter, weswapRouter) 
    {
        addRouter(daoRouter);
        _daoRouter = daoRouter;
    }
    
    /**
     * @dev dispose DT 
     * @param id DAO ID
     * @param dt address of dt
     * @param amountBurn amount of DT to be burned
     * @param amountSave amount of DT to be sent to stakingPool
     */
    function disposeDT(
        uint id,
        address dt,
        uint usedFund,
        uint amountBurn,
        uint amountSave
    ) 
        external
        override
        onlyFundRouter
    {
        unchecked {
            totalPurchaseFund[id] += usedFund;
            _dtInfos[id].totalBurnedAmount += amountBurn;
            _dtInfos[id].totalSavedAmount += amountSave;
        }

        if(IERC20(dt).allowance(address(this), _daoRouter) < amountSave) {
            require(IERC20(dt).approve(_daoRouter, type(uint).max), "IC0-DD0-390");
        }

        IDAORouter(_daoRouter).disposeDT(id, dt, amountBurn, amountSave);
        
        emit Burned(id, dt, amountBurn);
        emit Saved(id, dt, amountSave);
    }

    /**
     * @dev change address of DAORouter
     * @param router new address of DAORouter
     */
    function changeDAORouter(address router) external onlyEditor {
        require(isRouter(router), "IC0-CD0-520");
        _daoRouter = router;
    }

    /**
     * @dev change purchase criteria
     * @param criteria buy criteria
     */
    function changePurchaseCriteria(uint criteria) external onlyEditor {
        require(criteria <= unit, "IC0-CP0-210");
        purchaseCriteria = criteria;
    }

        /**
     * @dev Change purchase amount
     * @param amount purchase amount
     */
    function changeAmountPurchase(uint amount) external onlyEditor {
        amountPurchase = amount;
    }

    /**
     * @dev Change unit
     * @param exponent exponent of unit
     */
    function changeUnit(uint exponent) external onlyEditor {
        require(exponent >= 2, "IC0-CU0-110");
        unit = 10 ** (exponent);
    }

    /**
     * @dev to get amount of the DT purchased
     * @param id DAO ID
     */
    function purchasedDT(uint id) external view returns (uint) {
        return totalBurnedDT(id) + totalSavedDT(id);
    }

    /**
     * @dev to get amount of the DT burned
     * @param id DAO ID
     */
    function totalBurnedDT(uint id) public view returns (uint) {
        return _dtInfos[id].totalBurnedAmount;
    }

    /**
     * @dev to get amount of the DT saved at staking pool
     * @param id DAO ID
     */
    function totalSavedDT(uint id) public view returns (uint) {
        return _dtInfos[id].totalSavedAmount;
    }
}