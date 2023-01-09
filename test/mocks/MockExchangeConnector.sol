// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

import {IExchangeConnector} from "../../src/interface/IExchangeConnector.sol";
import {IOracleRegistry} from "../../src/interface/IOracleRegistry.sol";
import {IERC20} from "openzeppelin-contracts/interfaces/IERC20.sol";

contract MockExchangeConnector is IExchangeConnector {
    IOracleRegistry public oracle;
    uint256 public fee;
    uint256 slippage; // 1e18 = 100%

    constructor(IOracleRegistry _oracle) {
        oracle = _oracle;
        fee = 3e14; // 0.03%
        slippage = 1e15; // 0.1%
    }

    function swap(address _from, address _to, uint256 _amountIn, uint256 _amountOutMin)
        external
        override
        returns (uint256 amountOut)
    {
        uint256 price = oracle.getPrice(_from, _to);

        // calculate the price minus slippage and fee
        uint256 adjustedPrice = price * (slippage / 1e18);
        adjustedPrice = (adjustedPrice + price) / (1 - (fee / 1e18));

        // calculate the amountOut
        amountOut = _amountIn * (adjustedPrice / 1e18);

        // check if the calculated amountOut is greater than the minimum amountOut
        require(amountOut >= _amountOutMin, "Insufficient amountOut");

        // transfer the tokens
        IERC20(_from).transferFrom(msg.sender, address(this), _amountIn);
        IERC20(_to).transfer(msg.sender, amountOut);
    }
}
