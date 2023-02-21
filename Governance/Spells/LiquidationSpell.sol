// SPDX-License-Identifier: MIT
pragma solidity 0.8.10;

import "../SpellBase.sol";
import "../../Station/IStation.sol";
import "../../Token/IDAOToken.sol";
import "../../Token/IGovernanceToken.sol";
import "../../StakingPool/IStakingPool.sol";
import "../../Router/IFundRouter.sol";
import "../../../../../contracts/openzeppelin-contracts/utils/Address.sol";

/**
    This spell use for Liquidation
 */

interface IForSpell {
    function businessFund(uint) external view returns (uint);
    function getBalance(uint) external view returns (uint);
}
contract LiquidationSpell is SpellBase {
    using Address for address;

    struct Params {
        uint daoId;
    }

    address immutable private _stakingPool;
    address immutable private _fundRouter;

    event Liquidated(uint indexed daoId);

    constructor(
        address governance,
        address station,
        address spellRegistry,
        address fundRouter,
        address stakingPool
    )
        SpellBase(governance, station, spellRegistry) 
    {
        _fundRouter = fundRouter;
        _stakingPool = stakingPool;
    }

    /**
     * @dev execute spell
     */
    function cast(Params memory input) external onlyGovernance returns(bool) {

        // set status dissolve
        (bool SStatus, ) = address(_station).call(
            abi.encodeWithSelector(
                IStation.dissolve.selector,
                input.daoId
            )
        );
        
        if(!SStatus) {
            return false;
        }
       
        // staking pool liquidation
        (bool SPStatus, ) = _stakingPool.call(
            abi.encodeWithSelector(
                IStakingPool.liquidation.selector,
                input.daoId
            )
        );
        
        if(!SPStatus) {
            return false;
        }

        // treasury liquidation
        
        (bool TStatus, ) = _fundRouter.call(
            abi.encodeWithSelector(
                IFundRouter.liquidate.selector,
                input.daoId
            )
        );

        if(!TStatus) {
            return false;
        }
       
        emit Liquidated(input.daoId);

        return true;
    }

    function isValidParams(bytes calldata params, uint daoId) external view virtual override returns(bool) {
        bytes4 paramsSelector = params[0] |
            (bytes4(params[1]) >> 8) |
            (bytes4(params[2]) >> 16) |
            (bytes4(params[3]) >> 24);
            
        Params memory inputs = abi.decode(params[4:], (Params));

        require(paramsSelector == this.cast.selector, "LS0-IV0-540");
        require(_isValidDaoId(inputs.daoId, daoId), "LS0-IV0-510");

        return true;
    }
}