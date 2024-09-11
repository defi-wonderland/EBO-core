// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.26;

/**
 * @title Arbitrable
 * @notice Makes a contract subject to arbitration by The Graph
 */
interface IArbitrable {
  /*///////////////////////////////////////////////////////////////
                              EVENTS
  //////////////////////////////////////////////////////////////*/

  /**
   * @notice Emitted when The Graph's Arbitrator is set
   * @param _arbitrator The address of The Graph's Arbitrator
   */
  event SetArbitrator(address indexed _arbitrator);

  /**
   * @notice Emitted when The Graph's Council is set
   * @param _council The address of The Graph's Council
   */
  event SetCouncil(address indexed _council);

  /**
   * @notice Emitted when the pending The Graph's Council is set
   * @param _pendingCouncil The address of the pending The Graph's Council
   */
  event SetPendingCouncil(address indexed _pendingCouncil);

  /*///////////////////////////////////////////////////////////////
                              ERRORS
  //////////////////////////////////////////////////////////////*/

  /**
   * @notice Thrown when the caller is not The Graph's Arbitrator
   */
  error Arbitrable_OnlyArbitrator();

  /**
   * @notice Thrown when the caller is not The Graph's Council
   */
  error Arbitrable_OnlyCouncil();

  /**
   * @notice Thrown when the caller is not the pending The Graph's Council
   */
  error Arbitrable_OnlyPendingCouncil();

  /*///////////////////////////////////////////////////////////////
                              VARIABLES
  //////////////////////////////////////////////////////////////*/

  /**
   * @notice Returns the address of The Graph's Arbitrator
   * @return __arbitrator The address of The Graph's Arbitrator
   */
  function arbitrator() external view returns (address __arbitrator);

  /**
   * @notice Returns the address of The Graph's Council
   * @return __council The address of The Graph's Council
   */
  function council() external view returns (address __council);

  /**
   * @notice Returns the address of the pending The Graph's Council
   * @return __pendingCouncil The address of the pending The Graph's Council
   */
  function pendingCouncil() external view returns (address __pendingCouncil);

  /**
   * @notice Checks that the caller is The Graph's Arbitrator
   */
  function isArbitrator(address _caller) external view;

  /*///////////////////////////////////////////////////////////////
                              LOGIC
  //////////////////////////////////////////////////////////////*/

  /**
   * @notice Changes the address of The Graph's Arbitrator
   * @dev Callable only by The Graph's Council
   * @param _arbitrator The address of The Graph's Arbitrator
   */
  function setArbitrator(address _arbitrator) external;

  /**
   * @notice Sets the address of the pending The Graph's Council
   * @dev Callable only by The Graph's Council
   * @param _pendingCouncil The address of the pending The Graph's Council
   */
  function setPendingCouncil(address _pendingCouncil) external;

  /**
   * @notice Changes the address of The Graph's Council to the pending one
   * @dev Callable only by the pending The Graph's Council
   */
  function confirmCouncil() external;
}
