// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.26;

import {IEBORequestCreator} from 'interfaces/IEBORequestCreator.sol';

contract EBORequestCreator is IEBORequestCreator {
  // /// @inheritdoc IEBORequestCreator
  // IOracle public oracle;

  /// @inheritdoc IEBORequestCreator
  address public owner;

  /// @inheritdoc IEBORequestCreator
  address public pendingOwner;

  /// @inheritdoc IEBORequestCreator
  uint256 public reward;

  /// @inheritdoc IEBORequestCreator
  mapping(string _chainId => bool _approved) public chainIds;

  constructor(address _owner) {
    // oracle = _oracle;
    owner = _owner;
    reward = 0;
  }

  /// @inheritdoc IEBORequestCreator
  function setPendingOwner(address _pendingOwner) external onlyOwner {
    pendingOwner = _pendingOwner;

    emit PendingOwnerSetted(_pendingOwner);
  }

  /// @inheritdoc IEBORequestCreator
  function acceptPendingOwner() external onlyPendingOwner {
    address _oldOwner = owner;
    owner = pendingOwner;
    pendingOwner = address(0);

    emit OwnerSetted(_oldOwner, owner);
  }

  /// @inheritdoc IEBORequestCreator
  function createRequest(
    address _requester,
    address _target,
    bytes calldata _data,
    uint256 _value,
    uint256 _nonce
  ) external returns (bytes32 _requestId) {
    // emit RequestCreated(_requestId, _requester, _target, _data, _value, _nonce);
  }

  /// @inheritdoc IEBORequestCreator
  function addChain(string calldata _chainId) external onlyOwner {
    if (chainIds[_chainId]) {
      revert EBORequestCreator_ChainAlreadyAdded();
    }
    chainIds[_chainId] = true;

    emit ChainAdded(_chainId);
  }

  /// @inheritdoc IEBORequestCreator
  function removeChain(string calldata _chainId) external onlyOwner {
    if (!chainIds[_chainId]) {
      revert EBORequestCreator_ChainNotAdded();
    }
    chainIds[_chainId] = false;

    emit ChainRemoved(_chainId);
  }

  /// @inheritdoc IEBORequestCreator
  function setReward(uint256 _reward) external onlyOwner {
    uint256 _oldReward = reward;
    reward = _reward;
    emit RewardSet(_oldReward, _reward);
  }

  /**
   * @notice Checks if the sender is the owner
   */
  modifier onlyOwner() {
    if (msg.sender != owner) {
      revert EBORequestCreator_OnlyOwner();
    }
    _;
  }

  /**
   * @notice Checks if the sender is the pending owner
   */
  modifier onlyPendingOwner() {
    if (msg.sender != pendingOwner) {
      revert EBORequestCreator_OnlyPendingOwner();
    }

    _;
  }
}
