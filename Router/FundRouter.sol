// SPDX-License-Identifier: MIT

pragma solidity 0.8.10;

import "./IFundRouter.sol";
import "../Role/EditorRole.sol";
import "../Common/DAOPausable.sol";
import "../Components/FundManager/IFundManager.sol";
import "../Components/Treasury/ITreasury.sol";
import "../Components/Trust/ITrust.sol";
import "../Components/Incinerator/IIncinerator.sol";
import "../Station/IStationView.sol";
import "../Registry/ISpellRegistry.sol";
import "../Governance/Payment/IPayment.sol";
import "../../../VRF/contracts/IVRF.sol";
import "../../../../contracts/openzeppelin-contracts/token/ERC20/IERC20.sol";
import "../../../../contracts/openzeppelin-contracts/utils/Address.sol";

/**
 * @title FundRouter
 * @author Wemade Pte, Ltd
 * @dev The router through which NILE components transfer funds
 */
contract FundRouter is IFundRouter, EditorRole, DAOPausable {

    using Address for address;

    bool public isInit;
    uint public period = 86400;

    // address of contracts
    address private _station;
    address private _treasury;
    address private _trust;
    address private _incinerator;
    address private _spellRegistry;
    address private _payment;
    address private _reOpen;
    address private _vrfVerify;

    address[] private _components;

    struct VRF {
        uint256[2] publicKey;               // [0]: X of private key, [1]: Y of private key 
        uint256[4] proof;                   // [0]: GammaX, [1]: GammaY, [2]: c, [3]: s
        bytes seed;                         // seed to generate proof (unix timestamp)
        bytes message;                      // "beta" of result that prove VRF proof
        uint ranNum;                        // converted "message" to an integer
        uint256[2] uPoint;                  // converted "message" to an integer
        uint256[4] vComponents;             // converted "message" to an integer
    }

    event Init(
        address station,
        address treasury,
        address trust,
        address incinerator,
        address spellRegistry,
        address payament,
        address reOpen,
        address vrfVerify
    );
    
    event UsedVRF(
        uint256[2] publicKey,
        uint256[4] proof,
        bytes seed,
        bytes message,
        uint ranNum,
        uint256[2] uPoint,
        uint256[4] vComponents        
    );

    event PurchasedDT(
        uint id,
        bool success
    );

    modifier afterInit() {
        require(isInit, "FR0-MDF-500");
        _;
    }

    modifier onlyStation() {
        require(msg.sender == _station || msg.sender == _reOpen, "FR0-MDF-520");
        _;
    }

    modifier onlySpell {
        require(ISpellRegistry(_spellRegistry).isSpell(msg.sender), "FR0-MDF-521");
        _;
    }

    modifier onlyPte(uint id, bytes32 business) {
        require(msg.sender == IPayment(_payment).getBusinessInfo(id, business).receiver, "FR0-MDF-522");
        _;
    }

    /**
     * @dev set NILE contracts address
     * @param station Station address
     * @param treasury Treasury address
     * @param trust Trust address
     * @param incinerator Incinerator address
     * @param spellRegistry spellRegistry address
     * @param payment Payment address
     * @param reOpen ReOpen address
     * @param vrfVerify VRF address
     */
    function init(
        address station,
        address treasury,
        address trust,
        address incinerator,
        address spellRegistry,
        address payment,
        address reOpen,
        address vrfVerify
    )
        external
        onlyOwner
    {
        require(!isInit, "FR0-IN0-500");
        require(station.isContract() && treasury.isContract() && trust.isContract() 
           && incinerator.isContract() && spellRegistry.isContract() && payment.isContract()
           && reOpen.isContract() && vrfVerify.isContract()
           , "FR0-IN0-520" 
        );

        _station = station;
        _treasury = treasury;
        _trust = trust;
        _incinerator = incinerator;
        _spellRegistry = spellRegistry;
        _payment = payment;
        _reOpen = reOpen;
        _vrfVerify = vrfVerify;

        _components.push(_station);
        _components.push(_treasury);
        _components.push(_trust);
        _components.push(_incinerator);
        
        
        isInit = true;

        emit Init(
            _station,
            _treasury,
            _trust,
            _incinerator,
            _spellRegistry,
            _payment,
            _reOpen,
            _vrfVerify
        );
    }

    /**
     * @dev Transfer recruitment funds to treasury from station
     * @param id DAO ID
     * @param token token address
     * @param amount amout collected at station
     * @param recruitType type of recruitment
     */
    function transferToTreasury(
        uint id,
        address token,
        uint amount,
        RecruitType recruitType
    ) 
        external
        payable 
        override
        afterInit
        whenNotPaused(id)
        onlyStation
    {
        if (_isCoin(token)) {
            require(msg.value == amount, "FR0-TT0-410");
            IFundManager(_treasury).receiveFund{ value : amount }(id, "Recruitment", token, amount);    
        } else {
            require(IERC20(token).transferFrom(msg.sender, _treasury, amount), "FR0-TT0-390");
            IFundManager(_treasury).receiveFund(id, "Recruitment", token, amount);
        }

        if (recruitType == RecruitType.DAO) {
            bytes32 business = IPayment(_payment).getBusinessHash(id, 0);
            transferToReceiver(id, business);
        }
    }

    /**
     * @dev Transfer busniess funds to trust from treasury
     * @param id DAO ID
     * @param business Business ID
     */
    function transferToReceiver(
        uint id,
        bytes32 business
    )
        public
        override
        afterInit
        whenNotPaused(id)
    {
        require(msg.sender == _station || ISpellRegistry(_spellRegistry).isSpell(msg.sender), "FR0-TR0-520");
        
        address token = IPayment(_payment).getBusinessInfo(id, business).fundAddr;
        uint amount = IPayment(_payment).getBusinessInfo(id, business).amount;
        uint fee = IPayment(_payment).getPerformFee(id, business, amount);

        uint totalAmount = amount + fee;
        address receiver = IPayment(_payment).getBusinessInfo(id, business).receiver;
        uint rType = IStationView(_station).getReceiverType(receiver);
        bytes32 column;

        if (rType == 0) {
            column = "Busniess";
            IFundManager(_treasury).transferFund(id, column, token, _trust, totalAmount);
            ITrust(_trust).transferToPte(id, business, token, receiver, amount, fee);
        } else {
            column = "Charge_Gas";
            IFundManager(_treasury).transferFund(id, column, token, receiver, totalAmount);
        }
    }

    /**
     * @dev deposit funds(business revenue)
     * @param id DAO ID
     * @param business Business ID
     * @param token token address
     * @param amount deposit amount
     */
    function deposit(
        uint id,
        bytes32 business,
        address token,
        uint amount
    )
        external
        payable
        afterInit
        whenNotPaused(id)
        onlyPte(id,business)
    {
        (address[] memory recipients, uint[] memory amounts) = IPayment(_payment).getRevenueDistributionInfo(id, business, amount);
        
        if (_isCoin(token)) {
            require(msg.value == amount, "FR0-DP0-410");
            ITrust(_trust).distributeRevenue{value: amount}(id, business, token, recipients, amounts);
        } else {
            require(IERC20(token).transferFrom(msg.sender, _trust, amount), "FR0-DP0-390");
            ITrust(_trust).distributeRevenue(id, business, token, recipients, amounts);
        }

        IFundManager(_treasury).receiveFund(id, "Business Revenue", token, amounts[1]);
        IFundManager(_incinerator).receiveFund(id, "Business Revenue", token, amounts[2]);

    }

    /**
     * @dev purchase DT
     * @param id DAO ID
     * @param business Business ID
     * @param amountOutMin minimum amount of tokens to be paid through swap
     * @param path token path to use for swap
     * @param vrf VRF data
     */
    function purchaseDT(
        uint id,
        bytes32 business,
        uint amountOutMin,
        address[] memory path,
        VRF memory vrf
    ) 
        external 
        payable 
        afterInit 
        whenNotPaused(id) 
    {
        require(msg.sender == IStationView(_station).getMelter(id), "FR0-PD0-520");
        require(IPayment(_payment).isValidBusinessInfo(id, business), "FR0-PD0-050");

        uint _ranNum = vrf.ranNum; 
        {
            uint256[2] memory _publicKey = vrf.publicKey;
            uint256[4] memory _proof = vrf.proof;
            bytes memory _seed = vrf.seed;
            bytes memory _message = vrf.message;
            
            uint256[2] memory _uPoint = vrf.uPoint;
            uint256[4] memory _vComponents = vrf.vComponents;
            uint[2] memory gamma;
            gamma[0] = _proof[0];
            gamma[1] = _proof[1];

            require(IVRF(_vrfVerify).fastVerify(_publicKey, _proof, _seed, _uPoint, _vComponents), "FR0-PD0-090");
            require(IVRF(_vrfVerify).verifyByProof(gamma, _message), "FR0-PD0-091");
            emit UsedVRF(_publicKey, _proof, _seed, _message, _ranNum, _uPoint, _vComponents);
        }
        
        uint _id = id;
        bytes32 _business = business;
        uint _amountOutMin = amountOutMin;
        address[] memory _path = path;
        uint unit = IIncinerator(_incinerator).unit();
        uint amountPurchase = IIncinerator(_incinerator).amountPurchase();
        uint criteria = IIncinerator(_incinerator).purchaseCriteria();
        uint usableFund = IFundManager(_incinerator).usableFund(_id, _path[0]);

        bool success;

        if (amountPurchase > usableFund) {
            amountPurchase = usableFund;
        }

        if ((_ranNum % unit) <= criteria) {
            address dt = IStationView(_station).getDAOContractInfo(_id).dtInfo.cAddress;

            uint amountOut = IFundManager(_incinerator).swap(_id, amountPurchase, _amountOutMin, _path, deadline());
            (uint amountBurn, uint amountSave) = IPayment(_payment).getPurchasedDTDisposeInfo(_id, _business, amountOut);
            
            IIncinerator(_incinerator).disposeDT(_id, dt, amountPurchase, amountBurn, amountSave);
            success = true;
        }

        emit PurchasedDT(_id, success);
        
    }

    /**
     * @dev swap
     * @param id DAO ID
     * @param amountIn amount to swap
     * @param amountOutMin minimum amount of tokens to be paid through swap
     * @param path token array to swap
     */
    function swap(
        uint id,
        uint amountIn,
        uint amountOutMin,
        address[] calldata path
    ) 
        external
        override
        afterInit
        whenNotPaused(id)
        onlySpell
    {
        uint amountOut = IFundManager(_treasury).swap(id, amountIn, amountOutMin, path, deadline());
        IFundManager(_treasury).receiveFund(id, "Swap", path[path.length - 1], amountOut);
    }

    /**
     * @dev liquidate when the DAO disolved
     * @param id DAO ID
     */
    function liquidate(
        uint id
    ) 
        external
        override
        afterInit
        whenNotPaused(id)
        onlySpell
    {
        address[] memory incineratorTokens = IFundManager(_incinerator).tokenCollection(id);
        address[] memory incineratorFunds = new address[](incineratorTokens.length + 1);

        for(uint i = 0; i < incineratorTokens.length; i++) {
            incineratorFunds[i+1] = incineratorTokens[i];
        }

        for(uint j = 0; j < incineratorFunds.length; j++) {
            uint balance = IFundManager(_incinerator).usableFund(id, incineratorFunds[j]);
            if(balance != 0) {
                IFundManager(_incinerator).transferFund(id, "Liquidate", incineratorFunds[j], _treasury, balance);
                IFundManager(_treasury).receiveFund(id, "Liquidate", incineratorFunds[j], balance);
                assert(IFundManager(_incinerator).usableFund(id, incineratorFunds[j]) == 0);
            }
        }

        (address[] memory allFunds, uint[] memory amounts) = ITreasury(_treasury).liquidate(id, _station);
        IStation(_station).setTokenCollection(id, allFunds, amounts);
        
        _pause(id);
    }

    /**
     * @dev to set deadline
     * @param _period period
     */
    function setDeadline(uint _period) external onlySpell {
        period = _period;
    }

    /**
     * @dev to get deadline
     */
    function deadline() public view returns (uint) {
        return block.timestamp + period;
    }

    /**
     * @dev to get array of components
     */
    function components() external view returns(address[] memory) {
        return _components;
    }

    /**
     * @dev check the token is coin
     * @param token token address
     */
    function _isCoin(address token) internal view returns (bool isCoin) {
        isCoin = (token == address(0));

        if(isCoin) {
            require(msg.value != 0, "FR0-IC0-410");
        }
    }
}