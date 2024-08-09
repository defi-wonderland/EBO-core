// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.26;

import {EnumerableSet} from '@openzeppelin/contracts/utils/structs/EnumerableSet.sol';

import {SafeERC20} from '@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol';
import {Arbitrable} from 'contracts/Arbitrable.sol';
import {IEBORequestCreator, IERC20, IOracle} from 'interfaces/IEBORequestCreator.sol';

contract EBORequestCreator is IEBORequestCreator, Arbitrable {
  using EnumerableSet for EnumerableSet.Bytes32Set;
  using SafeERC20 for IERC20;

  /// @inheritdoc IEBORequestCreator
  IOracle public oracle;

  /// @inheritdoc IEBORequestCreator
  IOracle.Request public requestData;

  /// @inheritdoc IEBORequestCreator
  mapping(string _chainId => mapping(uint256 _epoch => bytes32 _requestId)) public requestIdPerChainAndEpoch;

  /**
   * @notice The set of chain ids allowed
   */
  EnumerableSet.Bytes32Set internal _chainIdsAllowed;

  constructor(IOracle _oracle, address _arbitrator, address _council) Arbitrable(_arbitrator, _council) {
    oracle = _oracle;
  }

  /// @inheritdoc IEBORequestCreator
  function createRequests(uint256 _epoch, string[] calldata _chainIds) external {
    bytes32 _encodedChainId;

    IOracle.Request memory _requestData = requestData;

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
  function dustCollector(IERC20 _token, address _to) external onlyCouncil {
    uint256 _amount = _token.balanceOf(address(this));
    _token.safeTransfer(_to, _amount);

    emit DustCollected(_token, _to, _amount);
  }

  /**
   * @notice Encodes the chain id
   * @dev The chain id is hashed to have a enumerable set to avoid duplicates
   */
  function _encodeChainId(string calldata _chainId) internal pure returns (bytes32 _encodedChainId) {
    _encodedChainId = keccak256(abi.encodePacked(_chainId));
  }
}
