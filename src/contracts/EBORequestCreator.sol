// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.26;

import {EnumerableSet} from '@openzeppelin/contracts/utils/structs/EnumerableSet.sol';
import {IEBORequestCreator} from 'interfaces/IEBORequestCreator.sol';

contract EBORequestCreator is IEBORequestCreator {
  using EnumerableSet for EnumerableSet.Bytes32Set;

  // /// @inheritdoc IEBORequestCreator
  // IOracle public oracle;

  /// @inheritdoc IEBORequestCreator
  address public owner;

  /// @inheritdoc IEBORequestCreator
  address public pendingOwner;

  /// @inheritdoc IEBORequestCreator
  uint256 public reward;

  /**
   * @notice The list of chain ids
   */
  EnumerableSet.Bytes32Set internal _chainIds;

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
    if (!_chainIds.add(_chaindIdToBytes32(_chainId))) {
      revert EBORequestCreator_ChainAlreadyAdded();
    }
    emit ChainAdded(_chainId);
  }

  /// @inheritdoc IEBORequestCreator
  function removeChain(string calldata _chainId) external onlyOwner {
    if (!_chainIds.remove(_chaindIdToBytes32(_chainId))) {
      revert EBORequestCreator_ChainNotAdded();
    }
    emit ChainRemoved(_chainId);
  }

  /// @inheritdoc IEBORequestCreator
  function setReward(uint256 _reward) external onlyOwner {
    uint256 _oldReward = reward;
    reward = _reward;
    emit RewardSet(_oldReward, _reward);
  }

  /// @inheritdoc IEBORequestCreator
  function getChainIds() external view returns (string[] memory _chainIdsValues) {
    bytes32[] memory _chainIdsBytes = _chainIds.values();

    for (uint256 _i; _i < _chainIdsBytes.length; _i++) {
      _chainIdsValues[_i] = _chaindIdToString(_chainIdsBytes[_i]);
    }
  }

  function _chaindIdToBytes32(string memory _chainId) internal pure returns (bytes32 _convertedChainId) {
    assembly {
      _convertedChainId := mload(add(_chainId, 32))
    }
  }

  function _chaindIdToString(bytes32 _chainId) internal pure returns (string memory _convertedChainId) {
    _convertedChainId = string(abi.encodePacked(_chainId));
  }

  modifier onlyOwner() {
    if (msg.sender != owner) {
      revert EBORequestCreator_OnlyOwner();
    }
    _;
  }

  modifier onlyPendingOwner() {
    if (msg.sender != pendingOwner) {
      revert EBORequestCreator_OnlyPendingOwner();
    }
    _;
  }
}
