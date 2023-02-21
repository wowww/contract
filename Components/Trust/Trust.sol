// SPDX-License-Identifier: MIT

pragma solidity 0.8.10;

import "./ITrust.sol";
import "../NILEComponent.sol";
import "../../Governance/Payment/IPayment.sol";

/**
 * @title Trust
 * @author Wemade Pte, Ltd
 * @dev Contract in which an off-chain company carrying out the business of WONDER DAO withdraws business funds or deposits business revenue
 */
contract Trust is ITrust, NILEComponent {
    // Pte fee
    struct Pte {
        mapping(bytes32 => Fund) fee;        // total Pte fee by the business
        Fund totalFee;                       // total Pte fee by all business
    }

    // Creator fee
    struct Creator {
        mapping(bytes32 => mapping(address => Fund)) personalFeePerBusiness; // personal creator fee per business
        mapping(address => Fund) personalFee;                                // personal creator fee per all business
        mapping(bytes32 => Fund) feePerBusiness;                             // total creator fee per business
        Fund totalFee;                                                       // total creator fee per all business
    }

    // History of distribution of business revenue
    struct Distribution {
        // Purchase funds
        mapping(bytes32 => Fund) purchaseFund;     // total burned DT in the business
        Fund totalPurchaseFund;                    // total burned DT in all business

        // Reserve funds
        mapping(bytes32 => Fund) reserveFund;      // total distributed funds transferred to Treasury
        Fund totalReserveFund;                     // total all distributed funds transferred to Treasury

        Creator creator;
    }

    // History of the Pte's use of funds
    struct Withdrawal {
        // start business
        mapping(bytes32 => address) token;     // used token
        mapping(bytes32 => Fund) businessFund; // total used business funds
        Fund totalBusinessFund;                // total all used business funds

        Pte pte;
    }

    // History of the Trust's business revenue deposits
    struct Deposit {
        // Pte -> Trust (finish business)
        mapping(bytes32 => address) token;    // revenue token
        mapping(bytes32 => Fund) revenue;     // total business revenue
        Fund totalRevenue;                    // total all business revenue

        Pte pte;
        Distribution distribution;
    }

    // mapping structures with DAO ID
    mapping(uint => Withdrawal) private  _withdrawal;
    mapping(uint => Deposit) private _deposit;

    constructor(address fundRouter) NILEComponent(fundRouter) {}

    /**
     * @dev transfer funds to Pte
     * @param id DAO ID
     * @param business Business ID
     * @param token token address used by business
     * @param pte Pte address
     * @param amount amount of business funds
     * @param fee amount of Pte fee
     */
    function transferToPte(
        uint id,
        bytes32 business,
        address token,
        address pte,
        uint amount,
        uint fee
    ) 
        external
        payable
        override
        onlyFundRouter
    {
        unchecked {
            if(_isCoin(token)) {
                _withdrawal[id].businessFund[business].wemix += amount;
                _withdrawal[id].totalBusinessFund.wemix += amount;

                _withdrawal[id].pte.fee[business].wemix += fee;
                _withdrawal[id].pte.totalFee.wemix += fee;
            } else {
                _withdrawal[id].businessFund[business].token[token] += amount;
                _withdrawal[id].totalBusinessFund.token[token] += amount;

                _withdrawal[id].pte.fee[business].token[token] += fee;
                _withdrawal[id].pte.totalFee.token[token] += fee;
            }
        }

        _withdrawal[id].token[business] = token;

        _transferFund(id, business, token, pte, amount + fee);
    }

    /**
     * @dev Transfer revenue Trust -> Pte,Treasury,Incinerator,Creator....                    
     * @param id DAO ID
     * @param business Business ID
     * @param token token address used by revenue
     * @param recipients array of recipient's address
     * @param amounts array of amount that recipients will be recieved
     */
    function distributeRevenue(
        uint id,
        bytes32 business,
        address token,
        address[] calldata recipients,
        uint[] calldata amounts
    )
        external
        payable
        override
        onlyFundRouter
    {
        uint pteFee = amounts[0];
        uint reserveFund = amounts[1];
        uint purchaseFund = amounts[2];
        uint creatorFee;
        uint totalAmount;

        for(uint i = 0; i < recipients.length; i++) {
            totalAmount += amounts[i];
            if(i > 2) {
                unchecked {
                    if(_isCoin(token)) {
                        _deposit[id].distribution.creator.personalFeePerBusiness[business][recipients[i]].wemix += amounts[i];
                        _deposit[id].distribution.creator.personalFee[recipients[i]].wemix += amounts[i];
                        _deposit[id].distribution.creator.feePerBusiness[business].wemix += amounts[i];
                        _deposit[id].distribution.creator.totalFee.wemix += amounts[i];
                    } else {
                        _deposit[id].distribution.creator.personalFeePerBusiness[business][recipients[i]].token[token] += amounts[i];
                        _deposit[id].distribution.creator.personalFee[recipients[i]].token[token] += amounts[i];
                        _deposit[id].distribution.creator.feePerBusiness[business].token[token] += amounts[i];
                        _deposit[id].distribution.creator.totalFee.token[token] += amounts[i];
                    }   
                }
            }
            _transferFund(id, business, token, recipients[i], amounts[i]);
        }

        unchecked { creatorFee = totalAmount - (pteFee + purchaseFund + reserveFund); }

        unchecked {
            if (_isCoin(token)) {
                _deposit[id].revenue[business].wemix += totalAmount;
                _deposit[id].totalRevenue.wemix += totalAmount;

                _deposit[id].pte.fee[business].wemix += pteFee;
                _deposit[id].pte.totalFee.wemix += pteFee;

                _deposit[id].distribution.reserveFund[business].wemix += reserveFund;
                _deposit[id].distribution.totalReserveFund.wemix += reserveFund;

                _deposit[id].distribution.purchaseFund[business].wemix += purchaseFund;
                _deposit[id].distribution.totalPurchaseFund.wemix += purchaseFund;
            
        } else {            
                _deposit[id].revenue[business].token[token] += totalAmount;
                _deposit[id].totalRevenue.token[token] += totalAmount;

                _deposit[id].pte.fee[business].token[token] += pteFee;
                _deposit[id].pte.totalFee.token[token] += pteFee;

                _deposit[id].distribution.reserveFund[business].token[token] += reserveFund;
                _deposit[id].distribution.totalReserveFund.token[token] += reserveFund;

                _deposit[id].distribution.purchaseFund[business].token[token] += purchaseFund;
                _deposit[id].distribution.totalPurchaseFund.token[token] += purchaseFund;
            }   
        }

        _deposit[id].token[business] = token;

        emit RevenueDistributed(id, business, token, pteFee, purchaseFund, reserveFund, creatorFee);
    }

    /////// get details of deposit
    function revenue(uint id, bytes32 business) external view returns (address token, uint amount) {
        token = _deposit[id].token[business];

        if(_isCoin(token)) {
            amount = _deposit[id].revenue[business].wemix;
        } else {
            amount = _deposit[id].revenue[business].token[token];
        }
    }

    function totalRevenue(uint id, address token) external view returns (uint amount) {
        if(_isCoin(token)) {
            amount = _deposit[id].totalRevenue.wemix;
        } else {
            amount = _deposit[id].totalRevenue.token[token];
        }
    }

    function distributedRevenue(
        uint id,
        bytes32 business
    ) 
        external 
        view 
        returns(
            address token,
            uint pteFee,
            uint reserveFund,
            uint purchaseFund,
            uint creatoreFee
        ) 
    {
        token = _deposit[id].token[business];
        
        if(_isCoin(token)) {
            pteFee = _deposit[id].pte.fee[business].wemix;
            reserveFund = _deposit[id].distribution.reserveFund[business].wemix;
            purchaseFund = _deposit[id].distribution.purchaseFund[business].wemix;
            creatoreFee = _deposit[id].distribution.creator.feePerBusiness[business].wemix;
        } else {
            pteFee = _deposit[id].pte.fee[business].token[token];
            reserveFund = _deposit[id].distribution.reserveFund[business].token[token];
            purchaseFund = _deposit[id].distribution.purchaseFund[business].token[token];
            creatoreFee = _deposit[id].distribution.creator.feePerBusiness[business].token[token];
        }
    }

    function totalDistributedRevenue(
        uint id,
        address token
    ) 
        external
        view
        returns(
            uint pteFee,
            uint reserveFund,
            uint purchaseFund,
            uint creatorFee
        ) 
    {
        
       if(_isCoin(token)) {
            pteFee = _deposit[id].pte.totalFee.wemix;
            reserveFund = _deposit[id].distribution.totalReserveFund.wemix;
            purchaseFund = _deposit[id].distribution.totalPurchaseFund.wemix;
            creatorFee = _deposit[id].distribution.creator.totalFee.wemix;
        } else {
            pteFee = _deposit[id].pte.totalFee.token[token];
            reserveFund = _deposit[id].distribution.totalReserveFund.token[token];
            purchaseFund = _deposit[id].distribution.totalPurchaseFund.token[token];
            creatorFee = _deposit[id].distribution.creator.totalFee.token[token];
        }
    }

    function personalCreatorFeePerBusiness(
        uint id,
        bytes32 business,
        address creator
    ) 
        external 
        view 
        returns(
            address token,
            uint creatoreFee
        ) 
    {
        token = _deposit[id].token[business];
        
        if(_isCoin(token)) {
            creatoreFee = _deposit[id].distribution.creator.personalFeePerBusiness[business][creator].wemix;
        } else {
            creatoreFee = _deposit[id].distribution.creator.personalFeePerBusiness[business][creator].token[token];
        }
    }

    function personalCreatorFee(
        uint id,
        address token,
        address creator
    ) 
        external 
        view 
        returns(
            uint creatoreFee
        ) 
    {
        if(_isCoin(token)) {
            creatoreFee = _deposit[id].distribution.creator.personalFee[creator].wemix;
        } else {
            creatoreFee = _deposit[id].distribution.creator.personalFee[creator].token[token];
        }
    }

    /////// get details of withdrawal
    function usedFund(
        uint id,
        bytes32 business
    ) 
        external
        view
        returns(
            address token,
            uint businessFund,
            uint fee
        ) 
    {
        token = _withdrawal[id].token[business];

        if(_isCoin(token)) {
            businessFund = _withdrawal[id].businessFund[business].wemix;
            fee = _withdrawal[id].pte.fee[business].wemix;
        } else {
            businessFund = _withdrawal[id].businessFund[business].token[token];
            fee = _withdrawal[id].pte.fee[business].token[token];
        }
    }

    function totalUsedFund(
        uint id,
        address token
    ) 
        external
        view
        returns (
            uint businessFund,
            uint fee
        ) 
    {
         if(_isCoin(token)) {
            businessFund = _withdrawal[id].totalBusinessFund.wemix;
            fee = _withdrawal[id].pte.totalFee.wemix;
        } else {
            businessFund = _withdrawal[id].totalBusinessFund.token[token];
            fee = _withdrawal[id].pte.totalFee.token[token];
        }
    }
}