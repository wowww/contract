// SPDX-License-Identifier: MIT
pragma solidity 0.8.10;

import "../SpellBase.sol";
import "../../Station/IReOpen.sol";
/**
    This spell used for FeeRatioInfo
    burn and staking pool
 */
contract ReopenSpell is SpellBase {

    struct Params {
        bytes32 purpose;
        uint daoId;
        uint period;
        uint purposeAmount;
        uint minEnterAmount; 
        uint addMintAmount;
        uint unit;
    }

    address private _reopen;

    event ReOpened(uint indexed daoId, uint amount);
    constructor(
        address governance,
        address station,
        address spellRegistry,
        address reopen
    )
        SpellBase(governance, station, spellRegistry) 
    {
        _reopen = reopen;
    }

    /**
     * @dev execute spell
     */
    function cast(Params memory input) external onlyGovernance returns(bool) {
        (bool status, ) = address(_reopen).call(
            abi.encodeWithSelector(
                IReOpen.reOpen.selector,
                input.daoId,
                input.period,
                input.purposeAmount,
                input.minEnterAmount,
                input.addMintAmount,
                input.unit
            )
        );
        if(status) {
            emit ReOpened(input.daoId, input.purposeAmount);
            
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

        require(paramsSelector == this.cast.selector, "RS1-IV0-540");
        require(_isValidDaoId(inputs.daoId, daoId), "RS1-IV0-510");
        require(inputs.period != 0, "RS1-IV0-010");
        require(inputs.minEnterAmount != 0 , "RS1-IV0-011");
        require(inputs.purposeAmount >= inputs.minEnterAmount, "RS1-IV0-511");

        return true;
    }
}