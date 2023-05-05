// SPDX-License-Identifier: MIT

pragma solidity ^0.8.9;

import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";

contract Marketplace is IERC721Receiver {
    
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
    }
    
    mapping(address => User) public users;
    
    uint256 public totalCilStaked;
    uint256 public totalNftStaked;
    uint256 public cilRewardPerShare;
    uint256 public nftRewardPerShare;
    uint256 public constant PRECISION = 1e18;
    
    event CilStake(address indexed user, uint256 amount);
    event NftStake(address indexed user, uint256 amount);
    event WithdrawCil(address indexed user, uint256 amount);
    event WithdrawNft(address indexed user, uint256 amount);
    
    constructor(address _cilNftAddress, address _cilTokenAddress) {
        cilNft = IERC721(_cilNftAddress);
        cilToken = IERC20(_cilTokenAddress);
    }
    
    function stakeCil(uint256 _amount) external {
        require(_amount > 0, "Amount must be greater than zero");
        
        // transfer CIL tokens from user to contract
        cilToken.transferFrom(msg.sender, address(this), _amount);
        
        User storage user = users[msg.sender];
        totalCilStaked += _amount;
        user.cilAmount += _amount;
        // user.lastCilRewardPerShare = cilRewardPerShare;
        
        emit CilStake(msg.sender, _amount);
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
    
    function withdrawCil(uint256 _amount) external {
        User storage user = users[msg.sender];
        require(user.cilAmount >= _amount, "Insufficient balance");
        
        cilToken.transfer(msg.sender, _amount + user.cilRewards);
        user.cilRewards = 0;
        
        totalCilStaked -= _amount;
        user.cilAmount -= _amount;
        // user.lastCilRewardPerShare = cilRewardPerShare;
        
        emit WithdrawCil(msg.sender, _amount);
    }
    
    function withdrawNft(uint256 _tokenId) external {
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
    function onERC721Received(address, address, uint256, bytes calldata) external override returns (bytes4) {
        return this.onERC721Received.selector;
    }
}