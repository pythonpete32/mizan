// SPDX-License-Identifier: MIT
pragma solidity 0.8.10;

import "forge-std/Test.sol";
import {IERC20} from "openzeppelin-contracts/interfaces/IERC20.sol";
import {IERC20Metadata} from "openzeppelin-contracts/interfaces/IERC20Metadata.sol";

import {IExchangeConnector} from "../src/interface/IExchangeConnector.sol";
import {IOracleRegistry} from "../src/interface/IOracleRegistry.sol";

import {MockToken} from "./mocks/MockToken.sol";
import {MockOracleRegistry} from "./mocks/MockOracleRegistry.sol";
import {MockExchangeConnector} from "./mocks/MockExchangeConnector.sol";
import {mVault} from "../src/mVault.sol";

contract mVaultBaseTest is Test {
    // constants
    uint64 constant PERCENT = 1e16;
    uint256 constant ONE_USDC = 1e18;

    // vault variables
    mVault public vault;
    string public vaultName = "Mizan Vault";
    string public vaultSymbol = "mVault";
    uint64 _maxSlippage = 2e15; // 0.1%
    uint64 _threshold = 1e17; // 10%

    // supporting contracts
    IOracleRegistry public oracle;
    IExchangeConnector public exchange;

    // tokens
    IERC20 public USDC;
    IERC20 public WETH;
    IERC20 public WBTC;
    IERC20 public ANT;

    // oracles
    address public WETH_USDC;
    address public WBTC_USDC;
    address public ANT_USDC;
    address public USDC_USDC;

    // people
    address public owner = vm.addr(0xB055);
    address public alice = vm.addr(0xa11c3);
    address public bob = vm.addr(0xb0b);
    address public bot_net = vm.addr(0xbeef);

    function setUp() public virtual {
        setupTokens();
        setupOracle();
        setupExchange();
        setupVault();
        setupUsers();
    }

    function setupVault() public {
        // deploy vault
        vm.startPrank(owner);
        vault = new mVault(
            vaultName, 
            vaultSymbol, 
            IERC20Metadata(address(USDC)), 
            oracle,
            _maxSlippage, 
            _threshold, 
            exchange
            );
        vm.label(address(vault), "mVault");

        address[] memory tokens;
        uint64[] memory percentages;

        tokens = new address[](3);
        percentages = new uint64[](3);

        tokens[0] = address(USDC);
        tokens[1] = address(WETH);
        tokens[2] = address(WBTC);
        // tokens[3] = address(ANT);

        percentages[0] = PERCENT * 50;
        percentages[1] = PERCENT * 25;
        percentages[2] = PERCENT * 25;
        // percentages[3] = PERCENT * 5;

        vault.setPortfolio(tokens, percentages);

        vm.stopPrank();
    }

    function setupTokens() public {
        // deploy tokens
        USDC = IERC20(address(new MockToken("USDC", "USDC", 18)));
        WETH = IERC20(address(new MockToken("WETH", "WETH", 18)));
        WBTC = IERC20(address(new MockToken("WBTC", "WBTC", 18)));
        ANT = IERC20(address(new MockToken("ANT", "ANT", 18)));

        // label tokens
        vm.label(address(USDC), "USDC");
        vm.label(address(WETH), "WETH");
        vm.label(address(WBTC), "WBTC");
        vm.label(address(ANT), "ANT");
    }

    function setupOracle() public {
        // deploy oracle
        oracle = IOracleRegistry(address(new MockOracleRegistry()));
        vm.label(address(oracle), "oracle");

        // set the oracles
        MockOracleRegistry(address(oracle)).setOracle(address(WETH), address(USDC), address(0x1111));
        MockOracleRegistry(address(oracle)).setOracle(address(WBTC), address(USDC), address(0x2222));
        MockOracleRegistry(address(oracle)).setOracle(address(ANT), address(USDC), address(0x3333));
        MockOracleRegistry(address(oracle)).setOracle(address(USDC), address(USDC), address(0xffff));

        // set the prices
        MockOracleRegistry(address(oracle)).setPrice(address(USDC), address(USDC), 1);
        MockOracleRegistry(address(oracle)).setPrice(address(WETH), address(USDC), 1_000);
        MockOracleRegistry(address(oracle)).setPrice(address(WBTC), address(USDC), 10_000);
        MockOracleRegistry(address(oracle)).setPrice(address(ANT), address(USDC), 169);
    }

    function setupExchange() public {
        // deploy exchange
        exchange = IExchangeConnector(address(new MockExchangeConnector(oracle)));
        vm.label(address(exchange), "exchange");

        // give the exchange tokens
        MockToken(address(USDC)).mint(address(exchange), 1e18 * 10_000_000);
        MockToken(address(ANT)).mint(address(exchange), 1e18 * 1_000_000);
        MockToken(address(WETH)).mint(address(exchange), 1e18 * 10_000);
        MockToken(address(WBTC)).mint(address(exchange), 1e18 * 1_000);
    }

    function setupUsers() public {
        // label the users
        vm.label(owner, "owner");
        vm.label(alice, "alice");
        vm.label(bob, "bob");
        vm.label(bot_net, "bot_net");

        // give the users some eth
        vm.deal(owner, 1e18);
        vm.deal(alice, 1e18);
        vm.deal(bob, 1e18);
        vm.deal(bot_net, 1e18);

        // give the users some USDC
        MockToken(address(USDC)).mint(owner, 1e18 * 100_000);
        MockToken(address(USDC)).mint(alice, 1e18 * 100_000);
        MockToken(address(USDC)).mint(bob, 1e18 * 100_000);
    }

    /* ====================================================================== */
    /*                              PORTFOLIO HELPERS                           
    /* ====================================================================== */

    function rebalanceWithBot() public {
        vm.startPrank(bot_net);
        vault.rebalance();
        vm.stopPrank();
    }
}
