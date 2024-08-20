// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.26;

import {IHorizonStaking} from './external/IHorizonStaking.sol';

interface IHorizonAccountingExtension {
  /*///////////////////////////////////////////////////////////////
                              EVENTS
  //////////////////////////////////////////////////////////////*/

  /**
   * @notice Emitted when a user bonds tokens
   */
  event Bonded(address indexed _user, uint256 _amount);

  /**
   * @notice Emitted when a user finalizes bonded tokens
   */
  event Finalized(address indexed _user, uint256 _amount);

  /*///////////////////////////////////////////////////////////////
                              ERRORS
  //////////////////////////////////////////////////////////////*/

  /**
   * @notice Thrown when the thawing period is invalid
   */
  error HorizonAccountingExtension_InvalidThawingPeriod();

  /**
   * @notice Thrown when the user has insufficient tokens
   */
  error HorizonAccountingExtension_InsufficientTokens();

  /**
   * @notice Thrown when the user has insufficient bonded tokens
   */
  error HorizonAccountingExtension_InsufficientBondedTokens();

  /*///////////////////////////////////////////////////////////////
                              VARIABLES
  //////////////////////////////////////////////////////////////*/

  /**
   * @notice The minimum thawing period
   * @return _MIN_THAWING_PERIOD The minimum thawing period
   */
  function MIN_THAWING_PERIOD() external view returns (uint256 _MIN_THAWING_PERIOD);

  /**
   * @notice The Horizon Staking contract
   * @return _horizonStaking The Horizon Staking contract
   */
  function horizonStaking() external view returns (IHorizonStaking _horizonStaking);

  /**
   * @notice The Prophet contract
   * @return _prophet The Prophet contract
   */
  function prophet() external view returns (address _prophet);

  /**
   * @notice The total bonded tokens for a user
   * @param _user The user address
   * @return _totalBonded The total bonded tokens for a user
   */
  function totalBonded(address _user) external view returns (uint256 _totalBonded);

  /*///////////////////////////////////////////////////////////////
                              LOGIC
  //////////////////////////////////////////////////////////////*/

  /**
   * @notice Bond tokens to response or dispute
   * @param _bondAmount The amount of tokens to bond
   */
  function bondedAction(uint256 _bondAmount) external;

  /**
   * @notice Finalize bonded tokens
   * @param _bondAmount The amount of tokens to finalize
   */
  function finalize(uint256 _bondAmount) external;
}
