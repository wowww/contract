// SPDX-License-Identifier: MIT
pragma solidity 0.8.10;

import "../SpellBase.sol";
import "../../Router/IFundRouter.sol";

/**
    This spell used for swap
    swap treasury fund
 */

contract SwapSpell is SpellBase {

    struct SwapInfo {
        uint amount;
        uint outMin;
        address[] path;
    }

    struct Params {
        uint daoId;
        SwapInfo[] orders;
    }

    address immutable private _fundRouter;

    event SwapSucceed(uint indexed daoId, uint idx, address from, address to);
    event SwapFailed(uint indexed daoId, uint idx, address from, address to);

    constructor(
        address governance,
        address station,
        address spellRegistry,
        address fundRouter
    )
        SpellBase(governance, station, spellRegistry) 
    {
        _fundRouter = fundRouter;
    }

    /**
     * @dev execute spell
     */
    function cast(Params memory input) external virtual onlyGovernance returns(bool) {
        bool totalStatus = true;
        for(uint i = 0; i < input.orders.length; i++) {
            SwapInfo memory info = input.orders[i];

            (bool status,) = _fundRouter.call(
                abi.encodeWithSelector(
                    IFundRouter.swap.selector,
                    input.daoId,
                    info.amount,
                    info.outMin,
                    info.path
                )
            );
            totalStatus = totalStatus && status;
            if(status) {
                emit SwapSucceed(
                    input.daoId,
                    i,
                    info.path[0],
                    info.path[info.path.length - 1]
                );
            }else {
                emit SwapFailed(
                    input.daoId,
                    i,
                    info.path[0],
                    info.path[info.path.length - 1]
                );
            }  
        }
        if(totalStatus) {
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

        require(paramsSelector == this.cast.selector, "SS0-IV0-540");
        require(_isValidDaoId(inputs.daoId, daoId), "SS0-IV0-510");
        require(inputs.orders.length > 0, "SS0-IV0-110");

        return true;
    }
}