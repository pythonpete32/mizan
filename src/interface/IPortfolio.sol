// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

interface IPortfolio {
    /// @notice Reverts if the portfolio is empty
    error NoAssetsInPortfolio();

    /// @notice Reverts if the threshold is above 100%
    error ThresholdAboveOneHundredPercent();

    /// @notice Reverts if the threshold is not reached
    error ThresholdNotReached();

    /// @notice Reverts if the number of assets and weights do not match
    error AssetWeightsMissmatch();

    /// @notice Reverts if the weights do not add up to 100%
    error WeightsNotOneHundredPercent();

    /// @notice Reverts if the portfolio cannot be rebalanced
    error RebalanceNotAllowed();

    /// @notice Reverts if weight is invalid
    error InvalidWeight();

    /// @notice Reverts if the max slippage is invalid
    error InvalidMaxSlippage();

    /// @notice Reverts if the threshold is invalid
    error InvalidThreshold();

    /// @notice Reverts if the asset does not have an oracle
    error NoTokenOracle();

    /// @notice Emitted when the portfolio is rebalanced
    event IndexRebalanced(address[] indexed asset, uint64[] weights);

    /// @notice Emitted when the max slippage is set
    event SetMaxSlippage(uint64 maxSlippage);

    /// @notice Emitted when the threshold is set
    event SetThreshold(uint64 threshold);

    /// @notice Emitted when the portfolio is set
    event SetPortfolio(address[] indexed assets, uint64[] weights);

    /// @notice sets the portfolio
    /// @param _assets The addresses of the assets in the portfolio
    /// @param _weights The target weights of the assets in the portfolio
    function setPortfolio(address[] memory _assets, uint64[] memory _weights) external;

    /// @notice sets the target weights of the assets in the portfolio
    /// @param _weights The target weights of the assets in the portfolio
    function setWeights(uint64[] memory _weights) external;

    /// @notice sets the max slippage allowed when rebalancing
    /// @param _maxSlippage The max slippage allowed when rebalancing
    function setMaxSlippage(uint64 _maxSlippage) external;

    /// @notice sets the threshold for rebalancing
    /// @param _threshold The threshold for rebalancing
    function setThreshold(uint64 _threshold) external;

    /// @notice rebalances the portfolio
    /// @dev this function can be called by anyone
    function rebalance() external;

    /// @notice withdraw from the portfolio into base asset
    /// @param percentage The percentage of the portfolio to withdraw
    // function withdraw(uint256 percentage) external;
}
