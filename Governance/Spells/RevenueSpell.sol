// SPDX-License-Identifier: MIT
pragma solidity 0.8.10;

import "../SpellBase.sol";
import "../Payment/IPayment.sol";
/**
    This spell used for change revenue policy
 */
contract RevenueSpell is SpellBase, IPaymentStruct {

    struct Params {
        uint daoId;
        uint agendaId;
        bytes32 hashed;
        uint revenueRatio;
        uint performRatio;
        uint incomeRatio;
    }

    address immutable private _payment;

    event PurchaseRatioChanged(uint indexed daoId, bytes32 indexed hashed);

    constructor(
        address governance,
        address station,
        address spellRegistry,
        address payment
    )
        SpellBase(governance, station, spellRegistry) 
    {
        _payment = payment;
    }

    /**
     * @dev execute spell
     */
    function cast(Params memory input) external onlyGovernance returns(bool) {
        (bool status, ) = address(_payment).call(
            abi.encodeWithSelector(
                IPayment.changeRevenueDistribution.selector,
                input.daoId,
                input.hashed,
                input.revenueRatio,
                input.performRatio,
                input.incomeRatio
            )
        );

       if(status) {
            emit PurchaseRatioChanged(input.daoId, input.hashed);

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
            
        Params memory inputs = abi.decode(params[4:], (Params));

        require(paramsSelector == this.cast.selector, "RS0-IV0-540");
        require(_isValidDaoId(inputs.daoId, daoId), "RS0-IV0-510");
        require(inputs.agendaId <= IGovernance(_governance).getCurrentId(inputs.daoId), "RS0-IV0-511");

        bytes32 hashed = IPayment(_payment).getBusinessHash(inputs.daoId, inputs.agendaId);
        require(hashed == inputs.hashed, "RS0-IV0-541");
        require(IPayment(_payment).isValidBusinessInfo(inputs.daoId, inputs.hashed), "RS0-IV0-050");
        require(inputs.revenueRatio <= _baseUnit, "RS0-IV0-210");
        require(inputs.performRatio <= _baseUnit, "RS0-IV0-211");

        PInfo memory info = IPayment(_payment).getBusinessInfo(inputs.daoId, hashed);
        
        uint sum = inputs.incomeRatio;

        for(uint8 i = 0;i < info.creators.length;i++) {
            sum += info.creators[i].ratio;
        }

        require(sum <= _baseUnit, "RS0-IV0-212");
        
        return true;
    }
}