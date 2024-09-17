// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.26;

import {IOracle} from '@defi-wonderland/prophet-core/solidity/interfaces/IOracle.sol';
import {IBondEscalationModule} from
  '@defi-wonderland/prophet-modules/solidity/interfaces/modules/dispute/IBondEscalationModule.sol';
import {IArbitratorModule} from
  '@defi-wonderland/prophet-modules/solidity/interfaces/modules/resolution/IArbitratorModule.sol';
import {IBondedResponseModule} from
  '@defi-wonderland/prophet-modules/solidity/interfaces/modules/response/IBondedResponseModule.sol';
import {IEpochManager} from 'interfaces/external/IEpochManager.sol';

import {IArbitrable} from 'interfaces/IArbitrable.sol';
import {IEBORequestModule} from 'interfaces/IEBORequestModule.sol';

interface IEBORequestCreator is IArbitrable {
  /*///////////////////////////////////////////////////////////////
                            EVENTS
  //////////////////////////////////////////////////////////////*/

  /**
   * @notice Emitted when a request is created
   * @param _requestId The id of the request
   * @param _epoch The epoch of the request
   * @param _chainId The chain id of the request
   */
  event RequestCreated(bytes32 indexed _requestId, uint256 indexed _epoch, string indexed _chainId);

  /**
   * @notice Emitted when a chain is added
   * @param _chainId The chain id added
   */
  event ChainAdded(string indexed _chainId);

  /**
   * @notice Emitted when a chain is removed
   * @param _chainId The chain id removed
   */
  event ChainRemoved(string indexed _chainId);

  /**
   * @notice Emitted when the request data module is set
   * @param _requestModule The request module
   * @param _requestModuleData The request module data
   */
  event RequestModuleDataSet(address indexed _requestModule, IEBORequestModule.RequestParameters _requestModuleData);

  /**
   * @notice Emitted when the response data module is set
   * @param _responseModule The response module
   * @param _responseModuleData The response module data
   */
  event ResponseModuleDataSet(
    address indexed _responseModule, IBondedResponseModule.RequestParameters _responseModuleData
  );

  /**
   * @notice Emitted when the dispute data module is set
   * @param _disputeModule The dispute module
   * @param _disputeModuleData The dispute module data
   */
  event DisputeModuleDataSet(
    address indexed _disputeModule, IBondEscalationModule.RequestParameters _disputeModuleData
  );

  /**
   * @notice Emitted when the resolution data module is set
   * @param _resolutionModule The resolution module
   * @param _resolutionModuleData The resolution module data
   */
  event ResolutionModuleDataSet(
    address indexed _resolutionModule, IArbitratorModule.RequestParameters _resolutionModuleData
  );

  /**
   * @notice Emitted when the finality data module is set
   * @param _finalityModule The finality module
   * @param _finalityModuleData The finality module data
   */
  event FinalityModuleDataSet(address indexed _finalityModule, bytes _finalityModuleData);

  /**
   * @notice Emitted when the epoch manager is set
   * @param _epochManager The epoch manager
   */
  event EpochManagerSet(IEpochManager indexed _epochManager);

  /*///////////////////////////////////////////////////////////////
                            ERRORS
  //////////////////////////////////////////////////////////////*/

  /**
   * @notice Thrown when the nonce is not zero
   */
  error EBORequestCreator_InvalidNonce();
  /**
   * @notice Thrown when the chain is already added
   */
  error EBORequestCreator_ChainAlreadyAdded();

  /**
   * @notice Thrown when the request is already created
   */
  error EBORequestCreator_RequestAlreadyCreated();

  /**
   * @notice Thrown when the chain is not added
   */
  error EBORequestCreator_ChainNotAdded();

  /**
   * @notice Thrown when the epoch is not valid
   */
  error EBORequestCreator_InvalidEpoch();

  /*///////////////////////////////////////////////////////////////
                            VARIABLES
  //////////////////////////////////////////////////////////////*/

  /**
   * @notice The oracle contract
   * @return _ORACLE The oracle contract
   */
  function ORACLE() external view returns (IOracle _ORACLE);

