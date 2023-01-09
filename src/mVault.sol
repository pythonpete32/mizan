// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

import {Owned} from "solmate/auth/Owned.sol";
import {BasePortfolio} from "./BasePortfolio.sol";
import {IERC20Metadata} from "openzeppelin-contracts/interfaces/IERC20Metadata.sol";
import {IExchangeConnector} from "./interface/IExchangeConnector.sol";
import {IOracleRegistry} from "./interface/IOracleRegistry.sol";

contract mVault is BasePortfolio, Owned {
    constructor(
        string memory _name,
        string memory _symbol,
        IERC20Metadata _stableCoin,
        IOracleRegistry _oracles,
        uint64 _maxSlippage,
        uint64 _threshold,
        IExchangeConnector _exchange
    ) BasePortfolio(_name, _symbol, _stableCoin, _oracles, _maxSlippage, _threshold, _exchange) Owned(msg.sender) {}

    function setPortfolio(address[] memory _assets, uint64[] memory _weights)
        external
        validatePortfolio(_assets, _weights)
        onlyOwner
    {
        _setPortfolio(_assets, _weights);
    }

    function setWeights(uint64[] memory _weights) external validatePortfolio(allowedAssets, _weights) onlyOwner {
        _setWeights(_weights);
    }

    function setMaxSlippage(uint64 _maxSlippage) external onlyOwner {
        _setMaxSlippage(_maxSlippage);
    }

    function setThreshold(uint64 _threshold) external onlyOwner {
        _setThreshold(_threshold);
    }

    function forceRebalance() external onlyOwner {
        _rebalance();
    }

    function rebalance() external canRebalance {
        _rebalance();
    }
}
