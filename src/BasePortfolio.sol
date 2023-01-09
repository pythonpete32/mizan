// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

import {ERC4626} from "openzeppelin-contracts/token/ERC20/extensions/ERC4626.sol";
import {IERC4626} from "openzeppelin-contracts/interfaces/IERC4626.sol";
import {IERC20Metadata} from "openzeppelin-contracts/interfaces/IERC20Metadata.sol";
import {ERC20} from "openzeppelin-contracts/token/ERC20/ERC20.sol";
import "openzeppelin-contracts/token/ERC20/extensions/draft-ERC20Permit.sol";
import "openzeppelin-contracts/token/ERC20/extensions/ERC20Votes.sol";
import {IPortfolio} from "./interface/IPortfolio.sol";
import {IOracleRegistry} from "./interface/IOracleRegistry.sol";
import {IExchangeConnector} from "./interface/IExchangeConnector.sol";

// TODO: Maybe we need to override the withdraw and redeem because the slippage may make the withdraw fail

/**
 * @title BasePortfolio
 * @author PythonPete32
 *
 * @notice BasePortfolio is an abstract contract that provides a base implementation for creating a rebalancing
 * portfolio of assets. The contract allows users to set a list of allowed assets and their corresponding
 * weights, and it automatically rebalances the portfolio to maintain the desired asset distribution. The
 * contract also includes measures to prevent slippage and ensure that rebalancing is performed efficiently.
 *
 * @dev concrete implementation of the BasePortfolio contract are expected to implement authentication and
 * communication with a smart account contract that will hold the portfolio
 */
