// SPDX-License-Identifier: MIT

pragma solidity 0.8.10;

import "./IFundManager.sol";
import "../NILEComponent.sol";
import "../../WemixFi/interfaces/IWeswapRouter.sol";
import "../..//WemixFi/interfaces/IWeswapFactory.sol";

/**
 * @title FundManager
 * @author Wemade Pte, Ltd
 * @dev Parent Contract of NILE Components that owns funds
 */
abstract contract FundManager is IFundManager, NILEComponent {
    
    address public wwemix;         // address of WWEMIX
    address internal _weswapRouter; // address of WeswapRouter

    // mapping with DAO ID
    mapping(uint => Fund) internal  _balance;                   // the information of balance of the id
    mapping(uint => address[]) internal _tokenCollection;       // the array of the tokens owned by DAO of the id
    mapping(uint => mapping(address => bool)) internal _isOwn;  // is the token owned by DAO of the id

    constructor(address fundRouter, address weswapRouter) NILEComponent(fundRouter) {
        _weswapRouter = weswapRouter;
        wwemix = IWeswapRouter(_weswapRouter).WWEMIX();
    }

    receive() external virtual payable override {
        bool isComponent;
        address[] memory components = IFundRouter(_fundRouter).components();
        
        for(uint i = 0; i < components.length; i++) {
            if(msg.sender == components[i] || msg.sender == _weswapRouter) {
                isComponent = true;
                break;
            }
        }

        require(isComponent, "FM0-RC0-020");
    }

    /**
     * @dev receive funds
     * @param id DAO ID
     * @param column source of funds
     * @param token token address to receive
     * @param amount amount of funds
     */
    function receiveFund(
        uint id,
        bytes32 column,
        address token,
        uint amount
    ) 
        external
        payable
        override
        onlyFundRouter
    {
        if(_isCoin(token)) {
            _balance[id].wemix += amount;
        } else {
            if(!isOwn(id, token)) {
                _addToken(id, token);
            }
            _balance[id].token[token] += amount;
        }

        emit FundReceived(id, column, token, amount);
    }

    /**
     * @dev transfer funds
     * @param id DAO ID
     * @param column source of funds
     * @param token token address to transfer
     * @param to address of recipient
     * @param amount amount of funds
     */
    function transferFund(
        uint id,
        bytes32 column,
        address token,
        address to,
        uint amount
    )   
        public 
        override
        onlyFundRouter
    {
        _spendBalance(id, token, amount);

        super._transferFund(id, column, token, to, amount);
    }

    /**
     * @dev swap
     * @param id DAO ID
     * @param amountIn amount to swap
     * @param path token array to swap
     * @param deadline dealine of swap
     */
    function swap(
        uint id,
        uint amountIn,
        uint amountOutMin,
        address[] calldata path,
        uint deadline
    )
        external
        override
        onlyFundRouter
        returns(uint amountOut)
    {
        _spendBalance(id, path[0], amountIn);

        uint[] memory amounts;

        if(_isCoin(path[0])) {
            amounts = IWeswapRouter(_weswapRouter).swapExactWEMIXForTokens{value: amountIn}(amountOutMin, path, address(this), deadline);
        } else {
            require(IERC20(path[0]).approve(_weswapRouter, amountIn), "FM0-SW0-390");
            if(path[path.length - 1] == wwemix) {
                amounts = IWeswapRouter(_weswapRouter).swapExactTokensForWEMIX(amountIn, amountOutMin, path, address(this), deadline);
            } else {
                amounts = IWeswapRouter(_weswapRouter).swapExactTokensForTokens(amountIn, amountOutMin, path, address(this), deadline);
            }
        }

        amountOut = amounts[amounts.length - 1];
    }

    /**
     * @dev change address of WeswapRouter
     * @param router new address of WeswapRouter
     */
    function changeWeswapRouter(address router) external onlyEditor {
        _weswapRouter = router;

        emit RouterChanged("WeswapRouter", router);
    }

    /**
     * @dev to get usable funds of the DAO
     * @param id DAO ID
     * @param token token address
     */
    function usableFund(uint id, address token) public view override returns (uint) {
        if(token == address(0) || token == wwemix) {
            return _balance[id].wemix;
        } else {
            return _balance[id].token[token];
        }
    }

    /**
     * @dev to get real balance of this contract
     * @param token token address
     */
    function getBalance(address token) public view returns (uint) {
        if(_isCoin(token)) {
            return address(this).balance;
        } else {
            return IERC20(token).balanceOf(address(this));
        }
    }

    /**
     * @dev to get arryay of tokens that owns this contract
     * @param id DAO ID
     */
    function tokenCollection(uint id) public view override returns (address[] memory) {
        return _tokenCollection[id];
    }

    /**
     * @dev is the DAO owns the token
     * @param id DAO ID
     * @param token token address
     */
    function isOwn(uint id, address token) public view override returns (bool){
        return _isOwn[id][token];
    }

    function _addToken(uint id, address token) internal {
        _tokenCollection[id].push(token);
        _isOwn[id][token] = true;
    }

    function _spendBalance(uint id, address token, uint amount) internal {
        require(amount > 0 && amount <= usableFund(id, token), "FM0-SB0-590");
        if(_isCoin(token)) {
            _balance[id].wemix -= amount;
        } else {
            require(isOwn(id, token), "FM0-SB0-010");
            _balance[id].token[token] -= amount;
        }
    }

    function _isCoin(address token) internal virtual view override returns (bool) {
        return super._isCoin(token) || token == wwemix;
    }
}