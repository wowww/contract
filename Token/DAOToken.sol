// SPDX-License-Identifier: MIT
pragma solidity 0.8.10;

import "../../../../contracts/openzeppelin-contracts/token/ERC20/ERC20.sol";
import "../../../../contracts/openzeppelin-contracts/security/ReentrancyGuard.sol";
import "../Registry/ISpellRegistry.sol";
import "../Role/RouterRole.sol";
import "../Station/IStation.sol";
import "./IDAOToken.sol";

contract DAOToken is ERC20, IDAOToken, ReentrancyGuard, IStationStruct, RouterRole {

    ISpellRegistry immutable private _spellRegistry;
    uint immutable public daoId;
    address immutable private _incinerator;
    address immutable private _stakingPool;
    address immutable private _station;
    address immutable private _reopen;
    address private _router;
    uint public burnAmount;
    bool private _isValidToken = true;

    event RouterChanged(address oldAddr, address newAddr);

    constructor(
        string memory name, 
        string memory symbol,
        address stakingPool,
        address incinerator,
        address spellRegistry,
        address router,
        address station,
        address reopen,
        uint DAOID,
        uint totalAmount
    ) 
        ERC20(name, symbol)
    {
        daoId = DAOID;
        _incinerator = incinerator;
        _stakingPool = stakingPool;
        _router = router;
        addRouter(router);
        _station = station;
        _reopen = reopen;
        _spellRegistry = ISpellRegistry(spellRegistry);

        _mint(address(this), totalAmount); 
    }

    modifier onlySpell() {
        require(_spellRegistry.isSpell(_msgSender()), "DT0-MDF-520");
        _;
    }
    
    function mint(uint amount) external override {
        require(_spellRegistry.isSpell(_msgSender()) || _msgSender() == _station || _msgSender() == _reopen, "DT0-MT0-520");

        _mint(address(this), amount);
    }

    function burn(address account, uint amount) external override onlyRouter {
        _burn(account, amount);
        burnAmount += amount;
    }

    function transferFrom(address from, address to, uint amount) public virtual override(ERC20, IERC20) returns (bool) {
        return super.transferFrom(from, to, amount);
    }

    function changeRouter(address router) external onlyEditor {
        require(isRouter(router), "DT0-CR0-520");
        address oldAddr = _router;
        address newAddr = router;
        removeRouter(oldAddr);
        addRouter(newAddr);
        _router = router;

        emit RouterChanged(oldAddr, newAddr);
    }

    function _transfer(address from, address to, uint256 amount) internal virtual override {
        if(to == _stakingPool) {
            require(isRouter(_msgSender()), "DT0-TF0-520");
        }
        super._transfer(from, to, amount);
    }

    function _mint(address account, uint256 amount) internal virtual override {
        super._mint(account, amount);
        _approve(address(this), _router, type(uint).max );
        _approve(address(this), _incinerator, type(uint).max );
        _approve(address(this), _stakingPool, type(uint).max );
    }
}