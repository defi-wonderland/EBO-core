// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {IOracle} from '@defi-wonderland/prophet-core/solidity/interfaces/IOracle.sol';
import {IFinalityModule} from '@defi-wonderland/prophet-core/solidity/interfaces/modules/finality/IFinalityModule.sol';

import {IArbitrable} from 'interfaces/IArbitrable.sol';

/**
 * @title EBOFinalityModule
 * @notice Module allowing users to index data into the subgraph
 * as a result of a request being finalized
 */
interface IEBOFinalityModule is IFinalityModule, IArbitrable {
  /*///////////////////////////////////////////////////////////////
                              EVENTS
  //////////////////////////////////////////////////////////////*/

  /**
   * @notice Emitted when the block number has been resolved for a particular epoch-chainId pair
   * @param _epoch The new epoch
   * @param _chainId The chain ID
   * @param _blockNumber The block number for the epoch-chainId pair
   */
  event NewEpoch(uint256 indexed _epoch, string indexed _chainId, uint256 _blockNumber);

  /**
   * @notice Emitted when a block number is amended
   * @param _epoch The epoch to amend
   * @param _chainId The chain ID to amend
   * @param _blockNumber The amended block number
   */
  event AmendEpoch(uint256 indexed _epoch, string indexed _chainId, uint256 _blockNumber);

  /**
   * @notice Emitted when the EBORequestCreator is set
   * @param _eboRequestCreator The address of the EBORequestCreator
   */
  event SetEBORequestCreator(address indexed _eboRequestCreator);

  /*///////////////////////////////////////////////////////////////
                              ERRORS
  //////////////////////////////////////////////////////////////*/

  /**
   * @notice Thrown when the requester is not the EBORequestCreator
   */
  error EBOFinalityModule_InvalidRequester();

  /**
   * @notice Thrown when the lengths of chain IDs and block numbers do not match
   */
  error EBOFinalityModule_LengthMismatch();

  /*///////////////////////////////////////////////////////////////
                              VARIABLES
  //////////////////////////////////////////////////////////////*/

  /**
   * @notice Returns the address of the EBORequestCreator
   * @return _eboRequestCreator The address of the EBORequestCreator
   */
  function eboRequestCreator() external view returns (address _eboRequestCreator);

  /*///////////////////////////////////////////////////////////////
                              LOGIC
  //////////////////////////////////////////////////////////////*/

  /**
   * @notice Finalizes the request by publishing the response
   * @dev Callable only by the Oracle
   * @param _request The request being finalized
   * @param _response The final response
   * @param _finalizer The address that initiated the finalization
   */
  function finalizeRequest(
    IOracle.Request calldata _request,
    IOracle.Response calldata _response,
    address _finalizer
  ) external;

  /**
   * @notice Allows to amend data in case of an error or an emergency
   * @dev Callable only by The Graph's Arbitrator
   * @param _epoch The epoch to amend
   * @param _chainIds The chain IDs to amend
   * @param _blockNumbers The amended block numbers
   */
  function amendEpoch(uint256 _epoch, string[] calldata _chainIds, uint256[] calldata _blockNumbers) external;

  /**
   * @notice Sets the address of the EBORequestCreator
   * @dev Callable only by The Graph's Arbitrator
   * @param _eboRequestCreator The address of the EBORequestCreator
   */
  function setEBORequestCreator(address _eboRequestCreator) external;
}