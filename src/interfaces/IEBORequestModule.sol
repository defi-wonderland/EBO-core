// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.26;

import {IOracle} from '@defi-wonderland/prophet-core/solidity/interfaces/IOracle.sol';
import {IRequestModule} from '@defi-wonderland/prophet-core/solidity/interfaces/modules/request/IRequestModule.sol';
import {IAccountingExtension} from
  '@defi-wonderland/prophet-modules/solidity/interfaces/extensions/IAccountingExtension.sol';

import {IArbitrable} from 'interfaces/IArbitrable.sol';
import {IEBORequestCreator} from 'interfaces/IEBORequestCreator.sol';

/**
 * @title EBORequestModule
 * @notice Module allowing users to create a request for RPC data for a specific epoch
 */
interface IEBORequestModule is IRequestModule, IArbitrable {
  /*///////////////////////////////////////////////////////////////
                              STRUCTS
  //////////////////////////////////////////////////////////////*/

  /**
   * @notice Parameters of the request as stored in the module
   * @param epoch The epoch for which the data is requested
   * @param chainId The chain ID for which the data is requested
   * @param accountingExtension The address of the AccountingExtension
   * @param paymentAmount The amount of payment for the request
   */
  struct RequestParameters {
    uint256 epoch;
    string chainId;
    IAccountingExtension accountingExtension;
    uint256 paymentAmount;
  }

  /*///////////////////////////////////////////////////////////////
                              EVENTS
  //////////////////////////////////////////////////////////////*/

  /**
   * @notice Emitted when the EBORequestCreator is set
   * @param _eboRequestCreator The address of the EBORequestCreator
   */
  event SetEBORequestCreator(IEBORequestCreator indexed _eboRequestCreator);

  /*///////////////////////////////////////////////////////////////
                              ERRORS
  //////////////////////////////////////////////////////////////*/

  /**
   * @notice Thrown when the requester is not the EBORequestCreator
   */
  error EBORequestModule_InvalidRequester();

  /*///////////////////////////////////////////////////////////////
                              VARIABLES
  //////////////////////////////////////////////////////////////*/

  /**
   * @notice Returns the address of the EBORequestCreator
   * @return _eboRequestCreator The address of the EBORequestCreator
   */
  function eboRequestCreator() external view returns (IEBORequestCreator _eboRequestCreator);

  /*///////////////////////////////////////////////////////////////
                              LOGIC
  //////////////////////////////////////////////////////////////*/

  /**
   * @notice Executes pre-request logic, bonding the requester's funds
   * @dev Callable only by the Oracle
   * @param _requestId The ID of the request
   * @param _data The data of the request
   * @param _requester The address of the requester
   */
  function createRequest(bytes32 _requestId, bytes calldata _data, address _requester) external;

  /**
   * @notice Finalizes the request by paying the proposer for the response or releasing the requester's bond if no response was submitted
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
   * @notice Sets the address of the EBORequestCreator
   * @dev Callable only by The Graph's Arbitrator
   * @param _eboRequestCreator The address of the EBORequestCreator
   */
  function setEBORequestCreator(
    IEBORequestCreator _eboRequestCreator
  ) external;

  /**
   * @notice Determines how to decode the inputted request data
   * @param _data The encoded request parameters
   * @return _params The struct containing the parameters for the request
   */
  function decodeRequestData(
    bytes calldata _data
  ) external pure returns (RequestParameters memory _params);
}
