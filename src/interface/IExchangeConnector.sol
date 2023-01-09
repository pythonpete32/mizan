// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

interface IExchangeConnector {
    function swap(address _from, address _to, uint256 _amountIn, uint256 _amountOutMin)
        external
        returns (uint256 amountOut);
}
