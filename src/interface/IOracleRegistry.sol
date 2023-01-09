// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

interface IOracleRegistry {
    /// @notice gets the price of an asset in a base asset
    function getPrice(address _asset, address _base) external view returns (uint256);

    /// @notice gets the oracle of an asset in a base asset
    function getOracle(address _asset, address _base) external view returns (address);
}
