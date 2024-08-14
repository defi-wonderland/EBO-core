// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.26;

import {EnumerableSet} from '@openzeppelin/contracts/utils/structs/EnumerableSet.sol';

import {Arbitrable} from 'contracts/Arbitrable.sol';
import {IEBORequestCreator, IEpochManager, IOracle} from 'interfaces/IEBORequestCreator.sol';

contract EBORequestCreator is IEBORequestCreator, Arbitrable {
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
    ORACLE = _oracle;
    epochManager = _epochManager;

    if (_requestData.nonce != 0) revert EBORequestCreator_InvalidNonce();
    _requestData.requester = address(this);
    requestData = _requestData;

    START_EPOCH = epochManager.currentEpoch();
  }

  /// @inheritdoc IEBORequestCreator
  function createRequests(uint256 _epoch, string[] calldata _chainIds) external {
    if (_epoch > epochManager.currentEpoch() || START_EPOCH > _epoch) revert EBORequestCreator_InvalidEpoch();

    bytes32 _encodedChainId;

    IOracle.Request memory _requestData = requestData;

    for (uint256 _i; _i < _chainIds.length; _i++) {
      _encodedChainId = _encodeChainId(_chainIds[_i]);
      if (!_chainIdsAllowed.contains(_encodedChainId)) revert EBORequestCreator_ChainNotAdded();

      if (requestIdPerChainAndEpoch[_chainIds[_i]][_epoch] == bytes32(0)) {
        // TODO: CREATE REQUEST DATA
        bytes32 _requestId = ORACLE.createRequest(_requestData, bytes32(0));

        requestIdPerChainAndEpoch[_chainIds[_i]][_epoch] = _requestId;

        emit RequestCreated(_requestId, _epoch, _chainIds[_i]);
      }
    }
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
  function setRequestModuleData(address _requestModule, bytes calldata _requestModuleData) external onlyArbitrator {
    requestData.requestModule = _requestModule;
    requestData.requestModuleData = _requestModuleData;

    emit RequestModuleDataSet(_requestModule, _requestModuleData);
  }

  /// @inheritdoc IEBORequestCreator
  function setResponseModuleData(address _responseModule, bytes calldata _responseModuleData) external onlyArbitrator {
    requestData.responseModule = _responseModule;
    requestData.responseModuleData = _responseModuleData;

    emit ResponseModuleDataSet(_responseModule, _responseModuleData);
  }

  /// TODO: Change module data to the specific interface when we have
  /// @inheritdoc IEBORequestCreator
  function setDisputeModuleData(address _disputeModule, bytes calldata _disputeModuleData) external onlyArbitrator {
    requestData.disputeModule = _disputeModule;
    requestData.disputeModuleData = _disputeModuleData;

    emit DisputeModuleDataSet(_disputeModule, _disputeModuleData);
  }

  /// @inheritdoc IEBORequestCreator
  function setResolutionModuleData(
    address _resolutionModule,
    bytes calldata _resolutionModuleData
  ) external onlyArbitrator {
    requestData.resolutionModule = _resolutionModule;
    requestData.resolutionModuleData = _resolutionModuleData;

    emit ResolutionModuleDataSet(_resolutionModule, _resolutionModuleData);
  }

  /// @inheritdoc IEBORequestCreator
  function setFinalityModuleData(address _finalityModule, bytes calldata _finalityModuleData) external onlyArbitrator {
    requestData.finalityModule = _finalityModule;
    requestData.finalityModuleData = _finalityModuleData;

    emit FinalityModuleDataSet(_finalityModule, _finalityModuleData);
  }

  /// @inheritdoc IEBORequestCreator
  function setEpochManager(IEpochManager _epochManager) external onlyArbitrator {
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
