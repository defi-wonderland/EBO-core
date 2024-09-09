// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.26;

import {IHorizonStaking} from './external/IHorizonStaking.sol';

import {IOracle} from '@defi-wonderland/prophet-core/solidity/interfaces/IOracle.sol';
import {IBondEscalationModule} from
  '@defi-wonderland/prophet-modules/solidity/interfaces/modules/dispute/IBondEscalationModule.sol';
import {IERC20} from '@openzeppelin/contracts/token/ERC20/IERC20.sol';

interface IHorizonAccountingExtension {
  /*///////////////////////////////////////////////////////////////
                              EVENTS
  //////////////////////////////////////////////////////////////*/

  /**
   * @notice A payment between users has been made
   * @param _requestId    The ID of the request
   * @param _beneficiary  The user receiving the tokens
   * @param _payer        The user who is getting its tokens transferred
   * @param _amount       The amount of GRT transferred
   */
  event Paid(bytes32 indexed _requestId, address indexed _beneficiary, address indexed _payer, uint256 _amount);

  /**
   * @notice User's funds have been bonded
   * @param _requestId    The ID of the request
   * @param _bonder       The user who is getting its tokens bonded
   * @param _amount       The amount of GRT bonded
   */
  event Bonded(bytes32 indexed _requestId, address indexed _bonder, uint256 _amount);

  /**
   * @notice User's funds have been released
   * @param _requestId    The ID of the request
   * @param _beneficiary  The user who is getting its tokens released
   * @param _amount       The amount of GRT released
   */
  event Released(bytes32 indexed _requestId, address indexed _beneficiary, uint256 _amount);

  /**
   * @notice A user pledged tokens for one of the sides of a dispute
   *
   * @param _pledger          The user who pledged the tokens
   * @param _requestId        The ID of the bond-escalated request
   * @param _disputeId        The ID of the bond-escalated dispute
   * @param _amount           The amount of GRT pledged by the user
   */
  event Pledged(address indexed _pledger, bytes32 indexed _requestId, bytes32 indexed _disputeId, uint256 _amount);

  /**
   * @notice The pledgers of the winning side of a dispute have been paid
   *
   * @param _requestId        The ID of the bond-escalated request
   * @param _disputeId        The ID of the bond-escalated dispute
   * @param _winningPledgers  The users who got paid for pledging for the winning side
   * @param _amountPerPledger The amount of GRT paid to each of the winning pledgers
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
   * @param _amountPerPledger      The amount of GRT to be paid for each winning pledgers
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
   * @param _amount           The amount of GRT released
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
   * @param _reward           The amount of GRT the user claimed
   * @param _released         The amount of GRT released to the user
   */
  event EscalationRewardClaimed(
    bytes32 indexed _requestId, bytes32 indexed _disputeId, address indexed _pledger, uint256 _reward, uint256 _released
  );

  /*///////////////////////////////////////////////////////////////
                              ERRORS
  //////////////////////////////////////////////////////////////*/

  /**
   * @notice Thrown when the bonder changed in the middle of an open request/dispute
   */
  error HorizonAccountingExtension_BonderMismatch();

  /**
   * @notice Thrown when the caller is not the operator of the service provider
   */
  error HorizonAccountingExtension_UnauthorizedOperator();

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

  /**
   * @notice Thrown when the max verifier cut is invalid
   */
  error HorizonAccountingExtension_InvalidMaxVerifierCut();

  /*///////////////////////////////////////////////////////////////
                              STRUCTS
  //////////////////////////////////////////////////////////////*/

  /**
   * @notice Contains the data of the result of an escalation. Is used by users to claim their pledges
   * @param requestId         The ID of the bond-escalated request
   * @param amountPerPledger  The amount of token paid to each of the winning pledgers
   * @param bondSize             The size of the bond required for bond escalation
   * @param bondEscalationModule The address of the bond escalation module that was used
   */
  struct EscalationResult {
    bytes32 requestId;
    uint256 amountPerPledger;
    uint256 bondSize;
    IBondEscalationModule bondEscalationModule;
  }

  /*///////////////////////////////////////////////////////////////
                              VARIABLES
  //////////////////////////////////////////////////////////////*/

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
   * @notice The minimum thawing period
   * @return _MIN_THAWING_PERIOD The minimum thawing period
   */
  function MIN_THAWING_PERIOD() external view returns (uint256 _MIN_THAWING_PERIOD);

  /**
   * @notice The maximum verifier cut
   * @return _MAX_VERIFIER_CUT The maximum verifier cut
   */
  function MAX_VERIFIER_CUT() external view returns (uint256 _MAX_VERIFIER_CUT);

