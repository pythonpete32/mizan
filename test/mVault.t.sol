// SPDX-License-Identifier: MIT
pragma solidity 0.8.10;

import "forge-std/Test.sol";
import {mVaultBaseTest} from "./mVaultBaseTest.sol";
import {BasePortfolio} from "../src/BasePortfolio.sol";
import {IPortfolio} from "../src/interface/IPortfolio.sol";

contract mVaultTest is mVaultBaseTest {
    function setUp() public override {
        super.setUp();
    }

    /* ====================================================================== */
    /*                              PORTFOLIO FUNCTIONS
    /* ====================================================================== */
    function test_setup_mvault() public {
        // test if the setup function works
        assertTrue(vault.owner() == owner);
        assertTrue(USDC.balanceOf(address(vault)) == 0);
        // console.log("total Assets", vault.totalAssets());
        assertTrue(vault.totalAssets() == 0);
        assertTrue(vault.totalSupply() == 0);

        // vm.expectRevert(IPortfolio.NoAssetsInPortfolio.selector);
        // rebalanceWithBot();
    }

    function test_setPortfolio() public {
        address[] memory assets = new address[](2);
        assets[0] = address(USDC);
        assets[1] = address(WETH);

        uint64[] memory weights = new uint64[](2);
        weights[0] = 3e17;
        weights[1] = 7e17;

        vm.prank(owner);
        vault.setPortfolio(assets, weights);

        assertTrue(vault.allowedAssets(0) == address(USDC));
        assertTrue(vault.allowedAssets(1) == address(WETH));
        assertTrue(vault.weights(0) == 3e17);
        assertTrue(vault.weights(1) == 7e17);
    }

    function testRevert_setPortfolio_AssetWeightsMissmatch() public {
        address[] memory assets = new address[](3);
        assets[0] = address(USDC);
        assets[1] = address(WETH);
        assets[2] = address(WBTC);

        uint64[] memory weights = new uint64[](2);
        weights[0] = 3e17;
        weights[1] = 7e17;

        vm.startPrank(owner);
        vm.expectRevert(IPortfolio.AssetWeightsMissmatch.selector);
        vault.setPortfolio(assets, weights);
    }

    function testRevert_setPortfolio_InvalidWeight() public {
        address[] memory assets = new address[](2);
        assets[0] = address(USDC);
        assets[1] = address(WETH);

        uint64[] memory weights = new uint64[](2);
        weights[0] = 4e17;
        weights[1] = 11e17;

        vm.startPrank(owner);
        vm.expectRevert(IPortfolio.InvalidWeight.selector);
        vault.setPortfolio(assets, weights);
    }

    function testRevert_setPortfolio_NoTokenOracle() public {
        address[] memory assets = new address[](2);
        assets[0] = address(USDC);
        assets[1] = vm.addr(0xdEaD);

        uint64[] memory weights = new uint64[](2);
        weights[0] = 4e17;
        weights[1] = 6e17;

        vm.startPrank(owner);
        vm.expectRevert(IPortfolio.NoTokenOracle.selector);
        vault.setPortfolio(assets, weights);
    }

    function testRevert_setPortfolio_WeightsNotOneHundredPercent() public {
        address[] memory assets = new address[](2);
        assets[0] = address(USDC);
        assets[1] = address(WETH);

        uint64[] memory weights = new uint64[](2);
        weights[0] = 4e17;
        weights[1] = 5e17;

        vm.startPrank(owner);
        vm.expectRevert(IPortfolio.WeightsNotOneHundredPercent.selector);
        vault.setPortfolio(assets, weights);
    }

    function test_setWeights() public {
        uint64[] memory weights = new uint64[](3);
        weights[0] = 3e17;
        weights[1] = 65e16;
        weights[2] = 5e16;

        vm.prank(owner);
        vault.setWeights(weights);

        assertTrue(vault.weights(0) == 3e17);
        assertTrue(vault.weights(1) == 65e16);
        assertTrue(vault.weights(2) == 5e16);
    }

    function testRevert_setWeights_AssetWeightsMissmatch() public {
        uint64[] memory weights = new uint64[](2);
        weights[0] = 3e17;
        weights[1] = 7e17;

        vm.startPrank(owner);
        vm.expectRevert(IPortfolio.AssetWeightsMissmatch.selector);
        vault.setWeights(weights);
    }

    function testRevert_setWeights_InvalidWeight() public {
        uint64[] memory weights = new uint64[](3);
        weights[0] = 4e17;
        weights[1] = 11e17;
        weights[2] = 5e16;

        vm.startPrank(owner);
        vm.expectRevert(IPortfolio.InvalidWeight.selector);
        vault.setWeights(weights);
    }

    function testRevert_setWeights_WeightsNotOneHundredPercent() public {
        uint64[] memory weights = new uint64[](3);
        weights[0] = 4e17;
        weights[1] = 5e17;
        weights[2] = 5e16;

        vm.startPrank(owner);
        vm.expectRevert(IPortfolio.WeightsNotOneHundredPercent.selector);
        vault.setWeights(weights);
    }

    function test_setMaxSlippage() public {
        vm.prank(owner);
        vault.setMaxSlippage(1e17);

        assertTrue(vault.maxSlippage() == 1e17);
    }

    function testRevert_setMaxSlippage() public {
        vm.startPrank(owner);
        vm.expectRevert(IPortfolio.InvalidMaxSlippage.selector);
        vault.setMaxSlippage(2e17);
    }

    function test_setThreshold() public {
        vm.prank(owner);
        vault.setThreshold(1e17);

        assertTrue(vault.threshold() == 1e17);
    }

    function testRevert_setThreshold() public {
        vm.startPrank(owner);
        vm.expectRevert(IPortfolio.InvalidThreshold.selector);
        vault.setThreshold(2e17);
    }

    function test_getPortfolioBalances() public {}

    // -------------------------- rebalance -------------------------- //

    function test_rebalance() public {}
    function test_liquidate() public {}

    function test_deposit() public {
        // test if the deposit function works

        assertTrue(USDC.balanceOf(address(vault)) == 0);
        assertTrue(vault.totalAssets() == 0);
        assertTrue(vault.balanceOf(alice) == 0);

        vm.startPrank(alice);
        USDC.approve(address(vault), 1e18 * 10_000);
        vault.deposit(ONE_USDC * 10_000, alice);
        vm.stopPrank();

        assertTrue(USDC.balanceOf(address(vault)) == ONE_USDC * 10_000);
        // console.log("total Assets", vault.totalAssets());
        assertTrue(vault.totalAssets() == ONE_USDC * 10_000);
        assertTrue(vault.balanceOf(alice) == ONE_USDC * 10_000);

        // uint256 wethPrice = oracle.getPrice(address(WETH), address(USDC));
        // uint256 wbtcPrice = oracle.getPrice(address(WBTC), address(USDC));
        // console.log("weth price", wethPrice);
        // console.log("wbtc price", wbtcPrice);

        // (uint256[] memory targetBalances, uint256[] memory actuals) = vault.getPortfolioBalances();
        // console.log("targets");
        // console.log(targetBalances[0], targetBalances[1], targetBalances[2]); //, targetBalances[3]);
        // console.log("actuals");
        // console.log(actuals[0], actuals[1], actuals[2]); //, actuals[3]);

        // rebalanceWithBot();
    }
}
