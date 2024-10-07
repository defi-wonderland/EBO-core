// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.26;

import {SafeERC20} from '@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol';
import {EnumerableSet} from '@openzeppelin/contracts/utils/structs/EnumerableSet.sol';

import {
  IBondEscalationModule,
  IERC20,
  IHorizonAccountingExtension,
  IHorizonStaking,
  IOracle
} from 'interfaces/IHorizonAccountingExtension.sol';

import {Validator} from '@defi-wonderland/prophet-core/solidity/contracts/Validator.sol';

contract HorizonAccountingExtension is Validator, IHorizonAccountingExtension {
  using EnumerableSet for EnumerableSet.AddressSet;
  using SafeERC20 for IERC20;

  /// @inheritdoc IHorizonAccountingExtension
  IHorizonStaking public immutable HORIZON_STAKING;

  /// @inheritdoc IHorizonAccountingExtension
  IERC20 public immutable GRT;

  /// @inheritdoc IHorizonAccountingExtension
  uint64 public immutable MIN_THAWING_PERIOD;

  /// @inheritdoc IHorizonAccountingExtension
  uint32 public constant MAX_VERIFIER_CUT = 1_000_000;

  // TODO: Validate what the correct magic numbers should be
  uint256 public constant MAX_SLASHING_USERS = 4;

  // TODO: Validate what the correct magic numbers should be
  uint256 public constant MAX_USERS_TO_CHECK = 10;

  /// @inheritdoc IHorizonAccountingExtension
  mapping(address _user => uint256 _bonded) public totalBonded;

  /// @inheritdoc IHorizonAccountingExtension
  mapping(address _bonder => mapping(bytes32 _requestId => uint256 _amount)) public bondedForRequest;

  /// @inheritdoc IHorizonAccountingExtension
  mapping(bytes32 _disputeId => uint256 _amount) public pledges;

  /// @inheritdoc IHorizonAccountingExtension
  mapping(bytes32 _disputeId => EscalationResult _result) public escalationResults;

  /// @inheritdoc IHorizonAccountingExtension
  mapping(bytes32 _requestId => mapping(address _pledger => bool _claimed)) public pledgerClaimed;

  /// @inheritdoc IHorizonAccountingExtension
  mapping(address _caller => bool _authorized) public authorizedCallers;

  /**
   * @notice Storing which modules have the users approved to bond their tokens.
   */
  mapping(address _bonder => EnumerableSet.AddressSet _modules) internal _approvals;

  /**
   * @notice Storing the users that have pledged for a dispute.
   */
  mapping(bytes32 _disputeId => EnumerableSet.AddressSet _pledger) internal _pledgers;

  /**
   * @notice Constructor
   * @param _horizonStaking The address of the Oracle
   * @param _oracle The address of the Oracle
   * @param _grt The address of the GRT token
   * @param _minThawingPeriod The minimum thawing period for the staking
   */
  constructor(
    IHorizonStaking _horizonStaking,
    IOracle _oracle,
    IERC20 _grt,
    uint64 _minThawingPeriod,
    address[] memory _authorizedCallers
  ) Validator(_oracle) {
    HORIZON_STAKING = _horizonStaking;
    GRT = _grt;
    MIN_THAWING_PERIOD = _minThawingPeriod;

    // Set the authorized callers
    for (uint256 _i; _i < _authorizedCallers.length; ++_i) {
      authorizedCallers[_authorizedCallers[_i]] = true;
    }
  }

  /**
   * @notice Checks that the caller is an authorized caller.
   */
  modifier onlyAuthorizedCaller() {
    if (!authorizedCallers[msg.sender]) revert HorizonAccountingExtension_UnauthorizedCaller();
    _;
  }

  /**
   * @notice Checks that the caller is an allowed module used in the request.
   * @param _requestId The request ID.
   */
  modifier onlyAllowedModule(bytes32 _requestId) {
    if (!ORACLE.allowedModule(_requestId, msg.sender)) revert HorizonAccountingExtension_UnauthorizedModule();
    _;
  }

  /**
   * @notice Checks if the user is either the requester or a proposer, or a disputer.
   * @param _requestId The request ID.
   * @param _user The address to check.
   */
  modifier onlyParticipant(bytes32 _requestId, address _user) {
    if (!ORACLE.isParticipant(_requestId, _user)) revert HorizonAccountingExtension_UnauthorizedUser();
    _;
  }

  /// @inheritdoc IHorizonAccountingExtension
  function approveModule(address _module) external {
    _approvals[msg.sender].add(_module);
  }

  /// @inheritdoc IHorizonAccountingExtension
  function revokeModule(address _module) external {
    _approvals[msg.sender].remove(_module);
  }

  /// @inheritdoc IHorizonAccountingExtension
  function pledge(
    address _pledger,
    IOracle.Request calldata _request,
    IOracle.Dispute calldata _dispute,
    IERC20, /* _token */
    uint256 _amount
  ) external onlyAuthorizedCaller {
    bytes32 _requestId = _getId(_request);
    bytes32 _disputeId = _validateDispute(_request, _dispute);

    if (!ORACLE.allowedModule(_requestId, msg.sender)) revert HorizonAccountingExtension_UnauthorizedModule();

    pledges[_disputeId] += _amount;

    _pledgers[_disputeId].add(_pledger);

    _bond(_pledger, _amount);

    emit Pledged({_pledger: _pledger, _requestId: _requestId, _disputeId: _disputeId, _amount: _amount});
  }

  /// @inheritdoc IHorizonAccountingExtension
  function onSettleBondEscalation(
    IOracle.Request calldata _request,
    IOracle.Dispute calldata _dispute,
    IERC20, /* _token */
    uint256 _amountPerPledger,
    uint256 _winningPledgersLength
  ) external onlyAuthorizedCaller {
    bytes32 _requestId = _getId(_request);
    bytes32 _disputeId = _validateDispute(_request, _dispute);

    if (!ORACLE.allowedModule(_requestId, msg.sender)) revert HorizonAccountingExtension_UnauthorizedModule();

    if (_amountPerPledger * _winningPledgersLength > pledges[_disputeId]) {
      revert HorizonAccountingExtension_InsufficientFunds();
    }

    if (escalationResults[_disputeId].requestId != bytes32(0)) {
      revert HorizonAccountingExtension_AlreadySettled();
    }

    IBondEscalationModule _bondEscalationModule = IBondEscalationModule(msg.sender);

    escalationResults[_disputeId] = EscalationResult({
      requestId: _requestId,
      amountPerPledger: _amountPerPledger,
      bondSize: _bondEscalationModule.decodeRequestData(_request.disputeModuleData).bondSize,
      bondEscalationModule: _bondEscalationModule
    });

    // TODO: The amount of money to be distributed needs to be slashed.
    // The problem is that there could be multiple users to slash and we can't do it fully
    // in this function.

    emit BondEscalationSettled({
      _requestId: _requestId,
      _disputeId: _disputeId,
      _amountPerPledger: _amountPerPledger,
      _winningPledgersLength: _winningPledgersLength
    });
  }

  /// @inheritdoc IHorizonAccountingExtension
  function claimEscalationReward(bytes32 _disputeId, address _pledger) external {
    EscalationResult memory _result = escalationResults[_disputeId];
    if (_result.requestId == bytes32(0)) revert HorizonAccountingExtension_NoEscalationResult();
    bytes32 _requestId = _result.requestId;
    if (pledgerClaimed[_requestId][_pledger]) revert HorizonAccountingExtension_AlreadyClaimed();

    IOracle.DisputeStatus _status = ORACLE.disputeStatus(_disputeId);
    uint256 _amountPerPledger = _result.amountPerPledger;
    uint256 _numberOfPledges;
    uint256 _pledgeAmount;
    uint256 _claimAmount;
    uint256 _rewardAmount;

    if (_status == IOracle.DisputeStatus.NoResolution) {
      _numberOfPledges = _result.bondEscalationModule.pledgesForDispute(_requestId, _pledger)
        + _result.bondEscalationModule.pledgesAgainstDispute(_requestId, _pledger);

      // If no resolution, pledge amount and claim amount are the same
      _pledgeAmount = _result.bondSize * _numberOfPledges;
      _claimAmount = _amountPerPledger * _numberOfPledges;
    } else {
      _numberOfPledges = _status == IOracle.DisputeStatus.Won
        ? _result.bondEscalationModule.pledgesForDispute(_requestId, _pledger)
        : _result.bondEscalationModule.pledgesAgainstDispute(_requestId, _pledger);

      _pledgeAmount = _result.bondSize * _numberOfPledges;
      _claimAmount = _amountPerPledger * _numberOfPledges;
      _rewardAmount = _claimAmount - _pledgeAmount;

      // Check the balance in the contract
      // If not enough balance, slash some users to get enough balance
      uint256 _balance = GRT.balanceOf(address(this)); // TODO: What if the balance is enough by means other than slashing?

      // TODO: How many iterations should we do?
      while (_balance < _rewardAmount) {
        _balance += _slash(_disputeId, 1, MAX_USERS_TO_CHECK, _result, _status);
      }

      // Send the user the amount they won by participating in the dispute
      GRT.safeTransfer(_pledger, _rewardAmount);
    }

    // Release the winning pledges to the user
    _unbond(_pledger, _pledgeAmount);

    pledgerClaimed[_requestId][_pledger] = true;

    pledges[_disputeId] -= _claimAmount;

    // TODO: Delete _pledgers[_disputeId] if pledges[_disputeId] == 0

    emit EscalationRewardClaimed({
      _requestId: _requestId,
      _disputeId: _disputeId,
      _pledger: _pledger,
      _reward: _rewardAmount,
      _released: _pledgeAmount
    });
  }

  // TODO: Remove?
  /// @inheritdoc IHorizonAccountingExtension
  function releasePledge(
    IOracle.Request calldata _request,
    IOracle.Dispute calldata _dispute,
    address _pledger,
    IERC20, /* _token */
    uint256 _amount
  ) external onlyAuthorizedCaller {
    bytes32 _requestId = _getId(_request);
    bytes32 _disputeId = _validateDispute(_request, _dispute);

    if (!ORACLE.allowedModule(_requestId, msg.sender)) revert HorizonAccountingExtension_UnauthorizedModule();

    if (_amount > pledges[_disputeId]) revert HorizonAccountingExtension_InsufficientFunds();

    unchecked {
      pledges[_disputeId] -= _amount;
    }

    // TODO: _pledgers[_disputeId].remove(_pledger);

    _unbond(_pledger, _amount);

    emit PledgeReleased({_requestId: _requestId, _disputeId: _disputeId, _pledger: _pledger, _amount: _amount});
  }

  /// @inheritdoc IHorizonAccountingExtension
  function pay(
    bytes32 _requestId,
    address _payer,
    address _receiver,
    IERC20, /* _token */
    uint256 _amount
  ) external onlyAllowedModule(_requestId) onlyParticipant(_requestId, _payer) onlyParticipant(_requestId, _receiver) {
    // Discount the payer bondedForRequest
    bondedForRequest[_payer][_requestId] -= _amount;

    // Discout the payer totalBonded
    _unbond(_payer, _amount);

    // Slash a payer to pay the receiver
    // TODO: Check if will provision that amount or we will send it directly
    HORIZON_STAKING.slash(_payer, _amount, _amount, _receiver);

    emit Paid({_requestId: _requestId, _beneficiary: _receiver, _payer: _payer, _amount: _amount});
  }

  /// @inheritdoc IHorizonAccountingExtension
  function bond(
    address _bonder,
    bytes32 _requestId,
    IERC20, /* _token */
    uint256 _amount
  ) external onlyAllowedModule(_requestId) onlyParticipant(_requestId, _bonder) {
    if (!_approvals[_bonder].contains(msg.sender)) revert HorizonAccountingExtension_NotAllowed();

    bondedForRequest[_bonder][_requestId] += _amount;

    _bond(_bonder, _amount);

    emit Bonded(_requestId, _bonder, _amount);
  }

  /// @inheritdoc IHorizonAccountingExtension
  function bond(
    address _bonder,
    bytes32 _requestId,
    IERC20, /* _token */
    uint256 _amount,
    address _sender
  ) external onlyAllowedModule(_requestId) onlyParticipant(_requestId, _bonder) {
    bool _moduleApproved = _approvals[_bonder].contains(msg.sender);
    bool _senderApproved = _approvals[_bonder].contains(_sender);

    if (!(_moduleApproved && _senderApproved)) {
      revert HorizonAccountingExtension_NotAllowed();
    }

    bondedForRequest[_bonder][_requestId] += _amount;

    _bond(_bonder, _amount);

    emit Bonded(_requestId, _bonder, _amount);
  }

  /// @inheritdoc IHorizonAccountingExtension
  function release(
    address _bonder,
    bytes32 _requestId,
    IERC20, /* _token */
    uint256 _amount
  ) external onlyAllowedModule(_requestId) onlyParticipant(_requestId, _bonder) {
    // TODO: Release is used to pay the user the rewards for proposing or returning the funds to the
    // creator in case the request finalized without a response. We need to finish designing the payments
    // integration to do this.

    // TODO: Release is also used in the bond escalation module to:
    // 1) return the funds to the disputer in case there is no resolution
    // 2) release the initial dispute bond if the disputer wins

    // Release the bond amount for the request for the user
    bondedForRequest[_bonder][_requestId] -= _amount;

    _unbond(_bonder, _amount);

    emit Released(_requestId, _bonder, _amount);
  }

  function slash(bytes32 _disputeId, uint256 _usersToSlash, uint256 _maxUsersToCheck) external {
    EscalationResult memory _result = escalationResults[_disputeId];

    if (_result.requestId == bytes32(0)) revert HorizonAccountingExtension_NoEscalationResult();

    IOracle.DisputeStatus _status = ORACLE.disputeStatus(_disputeId);

    _slash(_disputeId, _usersToSlash, _maxUsersToCheck, _result, _status);
  }

  /// @inheritdoc IHorizonAccountingExtension
  function getEscalationResult(bytes32 _disputeId) external view returns (EscalationResult memory _escalationResult) {
    _escalationResult = escalationResults[_disputeId];
  }

  /// @inheritdoc IHorizonAccountingExtension
  function approvedModules(address _user) external view returns (address[] memory _approvedModules) {
    _approvedModules = _approvals[_user].values();
  }

  // TODO: Remove if unwanted
  /// @inheritdoc IHorizonAccountingExtension
  function getPledgers(bytes32 _disputeId) external view returns (address[] memory __pledgers) {
    __pledgers = _pledgers[_disputeId].values();
  }

  /**
   * @notice Slash the users that have pledged for a dispute.
   * @param _disputeId The dispute id.
   * @param _usersToSlash The number of users to slash.
   * @param _maxUsersToCheck The maximum number of users to check.
   * @param _result The escalation result.
   * @param _status The dispute status.
   */
  function _slash(
    bytes32 _disputeId,
    uint256 _usersToSlash,
    uint256 _maxUsersToCheck,
    EscalationResult memory _result,
    IOracle.DisputeStatus _status
  ) internal returns (uint256 _slashedAmount) {
    EnumerableSet.AddressSet storage _users = _pledgers[_disputeId];

    uint256 _slashedUsers;
    address _user;
    uint256 _slashAmount;

    uint256 _length = _users.length();

    _maxUsersToCheck = _maxUsersToCheck > _length ? _length : _maxUsersToCheck;

    for (uint256 _i; _i < _maxUsersToCheck && _slashedUsers < _usersToSlash; ++_i) {
      _user = _users.at(0);

      // Check if the user is actually slashable
      _slashAmount = _calculateSlashAmount(_user, _result, _status);
      if (_slashAmount > 0) {
        // Slash the user
        HORIZON_STAKING.slash(_user, _slashAmount, _slashAmount, address(this));
        // TODO: What if `MIN_THAWING_PERIOD` has passed, all provision tokens have been thawed
        //       and slashing is skipped or reverts (bricking `claimEscalationReward()`)?

        _unbond(_user, _slashAmount);

        _slashedAmount += _slashAmount;

        ++_slashedUsers;
      }

      // Remove the user from the list of users
      _users.remove(_user);
    }
  }

  /**
   * @notice Calculate the amount to slash for a user.
   * @param _pledger The address of the user.
   * @param _result The escalation result.
   * @param _status The dispute status.
   */
  function _calculateSlashAmount(
    address _pledger,
    EscalationResult memory _result,
    IOracle.DisputeStatus _status
  ) internal view returns (uint256 _slashAmount) {
    bytes32 _requestId = _result.requestId;

    uint256 _numberOfPledges;

    // If Won slash the against pledges, if Lost slash the for pledges
    if (_status != IOracle.DisputeStatus.NoResolution) {
      _numberOfPledges = _status == IOracle.DisputeStatus.Won
        ? _result.bondEscalationModule.pledgesAgainstDispute(_requestId, _pledger)
        : _result.bondEscalationModule.pledgesForDispute(_requestId, _pledger);
    }

    _slashAmount = _result.bondSize * _numberOfPledges;
  }

  /**
   * @notice Bonds the tokens of the user.
   * @param _bonder The address of the user.
   * @param _amount The amount of tokens to bond.
   */
  function _bond(address _bonder, uint256 _amount) internal {
    IHorizonStaking.Provision memory _provisionData = HORIZON_STAKING.getProvision(_bonder, address(this));

    if (_provisionData.maxVerifierCut != MAX_VERIFIER_CUT) revert HorizonAccountingExtension_InvalidMaxVerifierCut();
    if (_provisionData.thawingPeriod < MIN_THAWING_PERIOD) revert HorizonAccountingExtension_InvalidThawingPeriod();
    if (_amount > _provisionData.tokens) revert HorizonAccountingExtension_InsufficientTokens();
    // TODO: `thaw()` does not subtract from provision `tokens` but adds to `tokensThawing`

    totalBonded[_bonder] += _amount;

    if (totalBonded[_bonder] > _provisionData.tokens + _provisionData.tokensThawing) {
      revert HorizonAccountingExtension_InsufficientBondedTokens();
    }
  }

  /**
   * @notice Unbonds the tokens of the user.
   * @param _bonder The address of the user.
   * @param _amount The amount of tokens to unbond.
   */
  function _unbond(address _bonder, uint256 _amount) internal {
    if (_amount > totalBonded[_bonder]) revert HorizonAccountingExtension_InsufficientBondedTokens();
    totalBonded[_bonder] -= _amount;
  }
}
