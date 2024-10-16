// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.26;

import {IOracle} from '@defi-wonderland/prophet-core/solidity/interfaces/IOracle.sol';
import {IValidator} from '@defi-wonderland/prophet-core/solidity/interfaces/IValidator.sol';
import {IBondEscalationModule} from
  '@defi-wonderland/prophet-modules/solidity/interfaces/modules/dispute/IBondEscalationModule.sol';
import {IERC20} from '@openzeppelin/contracts/token/ERC20/IERC20.sol';
import {IHorizonStaking} from 'interfaces/external/IHorizonStaking.sol';

import {IArbitrable} from 'interfaces/IArbitrable.sol';

interface IHorizonAccountingExtension is IValidator {
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

  /**
   * @notice Emitted when max users to check is set
   *
   * @param _maxUsersToCheck   The new value of max users to check
   */
  event MaxUsersToCheckSet(uint256 _maxUsersToCheck);

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

  /**
   * @notice Thrown when the max verifier cut is invalid
   */
  error HorizonAccountingExtension_InvalidMaxVerifierCut();

  /**
   * @notice Thrown when caller is not authorized
   */
  error HorizonAccountingExtension_UnauthorizedCaller();

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
   * @notice The Arbitrable contract
   * @return _arbitrable The Arbitrable contract
   */
  function ARBITRABLE() external view returns (IArbitrable _arbitrable);

  /**
   * @notice The minimum thawing period
   * @return _MIN_THAWING_PERIOD The minimum thawing period
   */
  function MIN_THAWING_PERIOD() external view returns (uint64 _MIN_THAWING_PERIOD);

  /**
   * @notice The maximum verifier cut
   * @return _MAX_VERIFIER_CUT The maximum verifier cut
   */
  function MAX_VERIFIER_CUT() external view returns (uint32 _MAX_VERIFIER_CUT);

  /**
   * @notice The max number of users to slash
   * @return _MAX_USERS_TO_SLASH The number of users to slash
   */
  function MAX_USERS_TO_SLASH() external view returns (uint32 _MAX_USERS_TO_SLASH);

  /**
   * @notice The maximum users to check
   * @return _maxUsersToCheck The maximum users to check
   */
  function maxUsersToCheck() external view returns (uint128 _maxUsersToCheck);

  /**
   * @notice The total bonded tokens for a user
   * @param _user The user address
   * @return _totalBonded The total bonded tokens for a user
   */
  function totalBonded(address _user) external view returns (uint256 _totalBonded);

  /**
   * @notice The bound amount of tokens for a user in a request
   * @param _user The user address
   * @param _requestId The ID of the request
   * @return _amount The amount of tokens bonded
   */
  function bondedForRequest(address _user, bytes32 _requestId) external view returns (uint256 _amount);

  /**
   * @notice The total pledged tokens for a user
   * @param _disputeId The ID of the dispute
   * @return _amount The total pledged tokens for a user
   */
  function pledges(bytes32 _disputeId) external view returns (uint256 _amount);

  /**
   * @notice The escalation result of a dispute
   * @param _disputeId The ID of the dispute
   * @return _requestId The ID of the request
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
   * @notice The escalation result of a dispute
   * @param _disputeId The ID of the dispute
   * @return _escalationResult The escalation result
   */
  function getEscalationResult(bytes32 _disputeId) external view returns (EscalationResult memory _escalationResult);

  /**
   * @notice The claim status of a user for a pledge
   * @param _requestId The ID of the request
   * @param _pledger The user address
   * @return _claimed True if the user claimed their pledge
   */
  function pledgerClaimed(bytes32 _requestId, address _pledger) external view returns (bool _claimed);

  /**
   * @notice Checks whether an address is an authorized caller
   *
   * @param _caller      The address to check
   * @return _authorized True if the address is authorized, false otherwise
   */
  function authorizedCallers(address _caller) external returns (bool _authorized);

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
   * @notice Pledges the given amount of token to the provided dispute ID of the provided request ID
   * @param _pledger Address of the pledger
   * @param _request The bond-escalated request
   * @param _dispute The bond-escalated dispute
   * @param _token Address of the token being paid as a reward for winning the bond escalation
   * @param _amount Amount of GRT to pledge
   */
  function pledge(
    address _pledger,
    IOracle.Request calldata _request,
    IOracle.Dispute calldata _dispute,
    IERC20 _token,
    uint256 _amount
  ) external;

  /**
   *
   * @notice Updates the accounting of the given dispute to reflect the result of the bond escalation
   * @param _request The bond-escalated request
   * @param _dispute The bond-escalated dispute
   * @param _token Address of the token being paid as a reward for winning the bond escalation
   * @param _amountPerPledger Amount of GRT to be rewarded to each of the winning pledgers
   * @param _winningPledgersLength Amount of pledges that won the dispute
   */
  function onSettleBondEscalation(
    IOracle.Request calldata _request,
    IOracle.Dispute calldata _dispute,
    IERC20 _token,
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
   * @param _requestId The ID of the request handling the user's tokens
   * @param _payer The address of the user paying the tokens
   * @param _receiver The address of the user receiving the tokens
   * @param _token The address of the token being transferred
   * @param _amount The amount of GRT being transferred
   */
  function pay(bytes32 _requestId, address _payer, address _receiver, IERC20 _token, uint256 _amount) external;

  /**
   * @notice Allows an allowed module to bond a user's tokens for a request
   * @param _bonder The address of the user to bond tokens for
   * @param _requestId The ID of the request the user is bonding for
   * @param _token The address of the token being bonded
   * @param _amount The amount of GRT to bond
   */
  function bond(address _bonder, bytes32 _requestId, IERC20 _token, uint256 _amount) external;

  /**
   * @notice Allows a valid module to bond a user's tokens for a request
   * @param _bonder The address of the user to bond tokens for
   * @param _requestId The ID of the request the user is bonding for
   * @param _token The address of the token being bonded
   * @param _amount The amount of GRT to bond
   * @param _sender The address starting the propose call on the Oracle
   */
  function bond(address _bonder, bytes32 _requestId, IERC20 _token, uint256 _amount, address _sender) external;

  /**
   * @notice Allows a valid module to release a user's tokens
   * @param _bonder The address of the user to release tokens for
   * @param _requestId The ID of the request where the tokens were bonded
   * @param _token The address of the token being released
   * @param _amount The amount of GRT to release
   */
  function release(address _bonder, bytes32 _requestId, IERC20 _token, uint256 _amount) external;

  /**
   * @notice Slashes the users that lost the dispute
   * @param _disputeId The ID of the dispute
   * @param _usersToSlash The number of users to slash
   * @param _maxUsersToCheck The number of users to check
   */
  function slash(bytes32 _disputeId, uint256 _usersToSlash, uint256 _maxUsersToCheck) external;

  /**
   * @notice Sets the maximum users to check
   * @param _maxUsersToCheck The new value of max users to check
   */
  function setMaxUsersToCheck(uint128 _maxUsersToCheck) external;
}
