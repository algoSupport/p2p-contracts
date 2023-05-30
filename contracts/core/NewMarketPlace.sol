// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import {SafeERC20Upgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";
import {SafeERC20, IERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {ReentrancyGuardUpgradeable} from "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import {ICILStaking} from "./interfaces/ICILStaking.sol";

/**
 * @title Cilistia P2P MarketPlace
 * @notice cilistia MarketPlace contract
 * price decimals 8
 * percent decimals 2
 */
contract NewMarketPlace is OwnableUpgradeable, ReentrancyGuardUpgradeable {
  using SafeERC20 for IERC20;
  struct PositionCreateParam {
    uint128 price;
    uint128 amount;
    uint128 minAmount;
    uint128 maxAmount;
    bool priceType; // 0 => fixed, 1 => percent
    uint8 paymentMethod; // 0 => BankTransfer, 1 => Other
    address token;
  }

  struct Position {
    uint128 price;
    uint128 amount;
    uint128 minAmount;
    uint128 maxAmount;
    uint128 offeredAmount;
    bool priceType; // 0 => fixed, 1 => percent
    uint8 paymentMethod; // 0 => BankTransfer, 1 => Other
    address token;
    address creator;
  }

  struct Offer {
    bytes32 positionKey;
    uint128 amount;
    address creator;
    bool released;
    bool canceled;
  }

  mapping(address => bool) public whitelists;

  /// @notice cil staking address
  address public cilStaking;

  /// @notice positions (bytes32 => Position)
  mapping(bytes32 => Position) public positions;

  bytes32[] public positionKeys;
  mapping(bytes32 => bytes32[]) public offerKeys;

  /// @notice offers (bytes32 => Offer)
  mapping(bytes32 => Offer) public offers;
  /// @notice fee decimals 2
  uint256 public constant feePoint = 100;
  uint256 public constant minCilAmount = 10 * 10**18;

  /// @notice blocked address
  mapping(address => bool) public isBlocked;

  /// @notice fires when create position
  event PositionCreated(
    bytes32 key,
    uint128 price,
    uint128 amount,
    uint128 minAmount,
    uint128 maxAmount,
    bool priceType,
    uint8 paymentMethod,
    address indexed token,
    address indexed creator,
    string terms
  );

  /// @notice fires when update position
  event PositionUpdated(bytes32 indexed key, uint128 amount, uint128 offeredAmount);

  /// @notice fires when position state change
  event OfferCreated(
    bytes32 offerKey,
    bytes32 indexed positionKey,
    address indexed creator,
    uint128 amount,
    string terms
  );

  /// @notice fires when cancel offer
  event OfferCanceled(bytes32 indexed key);

  /// @notice fires when release offer
  event OfferReleased(bytes32 indexed key);

  /// @notice fires when block account
  event AccountBlocked(address account);

  function initialize(address cilStaking_) public initializer {
    cilStaking = cilStaking_;

    __Ownable_init();
    __ReentrancyGuard_init();
  }

  modifier initialized() {
    require(cilStaking != address(0), "MarketPlace: not initialized yet");
    _;
  }

  modifier whitelisted(address token) {
    require(whitelists[token] == true, "MarketPlace: token not whitelisted");
    _;
  }

  modifier noBlocked() {
    require(!isBlocked[msg.sender], "MarketPlace: blocked address");
    _;
  }

  modifier validPosition(bytes32 key) {
    require(positions[key].creator != address(0), "MarketPlace: not exist such position");
    _;
  }

  /// @dev calcualate key of position
  function getPositionKey(
    uint8 paymentMethod,
    uint128 price,
    address token,
    address creator,
    uint256 amount,
    uint128 minAmount,
    uint128 maxAmount,
    uint256 timestamp
  ) public pure returns (bytes32) {
    return
      keccak256(
        abi.encodePacked(
          paymentMethod,
          price,
          token,
          amount,
          minAmount,
          maxAmount,
          creator,
          timestamp
        )
      );
  }

  /// @dev calcualate key of position
  function getOfferKey(
    bytes32 positionKey,
    uint256 amount,
    address creator,
    uint256 timestamp
  ) public pure returns (bytes32) {
    return keccak256(abi.encodePacked(positionKey, amount, creator, timestamp));
  }

  /**
   * @dev get staking amount with eth
   * @param user wallet address
   * @return totalAmount amount of staked cil with usd
   */
  function getStakedCil(address user) public view returns (uint256 totalAmount) {
    totalAmount = (ICILStaking(cilStaking).stakedCilAmount(user));
  }

  /**
   * @dev create position
   * @param params position create params
   * @param terms terms of position
   */
  function createPosition(PositionCreateParam memory params, string memory terms)
    external
    payable
    initialized
    whitelisted(params.token)
    noBlocked
    nonReentrant
  {
    bytes32 key = getPositionKey(
      params.paymentMethod,
      params.price,
      params.token,
      msg.sender,
      params.amount,
      params.minAmount,
      params.maxAmount,
      block.timestamp
    );

    positionKeys.push(key);

    positions[key] = Position(
      params.price,
      params.amount,
      params.minAmount,
      params.maxAmount,
      0,
      params.priceType,
      params.paymentMethod,
      params.token,
      msg.sender
    );

    if (params.token == address(0)) {
      require(params.amount == msg.value, "MarketPlace: invalid eth amount");
    } else {
      IERC20(params.token).transferFrom(msg.sender, address(this), params.amount);
    }

    uint256 lockedAmount = getStakedCil(msg.sender);
    require(lockedAmount > minCilAmount, "MarketPlace: insufficient staking amount for offer");

    ICILStaking(cilStaking).lock(msg.sender, minCilAmount);
    require(ICILStaking(cilStaking).isVerified(msg.sender), "Not verified");

    emit PositionCreated(
      key,
      params.price,
      params.amount,
      params.minAmount,
      params.maxAmount,
      params.priceType,
      params.paymentMethod,
      params.token,
      msg.sender,
      terms
    );
  }

  /**
   * @dev increase position amount
   * @param key key of position
   * @param amount amount to increase
   */
  function increasePosition(bytes32 key, uint128 amount)
    external
    payable
    initialized
    noBlocked
    validPosition(key)
    nonReentrant
  {
    Position memory position = positions[key];
    require(position.creator == msg.sender, "MarketPlace: not owner of this position");

    position.amount += amount;

    if (position.token == address(0)) {
      require(amount == msg.value, "MarketPlace: invalid eth amount");
    } else {
      IERC20(position.token).transferFrom(msg.sender, address(this), amount);
    }

    positions[key] = position;

    emit PositionUpdated(key, position.amount, position.offeredAmount);
  }

  /**
   * @dev decrease position amount
   * @param key key of position
   * @param amount amount to increase
   */
  function decreasePosition(bytes32 key, uint128 amount)
    external
    initialized
    noBlocked
    validPosition(key)
    nonReentrant
  {
    Position memory position = positions[key];
    require(position.creator == msg.sender, "MarketPlace: not owner of this position");
    require(position.amount >= position.offeredAmount + amount, "MarketPlace: insufficient amount");

    position.amount -= amount;
    positions[key] = position;

    if (position.token == address(0)) {
      payable(msg.sender).transfer(amount);
    } else {
      IERC20(position.token).transfer(msg.sender, amount);
    }

    emit PositionUpdated(key, position.amount, position.offeredAmount);
  }

  /**
   * @dev create offer
   * @param positionKey key of position
   * @param amount amount to offer
   * @param terms terms of position
   */
  function createOffer(
    bytes32 positionKey,
    uint128 amount,
    string memory terms
  ) external initialized noBlocked nonReentrant {
    Position memory position = positions[positionKey];

    require(position.creator != address(0), "MarketPlace: such position don't exist");

    require(position.minAmount <= amount, "MarketPlace: amount less than min");
    require(position.maxAmount >= amount, "MarketPlace: amount exceed max");

    bytes32 key = getOfferKey(positionKey, amount, msg.sender, block.timestamp);
    offerKeys[positionKey].push(key);

    position.offeredAmount += uint128(amount);
    positions[positionKey] = position;
    offers[key] = Offer(positionKey, uint128(amount), msg.sender, false, false);

    emit OfferCreated(key, positionKey, msg.sender, amount, terms);
    emit PositionUpdated(key, positions[key].amount, positions[key].offeredAmount);
  }

  /**
   * @dev cancel offer
   * @param key key of offer
   */
  function cancelOffer(bytes32 key) external noBlocked nonReentrant {
    Offer memory offer = offers[key];
    require(offer.creator == msg.sender, "MarketPlace: you aren't creator of this offer");
    require(!offer.released && !offer.canceled, "MarketPlace: offer already finished");

    offer.canceled = true;
    positions[offer.positionKey].offeredAmount -= offer.amount;

    offers[key] = offer;

    emit PositionUpdated(key, positions[key].amount, positions[key].offeredAmount);
    emit OfferCanceled(key);
  }

  /**
   * @dev release offer
   * @param key key of offer
   */
  function releaseOffer(bytes32 key) external noBlocked nonReentrant {
    bytes32 positionKey = offers[key].positionKey;

    Position memory position = positions[positionKey];
    Offer memory offer = offers[key];

    require(
      positions[positionKey].creator == msg.sender,
      "MarketPlace: you aren't creator of this position"
    );
    require(!offers[key].released && !offers[key].canceled, "MarketPlace: offer already finished");
    require(position.amount >= offers[key].amount, "MarketPlace: not available amount");

    offer.released = true;
    position.amount -= offer.amount;

    if (position.amount == 0) {
      ICILStaking(cilStaking).remove(positions[key].creator);
    }

    position.offeredAmount -= offer.amount;

    positions[positionKey] = position;
    offers[key] = offer;

    uint256 fee = (offer.amount * feePoint) / 10000;
    if (position.token == address(0)) {
      payable(offer.creator).transfer(offer.amount - fee);
      payable(cilStaking).transfer(fee);
    } else {
      IERC20(position.token).transfer(offer.creator, offer.amount - fee);
      IERC20(position.token).transfer(cilStaking, fee);
    }

    emit PositionUpdated(key, positions[key].amount, positions[key].offeredAmount);
    emit OfferReleased(key);
  }

  /**
   * @dev set staking contract address
   * @param cilStaking_ staking contract address
   */
  function setStakeAddress(address cilStaking_) external onlyOwner {
    cilStaking = cilStaking_;
  }

  /**
   * @dev set token price feed
   * @param token address of token
   * @param status status of toke whitelist
   */
  function setWhitelist(address token, bool status) external onlyOwner {
    whitelists[token] = status;
  }

  /**
   * @dev force cancel offer
   * @param key key of offer
   */
  function forceCancelOffer(bytes32 key) external onlyOwner {
    require(!offers[key].released && !offers[key].canceled, "MarketPlace: offer already finished");

    offers[key].canceled = true;
    positions[offers[key].positionKey].offeredAmount -= offers[key].amount;

    emit OfferCanceled(key);
  }

  /**
   * @dev force remove position
   * @param key key of position
   */
  function forceRemovePosition(bytes32 key) external onlyOwner {
    uint256 positionAmount = positions[key].amount;
    isBlocked[positions[key].creator] = true;
    positions[key].amount = 0;
    ICILStaking(cilStaking).remove(positions[key].creator);

    if (positions[key].token == address(0)) {
      payable(cilStaking).transfer(positionAmount);
    } else {
      IERC20(positions[key].token).transfer(cilStaking, positionAmount);
    }

    emit PositionUpdated(key, positions[key].amount, positions[key].offeredAmount);
    emit AccountBlocked(positions[key].creator);
  }

  function getOffers(bytes32 positionKey) public view returns (Offer[] memory _offers) {
    uint256 len = offerKeys[positionKey].length;
    if (len > 0) {
      for (uint256 i = 0; i < len; ) {
        _offers[i] = offers[offerKeys[positionKey][i]];
        unchecked {
          ++i;
        }
      }
    }
  }

  function getAllPositions() public view returns (Position[] memory _positions) {
    uint256 len = positionKeys.length;
    if (len > 0) {
      for (uint256 i = 0; i < len; ) {
        _positions[i] = positions[positionKeys[i]];
        unchecked {
          ++i;
        }
      }
    }
  }
}
