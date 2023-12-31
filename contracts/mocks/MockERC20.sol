// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import {ERC20Permit, ERC20} from "@openzeppelin/contracts/token/ERC20/extensions/draft-ERC20Permit.sol";

contract MockERC20 is ERC20Permit {
  uint8 private immutable _decimals;

  constructor(
    string memory name_,
    string memory symbol_,
    uint8 decimals_
  ) ERC20Permit(name_) ERC20(name_, symbol_) {
    _decimals = decimals_;
  }

  function mint(address to, uint256 amount) external {
    _mint(to, amount);
  }

  function burn(address account, uint256 amount) external {
    _burn(account, amount);
  }

  function decimals() public view override returns (uint8) {
    return _decimals;
  }
}
