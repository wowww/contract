// SPDX-License-Identifier: MIT
pragma solidity 0.8.10;

import "../ContractFactory/IContractFactory.sol";
import "../Token/GovernanceToken.sol";
import "../Token/DAOToken.sol";
import "../Role/EditorRole.sol";
import "../../../../contracts/openzeppelin-contracts/utils/Address.sol";

/**
 * @title ContractFactory
 * @author Wemade Pte, Ltd
 *
 */

contract ContractFactory is IContractFactory, EditorRole {
    using Address for address;

    address private _station;
    address private _spellRegistry;
    address private _daoRouter;
    address private _reopen;
    address private _governance;
    bool isInit;

    function init(
        address station, 
        address spellRegistry, 
        address daoRouter,
        address reopen,
        address governance
    ) 
        external 
        onlyEditor
    {
        require(!isInit, "CF0-IN0-500");
        require(station.isContract() 
            && spellRegistry.isContract() 
            && daoRouter.isContract()
            && reopen.isContract()
            && governance.isContract(), 
            "CF0-IN0-520" 
        );

        _station = station;
        _spellRegistry = spellRegistry;
        _daoRouter = daoRouter;
        _reopen = reopen;
        _governance = governance;

        isInit = true;
    }

    /** @dev After the DAO is confirmed, the Station deploys the DAO Token
     * @param name DAO token name
     * @param symbol DAO token symbol
     * @param id  DAO ID
     * @param totalSupply token issuance
     */
    function deployDT(
        string memory name, 
        string memory symbol, 
        address stakingPool, 
        address incinerator, 
        uint id, 
        uint totalSupply
    )
        external 
        override  
        onlyEditor 
        returns (address) 
    {
        DAOToken dtToken = new DAOToken(
            name, 
            symbol, 
            stakingPool,
            incinerator, 
            _spellRegistry, 
            _daoRouter,
            _station,
            _reopen,
            id, 
            totalSupply
        );

        return address(dtToken);
    }

    /** @dev After the DAO is confirmed, the Station deploys the Governance Token
     * @param name DAO token name
     * @param symbol DAO token symbol
     */
    function deployGT(
        string memory name, 
        string memory symbol, 
        address stakingPool
    ) 
        external 
        override 
        onlyEditor   
        returns (address) 
    {
        GovernanceToken gtToken = new GovernanceToken(name, symbol, _spellRegistry, stakingPool, _governance, _daoRouter);
        
        return address(gtToken);
    }
}