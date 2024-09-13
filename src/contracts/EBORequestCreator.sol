// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.26;

import {EnumerableSet} from '@openzeppelin/contracts/utils/structs/EnumerableSet.sol';

import {Arbitrable} from 'contracts/Arbitrable.sol';

import {
  IArbitratorModule,
  IBondEscalationModule,
  IBondedResponseModule,
  IBondedResponseModule,
  IEBOFinalityModule,
  IEBORequestCreator,
  IEBORequestModule,
  IEpochManager,
  IOracle
} from 'interfaces/IEBORequestCreator.sol';

contract EBORequestCreator is Arbitrable, IEBORequestCreator {
  using EnumerableSet for EnumerableSet.Bytes32Set;

  /// @inheritdoc IEBORequestCreator
  IOracle public immutable ORACLE;

  /// @inheritdoc IEBORequestCreator
  uint256 public immutable START_EPOCH;

  /// @inheritdoc IEBORequestCreator
  IEpochManager public epochManager;

  /// @inheritdoc IEBORequestCreator
  IOracle.Request public requestData;

  /// @inheritdoc IEBORequestCreator
  mapping(string _chainId => mapping(uint256 _epoch => bytes32 _requestId)) public requestIdPerChainAndEpoch;

  /**
   * @notice The set of chain ids allowed
   */
  EnumerableSet.Bytes32Set internal _chainIdsAllowed;

  constructor(
    IOracle _oracle,
    IEpochManager _epochManager,
    address _arbitrator,
    address _council,
    IOracle.Request memory _requestData
  ) Arbitrable(_arbitrator, _council) {
    if (_requestData.nonce != 0) revert EBORequestCreator_InvalidNonce();

    ORACLE = _oracle;
    _setEpochManager(_epochManager);

    _requestData.requester = address(this);
    requestData = _requestData;

    START_EPOCH = epochManager.currentEpoch();
  }

  /// @inheritdoc IEBORequestCreator
  function createRequest(uint256 _epoch, string calldata _chainId) external {
    if (_epoch > epochManager.currentEpoch() || START_EPOCH > _epoch) revert EBORequestCreator_InvalidEpoch();

    bytes32 _encodedChainId = _encodeChainId(_chainId);
    if (!_chainIdsAllowed.contains(_encodedChainId)) revert EBORequestCreator_ChainNotAdded();

    bytes32 _requestId = requestIdPerChainAndEpoch[_chainId][_epoch];

    if (
      _requestId != bytes32(0)
        && (ORACLE.finalizedAt(_requestId) == 0 || ORACLE.finalizedResponseId(_requestId) != bytes32(0))
    ) revert EBORequestCreator_RequestAlreadyCreated();

    // Request data
    IOracle.Request memory _requestData = requestData;

    // Request module data
    IEBORequestModule.RequestParameters memory _requestModuleData =
      IEBORequestModule(_requestData.requestModule).decodeRequestData(_requestData.requestModuleData);

    _requestModuleData.chainId = _chainId;
    _requestModuleData.epoch = _epoch;
    _requestData.requestModuleData = abi.encode(_requestModuleData);

    // Response module data
    IBondedResponseModule.RequestParameters memory _responseModuleData =
      IBondedResponseModule(_requestData.responseModule).decodeRequestData(_requestData.responseModuleData);

    // Deadline is relative to the current block timestamp
    _responseModuleData.deadline = block.timestamp + _responseModuleData.deadline;
    _requestData.responseModuleData = abi.encode(_responseModuleData);

    // Dispute module data
    IBondEscalationModule.RequestParameters memory _disputeModuleData =
      IBondEscalationModule(_requestData.disputeModule).decodeRequestData(_requestData.disputeModuleData);

    // Bond escalation deadline is relative to the deadline
    _disputeModuleData.disputeWindow = _responseModuleData.deadline + _disputeModuleData.disputeWindow;
    _disputeModuleData.bondEscalationDeadline =
      _disputeModuleData.disputeWindow + _disputeModuleData.bondEscalationDeadline;
    _disputeModuleData.tyingBuffer = _disputeModuleData.bondEscalationDeadline + _disputeModuleData.tyingBuffer;
    _requestData.disputeModuleData = abi.encode(_disputeModuleData);

    _requestId = ORACLE.createRequest(_requestData, bytes32(0));

    requestIdPerChainAndEpoch[_chainId][_epoch] = _requestId;

    emit RequestCreated(_requestId, _epoch, _chainId);
  }

  /// @inheritdoc IEBORequestCreator
  function addChain(string calldata _chainId) external onlyArbitrator {
    bytes32 _encodedChainId = _encodeChainId(_chainId);
    if (!_chainIdsAllowed.add(_encodedChainId)) {
      revert EBORequestCreator_ChainAlreadyAdded();
    }

    emit ChainAdded(_chainId);
  }

  /// @inheritdoc IEBORequestCreator
  function removeChain(string calldata _chainId) external onlyArbitrator {
    bytes32 _encodedChainId = _encodeChainId(_chainId);
    if (!_chainIdsAllowed.remove(_encodedChainId)) {
      revert EBORequestCreator_ChainNotAdded();
    }

    emit ChainRemoved(_chainId);
  }

  /// @inheritdoc IEBORequestCreator
  function setRequestModuleData(
    address _requestModule,
    IEBORequestModule.RequestParameters calldata _requestModuleData
  ) external onlyArbitrator {
    requestData.requestModule = _requestModule;
    requestData.requestModuleData = abi.encode(_requestModuleData);

    emit RequestModuleDataSet(_requestModule, _requestModuleData);
  }

  /// @inheritdoc IEBORequestCreator
  function setResponseModuleData(
    address _responseModule,
    IBondedResponseModule.RequestParameters calldata _responseModuleData
  ) external onlyArbitrator {
    requestData.responseModule = _responseModule;
    requestData.responseModuleData = abi.encode(_responseModuleData);

    emit ResponseModuleDataSet(_responseModule, _responseModuleData);
  }

  /// @inheritdoc IEBORequestCreator
  function setDisputeModuleData(
    address _disputeModule,
    IBondEscalationModule.RequestParameters calldata _disputeModuleData
  ) external onlyArbitrator {
    requestData.disputeModule = _disputeModule;
    requestData.disputeModuleData = abi.encode(_disputeModuleData);

    emit DisputeModuleDataSet(_disputeModule, _disputeModuleData);
  }

  /// @inheritdoc IEBORequestCreator
  function setResolutionModuleData(
    address _resolutionModule,
    IArbitratorModule.RequestParameters calldata _resolutionModuleData
  ) external onlyArbitrator {
    requestData.resolutionModule = _resolutionModule;
    requestData.resolutionModuleData = abi.encode(_resolutionModuleData);

    emit ResolutionModuleDataSet(_resolutionModule, _resolutionModuleData);
  }

  // TODO: Why set finality module data?
  // TODO: Change module data to the specific interface when we have
  /// @inheritdoc IEBORequestCreator
  function setFinalityModuleData(
    address _finalityModule,
    IEBOFinalityModule.RequestParameters calldata _finalityModuleData
  ) external onlyArbitrator {
    requestData.finalityModule = _finalityModule;
    requestData.finalityModuleData = abi.encode(_finalityModuleData);

    emit FinalityModuleDataSet(_finalityModule, _finalityModuleData);
  }

  /// @inheritdoc IEBORequestCreator
  function setEpochManager(IEpochManager _epochManager) external onlyArbitrator {
    _setEpochManager(_epochManager);
  }

  /// @inheritdoc IEBORequestCreator
  function getRequestData() external view returns (IOracle.Request memory _requestData) {
    _requestData = requestData;
  }

  /**
   * @notice Set the epoch manager
   * @param _epochManager The epoch manager
   */
  function _setEpochManager(IEpochManager _epochManager) internal {
    epochManager = _epochManager;

    emit EpochManagerSet(_epochManager);
  }

  /**
   * @notice Encodes the chain id
   * @dev The chain id is hashed to have a enumerable set to avoid duplicates
   */
  function _encodeChainId(string calldata _chainId) internal pure returns (bytes32 _encodedChainId) {
    _encodedChainId = keccak256(abi.encodePacked(_chainId));
  }
}
