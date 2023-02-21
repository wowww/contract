// SPDX-License-Identifier: MIT

pragma solidity 0.8.10;

import "../Role/RouterRole.sol";
import "../Router/IFundRouter.sol";
import "../Registry/ISpellRegistry.sol";
import "../Governance/Payment/IPayment.sol";
import "../../../../contracts/openzeppelin-contracts/token/ERC20/IERC20.sol";

/**
 * @title NILEComponent
 * @author Wemade Pte, Ltd
 * @dev Parent Contract of NILE Components
 */
abstract contract NILEComponent is RouterRole {

    address internal _fundRouter;  // address of FundRouter

    // Manage Funds
    struct Fund {
        uint wemix;                      // WEMIX COIN
        mapping(address => uint) token;  // ERC20 Tokens
    }

    event RouterChanged(bytes32 indexed column, address indexed router);
    event FundTransferred(uint indexed id, bytes32 indexed column, address indexed token, address to, uint amount);
    
    constructor(address fundRouter) {
        addRouter(fundRouter);
        _fundRouter = fundRouter;
    }

    receive() external virtual payable {
        bool isComponent;
        address[] memory components = IFundRouter(_fundRouter).components();
        for(uint i = 0; i < components.length; i++) {
            if(msg.sender == components[i]) {
                isComponent = true;
                break;
            }
        }

        require(isComponent, "NC0-RC0-020");
    }

    modifier onlyFundRouter() {
        require(msg.sender == _fundRouter, "NC0-MDF-520");
        _;
    }

    /**
     * @dev change address of FundRouter
     * @param router new address of FundRouter
     */
    function changeFundRouter(address router) external onlyEditor {
        removeRouter(_fundRouter);
        addRouter(router);
        _fundRouter = router;

        emit RouterChanged("FundRouter", router);
    }

    /**
     * @dev transfer funds
     * @param id DAO ID
     * @param column a reason for the transfer of funds
     * @param token token address to transfer
     * @param to receiver address
     * @param to amount to transfer
     */
    function _transferFund(uint id, bytes32 column, address token, address to, uint amount) internal {
        if(_isCoin(token)) {
            (bool success,) = payable(to).call{value: amount}("");
            require(success, "NC0-TF0-310");
        } else {
            require(IERC20(token).transfer(to, amount),"NC0-TF0-311");
        }

        emit FundTransferred(id, column, token, to, amount);
    }

    /**
     * @dev is the address coin
     * @param token token address to transfer
     */
    function _isCoin(address token) internal virtual view returns (bool) {
        return token == address(0);
    }
}