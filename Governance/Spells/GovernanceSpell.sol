// SPDX-License-Identifier: MIT
pragma solidity 0.8.10;

import "../SpellBase.sol";
/**
    This spell use for change permit policy
 */

contract GovernanceSpell is SpellBase, IGovernanceStruct {

    struct Params {
        uint daoId;
        uint spellType;
        BasePolicy basePolicy;
        SubPolicy[2] subPolicy;
    }
 
    event PolicyChanged(uint indexed daoId, uint indexed spellType, BasePolicy basePolicy, SubPolicy[2] subPolicy);

    constructor(
        address governance,
        address station,
        address spellRegistry
    )
        SpellBase(governance, station, spellRegistry) 
    {}

    /**
     * @dev execute spell
     */
    function cast(Params memory input) external onlyGovernance returns(bool) {
        //setPolicy(address dt, uint64 actionType, uint purpose, uint permitCutOff, uint rejectCutOff, uint aliveTime)
        (bool status, ) = _getGovernance().call(
            abi.encodeWithSelector(
                IGovernance.setPolicy.selector,
                input.daoId,
                input.spellType,
                input.basePolicy,
                input.subPolicy
            )
        );

        if(status) {
            emit PolicyChanged(input.daoId, input.spellType, input.basePolicy, input.subPolicy);

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

        BasePolicy memory basePolicy = inputs.basePolicy;
        SubPolicy[2] memory subPolicy = inputs.subPolicy;

        require(paramsSelector == this.cast.selector, "GS0-IV0-540");
        require(_isValidDaoId(inputs.daoId, daoId), "GS0-IV0-510");
        require(_isValidSpellType(inputs.spellType), "GS0-IV0-511");
        require(basePolicy.baseRatio <= _baseUnit, "GS0-IV0-210");
        require(basePolicy.baseRatio * 100 >= _baseUnit, "GS0-IV0-110");
        require(subPolicy[0].obligation + subPolicy[1].obligation <= _baseUnit, "GS0-IV0-211");
        require(_checkSubPolicy(basePolicy, subPolicy[0]), "GS0-IV0-050");
        require(_checkSubPolicy(basePolicy, subPolicy[1]), "GS0-IV0-051");
        
        return true;
    }

    function _checkSubPolicy(BasePolicy memory basePolicy, SubPolicy memory subPolicy) private view returns (bool) {
        return subPolicy.permitCutOff <= _baseUnit
        && subPolicy.permitCutOff * 2 >= _baseUnit
        && subPolicy.quorum <= _baseUnit
        && subPolicy.quorum * 100 >= basePolicy.baseRatio * 101
        && subPolicy.deadLine >= 1 days
        && subPolicy.deadLine <= 10 days;
    }

}