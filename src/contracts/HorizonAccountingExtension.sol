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

import 'forge-std/console.sol';

contract HorizonAccountingExtension is Validator, IHorizonAccountingExtension {
  using EnumerableSet for EnumerableSet.AddressSet;
  using SafeERC20 for IERC20;

  /// @inheritdoc IHorizonAccountingExtension
  IHorizonStaking public immutable HORIZON_STAKING;

  /// @inheritdoc IHorizonAccountingExtension
  IERC20 public immutable GRT;

  /// @inheritdoc IHorizonAccountingExtension
  uint256 public immutable MIN_THAWING_PERIOD;

  /// @inheritdoc IHorizonAccountingExtension
  uint256 public immutable MAX_VERIFIER_CUT;

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

  /**
   * @notice Storing which modules have the users approved to bond their tokens.
   */
  mapping(address _bonder => EnumerableSet.AddressSet _modules) internal _approvals;

  /**
   * @notice Storing the users that have pledged for a dispute.
   */
  // TODO: Pledgers holds either the bonder or the operator.
  mapping(bytes32 _disputeId => EnumerableSet.AddressSet _pledger) internal _pledgers;
  
  // Operator sets who they operatate for. 
  // We check that they can operate on the bonder by calling horzionStaking.isAuthorized
  // RULES:
  // [X] 1. Operator can only operate for one bonder at a time 
  // [X] 2. Operator can only operate for bonder if it's still authorized by that bonder 
  // [X] 3. Operator can't be changed in the middle of a dispute for pledges
  // [X] 4. Operator can't be changed in the middle of a request for bonds
  // [ ] 5. Bonder or operator should be able to remove the operator
  // [ ] 6. Can a bonder have an operator and mix calls by the operator and themselves in the same disputeId?
  //          The end result would be that both the operator and the bonder need to call the claim function if they win
  //          or they both need to be slashed in separate calls if they lose.
  // [ ] 7. Can a bonder that has an operator be an operator for another address?
  mapping(address _operator => address _bonder) public operators;

  mapping(bytes32 _requestId => mapping(address _caller => address _bonder)) public bonderForRequest;

  mapping(bytes32 _disputeId => mapping(address _caller => address _bonder)) public bonderForDispute;

  /**
   * @notice Constructor
   * @param _horizonStaking The address of the Oracle
   * @param _oracle The address of the Oracle
   * @param _grt The address of the GRT token
   * @param _minThawingPeriod The minimum thawing period for the staking
   * @param _maxVerifierCut The maximum verifier cut
   */
  constructor(
    IHorizonStaking _horizonStaking,
    IOracle _oracle,
    IERC20 _grt,
    uint256 _minThawingPeriod,
    uint256 _maxVerifierCut
  ) Validator(_oracle) {
    HORIZON_STAKING = _horizonStaking;
    GRT = _grt;
    MIN_THAWING_PERIOD = _minThawingPeriod;
    MAX_VERIFIER_CUT = _maxVerifierCut;
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
  function approvedModules(address _user) external view returns (address[] memory _approvedModules) {
    _approvedModules = _approvals[_user].values();
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
    uint256 _amount
  ) external {
    bytes32 _requestId = _getId(_request);
    bytes32 _disputeId = _validateDispute(_request, _dispute);

    if (!ORACLE.allowedModule(_requestId, msg.sender)) revert HorizonAccountingExtension_UnauthorizedModule();
    
    // Translate pledger to bonder if operator is set
    address _bonder = _getBonder(_pledger);

    _bondForDispute(_disputeId, _pledger, _bonder);

    pledges[_disputeId] += _amount;

    _pledgers[_disputeId].add(_pledger);

    _bond(_bonder, _amount);

    emit Pledged({_pledger: _bonder, _requestId: _requestId, _disputeId: _disputeId, _amount: _amount});
  }

  /// @inheritdoc IHorizonAccountingExtension
  function onSettleBondEscalation(
    IOracle.Request calldata _request,
    IOracle.Dispute calldata _dispute,
    uint256 _amountPerPledger,
    uint256 _winningPledgersLength
  ) external {
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
      bondSize: _bondEscalationModule.decodeRequestData(_request.requestModuleData).bondSize,
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

    // TODO: To calculate the amount of pledges, we need to check for both 
    //       the bonder and the operator. How should we do this?

    address _bonder = bonderForDispute[_disputeId][_pledger];

    if (_status == IOracle.DisputeStatus.NoResolution) {
      _numberOfPledges = _result.bondEscalationModule.pledgesForDispute(_requestId, _pledger)
        + _result.bondEscalationModule.pledgesAgainstDispute(_requestId, _pledger);

      _pledgeAmount = _result.bondSize * _numberOfPledges;
      _claimAmount = _amountPerPledger * _numberOfPledges;

      _unbond(_bonder, _pledgeAmount);
    } else {
      _numberOfPledges = _status == IOracle.DisputeStatus.Won
        ? _result.bondEscalationModule.pledgesForDispute(_requestId, _pledger)
        : _result.bondEscalationModule.pledgesAgainstDispute(_requestId, _pledger);

      // Release the winning pledges to the user
      _pledgeAmount = _result.bondSize * _numberOfPledges;
      _unbond(_bonder, _pledgeAmount);

      _claimAmount = _amountPerPledger * _numberOfPledges;

      // Check the balance in the contract
      // If not enough balance, slash some users to get enough balance
      uint256 _balance = GRT.balanceOf(address(this));

      // TODO: How many iterations should we do?
      while (_balance < _claimAmount) {
        _balance += _slash(_disputeId, 1, MAX_USERS_TO_CHECK, _result, _status);
      }

      _rewardAmount = _claimAmount - _pledgeAmount;

      // Send the user the amount they won by participating in the dispute
      GRT.safeTransfer(_bonder, _rewardAmount);
    }

    pledgerClaimed[_requestId][_pledger] = true;

    pledges[_disputeId] -= _claimAmount;

    emit EscalationRewardClaimed({
      _requestId: _requestId,
      _disputeId: _disputeId,
      _pledger: _pledger,
      _reward: _rewardAmount,
      _released: _pledgeAmount
    });
  }

  /// @inheritdoc IHorizonAccountingExtension
  function pay(
    bytes32 _requestId,
    address _payer,
    address _receiver,
    uint256 _amount
  ) external onlyAllowedModule(_requestId) onlyParticipant(_requestId, _payer) onlyParticipant(_requestId, _receiver) {
    // TODO: Validate participants against bonders
    address _bonderPayer = bonderForRequest[_requestId][_payer];
    address _bonderReceiver = bonderForRequest[_requestId][_receiver];

    // Discount the payer bondedForRequest
    bondedForRequest[_bonderPayer][_requestId] -= _amount;

    // Discout the payer totalBonded
    totalBonded[_bonderPayer] -= _amount;

    // Increase the receiver bond
    HORIZON_STAKING.slash(_bonderPayer, _amount, _amount, _bonderReceiver);

    emit Paid({_requestId: _requestId, _beneficiary: _bonderReceiver, _payer: _bonderPayer, _amount: _amount});
  }

  /// @inheritdoc IHorizonAccountingExtension
  function bond(
    address _caller,
    bytes32 _requestId,
    uint256 _amount
  ) external onlyAllowedModule(_requestId) onlyParticipant(_requestId, _caller) {
    // TODO: The onlyParticipant should be called with the _bonder. Not the caller
    address _bonder = _getBonder(_caller);

    _bondForRequest(_requestId, _caller, _bonder);

    if (!_approvals[_bonder].contains(msg.sender)) revert HorizonAccountingExtension_NotAllowed();

    bondedForRequest[_bonder][_requestId] += _amount;

    _bond(_bonder, _amount);

    emit Bonded(_requestId, _bonder, _amount);
  }

  function bond(
    address _caller,
    bytes32 _requestId,
    uint256 _amount,
    address _sender
  ) external onlyAllowedModule(_requestId) onlyParticipant(_requestId, _caller) {
    // TODO: The onlyParticipant should be called with the _bonder. Not the caller
    address _bonder = _getBonder(_caller);

    _bondForRequest(_requestId, _caller, _bonder);

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
    address _caller,
    bytes32 _requestId,
    uint256 _amount
  ) external onlyAllowedModule(_requestId) onlyParticipant(_requestId, _caller) {
    // TODO: Release is used to pay the user the rewards for proposing or returning the funds to the
    // creator in case the request finalized without a response. We need to finish designing the payments
    // integration to do this.

    // TODO: Release is also used in the bond escalation module to:
    // 1) return the funds to the disputer in case there is no resolution
    // 2) release the initial dispute bond if the disputer wins

    // TODO: The onlyParticipant should be called with the _bonder. Not the caller
    address _bonder = bonderForRequest[_requestId][_caller];

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

  function operateFor(address _bonder) external {
    // TODO: Include a function to remove the operator callable by the operator or the bonder
    if(!HORIZON_STAKING.isAuthorized(msg.sender, _bonder, address(this))) {
      revert HorizonAccountingExtension_UnauthorizedOperator();
    }
    operators[msg.sender] = _bonder;
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
    // The _pledger is the user that has the actual pledges
    address _pledger;
    uint256 _slashAmount;

    _maxUsersToCheck = _maxUsersToCheck > _users.length() ? _users.length() : _maxUsersToCheck;

    for (uint256 _i; _i < _maxUsersToCheck && _slashedUsers < _usersToSlash; _i++) {
      _pledger = _users.at(0);

      // Check if the user is actually slashable
      _slashAmount = _calculateSlashAmount(_pledger, _result, _status);
      if (_slashAmount > 0) {
        // Find the actual bonder. The user we need to slash
        address _bonder = bonderForDispute[_disputeId][_pledger];

        // Slash the bonder
        HORIZON_STAKING.slash(_bonder, _slashAmount, _slashAmount, address(this));

        _slashedAmount += _slashAmount;

        _slashedUsers++;
      }

      // Remove the user from the list of users
      _users.remove(_pledger);
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
    if (pledgerClaimed[_requestId][_pledger]) revert HorizonAccountingExtension_AlreadyClaimed();

    uint256 _numberOfPledges;
    // TODO: To calculate the amount of pledges, we need to check for both 
    //       the bonder and the operator. How should we do this?
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
    if (_provisionData.thawingPeriod != MIN_THAWING_PERIOD) revert HorizonAccountingExtension_InvalidThawingPeriod();
    if (_amount > _provisionData.tokens) revert HorizonAccountingExtension_InsufficientTokens();

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

  function _getBonder(address _caller) internal view returns (address _bonder) {
    address _operator = operators[_caller];
    if(_operator == address(0)) {
      _bonder = _caller;
    } else {
      if(!HORIZON_STAKING.isAuthorized(_caller, _operator, address(this))) {
        revert HorizonAccountingExtension_UnauthorizedOperator();
      }
      _bonder = _operator;
    }
  }

  function _bondForRequest(bytes32 _requestId, address _caller, address _bonder) internal {
    address _bonderSet = bonderForRequest[_requestId][_caller];
    if(_bonderSet == address(0)) {
      bonderForRequest[_requestId][_caller] = _bonder;
    } else {
      if(_bonderSet != _bonder) {
        revert HorizonAccountingExtension_BonderMismatch();
      }
    }
  }

  function _bondForDispute(bytes32 _disputeId, address _caller, address _bonder) internal {
    address _bonderSet = bonderForDispute[_disputeId][_caller];
    if(_bonderSet == address(0)) {
      bonderForDispute[_disputeId][_caller] = _bonder;
    } else {
      if(_bonderSet != _bonder) {
        revert HorizonAccountingExtension_BonderMismatch();
      }
    }
  }
}
