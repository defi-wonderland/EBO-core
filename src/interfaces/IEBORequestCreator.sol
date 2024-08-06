// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.26;

import {IOracle} from '@defi-wonderland/prophet-core-contracts/solidity/interfaces/IOracle.sol';

interface IEBORequestCreator {
  /*///////////////////////////////////////////////////////////////
                            EVENTS
  //////////////////////////////////////////////////////////////*/

  /**
   * @notice Emitted when the pending arbitrator is set
   * @param _pendingArbitrator The address of the pending arbitrator
   */
  event PendingArbitratorSetted(address _pendingArbitrator);

  /**
   * @notice Emitted when the abitrator is set
   * @param _oldArbitrator The old abitrator address
   * @param _newArbitrator The new abitrator address
   */
  event ArbitratorSetted(address _oldArbitrator, address _newArbitrator);

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
   * @notice Emitted when the reward is set
   * @param _oldReward The old reward value
   * @param _newReward The new reward value
   */
  event RewardSet(uint256 _oldReward, uint256 _newReward);

  /**
   * @notice Emitted when a request data is set
   * @param _requestData The request data
   */
  event RequestDataSet(RequestData _requestData);

  /*///////////////////////////////////////////////////////////////
                            ERRORS
  //////////////////////////////////////////////////////////////*/

  /**
   * @notice Thrown when the caller is not the arbitrator
   */
  error EBORequestCreator_OnlyArbitrator();

  /**
   * @notice Thrown when the caller is not the pending arbitrator
   */
  error EBORequestCreator_OnlyPendingArbitrator();

  /**
   * @notice hrown when the chain is already added
   */
  error EBORequestCreator_ChainAlreadyAdded();

  /**
   * @notice Thrown when the chain is not added
   */
  error EBORequestCreator_ChainNotAdded();

  /*///////////////////////////////////////////////////////////////
                            STRUCTS
  //////////////////////////////////////////////////////////////*/

  struct RequestData {
    address requestModule;
    address responseModule;
    address disputeModule;
    address resolutionModule;
    address finalityModule;
    bytes requestModuleData;
    bytes responseModuleData;
    bytes disputeModuleData;
    bytes resolutionModuleData;
    bytes finalityModuleData;
  }

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
   * @notice The arbitrator of the contract
   * @return _arbitrator The arbitrator
   */
  function arbitrator() external view returns (address _arbitrator);

  /**
   * @notice The pending arbitrator of the contract
   * @return _pendingArbitrator The pending owner
   */
  function pendingArbitrator() external view returns (address _pendingArbitrator);

  /**
   * @notice The reward paid for each chain updated
   * @return _reward The reward
   */
  function reward() external view returns (uint256 _reward);

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
   * @notice Set the pending arbitrator
   * @param _pendingArbitrator The address of the pending arbitrator
   */
  function setPendingArbitrator(address _pendingArbitrator) external;

  /**
   * @notice Accept the pending arbitrator
   */
  function acceptPendingArbitrator() external;

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
   * @notice Set the reward paid for each chain updated
   * @param _reward The reward to set
   */
  function setReward(uint256 _reward) external;

  /**
   * @notice Set the request data
   * @param _requestData The request data to set
   */
  function setRequestData(RequestData calldata _requestData) external;
}
