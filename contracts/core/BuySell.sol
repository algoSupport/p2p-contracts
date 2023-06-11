// SPDX-License-Identifier: MIT

pragma solidity ^0.8.9;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC721/IERC721ReceiverUpgradeable.sol";
import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {ReentrancyGuardUpgradeable} from "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";

contract BuySell is OwnableUpgradeable, ReentrancyGuardUpgradeable {
  address public constant ARB_ADDRESS = 0x912CE59144191C1204E64559FE8253a0e49E6548;
  address public constant USDT_ADDRESS = 0xFd086bC7CD5C481DCC9C85ebE478A1C0b69FCbb9;
  address public constant USDC_ADDRESS = 0xFF970A61A04b1cA14834A43f5dE4533eBDDB5CC8;
  address public constant WBTC_ADDRESS = 0x2f2a2543B76A4166549F7aaB2e75Bef0aefC5B0f;
  uint256 public constant ETH_INDEX = 4;

  address[] public SUPPORTED_ADDRESSES;

  mapping(address => uint256[]) userAmounts;
  mapping(address => uint256) totalAmounts;

  function initialize() public initializer {
    SUPPORTED_ADDRESSES = [
      0xFd086bC7CD5C481DCC9C85ebE478A1C0b69FCbb9, //arb
      0xFd086bC7CD5C481DCC9C85ebE478A1C0b69FCbb9, // usdt
      0xFF970A61A04b1cA14834A43f5dE4533eBDDB5CC8, //usdc
      0x2f2a2543B76A4166549F7aaB2e75Bef0aefC5B0f //wbtc
    ];
  }

  modifier onlySupportedAsset(address _asset) {
    require(getAssetIndex(_asset) != type(uint256).max, "Not Supported Asset");
    _;
  }

  function getAssetIndex(address _asset) public view returns (uint256) {
    uint256 length = SUPPORTED_ADDRESSES.length;
    for (uint256 i = 0; i < length; i++) {
      if (SUPPORTED_ADDRESSES[i] == _asset) {
        return i;
      }
      unchecked {
        ++i;
      }
    }

    return type(uint256).max;
  }

  function deposit(address _asset, uint256 _amount) public {
    IERC20(_asset).transferFrom(msg.sender, address(this), _amount);

    uint256 assetIndex = getAssetIndex(_asset);
    require(assetIndex != type(uint256).max, "Not Supported Asset");

    userAmounts[msg.sender][assetIndex] += _amount;
    totalAmounts[_asset] += _amount;
  }

  function withdrawAsset(address _asset, uint256 _amount) public {
    uint256 assetIndex = getAssetIndex(_asset);
    require(assetIndex != type(uint256).max, "Not Supported Asset");

    require(userAmounts[msg.sender][assetIndex] >= _amount, "Insufficient Balance");
    userAmounts[msg.sender][assetIndex] -= _amount;
    totalAmounts[_asset] -= _amount;

    IERC20(_asset).transferFrom(msg.sender, address(this), _amount);
  }

  function depositEth() public payable {
    userAmounts[msg.sender][ETH_INDEX] = msg.value;
  }

  function withdrawEth(uint256 _amount) public {
    require(userAmounts[msg.sender][ETH_INDEX] >= _amount, "Insufficient balance");
    userAmounts[msg.sender][ETH_INDEX] -= _amount;

    (bool sent, ) = payable(msg.sender).call{value: _amount}("");
    require(sent, "transfer failed to the user");
  }

  function getTotalAssetAmount(address _asset) public view returns (uint256) {
    return totalAmounts[_asset];
  }

  function getUserAmounts() public view returns (uint256[] memory) {
    return userAmounts[msg.sender];
  }

  function getTotalEthAmount() public view returns (uint256) {
    return address(this).balance;
  }
}
