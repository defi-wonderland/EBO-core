// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.26;

import {IOracle} from '@defi-wonderland/prophet-core/solidity/interfaces/IOracle.sol';
import {IArbitrator} from '@defi-wonderland/prophet-modules/solidity/interfaces/IArbitrator.sol';
import {IArbitratorModule} from
  '@defi-wonderland/prophet-modules/solidity/interfaces/modules/resolution/IArbitratorModule.sol';

/**
 * @title CouncilArbitrator
 * @notice Resolves disputes by arbitration by The Graph
 */
interface ICouncilArbitrator is IArbitrator {
  /*///////////////////////////////////////////////////////////////
                              EVENTS
  //////////////////////////////////////////////////////////////*/

  /**
   * @notice Emitted when a dispute is resolved by The Graph's Arbitrator
   * @param _disputeId The ID of the dispute that was resolved
   * @param _status The final result of the resolution
   */
  event DisputeResolved(bytes32 indexed _disputeId, IOracle.DisputeStatus _status);

  /*///////////////////////////////////////////////////////////////
                              ERRORS
  //////////////////////////////////////////////////////////////*/

  /**
   * @notice Thrown when the caller is not the Arbitrator Module
   */
  error CouncilArbitrator_OnlyArbitratorModule();

  /*///////////////////////////////////////////////////////////////
                              VARIABLES
  //////////////////////////////////////////////////////////////*/

  /**
   * @notice Returns the address of the Oracle
   * @return _oracle The address of the Oracle
   */
  function ORACLE() external view returns (IOracle _oracle);

  /**
   * @notice Returns the address of the Arbitrator Module
   * @return _arbitratorModule The address of the Arbitrator Module
   */
  function ARBITRATOR_MODULE() external view returns (IArbitratorModule _arbitratorModule);

  /*///////////////////////////////////////////////////////////////
                              LOGIC
  //////////////////////////////////////////////////////////////*/

  /**
   * @notice Publishes the result, resolves a dispute and finalizes a request
   * @dev Callable only by The Graph's Arbitrator
   * @param _disputeId The ID of the dispute
   * @param _status The resolution for the dispute
   */
  function resolveDispute(bytes32 _disputeId, IOracle.DisputeStatus _status) external;
}
