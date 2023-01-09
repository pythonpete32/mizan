// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

import {IOracleRegistry} from "../../src/interface/IOracleRegistry.sol";

contract MockOracleRegistry is IOracleRegistry {
    // mapping of asset prices in a base asset
    mapping(address => mapping(address => uint256)) public prices;

    // mapping of oracles for an asset in a base asset
    mapping(address => mapping(address => address)) public oracles;

    /// @notice gets the price of an asset in a base asset
    function getPrice(address _asset, address _base) external view returns (uint256) {
        return prices[_asset][_base];
    }

    /// @notice gets the oracle of an asset in a base asset
    function getOracle(address _asset, address _base) external view returns (address) {
        return oracles[_asset][_base];
    }

    /// @notice sets the price of an asset in a base asset
    function setPrice(address _asset, address _base, uint256 _price) external {
        prices[_asset][_base] = _price;
    }

    /// @notice sets the oracle of an asset in a base asset
    function setOracle(address _asset, address _base, address _oracle) external {
        oracles[_asset][_base] = _oracle;
    }
}
