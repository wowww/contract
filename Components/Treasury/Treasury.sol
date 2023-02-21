// SPDX-License-Identifier: MIT

pragma solidity 0.8.10;

import "./ITreasury.sol";
import "../FundManager/FundManager.sol";

/**
 * @title Treasury
 * @author Wemade Pte, Ltd
 * @dev Community vaults where DAO funds are kept
 */
contract Treasury is ITreasury, FundManager {
    constructor(address fundRouter, address weswapRouter) FundManager(fundRouter, weswapRouter) {}

    /**
     * @dev liquidate when the DAO disolved
     * @param id DAO ID
     * @param station station address
     */
    function liquidate(
        uint id,
        address station
    ) 
        external
        override
        onlyFundRouter
        returns (
            address[] memory,
            uint[] memory
        ) 
    {
        if (_tokenCollection[id].length > 0) {
            for(uint i = 0; i < _tokenCollection[id].length; i++) {
                address token = _tokenCollection[id][i];
                uint balance = _balance[id].token[token];
            
                if(balance == 0) {
                    _tokenCollection[id][i] = _tokenCollection[id][_tokenCollection[id].length - 1];
                    _tokenCollection[id].pop();
                }
            }
        }

        uint size = _tokenCollection[id].length + 1;

        address[] memory tokens = new address[](size);
        uint[] memory amounts = new uint[](size);
        amounts[0] = _balance[id].wemix;

        for(uint i = 0; i < (size - 1); i++) {
            address token = _tokenCollection[id][i];
            uint balance = usableFund(id, token);
            
            tokens[i+1] = token;
            amounts[i+1] = balance;
        }

        for(uint j = 0; j < size; j++) {
            transferFund(id, "Liquidate", tokens[j], station, amounts[j]);
            assert(usableFund(id, tokens[j]) == 0);
        }

        return (tokens, amounts);
    }

}