// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.26;

import {IOracle} from '@defi-wonderland/prophet-core/solidity/interfaces/IOracle.sol';
import {IFinalityModule} from '@defi-wonderland/prophet-core/solidity/interfaces/modules/finality/IFinalityModule.sol';

import {IArbitrable} from 'interfaces/IArbitrable.sol';
import {IEBORequestCreator} from 'interfaces/IEBORequestCreator.sol';

/**
 * @title EBOFinalityModule
 * @notice Module allowing users to index data into the subgraph
 * as a result of a request being finalized
 */
interface IEBOFinalityModule is IFinalityModule {
  /*///////////////////////////////////////////////////////////////
                              STRUCTS
  //////////////////////////////////////////////////////////////*/

  /**
   * @notice Parameters of the response in the module
   * @param epoch The epoch of the response
   * @param chainId The chain ID of the response
   * @param block The block number of the response
   */
  struct ResponseParameters {
    uint256 epoch;
    string chainId;
    uint256 block;
  }
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
  event SetEBORequestCreator(IEBORequestCreator indexed _eboRequestCreator);

  /**
   * @notice Emitted when an EBORequestCreator is removed
   * @param _eboRequestCreator The address of the EBORequestCreator
   */
  event RemoveEBORequestCreator(IEBORequestCreator indexed _eboRequestCreator);

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
   * @notice Returns the address of the arbitrable contract
   * @return _ARBITRABLE The address of the arbitrable contract
   */
  function ARBITRABLE() external view returns (IArbitrable _ARBITRABLE);

  /**
   * @notice Returns the EBORequestCreators allowed
   * @return _eboRequestCreators The EBORequestCreators allowed
   */
  function getAllowedEBORequestCreators() external view returns (address[] memory _eboRequestCreators);

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
  function setEBORequestCreator(IEBORequestCreator _eboRequestCreator) external;

  /**
   * @notice Removes the address of the EBORequestCreator
   * @dev Callable only by The Graph's Arbitrator
   * @param _eboRequestCreator The address of the EBORequestCreator
   */
  function removeEBORequestCreator(IEBORequestCreator _eboRequestCreator) external;

  /**
   * @notice Decodes the response data
   * @param _data The response data
   * @return _params The decoded response data
   */
  function decodeResponseData(bytes calldata _data) external pure returns (ResponseParameters memory _params);
}
