// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.26;

import {IOracle} from '@defi-wonderland/prophet-core/solidity/interfaces/IOracle.sol';
import {IBondEscalationModule} from
  '@defi-wonderland/prophet-modules/solidity/interfaces/modules/dispute/IBondEscalationModule.sol';
import {IArbitratorModule} from
  '@defi-wonderland/prophet-modules/solidity/interfaces/modules/resolution/IArbitratorModule.sol';
import {IBondedResponseModule} from
  '@defi-wonderland/prophet-modules/solidity/interfaces/modules/response/IBondedResponseModule.sol';
import {EnumerableSet} from '@openzeppelin/contracts/utils/structs/EnumerableSet.sol';
import {IEpochManager} from 'interfaces/external/IEpochManager.sol';

import {Arbitrable} from 'contracts/Arbitrable.sol';
import {IEBORequestCreator} from 'interfaces/IEBORequestCreator.sol';
import {IEBORequestModule} from 'interfaces/IEBORequestModule.sol';

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
  function createRequests(uint256 _epoch, string[] calldata _chainIds) external {
    if (_epoch > epochManager.currentEpoch() || START_EPOCH > _epoch) revert EBORequestCreator_InvalidEpoch();

    bytes32 _encodedChainId;
    bytes32 _requestId;

    IOracle.Request memory _requestData = requestData;

    IEBORequestModule.RequestParameters memory _requestModuleData =
      IEBORequestModule(_requestData.requestModule).decodeRequestData(_requestData.requestModuleData);

    _requestModuleData.epoch = _epoch;

    for (uint256 _i; _i < _chainIds.length; _i++) {
      _encodedChainId = _encodeChainId(_chainIds[_i]);
      if (!_chainIdsAllowed.contains(_encodedChainId)) revert EBORequestCreator_ChainNotAdded();

      _requestId = requestIdPerChainAndEpoch[_chainIds[_i]][_epoch];

      if (
        _requestId == bytes32(0)
          || (ORACLE.finalizedAt(_requestId) > 0 && ORACLE.finalizedResponseId(_requestId) == bytes32(0))
      ) {
        _requestModuleData.chainId = _chainIds[_i];
        //TODO: REWARDS

        _requestData.requestModuleData = abi.encode(_requestModuleData);

        _requestId = ORACLE.createRequest(_requestData, bytes32(0));

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
  function setFinalityModuleData(address _finalityModule, bytes calldata _finalityModuleData) external onlyArbitrator {
    requestData.finalityModule = _finalityModule;
    requestData.finalityModuleData = _finalityModuleData;

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
