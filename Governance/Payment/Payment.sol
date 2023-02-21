// SPDX-License-Identifier: MIT
pragma solidity 0.8.10;

import "./IPayment.sol";
import "../../Registry/ISpellRegistry.sol";
import "../../Role/EditorRole.sol";
import "../../../../../contracts/openzeppelin-contracts/utils/Context.sol";

contract Payment is IPayment, Context, EditorRole {

    ISpellRegistry private _spellRegistry;

    address private _governance;
    address private _station;
    address private _incinerator;
    address private _treasury;
    string constant private _salt = "NEITH_PROTOCOL_HASH_SALT";
    uint constant private UNIT = 1 ether;
    mapping(uint => mapping(bytes32 => PInfo)) private _businessInfos;              // mapping for business
    mapping(uint => mapping(uint => bytes32)) private _hashes;                      // business hashes, dao id => agenda id => hash
    constructor() {}

    modifier onlySpell() {
        require(_spellRegistry.isSpell(_msgSender()), "PM0-MDF-520");
        _;
    }

    /** 
    *   @dev init addresses for pointing other contracts
    */
    function setComponents(address spellRegistry, address governance, address station, address incinerator, address treasury) external onlyEditor {
        _spellRegistry = ISpellRegistry(spellRegistry);
        _governance = governance;
        _station = station;
        _incinerator = incinerator;
        _treasury = treasury;
    }
 
    /**
     * @dev set payment info
     * @param params input data. packed to use "function cast(PInfo memory)" from treasury spell
     * @param daoId dao id
     * @param agendaId agenda id
     */
    function setInfo(bytes calldata params, uint daoId, uint agendaId) external override {
        require(_msgSender() == _station || _msgSender() == _governance, "PM0-SI0-520");

        PInfo memory info = abi.decode(params[4:], (PInfo));
        bytes32 hashed = keccak256(abi.encodePacked(info.hashed, daoId, agendaId, _salt));
        
        _hashes[daoId][agendaId] = hashed;

        PInfo storage newInfo = _businessInfos[daoId][hashed];

        newInfo.fundAddr = info.fundAddr;
        newInfo.receiver = info.receiver;
        newInfo.name = info.name;
        newInfo.hashed = info.hashed;
        newInfo.desc = info.desc;
        newInfo.daoId = info.daoId;
        newInfo.agendaId = agendaId;
        newInfo.amount = info.amount;
        newInfo.revenueRatio = info.revenueRatio;
        newInfo.burnRatio = info.burnRatio;
        newInfo.performRatio = info.performRatio;
        newInfo.incomeRatio = info.incomeRatio;

        for(uint8 i = 0;i < info.creators.length;i++) {
            newInfo.creators.push(info.creators[i]);
        }
    }

    /**
     * @dev change revenue distribution policy
     * @param daoId dao id
     * @param hashed key of payment mapping. keccak256(business describe)
     * @param revenueRatio new rate which wemix used for revenue
     * @param performRatio new rate which wemix move to reciever when the revenue come out
     * @param incomeRatio new rate which wemix move to reciever when the revenue come in
     */
    function changeRevenueDistribution(uint daoId, bytes32 hashed, uint revenueRatio, uint performRatio, uint incomeRatio) external override onlySpell {
        _businessInfos[daoId][hashed].revenueRatio = revenueRatio;
        _businessInfos[daoId][hashed].performRatio = performRatio;
        _businessInfos[daoId][hashed].incomeRatio = incomeRatio;
    }

    /**
     * @dev change dao token distribution policy
     * @param daoId dao id
     * @param hashed key of payment mapping. keccak256(business describe)
     * @param burnRatio new rate which dao token to burn
     */
    function changeDTDistribution(uint daoId, bytes32 hashed, uint burnRatio) external override onlySpell {
        _businessInfos[daoId][hashed].burnRatio = burnRatio;
    }

    /**
     * @dev change business receiver name and address
     * @param daoId dao id
     * @param hashed key of payment mapping. keccak256(business describe)
     * @param name new receiver name
     * @param receiver new receiver address
     */
    function changeReceiver(uint daoId, bytes32 hashed, bytes32 name, address receiver) external override onlySpell {
        _businessInfos[daoId][hashed].name = name;
        _businessInfos[daoId][hashed].receiver = receiver;
    }

    /**
     *  @dev get target info
     */
    function getBusinessInfo(uint daoId, bytes32 hashed) external view override returns(PInfo memory) {
        return _businessInfos[daoId][hashed];
    }

    /**
     *  @dev get key hash
     */
    function getBusinessHash(uint daoId, uint agendaId) external view override returns (bytes32) {
        return _hashes[daoId][agendaId];
    }

    /**
     *  @dev check input account address is as same as target receiver address
     */
    function isValidReceiver(uint daoId, bytes32 hashed, address account) external view returns (bool) {
        return account == _businessInfos[daoId][hashed].receiver;
    }

    function isValidBusinessInfo(uint daoId, bytes32 hashed) external view returns (bool) {
        return _businessInfos[daoId][hashed].daoId != 0;
    }

    /**
     *  @dev calculate amount by distribution policy
     *  @param daoId target dao id
     *  @param hashed key hash
     *  @param amount total amount of revenue
     */
    function getPurchasedDTDisposeInfo(
        uint daoId,
        bytes32 hashed,
        uint amount
    ) 
        external
        view
        returns(
            uint amountBurn,
            uint amountSave
        )
    {
        amountBurn = _calcFee(
            amount,
            _businessInfos[daoId][hashed].burnRatio
        );
        amountSave = amount - amountBurn; 
    }

    /**
     *  @dev calculate amount by revenue distribution policy
     *  @param daoId target dao id
     *  @param hashed key hash
     *  @param amount total amount for business
     */
    function getRevenueDistributionInfo(
        uint daoId,
        bytes32 hashed,
        uint amount
    )
        external
        view
        override
        returns (address[] memory, uint[] memory)
    {
        PInfo memory info = _businessInfos[daoId][hashed];

        if(info.daoId == 0) {
            return (new address[](0), new uint[](0));
        }

        uint totalLen = 3 + info.creators.length;
        uint totalDistributedAmount;
        
        address[] memory recipients = new address[](totalLen);
        uint[] memory amounts = new uint[](totalLen);

        // pte
        recipients[0] = info.receiver;
        amounts[0] = _calcFee(amount, info.incomeRatio);

        totalDistributedAmount += amounts[0];

        // creators
        for(uint8 i = 0; i < info.creators.length; i++) {
            Recipient memory creator = info.creators[i];
            recipients[i + 3] = creator.account;
            amounts[i + 3] = _calcFee(amount, creator.ratio);

            totalDistributedAmount += amounts[i + 3];
        }

        uint remainAmount = amount - totalDistributedAmount;

        // treasury
        recipients[1] = _treasury;
        amounts[1] = _calcFee(remainAmount, info.revenueRatio);

        // incinerator
        recipients[2] = _incinerator;
        amounts[2] = remainAmount - amounts[1];

        return (recipients, amounts);
    }

    /**
     *  @dev calaulate income fee for pte
     *  @param daoId target dao id
     *  @param hashed key hash
     *  @param amount total amount for business 
     */
    function getPerformFee(
        uint daoId,
        bytes32 hashed,
        uint amount
    ) 
        public
        view
        override
        returns (uint) 
    {
        return _calcFee(
            amount,
            _businessInfos[daoId][hashed].performRatio
        );
    }

    /**
     *  @dev calaulate perform fee for pte
     *  @param daoId target dao id
     *  @param hashed key hash
     *  @param amount total amount for business 
     */
    function getIncomeFee(
        uint daoId,
        bytes32 hashed,
        uint amount
    ) 
        public
        view
        override
        returns (uint) 
    {
        return _calcFee(
            amount,
            _businessInfos[daoId][hashed].incomeRatio
        );
    }

    function _calcFee(uint amount, uint ratio) internal pure returns (uint) {
        return (amount * ratio) / UNIT;
    }
}