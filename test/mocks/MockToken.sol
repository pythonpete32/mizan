// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

import {ERC20} from "openzeppelin-contracts/token/ERC20/ERC20.sol";
import "openzeppelin-contracts/token/ERC20/extensions/draft-ERC20Permit.sol";

contract MockToken is ERC20, ERC20Permit {
    uint8 private decimals_;

    constructor(string memory _name, string memory _symbol, uint8 _decimals) ERC20(_name, _symbol) ERC20Permit(_name) {
        _mint(msg.sender, 1000000000000000000000000);
        decimals_ = _decimals;
    }

    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }

    function decimals() public view override returns (uint8) {
        return decimals_;
    }
}
