// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.26;

import {IHorizonStaking} from './external/IHorizonStaking.sol';

import {IBondEscalationModule} from
  '@defi-wonderland/prophet-modules/solidity/interfaces/modules/dispute/IBondEscalationModule.sol';
import {IERC20} from '@openzeppelin/contracts/token/ERC20/IERC20.sol';

interface IHorizonAccountingExtension {
  /*///////////////////////////////////////////////////////////////
                              EVENTS
  //////////////////////////////////////////////////////////////*/

  /**
   * @notice A payment between users has been made
   * @param _requestId The ID of the request
   * @param _beneficiary The user receiving the tokens
   * @param _payer The user who is getting its tokens transferred
   * @param _amount The amount of `_token` transferred
   */
  event Paid(bytes32 indexed _requestId, address indexed _beneficiary, address indexed _payer, uint256 _amount);

  /**
   * @notice User's funds have been bonded
   * @param _requestId The ID of the request
   * @param _bonder The user who is getting its tokens bonded
   * @param _amount The amount of `_token` bonded
   */
  event Bonded(bytes32 indexed _requestId, address indexed _bonder, uint256 _amount);

  /**
   * @notice User's funds have been released
   * @param _requestId The ID of the request
   * @param _beneficiary The user who is getting its tokens released
   * @param _amount The amount of `_token` released
   */
  event Released(bytes32 indexed _requestId, address indexed _beneficiary, uint256 _amount);

  /**
   * @notice A user pledged tokens for one of the sides of a dispute
   *
   * @param _pledger          The user who pledged the tokens
   * @param _requestId        The ID of the bond-escalated request
   * @param _disputeId        The ID of the bond-escalated dispute
   * @param _amount           The amount of `_token` pledged by the user
   */
  event Pledged(address indexed _pledger, bytes32 indexed _requestId, bytes32 indexed _disputeId, uint256 _amount);

  /**
   * @notice The pledgers of the winning side of a dispute have been paid
   *
   * @param _requestId        The ID of the bond-escalated request
   * @param _disputeId        The ID of the bond-escalated dispute
   * @param _winningPledgers  The users who got paid for pledging for the winning side
   * @param _amountPerPledger The amount of `_token` paid to each of the winning pledgers
   */
  event WinningPledgersPaid(
    bytes32 indexed _requestId,
    bytes32 indexed _disputeId,
    address[] indexed _winningPledgers,
    uint256 _amountPerPledger
  );

  /**
   * @notice A bond escalation has been settled
   *
   * @param _requestId             The ID of the bond-escalated request
   * @param _disputeId             The ID of the bond-escalated dispute
   * @param _amountPerPledger      The amount of `_token` to be paid for each winning pledgers
   * @param _winningPledgersLength The number of winning pledgers
   */
  event BondEscalationSettled(
    bytes32 _requestId, bytes32 _disputeId, uint256 _amountPerPledger, uint256 _winningPledgersLength
  );

  /**
   * @notice A pledge has been released back to the user
   *
   * @param _requestId        The ID of the bond-escalated request
   * @param _disputeId        The ID of the bond-escalated dispute
   * @param _pledger          The user who is getting their tokens released
   * @param _amount           The amount of `_token` released
   */
  event PledgeReleased(
    bytes32 indexed _requestId, bytes32 indexed _disputeId, address indexed _pledger, uint256 _amount
  );

  /**
   * @notice A user claimed their reward for pledging for the winning side of a dispute
   *
   * @param _requestId        The ID of the bond-escalated request
   * @param _disputeId        The ID of the bond-escalated dispute
   * @param _pledger          The user who claimed their reward
   * @param _amount           The amount of `_token` paid to the pledger
   */
  event EscalationRewardClaimed(
    bytes32 indexed _requestId, bytes32 indexed _disputeId, address indexed _pledger, uint256 _amount
  );

  /*///////////////////////////////////////////////////////////////
                              ERRORS
  //////////////////////////////////////////////////////////////*/

  /**
   * @notice Thrown when depositing tokens with a fee on transfer
   */
  error HorizonAccountingExtension_FeeOnTransferToken();

  /**
   * @notice Thrown when the module bonding user tokens hasn't been approved by the user.
   */
  error HorizonAccountingExtension_NotAllowed();

  /**
   * @notice Thrown when an `onlyAllowedModule` function is called by something
   * else than a module being used in the corresponding request
   */
  error HorizonAccountingExtension_UnauthorizedModule();

  /**
   * @notice Thrown when an `onlyParticipant` function is called with an address
   * that is not part of the request.
   */
  error HorizonAccountingExtension_UnauthorizedUser();

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

  /**
   * @notice Thrown when the user tries to claim their pledge for an escalation that was already claimed
   */
  error HorizonAccountingExtension_AlreadyClaimed();

  /**
   * @notice Thrown when the user tries to claim their pledge for an escalation that wasn't finished yet
   */
  error HorizonAccountingExtension_NoEscalationResult();

  /**
   * @notice Thrown when the user doesn't have enough funds to pledge
   */
  error HorizonAccountingExtension_InsufficientFunds();

  /**
   * @notice Thrown when trying to settle an already settled escalation
   */
  error HorizonAccountingExtension_AlreadySettled();

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
  function HORIZON_STAKING() external view returns (IHorizonStaking _horizonStaking);

  /**
   * @notice The GRT token
   * @return _GRT The GRT token
   */
  function GRT() external view returns (IERC20 _GRT);

  /**
   * @notice The total bonded tokens for a user
   * @param _user The user address
   * @return _totalBonded The total bonded tokens for a user
   */
  function totalBonded(address _user) external view returns (uint256 _totalBonded);

  /*///////////////////////////////////////////////////////////////
                              LOGIC
  //////////////////////////////////////////////////////////////*/

  /*///////////////////////////////////////////////////////////////
                              STRUCTS
  //////////////////////////////////////////////////////////////*/

  /**
   * @notice Contains the data of the result of an escalation. Is used by users to claim their pledges
   * @param requestId         The ID of the bond-escalated request
   * @param amountPerPledger  The amount of token paid to each of the winning pledgers
   * @param bondEscalationModule The address of the bond escalation module that was used
   */
  struct EscalationResult {
    bytes32 requestId;
    uint256 amountPerPledger;
    IBondEscalationModule bondEscalationModule;
  }
}
