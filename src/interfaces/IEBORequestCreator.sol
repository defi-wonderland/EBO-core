// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.26;

import {IOracle} from '@defi-wonderland/prophet-core/solidity/interfaces/IOracle.sol';

interface IEBORequestCreator {
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
  event RequestModuleDataSet(address indexed _requestModule, bytes _requestModuleData);

  /**
   * @notice Emitted when the response data module is set
   * @param _responseModule The response module
   * @param _responseModuleData The response module data
   */
  event ResponseModuleDataSet(address indexed _responseModule, bytes _responseModuleData);

  /**
   * @notice Emitted when the dispute data module is set
   * @param _disputeModule The dispute module
   * @param _disputeModuleData The dispute module data
   */
  event DisputeModuleDataSet(address indexed _disputeModule, bytes _disputeModuleData);

  /**
   * @notice Emitted when the resolution data module is set
   * @param _resolutionModule The resolution module
   * @param _resolutionModuleData The resolution module data
   */
  event ResolutionModuleDataSet(address indexed _resolutionModule, bytes _resolutionModuleData);

  /**
   * @notice Emitted when the finality data module is set
   * @param _finalityModule The finality module
   * @param _finalityModuleData The finality module data
   */
  event FinalityModuleDataSet(address indexed _finalityModule, bytes _finalityModuleData);

  /*///////////////////////////////////////////////////////////////
                            ERRORS
  //////////////////////////////////////////////////////////////*/

  /**
   * @notice Thrown when the chain is already added
   */
  error EBORequestCreator_ChainAlreadyAdded();

  /**
   * @notice Thrown when the chain is not added
   */
  error EBORequestCreator_ChainNotAdded();

  /*///////////////////////////////////////////////////////////////
                            VARIABLES
  //////////////////////////////////////////////////////////////*/

  /**
   * @notice The oracle contract
   */
  function oracle() external view returns (IOracle _oracle);

  /**
   * @notice The request data
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
   * @notice The request id per chain and epoch
   * @param _chainId The chain id
   * @param _epoch The epoch
   * @return _requestId The request id
   */
  function requestIdPerChainAndEpoch(
    string calldata _chainId,
    uint256 _epoch
  ) external view returns (bytes32 _requestId);

  /*///////////////////////////////////////////////////////////////
                            LOGIC
  //////////////////////////////////////////////////////////////*/

  /**
   * @notice Create requests
   * @param _epoch The epoch of the request
   * @param _chainIds The chain ids to update
   */
  function createRequests(uint256 _epoch, string[] calldata _chainIds) external;

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
  function setRequestModuleData(address _requestModule, bytes calldata _requestModuleData) external;

  /**
   * @notice Set the response data module
   * @param _responseModule The response module
   * @param _responseModuleData The response module data
   */
  function setResponseModuleData(address _responseModule, bytes calldata _responseModuleData) external;

  /**
   * @notice Set the dispute data module
   * @param _disputeModule The dispute module
   * @param _disputeModuleData The dispute module data
   */
  function setDisputeModuleData(address _disputeModule, bytes calldata _disputeModuleData) external;

  /**
   * @notice Set the resolution data module
   * @param _resolutionModule The resolution module
   * @param _resolutionModuleData The resolution module data
   */
  function setResolutionModuleData(address _resolutionModule, bytes calldata _resolutionModuleData) external;

  /**
   * @notice Set the finality data module
   * @param _finalityModule The finality module
   * @param _finalityModuleData The finality module data
   */
  function setFinalityModuleData(address _finalityModule, bytes calldata _finalityModuleData) external;
}
