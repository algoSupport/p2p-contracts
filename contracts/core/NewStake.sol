// SPDX-License-Identifier: MIT

pragma solidity ^0.8.9;

import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC721/IERC721ReceiverUpgradeable.sol";
import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {ReentrancyGuardUpgradeable} from "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import {ICILStaking} from "./interfaces/ICILStaking.sol";

contract NewStake is
  IERC721ReceiverUpgradeable,
  OwnableUpgradeable,
  ReentrancyGuardUpgradeable,
  ICILStaking
{
  IERC721 private cilNft;
  IERC20 private cilToken;

  // Define structure to store user info
  struct User {
    uint256 nftAmount;
    uint256 cilAmount;
    uint256 lastCilRewardPerShare;
    uint256 lastNftRewardPerShare;
    uint256 cilRewards;
    uint256 nftRewards;
    uint256 lockedAmount;
  }

  mapping(address => User) public users;

  uint256 public totalCilStaked;
  uint256 public totalNftStaked;
  uint256 public cilRewardPerShare;
  uint256 public nftRewardPerShare;
  uint256 public constant PRECISION = 1e18;
  address public marketplace;

  event NftStake(address indexed user, uint256 amount);
  event WithdrawNft(address indexed user, uint256 amount);

  function initialize(address _cilTokenAddress, address _cilNftAddress) public initializer {
    cilNft = IERC721(_cilNftAddress);
    cilToken = IERC20(_cilTokenAddress);

    __Ownable_init();
    __ReentrancyGuard_init();
  }

  modifier onlyMarketPlace() {
    require(msg.sender == marketplace, "Not Marketplace contract");
    _;
  }

  function setMarketPlace(address _marketplace) external onlyOwner {
    marketplace = _marketplace;
  }

  function stakeCil(uint256 _amount) external {
    require(_amount > 0, "Amount must be greater than zero");

    // transfer CIL tokens from user to contract
    cilToken.transferFrom(msg.sender, address(this), _amount);

    User storage user = users[msg.sender];
    totalCilStaked += _amount;
    user.cilAmount += _amount;
    // user.lastCilRewardPerShare = cilRewardPerShare;

    emit StakeUpdated(msg.sender, user.cilAmount, _amount);
  }

  function lock(address _address, uint256 amount) external onlyMarketPlace {
    require(amount > 0, "Amount must be greater than zero");

    User storage user = users[_address];
    require(user.cilAmount >= amount, "Insufficient balance to be locked");
    user.lockedAmount = amount;
  }

  function remove(address _address) external onlyMarketPlace {
    users[_address].lockedAmount = 0;
  }

  function stakeNft(uint256 _tokenId) external {
    require(cilNft.ownerOf(_tokenId) == msg.sender, "You don't own this NFT");

    // transfer NFT from user to contract
    cilNft.transferFrom(msg.sender, address(this), _tokenId);

    User storage user = users[msg.sender];
    totalNftStaked++;
    user.nftAmount++;
    // user.lastNftRewardPerShare = nftRewardPerShare;

    emit NftStake(msg.sender, _tokenId);
  }

  function withdrawCil(uint256 _amount) external nonReentrant {
    User storage user = users[msg.sender];
    require(user.cilAmount - user.lockedAmount >= _amount, "Insufficient balance");
    totalCilStaked -= _amount;
    user.cilAmount -= _amount;
    cilToken.transfer(msg.sender, _amount);
    user.cilRewards = 0;

    // user.lastCilRewardPerShare = cilRewardPerShare;

    emit UnStaked(msg.sender, _amount);
  }

  function withdrawNft(uint256 _tokenId) external nonReentrant {
    User storage user = users[msg.sender];
    require(user.nftAmount > 0, "You don't have any NFT staked");
    require(cilNft.ownerOf(_tokenId) == address(this), "Token is not in contract");

    cilToken.transfer(msg.sender, user.nftRewards);
    user.nftRewards = 0;

    cilNft.transferFrom(address(this), msg.sender, _tokenId);
    totalNftStaked--;
    user.nftAmount--;
    // user.lastNftRewardPerShare = nftRewardPerShare;

    emit WithdrawNft(msg.sender, _tokenId);
  }

  function distributeFee(uint256 _fee) internal {
    cilRewardPerShare = (_fee * 70 * PRECISION) / (totalCilStaked * 100);
    nftRewardPerShare = (_fee * 30 * PRECISION) / (totalNftStaked * 100);
    // distribute fee to users rewards
  }

  function getUserNfts(address _user) external view returns (uint256[] memory) {
    //to get users staked NFTs
  }

  // ERC721Receiver implementation
  function onERC721Received(
    address,
    address,
    uint256,
    bytes calldata
  ) external pure override returns (bytes4) {
    return this.onERC721Received.selector;
  }

  function isVerified(address _address) external view returns (bool) {
    return users[_address].nftAmount > 0 ? true : false;
  }

  function stakedCilAmount(address _address) external view returns (uint256) {
    return users[_address].cilAmount;
  }
}