abstract contract BasePortfolio is IPortfolio, ERC4626, ERC20Permit, ERC20Votes {
    /* ====================================================================== */
    /*                               STATE
    /* ====================================================================== */

    IExchangeConnector public exchange;

    /// @notice list of the assets in the index
    address[] public allowedAssets;

    /// @notice list of the weights of the assets in the index
    uint64[] public weights;

    /// @notice max slippage allowed when rebalancing
    uint64 public maxSlippage;

    /// @notice the minimum deviation from the target weights before rebalancing
    uint64 public threshold;

    /* ====================================================================== */
    /*                               IMMUTABLES
    /* ====================================================================== */

    /// @notice The address of the oracle registry
    IOracleRegistry public immutable oracles;

    /// @notice The address of the stable coin used to calculate the value of the assets in the portfolio
    IERC20Metadata public immutable stableCoin;

    /// @notice The base value being defined to correspond to 100% to calculate and compare percentages despite the lack of floating point arithmetic.
    uint64 public constant PCT_BASE = 10 ** 18; // 0% = 0; 1% = 10^16; 100% = 10^18

    constructor(
        string memory _name,
        string memory _symbol,
        IERC20Metadata _stableCoin,
        IOracleRegistry _oracles,
        uint64 _maxSlippage,
        uint64 _threshold,
        IExchangeConnector _exchange
    ) ERC4626(_stableCoin) ERC20(_name, _symbol) ERC20Permit(_name) {
        stableCoin = _stableCoin;
        oracles = _oracles;
        maxSlippage = _maxSlippage;
        threshold = _threshold;
        exchange = _exchange;
    }

    /* ====================================================================== */
    /*                              MODIFIERS
    /* ====================================================================== */

    modifier validatePortfolio(address[] memory _assets, uint64[] memory _weights) {
        uint64 totalWeights;
        if (_assets.length != _weights.length) revert AssetWeightsMissmatch();
        for (uint256 i = 0; i < _assets.length; i++) {
            if (_weights[i] > PCT_BASE) revert InvalidWeight();
            if (oracles.getOracle(_assets[i], address(stableCoin)) == address(0)) revert NoTokenOracle();
            totalWeights += _weights[i];
        }
        if (totalWeights != PCT_BASE) revert WeightsNotOneHundredPercent();
        _;
    }

    modifier canRebalance() {
        if (totalAssets() == 0) revert NoAssetsInPortfolio();
        uint256 len = allowedAssets.length;
        (uint256[] memory targetBalances, uint256[] memory actualBalances) = getPortfolioBalances();
        uint256 maxDifference = 0;
        for (uint256 i = 0; i < len; i++) {
            // Calculate the raw difference between the actual and target balances
            uint256 difference = actualBalances[i] > targetBalances[i]
                ? actualBalances[i] - targetBalances[i]
                : targetBalances[i] - actualBalances[i];

            // Calculate the percentage difference
            uint256 percentDifference = (actualBalances[i] == 0) ? 0 : (difference * PCT_BASE) / actualBalances[i];

            // Update the max difference
            maxDifference = (percentDifference > maxDifference) ? percentDifference : maxDifference;
        }
        // Check if the max difference is greater than the threshold
        if (threshold > maxDifference) revert ThresholdNotReached();

        _;
    }

    /* ====================================================================== */
    /*                              PORTFOLIO FUNCTIONS
    /* ====================================================================== */

    function _setPortfolio(address[] memory _assets, uint64[] memory _weights)
        internal
        validatePortfolio(_assets, _weights)
    {
        allowedAssets = _assets;
        weights = _weights;

        emit SetPortfolio(_assets, _weights);
    }

    function _setMaxSlippage(uint64 _maxSlippage) internal {
        if (_maxSlippage > PCT_BASE) revert InvalidMaxSlippage();
        maxSlippage = _maxSlippage;

        emit SetMaxSlippage(_maxSlippage);
    }

    function _setThreshold(uint64 _threshold) internal {
        if (_threshold > PCT_BASE) revert InvalidThreshold();
        threshold = _threshold;

        emit SetThreshold(_threshold);
    }

    function _setWeights(uint64[] memory _weights) internal validatePortfolio(allowedAssets, _weights) {
        weights = _weights;

        emit SetPortfolio(allowedAssets, _weights);
    }

    function _rebalance() internal {
        (uint256[] memory targetBalances, uint256[] memory actualBalances) = getPortfolioBalances();

        // Loop through the assets and sell the difference between the current and target balances
        for (uint256 i = 0; i < allowedAssets.length; i++) {
            // If the current balance is above the target balance, sell the difference
            if (actualBalances[i] > targetBalances[i]) {
                uint256 amountIn = actualBalances[i] - targetBalances[i];
                uint256 price = oracles.getPrice(allowedAssets[i], address(stableCoin));
                uint256 amountOutMin = (amountIn * price * (PCT_BASE - maxSlippage)) / PCT_BASE;

                _swap(allowedAssets[i], address(stableCoin), amountIn, amountOutMin);
            }
        }

        // Loop through the allowedAssets and buy the difference between the current and target balances
        for (uint256 i = 0; i < allowedAssets.length; i++) {
            if (actualBalances[i] < targetBalances[i]) {
                if (actualBalances[i] > targetBalances[i]) {
                    uint256 amountIn = actualBalances[i] - targetBalances[i];
                    uint256 price = oracles.getPrice(allowedAssets[i], address(stableCoin));
                    uint256 amountOutMin = (amountIn * price * (PCT_BASE - maxSlippage)) / PCT_BASE;

                    _swap(allowedAssets[i], address(stableCoin), amountIn, amountOutMin);
                }
            }

            emit IndexRebalanced(allowedAssets, weights);
        }
    }

    /// @notice withdraws a percentage of the assets into the portfolio from the smart account and liquidates into stableCoin
    function _liquidate(uint256 _percentage) internal returns (uint256 liquidated) {
        liquidated = 0;
        for (uint256 i = 0; i < allowedAssets.length; i++) {
            // Get the balance of the asset in the portfolio
            uint256 balance = IERC20(allowedAssets[i]).balanceOf(address(this));

            // Calculate the amount of the asset to sell based on the specified percentage
            uint256 amountIn = (balance * _percentage) / 100;

            // Sell the specified percentage of the asset for the stable coin
            liquidated += _swap(allowedAssets[i], address(stableCoin), amountIn, 0);
        }
    }

    /// @notice swaps tokens using the TradeRouter
    /// @param _from The address of the token to swap from
    /// @param _to The address of the token to swap to
    /// @param _amountIn The amount of tokens to swap from
    /// @param _amountOutMin The minimum amount of tokens to swap to
    function _swap(address _from, address _to, uint256 _amountIn, uint256 _amountOutMin)
        internal
        returns (uint256 amountOut)
    {
        amountOut = exchange.swap(_from, _to, _amountIn, _amountOutMin);
    }

    /// @notice gets he target and  current balance of each asset in the portfolio
    /// @return targetBalances the target balance of each asset in the portfolio
    /// @return actualBalances the current balance of each asset in the portfolio
    function getPortfolioBalances()
        public
        view
        returns (uint256[] memory targetBalances, uint256[] memory actualBalances)
    {
        uint256 len = allowedAssets.length;
        uint256 totalPortfolioValue = 0;
        uint256[] memory prices = new uint256[](len);

        actualBalances = new uint256[](len);
        targetBalances = new uint256[](len);

        for (uint256 i = 0; i < len; i++) {
            // This is returning the price of the whole unit not per wei of the unit
            prices[i] = oracles.getPrice(allowedAssets[i], address(stableCoin));
            actualBalances[i] = IERC20(allowedAssets[i]).balanceOf(address(this));
            totalPortfolioValue += prices[i] * actualBalances[i];
        }

        // Calculate the target value for each asset based on the current portfolio value and the target weights
        for (uint256 i = 0; i < weights.length; i++) {
            targetBalances[i] = ((weights[i] * totalPortfolioValue) / PCT_BASE) / prices[i];
        }
    }

    /* ====================================================================== */
    /*                              ERC4626 OVERRIDES
    /* ====================================================================== */

    /// @inheritdoc IERC4626
    function totalAssets() public view override returns (uint256) {
        uint256 len = allowedAssets.length;
        uint256 totalPortfolioValue = 0;

        for (uint256 i = 0; i < len; i++) {
            totalPortfolioValue += IERC20(allowedAssets[i]).balanceOf(address(this))
                * oracles.getPrice(allowedAssets[i], address(stableCoin));
        }

        return totalPortfolioValue;
    }

    function previewRedeem(uint256 shares) public view virtual override returns (uint256) {
        uint256 sharePercentage = (shares * PCT_BASE) / totalSupply();
        uint256 minValue = 0;
        for (uint256 i = 0; i < allowedAssets.length; i++) {
            // Get the balance of the asset in the portfolio
            uint256 balance = ERC20(allowedAssets[i]).balanceOf(address(this));
            uint256 price = oracles.getPrice(allowedAssets[i], address(stableCoin));

            // TODO: add fees
            uint256 shareOfAsset = (balance * sharePercentage) / PCT_BASE;
            uint256 slippage = (shareOfAsset * maxSlippage) / PCT_BASE;

            minValue += (shareOfAsset * price) - (slippage * price);
        }
        return minValue;
    }

    function redeem(uint256 shares, address receiver, address owner) public override returns (uint256 assets) {
        // 1. Calculate the percentage of the portfolio to liquidate
        uint256 sharePercentage = (shares * PCT_BASE) / totalSupply();
        // 2. Liquidate the percentage of the portfolio
        uint256 liquidated = _liquidate(sharePercentage);

        _withdraw(msg.sender, receiver, owner, liquidated, shares);

        return liquidated;
    }

    function previewWithdraw(uint256 assets) public view virtual override returns (uint256) {
        uint256 shares = convertToShares(assets);
        return previewRedeem(shares);
    }

    function withdraw(uint256 assets, address receiver, address owner) public override returns (uint256 shares) {
        shares = convertToShares(assets);
        return redeem(shares, receiver, owner);
    }

    /* ====================================================================== */
    /*                              VOTES OVERRIDES
    /* ====================================================================== */

    function _afterTokenTransfer(address from, address to, uint256 amount) internal override (ERC20, ERC20Votes) {
        super._afterTokenTransfer(from, to, amount);
    }

    function _mint(address to, uint256 amount) internal override (ERC20, ERC20Votes) {
        super._mint(to, amount);
    }

    function _burn(address account, uint256 amount) internal override (ERC20, ERC20Votes) {
        super._burn(account, amount);
    }

    function decimals() public view virtual override (ERC20, ERC4626) returns (uint8) {
        return stableCoin.decimals();
    }

    /* ====================================================================== */
    /*                             SCALE HELPERS
    /* ====================================================================== */

    function scaleTo18Decimals(uint256 _balance, uint256 _decimals) internal pure returns (uint256 scaledBalance) {
        _decimals == 18 ? scaledBalance = _balance : scaledBalance = _balance * (10 ** (18 - _decimals));
    }

    function scaleToDecimals(uint256 _balance, uint256 _decimals) internal pure returns (uint256 scaledBalance) {
        _decimals == 18 ? scaledBalance = _balance : scaledBalance = _balance / (10 ** (18 - _decimals));
    }
}
