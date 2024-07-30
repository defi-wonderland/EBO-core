// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {IOracle} from '@defi-wonderland/prophet-core-contracts/solidity/interfaces/IOracle.sol';
import {IFinalityModule} from
  '@defi-wonderland/prophet-core-contracts/solidity/interfaces/modules/finality/IFinalityModule.sol';

/**
 * @title EBOFinalityModule
 * @notice Module allowing users to call a function on a contract
 * as a result of a request being finalized
 */
interface IEBOFinalityModule is IFinalityModule {
  /*///////////////////////////////////////////////////////////////
                              EVENTS
  //////////////////////////////////////////////////////////////*/

  /**
   * @notice A callback has been executed
   * @param _requestId The id of the request being finalized
   * @param _target The target address for the callback
   * @param _data The calldata forwarded to the target
   */
  event Callback(bytes32 indexed _requestId, address indexed _target, bytes _data);

  /**
   * @notice Emitted when the block number has been resolved for a particular epoch-chainId pair
   * @param _epoch The new epoch
   * @param _chainId The chain ID
   * @param _blockNumber The block number for the epoch-chainId pair
   */
  event NewEpoch(uint256 _epoch, uint256 _chainId, uint256 _blockNumber);

  /**
   * @notice Emitted when a block number is amended
   * @param _epoch The epoch to amend
   * @param _chainId The chain ID to amend
   * @param _blockNumber The amended block number
   */
  event AmendEpoch(uint256 _epoch, uint256 _chainId, uint256 _blockNumber);

  /*///////////////////////////////////////////////////////////////
                              ERRORS
  //////////////////////////////////////////////////////////////*/

  /**
   * @notice Thrown when the caller is not The Graph's Arbitrator
   */
  error EBOFinalityModule_OnlyArbitrator();

  /**
   * @notice Thrown when the lengths of chain IDs and block numbers do not match
   */
  error EBOFinalityModule_LengthMismatch();

  /*///////////////////////////////////////////////////////////////
                              STRUCTS
  //////////////////////////////////////////////////////////////*/

  /**
   * @notice Parameters of the request as stored in the module
   * @param target The target address for the callback
   * @param data The calldata forwarded to the target
   */
  struct RequestParameters {
    address target;
    bytes data;
  }

  /*///////////////////////////////////////////////////////////////
                              LOGIC
  //////////////////////////////////////////////////////////////*/

  /**
   * @notice Returns the address of The Graph's arbitrator
   * @return _arbitrator The address of The Graph's arbitrator
   */
  function ARBITRATOR() external view returns (address _arbitrator);

  /**
   * @notice Returns the decoded data for a request
   * @param _data The encoded request parameters
   * @return _params The struct containing the parameters for the request
   */
  function decodeRequestData(bytes calldata _data) external view returns (RequestParameters memory _params);

  /**
   * @notice Finalizes the request by executing the callback call on the target
   * @dev The success of the callback call is purposely not checked
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
   * @dev Callable only with The Graph's Arbitrator
   * @param _epoch The epoch to amend
   * @param _chainIds The chain IDs to amend
   * @param _blockNumbers The amended block numbers
   */
  function amendEpoch(uint256 _epoch, uint256[] calldata _chainIds, uint256[] calldata _blockNumbers) external;
}
