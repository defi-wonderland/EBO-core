// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.26;

// import {IOracle} from '@defi-wonderland/prophet-core-contracts/solidity/interfaces/IOracle.sol';

interface IEBORequestCreator {
  /*///////////////////////////////////////////////////////////////
                            EVENTS
  //////////////////////////////////////////////////////////////*/

  /**
   * @notice Emitted when the pending owner is set
   * @param _pendingOwner The address of the pending owner
   */
  event PendingOwnerSetted(address _pendingOwner);

  /**
   * @notice Emitted when the owner is set
   * @param _oldOwner The old owner address
   * @param _newOwner The new owner address
   */
  event OwnerSetted(address _oldOwner, address _newOwner);

  /**
   * @notice Emitted when a request is created
   * @param _epoch The epoch of the request
   * @param _chainId The chain id of the request
   */
  event RequestCreated(uint256 indexed _epoch, string indexed _chainId);

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

  /*///////////////////////////////////////////////////////////////
                            ERRORS
  //////////////////////////////////////////////////////////////*/

  /**
   * @notice Thrown when the caller is not the owner
   */
  error EBORequestCreator_OnlyOwner();

  /**
   * @notice Thrown when the caller is not the pending owner
   */
  error EBORequestCreator_OnlyPendingOwner();

  /**
   * @notice hrown when the chain is already added
   */
  error EBORequestCreator_ChainAlreadyAdded();

  /**
   * @notice Thrown when the chain is not added
   */
  error EBORequestCreator_ChainNotAdded();

  /*///////////////////////////////////////////////////////////////
                            VARIABLES
  //////////////////////////////////////////////////////////////*/

  // /**
  //  * @notice The oracle contract
  //  */
  // function oracle() external view returns (IOracle _oracle);

  /**
   * @notice The owner of the contract
   * @return _owner The owner
   */
  function owner() external view returns (address _owner);

  /**
   * @notice The pending owner of the contract
   * @return _pendingOwner The pending owner
   */
  function pendingOwner() external view returns (address _pendingOwner);

  /**
   * @notice The reward paid for each chain updated
   * @return _reward The reward
   */
  function reward() external view returns (uint256 _reward);

  /**
   * @notice The chain ids
   * @param _chainId The chain id to check
   * @return _approved The chain id is approved
   */
  function chainIds(string calldata _chainId) external view returns (bool _approved);

  /*///////////////////////////////////////////////////////////////
                            LOGIC
  //////////////////////////////////////////////////////////////*/

  /**
   * @notice Set the pending owner
   * @param _pendingOwner The address of the pending owner
   */
  function setPendingOwner(address _pendingOwner) external;

  /**
   * @notice Accept the pending owner
   */
  function acceptPendingOwner() external;

  /**
   * @notice Create a request
   * @param _requester The address of the requester
   * @param _target The address of the target
   * @param _data The data of the request
   * @param _value The value of the request
   * @param _nonce The nonce of the request
   * @return _requestId The id of the request
   */
  function createRequest(
    address _requester,
    address _target,
    bytes calldata _data,
    uint256 _value,
    uint256 _nonce
  ) external returns (bytes32 _requestId);

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
}
