// SPDX-License-Identifier: MIT
pragma solidity 0.8.10;


import "../SpellBase.sol";
import "../Payment/IPayment.sol";
import "../../Station/IStation.sol";
import "../../Registry/IMelterRegistry.sol";
import "../../Registry/IPteRegistry.sol";
import "../../Router/IFundRouter.sol";
import "../../Components/FundManager/IFundManager.sol";
/**
    This spell use for treasury payment proposal
 */

contract TreasurySpell is SpellBase, IPaymentStruct, IStationStruct {

    address immutable private _fundRouter;
    address immutable private _payment;
    address immutable private _melter;
    IPteRegistry immutable private _pteRegistry;

    event TreasuryUsed(uint indexed daoId, uint amount);
    constructor(
        address governance,
        address station,
        address spellRegistry,
        address fundRouter,
        address pteRegistry,
        address payment,
        address melter
    )
        SpellBase(governance, station, spellRegistry) 
    {
        _pteRegistry = IPteRegistry(pteRegistry);
        _fundRouter = fundRouter;
        _payment = payment;
        _melter = melter;
    }

    /**
     * @dev execute spell
     * selector: 0x606ed86a
     */
    function cast(PInfo memory input) external onlyGovernance returns(bool) {
        (bool status,) = _fundRouter.call(
            abi.encodeWithSelector(
                IFundRouter.transferToReceiver.selector,
                input.daoId,
                input.hashed
            )
        );
        
        if(status) {
            emit TreasuryUsed(input.daoId, input.amount);
            return true;
        }else {
            return false;
        }
    }

    function isValidParams(bytes calldata params, uint daoId) external view virtual override returns(bool) {
        bytes4 paramsSelector = params[0] |
            (bytes4(params[1]) >> 8) |
            (bytes4(params[2]) >> 16) |
            (bytes4(params[3]) >> 24);

        PInfo memory inputs = abi.decode(params[4:], (PInfo));

        uint sum = inputs.incomeRatio;
        
        for(uint8 i = 0;i < inputs.creators.length; i++) {
            sum += inputs.creators[i].ratio;
        }

        require(paramsSelector == this.cast.selector, "TS0-IV0-540");
        require(_isValidDaoId(inputs.daoId, daoId), "TS0-IV0-510");
        require(sum <= _baseUnit, "TS0-IV0-210");
        require(inputs.revenueRatio <= _baseUnit, "TS0-IV0-211");
        require(inputs.burnRatio <= _baseUnit, "TS0-IV0-212");

        if(_pteRegistry.isRegistered(inputs.name)) {
            require(_pteRegistry.getRegisteredPte(inputs.name) == inputs.receiver, "TS0-IV0-520");
        }else {
            require(IMelterRegistry(_melter).isMelter(inputs.receiver), "TS0-IV0-521");
        }

        return true;
    }
}