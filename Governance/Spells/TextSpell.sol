// SPDX-License-Identifier: MIT
pragma solidity 0.8.10;

import "../SpellBase.sol";
import "../../Station/IStation.sol";
import "../../Token/IDAOToken.sol";
import "../../Token/IGovernanceToken.sol";
import "../../StakingPool/IStakingPool.sol";
import "../../Router/IFundRouter.sol";
import "../../../../../contracts/openzeppelin-contracts/utils/Counters.sol";
import "../../../../../contracts/openzeppelin-contracts/utils/Address.sol";

/**
    This spell use for Liquidation
 */

contract TextSpell is SpellBase {
    using Address for address;
    using Counters for Counters.Counter;

    struct Params {
        uint daoId;
        bytes desc;
    }

    event TextRecorded(uint daoId);

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

        emit TextRecorded(input.daoId);

        return true;
    }

    function isValidParams(bytes calldata params, uint daoId) external view virtual override returns(bool) {
        bytes4 paramsSelector = params[0] |
            (bytes4(params[1]) >> 8) |
            (bytes4(params[2]) >> 16) |
            (bytes4(params[3]) >> 24);
            
        Params memory inputs = abi.decode(params[4:], (Params));

        require(paramsSelector == this.cast.selector, "TS0-IV0-540");
        require(_isValidDaoId(inputs.daoId, daoId), "TS0-IV0-510");

        return true;
    }
}