  /**
   * @notice The first valid epoch to create requests
   * @return _START_EPOCH The start epoch
   */
  function START_EPOCH() external view returns (uint256 _START_EPOCH);

  /**
   * @notice The epoch manager contract
   * @return _epochManager The epoch manager contract
   */
  function epochManager() external view returns (IEpochManager _epochManager);

  /**
   * @notice The request data
   * @return _nonce The nonce
   * @return _requester The requester address
   * @return _requestModule The request module address
   * @return _responseModule The response module address
   * @return _disputeModule The dispute module address
   * @return _resolutionModule The resolution module address
   * @return _finalityModule The finality module address
   * @return _requestModuleData The request module data
   * @return _responseModuleData The response module data
   * @return _disputeModuleData The dispute module data
   * @return _resolutionModuleData The resolution module data
   * @return _finalityModuleData The finality module data
   */
  function requestData()
    external
    view
    returns (
      uint96 _nonce,
      address _requester,
      address _requestModule,
      address _responseModule,
      address _disputeModule,
      address _resolutionModule,
      address _finalityModule,
      bytes memory _requestModuleData,
      bytes memory _responseModuleData,
      bytes memory _disputeModuleData,
      bytes memory _resolutionModuleData,
      bytes memory _finalityModuleData
    );

  /**
   * @notice The request data
   * @return _requestData The request data
   */
  function getRequestData() external view returns (IOracle.Request memory _requestData);

  /**
   * @notice The request id per chain and epoch
   * @param _chainId The chain id
   * @param _epoch The epoch
   * @return _requestId The request id
   */
  function requestIdPerChainAndEpoch(
    string calldata _chainId,
    uint256 _epoch
  ) external view returns (bytes32 _requestId);

  /**
   * @notice Returns the allowed chain ids
   * @return _chainIds The allowed chain ids
   */
  function getAllowedChainIds() external view returns (bytes32[] memory _chainIds);

  /*///////////////////////////////////////////////////////////////
                            LOGIC
  //////////////////////////////////////////////////////////////*/

  /**
   * @notice Create request
   * @param _epoch The epoch of the request
   * @param _chainId The chain id to update
   */
  function createRequest(uint256 _epoch, string calldata _chainId) external;

  /**
   * @notice Add a chain to the allowed chains which can be updated
   * @param _chainId The chain id to add
   */
  function addChain(string calldata _chainId) external;

  /**
   * @notice Remove a chain from the allowed chains which can be updated
   * @param _chainId The chain id to remove
   */
  function removeChain(string calldata _chainId) external;

  /**
   * @notice Set the request data module
   * @param _requestModule The request module
   * @param _requestModuleData The request module data
   */
  function setRequestModuleData(
    address _requestModule,
    IEBORequestModule.RequestParameters calldata _requestModuleData
  ) external;

  /**
   * @notice Set the response data module
   * @param _responseModule The response module
   * @param _responseModuleData The response module data
   */
  function setResponseModuleData(
    address _responseModule,
    IBondedResponseModule.RequestParameters calldata _responseModuleData
  ) external;

  /**
   * @notice Set the dispute data module
   * @param _disputeModule The dispute module
   * @param _disputeModuleData The dispute module data
   */
  function setDisputeModuleData(
    address _disputeModule,
    IBondEscalationModule.RequestParameters calldata _disputeModuleData
  ) external;

  /**
   * @notice Set the resolution data module
   * @param _resolutionModule The resolution module
   * @param _resolutionModuleData The resolution module data
   */
  function setResolutionModuleData(
    address _resolutionModule,
    IArbitratorModule.RequestParameters calldata _resolutionModuleData
  ) external;

  /**
   * @notice Set the finality data module
   * @param _finalityModule The finality module
   * @param _finalityModuleData The finality module data
   */
  function setFinalityModuleData(address _finalityModule, bytes calldata _finalityModuleData) external;

  /**
   * @notice Set the epoch manager
   * @param _epochManager The epoch manager
   */
  function setEpochManager(IEpochManager _epochManager) external;
}
