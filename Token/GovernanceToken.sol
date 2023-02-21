// SPDX-License-Identifier: MIT
pragma solidity 0.8.10;

import "./IGovernanceToken.sol";
import "../Registry/ISpellRegistry.sol";
import "../Role/RouterRole.sol";
import "../../../../contracts/openzeppelin-contracts/token/ERC20/extensions/ERC20Votes.sol";

contract GovernanceToken is IGovernanceToken, ERC20Votes, RouterRole { 

    string constant private _alias =  "g.";

    ISpellRegistry immutable private _spellRegistry;
    address immutable private _stakingPool;
    address immutable private _governance;

    constructor(
        string memory name, 
        string memory symbol,
        address spellRegistry,
        address stakingPool,
        address governance,
        address router
    ) 
        ERC20Permit(string(abi.encodePacked(_alias, name))) 
        ERC20(string(abi.encodePacked(_alias, name)), string(abi.encodePacked(_alias, symbol)))
    {
        _stakingPool = stakingPool;
        _spellRegistry = ISpellRegistry(spellRegistry);
        _governance = governance;
        addRouter(router);
    }

    modifier onlySpell() {
        require(_spellRegistry.isSpell(_msgSender()), "GT0-MDF-520");
        _;
    }

    modifier whenNotLocked() {
        // lock transfer user to user
        require(isRouter(_msgSender()) || _msgSender() == _stakingPool || _msgSender() == _governance, "GT0-MDF-521");
        _;
        
    }

    modifier onlyStakingPool() {
        require(_msgSender() == _stakingPool, "GT0-MDF-522");
        _;
    }

    /**
     * @dev delegate it self for record votes   
     */
    function mint(address to, uint amount) external override onlyStakingPool {
        _delegate(to, to);
        super._mint(to, amount);
    }

    function burn(address to, uint amount) external override onlyStakingPool {
        super._burn(to, amount);
    }

    /**
        _delegete() => delegate(), delegateBySig() functions were used
        this function works move votes address to address
     */
    function delegate(address account) public virtual override(ERC20Votes, IVotes) onlyRouter whenNotLocked {
        super.delegate(account);
    }

    function increaseAllowance(address spender, uint256 addedValue) public virtual override(ERC20, IGovernanceToken) returns (bool) {
        return super.increaseAllowance(spender, addedValue);
    }

    function delegateBySig(
        address delegatee, 
        uint nonce, 
        uint expiry, 
        uint8 v, 
        bytes32 r, 
        bytes32 s
    )
        public
        virtual
        override(ERC20Votes, IVotes)
        onlyRouter
        whenNotLocked
    {
        super.delegateBySig(delegatee, nonce, expiry, v, r, s);
    }

    // lock transfer user to user and user to staking pool
    function _transfer(
        address from,
        address to,
        uint256 amount
    ) 
        internal
        virtual
        override
        whenNotLocked
    {
        require(to != _stakingPool, "GT0-TF0-520");

        super._transfer(from, to, amount);
    }

    function _afterTokenTransfer(
        address from,
        address to,
        uint256 amount
    ) internal virtual override {
        if(from != _governance && to != _governance) {
            super._afterTokenTransfer(from, to, amount);
        }
    }
}