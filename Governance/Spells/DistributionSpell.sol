// SPDX-License-Identifier: MIT
pragma solidity 0.8.10;

import "../SpellBase.sol";
import "../Payment/IPayment.sol";
/**
    This spell used for change revenue distribution policy
 */
contract DistributionSpell is SpellBase, IPaymentStruct, IStationStruct {

    struct Params {
        uint daoId;
        uint agendaId;
        bytes32 hashed;
        uint burnRatio;
    }

    address private _payment;

    event BurnRatioChanged(uint indexed daoId, bytes32 indexed hashed);

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
                IPayment.changeDTDistribution.selector,
                input.daoId,
                input.hashed,
                input.burnRatio
            )
        );

        if(status) {
            emit BurnRatioChanged(input.daoId, input.hashed);

            return true;
        }else{
            return false;
        }
    }

    function isValidParams(bytes calldata params, uint daoId) external view virtual override returns(bool) {
        bytes4 paramsSelector = params[0] |
            (bytes4(params[1]) >> 8) |
            (bytes4(params[2]) >> 16) |
            (bytes4(params[3]) >> 24);
            
        Params memory inputs = abi.decode(params[4:], (Params));

        require(paramsSelector == this.cast.selector, "DS0-IV0-540");
        require(_isValidDaoId(inputs.daoId, daoId), "DS0-IV0-510");
        require(inputs.agendaId <= IGovernance(_governance).getCurrentId(inputs.daoId), "DS0-IV0-511");

        bytes32 hashed = IPayment(_payment).getBusinessHash(inputs.daoId, inputs.agendaId);
        require(hashed == inputs.hashed, "DS0-IV0-541");
        require(IPayment(_payment).isValidBusinessInfo(inputs.daoId, inputs.hashed), "DS0-IV0-050");
        require(inputs.burnRatio <= _baseUnit, "DS0-IV0-210");
        
        return true;
    }
}