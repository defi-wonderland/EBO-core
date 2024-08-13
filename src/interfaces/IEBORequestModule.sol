// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {IRequestModule} from '@defi-wonderland/prophet-core/solidity/interfaces/modules/request/IRequestModule.sol';
import {IAccountingExtension} from
  '@defi-wonderland/prophet-modules/solidity/interfaces/extensions/IAccountingExtension.sol';

import {IArbitrable} from 'interfaces/IArbitrable.sol';

/**
 * @title EBORequestModule
 * @notice Module allowing users to fetch epoch block data from the oracle
 * as a result of a request being created
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
    uint256 chainId;
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
  event SetEBORequestCreator(address _eboRequestCreator);

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
  function eboRequestCreator() external view returns (address _eboRequestCreator);

  /*///////////////////////////////////////////////////////////////
                              LOGIC
  //////////////////////////////////////////////////////////////*/

  /**
   * @notice Creates a request for RPC data for a specific epoch
   * @dev Callable only by the Oracle
   * @param _requestId The id of the request
   * @param _data The data of the request
   * @param _requester The address of the requester
   */
  function createRequest(bytes32 _requestId, bytes calldata _data, address _requester) external;

  /**
   * @notice Sets the address of the EBORequestCreator
   * @dev Callable only by The Graph's Arbitrator
   * @param _eboRequestCreator The address of the EBORequestCreator
   */
  function setEBORequestCreator(address _eboRequestCreator) external;

  /**
   * @notice Determines how to decode the inputted request data
   * @param _data The encoded request parameters
   * @return _params The struct containing the parameters for the request
   */
  function decodeRequestData(bytes calldata _data) external pure returns (RequestParameters memory _params);
}