  /**
   * @notice The total bonded tokens for a user
   * @param _user The user address
   * @return _totalBonded The total bonded tokens for a user
   */
  function totalBonded(address _user) external view returns (uint256 _totalBonded);

  /**
   * @notice The bound amount of tokens for a user in a request
   * @param _user The user address
   * @param _requestId The request Id
   * @return _amount The amount of tokens bonded
   */
  function bondedForRequest(address _user, bytes32 _requestId) external view returns (uint256 _amount);

  /**
   * @notice The total pledged tokens for a user
   * @param _disputeId The dispute Id
   * @return _amount The total pledged tokens for a user
   */
  function pledges(bytes32 _disputeId) external view returns (uint256 _amount);

  /**
   * @notice The escalation result of a request
   * @param _disputeId The dispute Id
   * @return _requestId The request Id
   * @return _amountPerPledger The amount of token paid to each of the winning pledgers
   * @return _bondSize             The size of the bond required for bond escalation
   * @return _bondEscalationModule The address of the bond escalation module that was used
   */
  function escalationResults(bytes32 _disputeId)
    external
    view
    returns (
      bytes32 _requestId,
      uint256 _amountPerPledger,
      uint256 _bondSize,
      IBondEscalationModule _bondEscalationModule
    );

  /**
   * @notice The claim status of a user for a pledge
   * @param _requestId The request Id
   * @param _pledger The user address
   * @return _claimed True if the user claimed their pledge
   */
  function pledgerClaimed(bytes32 _requestId, address _pledger) external view returns (bool _claimed);

  /**
   * @notice Returns the approved modules for bonding tokens
   * @param _user The address of the user
   * @return _approvedModules The approved modules for bonding tokens
   */
  function approvedModules(address _user) external view returns (address[] memory _approvedModules);

  /*///////////////////////////////////////////////////////////////
                              LOGIC
  //////////////////////////////////////////////////////////////*/

  /**
   * @notice Allows a user to approve a module for bonding tokens
   * @param _module The address of the module to be approved
   */
  function approveModule(address _module) external;

  /**
   * @notice Allows a user to revoke a module's approval for bonding tokens
   * @param _module The address of the module to be revoked
   */
  function revokeModule(address _module) external;

  /**
   * @notice Pledges the given amount of token to the provided dispute id of the provided request id
   * @param _pledger Address of the pledger
   * @param _request The bond-escalated request
   * @param _dispute The bond-escalated dispute
   * @param _amount Amount of token to pledge
   */
  function pledge(
    address _pledger,
    IOracle.Request calldata _request,
    IOracle.Dispute calldata _dispute,
    uint256 _amount
  ) external;

  /**
   *
   * @notice Updates the accounting of the given dispute to reflect the result of the bond escalation
   * @param _request The bond-escalated request
   * @param _dispute The bond-escalated dispute
   * @param _amountPerPledger Amount of GRT to be rewarded to each of the winning pledgers
   * @param _winningPledgersLength Amount of pledges that won the dispute
   */
  function onSettleBondEscalation(
    IOracle.Request calldata _request,
    IOracle.Dispute calldata _dispute,
    uint256 _amountPerPledger,
    uint256 _winningPledgersLength
  ) external;

  /**
   * @notice Claims the reward for the pledger the given dispute
   * @param _disputeId The ID of the bond-escalated dispute
   * @param _pledger Address of the pledger to claim the rewards
   */
  function claimEscalationReward(bytes32 _disputeId, address _pledger) external;

  /**
   * @notice Allows a allowed module to transfer bonded tokens from one user to another
   * @param _requestId The id of the request handling the user's tokens
   * @param _payer The address of the user paying the tokens
   * @param _receiver The address of the user receiving the tokens
   * @param _amount The amount of GRT being transferred
   */
  function pay(bytes32 _requestId, address _payer, address _receiver, uint256 _amount) external;

  /**
   * @notice Allows a allowed module to bond a user's tokens for a request
   * @param _bonder The address of the user to bond tokens for
   * @param _requestId The id of the request the user is bonding for
   * @param _amount The amount of GRT to bond
   */
  function bond(address _bonder, bytes32 _requestId, uint256 _amount) external;

  /**
   * @notice Allows a valid module to release a user's tokens
   * @param _bonder The address of the user to release tokens for
   * @param _requestId The id of the request where the tokens were bonded
   * @param _amount The amount of GRT to release
   */
  function release(address _bonder, bytes32 _requestId, uint256 _amount) external;
}
