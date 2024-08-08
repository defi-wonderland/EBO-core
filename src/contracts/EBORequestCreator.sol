// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.26;

import {EnumerableSet} from '@openzeppelin/contracts/utils/structs/EnumerableSet.sol';
import {IEBORequestCreator, IOracle} from 'interfaces/IEBORequestCreator.sol';

contract EBORequestCreator is IEBORequestCreator {
  using EnumerableSet for EnumerableSet.Bytes32Set;

  /// @inheritdoc IEBORequestCreator
  IOracle public oracle;

  /// @inheritdoc IEBORequestCreator
  RequestData public requestData;

  /// @inheritdoc IEBORequestCreator
  address public arbitrator;

  /// @inheritdoc IEBORequestCreator
  address public pendingArbitrator;

  /// @inheritdoc IEBORequestCreator
  uint256 public reward;

  /// @inheritdoc IEBORequestCreator
  mapping(string _chainId => mapping(uint256 _epoch => bytes32 _requestId)) public requestIdPerChainAndEpoch;

  /**
   * @notice The set of chain ids allowed
   */
  EnumerableSet.Bytes32Set internal _chainIdsAllowed;

  constructor(IOracle _oracle, address _arbitrator) {
    oracle = _oracle;
    arbitrator = _arbitrator;
    reward = 0;
  }

  /// @inheritdoc IEBORequestCreator
  function setPendingArbitrator(address _pendingArbitrator) external onlyArbitrator {
    pendingArbitrator = _pendingArbitrator;

    emit PendingArbitratorSetted(_pendingArbitrator);
  }

  /// @inheritdoc IEBORequestCreator
  function acceptPendingArbitrator() external onlyPendingArbitrator {
    address _oldArbitrator = arbitrator;
    arbitrator = pendingArbitrator;
    pendingArbitrator = address(0);

    emit ArbitratorSetted(_oldArbitrator, arbitrator);
  }

  /// @inheritdoc IEBORequestCreator
  function createRequests(uint256 _epoch, string[] calldata _chainIds) external {
    bytes32 _encodedChainId;

    RequestData memory _requestData = requestData;

    for (uint256 _i; _i < _chainIds.length; _i++) {
      _encodedChainId = _encodeChainId(_chainIds[_i]);
      if (!_chainIdsAllowed.contains(_encodedChainId)) revert EBORequestCreator_ChainNotAdded();

      if (requestIdPerChainAndEpoch[_chainIds[_i]][_epoch] == bytes32(0)) {
        // TODO: COMPLETE THE REQUEST CREATION WITH THE PROPER MODULES
        IOracle.Request memory _request = IOracle.Request({
          nonce: uint96(0),
          requester: address(this),
          requestModule: _requestData.requestModule,
          responseModule: _requestData.responseModule,
          disputeModule: _requestData.disputeModule,
          resolutionModule: _requestData.resolutionModule,
          finalityModule: _requestData.finalityModule,
          requestModuleData: _requestData.requestModuleData,
          responseModuleData: _requestData.responseModuleData,
          disputeModuleData: _requestData.disputeModuleData,
          resolutionModuleData: _requestData.resolutionModuleData,
          finalityModuleData: _requestData.finalityModuleData
        });

        bytes32 _requestId = oracle.createRequest(_request, bytes32(0));

        requestIdPerChainAndEpoch[_chainIds[_i]][_epoch] = _requestId;

        emit RequestCreated(_requestId, _epoch, _chainIds[_i]);
      }
    }
  }

  /// @inheritdoc IEBORequestCreator
  function addChain(string calldata _chainId) external onlyArbitrator {
    bytes32 _encodedChainId = _encodeChainId(_chainId);
    if (_chainIdsAllowed.contains(_encodedChainId)) {
      revert EBORequestCreator_ChainAlreadyAdded();
    }
    _chainIdsAllowed.add(_encodedChainId);

    emit ChainAdded(_chainId);
  }

  /// @inheritdoc IEBORequestCreator
  function removeChain(string calldata _chainId) external onlyArbitrator {
    bytes32 _encodedChainId = _encodeChainId(_chainId);
    if (!_chainIdsAllowed.contains(_encodedChainId)) {
      revert EBORequestCreator_ChainNotAdded();
    }
    _chainIdsAllowed.remove(_encodedChainId);

    emit ChainRemoved(_chainId);
  }

  /// @inheritdoc IEBORequestCreator
  function setReward(uint256 _reward) external onlyArbitrator {
    uint256 _oldReward = reward;
    reward = _reward;
    emit RewardSet(_oldReward, _reward);
  }

  /// @inheritdoc IEBORequestCreator
  function setRequestData(RequestData calldata _requestData) external onlyArbitrator {
    requestData = _requestData;

    emit RequestDataSet(_requestData);
  }

  /**
   * @notice Encodes the chain id
   * @dev The chain id is hashed to have a enumerable set to avoid duplicates
   */
  function _encodeChainId(string calldata _chainId) internal pure returns (bytes32 _encodedChainId) {
    _encodedChainId = keccak256(abi.encodePacked(_chainId));
  }

  /**
   * @notice Checks if the sender is the arbitrator
   */
  modifier onlyArbitrator() {
    if (msg.sender != arbitrator) {
      revert EBORequestCreator_OnlyArbitrator();
    }
    _;
  }

  /**
   * @notice Checks if the sender is the pending arbitrator
   */
  modifier onlyPendingArbitrator() {
    if (msg.sender != pendingArbitrator) {
      revert EBORequestCreator_OnlyPendingArbitrator();
    }

    _;
  }
}
