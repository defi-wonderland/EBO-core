// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {IArbitrable} from 'interfaces/IArbitrable.sol';

/**
 * @title Arbitrable
 * @notice Makes a contract subject to arbitration by The Graph
 */
abstract contract Arbitrable is IArbitrable {
  address private _arbitrator;
  address private _council;
  address private _pendingCouncil;

  /**
   * @notice Checks that the caller is The Graph's Arbitrator
   */
  modifier onlyArbitrator() {
    if (msg.sender != _arbitrator) revert Arbitrable_OnlyArbitrator();
    _;
  }

  /**
   * @notice Checks that the caller is The Graph's Council
   */
  modifier onlyCouncil() {
    if (msg.sender != _council) revert Arbitrable_OnlyCouncil();
    _;
  }

  /**
   * @notice Checks that the caller is the pending The Graph's Council
   */
  modifier onlyPendingCouncil() {
    if (msg.sender != _pendingCouncil) revert Arbitrable_OnlyPendingCouncil();
    _;
  }

  /**
   * @notice Constructor
   * @param __arbitrator The address of The Graph's Arbitrator
   * @param __council The address of The Graph's Council
   */
  constructor(address __arbitrator, address __council) {
    _setArbitrator(__arbitrator);
    _setCouncil(__council);
  }

  /// @inheritdoc IArbitrable
  function arbitrator() public view returns (address __arbitrator) {
    __arbitrator = _arbitrator;
  }

  /// @inheritdoc IArbitrable
  function council() public view returns (address __council) {
    __council = _council;
  }

  /// @inheritdoc IArbitrable
  function pendingCouncil() public view returns (address __pendingCouncil) {
    __pendingCouncil = _pendingCouncil;
  }

  /// @inheritdoc IArbitrable
  function setArbitrator(address __arbitrator) external onlyCouncil {
    _setArbitrator(__arbitrator);
  }

  /// @inheritdoc IArbitrable
  function setPendingCouncil(address __pendingCouncil) external onlyCouncil {
    _setPendingCouncil(__pendingCouncil);
  }

  /// @inheritdoc IArbitrable
  function confirmCouncil() external onlyPendingCouncil {
    _setCouncil(_pendingCouncil);
    delete _pendingCouncil;
  }

  /**
   * @notice Sets the address of The Graph's Arbitrator
   * @param __arbitrator The address of The Graph's Arbitrator
   */
  function _setArbitrator(address __arbitrator) private {
    _arbitrator = __arbitrator;
    emit SetArbitrator(__arbitrator);
  }

  /**
   * @notice Sets the address of The Graph's Council
   * @param __council The address of The Graph's Council
   */
  function _setCouncil(address __council) private {
    _council = __council;
    emit SetCouncil(__council);
  }

  /**
   * @notice Sets the address of the pending The Graph's Council
   * @param __pendingCouncil The address of the pending The Graph's Council
   */
  function _setPendingCouncil(address __pendingCouncil) private {
    _pendingCouncil = __pendingCouncil;
    emit SetPendingCouncil(__pendingCouncil);
  }
}
