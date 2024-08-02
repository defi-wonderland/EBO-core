// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.26;

import {EnumerableSet} from '@openzeppelin/contracts/utils/structs/EnumerableSet.sol';
import {IEBORequestCreator, IOracle} from 'interfaces/IEBORequestCreator.sol';

contract EBORequestCreator is IEBORequestCreator {
  using EnumerableSet for EnumerableSet.Bytes32Set;

  /// @inheritdoc IEBORequestCreator
  IOracle public oracle;

  /// @inheritdoc IEBORequestCreator
  address public owner;

  /// @inheritdoc IEBORequestCreator
  address public pendingOwner;

  /// @inheritdoc IEBORequestCreator
  uint256 public reward;

  EnumerableSet.Bytes32Set internal _chainIdsAllowed;

  mapping(uint256 _epoch => EnumerableSet.Bytes32Set _chainIds) internal _epochChainIds;

  constructor(IOracle _oracle, address _owner) {
    oracle = _oracle;
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
  function createRequests(uint256 _epoch, string[] calldata _chainIds) external {
    bytes32 _encodedChainId;

    EnumerableSet.Bytes32Set storage _epochEncodedChainIds = _epochChainIds[_epoch];

    for (uint256 _i; _i < _chainIds.length; _i++) {
      _encodedChainId = _encodeChainId(_chainIds[_i]);
      if (!_chainIdsAllowed.contains(_encodedChainId)) revert EBORequestCreator_ChainNotAdded();

      if (!_epochEncodedChainIds.contains(_encodedChainId)) {
        _epochChainIds[_epoch].add(_encodedChainId);

        // TODO: COMPLETE THE REQUEST CREATION WITH THE PROPER MODULES
        IOracle.Request memory _request = IOracle.Request({
          nonce: 0,
          requester: msg.sender,
          requestModule: address(0),
          responseModule: address(0),
          disputeModule: address(0),
          resolutionModule: address(0),
          finalityModule: address(0),
          requestModuleData: '',
          responseModuleData: '',
          disputeModuleData: '',
          resolutionModuleData: '',
          finalityModuleData: ''
        });

        bytes32 _requestId = oracle.createRequest(_request, bytes32(0));

        emit RequestCreated(_requestId, _epoch, _chainIds[_i]);
      }
    }
  }

  /// @inheritdoc IEBORequestCreator
  function addChain(string calldata _chainId) external onlyOwner {
    bytes32 _encodedChainId = _encodeChainId(_chainId);
    if (_chainIdsAllowed.contains(_encodedChainId)) {
      revert EBORequestCreator_ChainAlreadyAdded();
    }
    _chainIdsAllowed.add(_encodedChainId);

    emit ChainAdded(_chainId);
  }

  /// @inheritdoc IEBORequestCreator
  function removeChain(string calldata _chainId) external onlyOwner {
    bytes32 _encodedChainId = _encodeChainId(_chainId);
    if (!_chainIdsAllowed.contains(_encodedChainId)) {
      revert EBORequestCreator_ChainNotAdded();
    }
    _chainIdsAllowed.remove(_encodedChainId);

    emit ChainRemoved(_chainId);
  }

  /// @inheritdoc IEBORequestCreator
  function setReward(uint256 _reward) external onlyOwner {
    uint256 _oldReward = reward;
    reward = _reward;
    emit RewardSet(_oldReward, _reward);
  }

  /**
   * @notice Encodes the chain id
   * @dev The chain id is hashed to have a enumerable set to avoid duplicates
   */
  function _encodeChainId(string calldata _chainId) internal pure returns (bytes32 _encodedChainId) {
    _encodedChainId = keccak256(abi.encodePacked(_chainId));
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
