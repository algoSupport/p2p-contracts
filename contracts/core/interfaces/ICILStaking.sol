// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

/// @notice cilistia staking contract interface
interface ICILStaking {
  /// @notice fires when stake state changes
  event StakeUpdated(address user, uint256 stakedAmount, uint256 lockedAmount);

  /// @notice fires when unstake token
  event UnStaked(address user, uint256 rewardAmount);

  /// @dev lock  token
  function lock(address user, uint256 amount) external;

  /// @dev remove staking data
  function remove(address user) external;

  /// @dev return lockable token amount
  function stakedCilAmount(address user) external view returns (uint256);

  /// @dev return verified status.
  // depending on if user staked nft.
  function isVerified(address user) external view returns (bool);
}
