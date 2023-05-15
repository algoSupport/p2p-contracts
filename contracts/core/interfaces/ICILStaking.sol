// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.9;

/// @notice cilistia staking contract interface
interface ICILStaking {
  /// @notice fires when stake state changes
  event StakeUpdated(address user, uint256 stakedAmount, uint256 lockedAmount);

  /// @notice fires when unstake token
  event UnStaked(address user, uint256 rewardAmount);

  /// @dev lock more token
  function increaseLock(address user, uint256 amount) external;

  /// @dev decrease locked token
  function decreaseLock(address user, uint256 amount) external;

  /// @dev remove staking data
  function remove(address user) external;

  /// @dev return colleted token amount
  function collectedToken(address user) external view returns (uint256);

  /// @dev return lockable token amount
  function lockableCil(address user) external view returns (uint256);

  /// @dev return verified status.
  // depending on if user staked nft.
  function isVerified(address user) external view returns (bool);

  /// @dev return locked token amount
  function lockedCil(address user) external view returns (uint256);
}
