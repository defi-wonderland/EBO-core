// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.26;

import {EnumerableSet} from '@openzeppelin/contracts/utils/structs/EnumerableSet.sol';
import {Helpers} from 'test/utils/Helpers.sol';

import {IBondEscalationAccounting} from
  '@defi-wonderland/prophet-modules/solidity/interfaces/extensions/IBondEscalationAccounting.sol';
import {IBondEscalationModule} from
  '@defi-wonderland/prophet-modules/solidity/interfaces/modules/dispute/IBondEscalationModule.sol';
import {
  HorizonAccountingExtension,
  IERC20,
  IHorizonAccountingExtension,
  IHorizonStaking,
  IOracle
} from 'contracts/HorizonAccountingExtension.sol';

import 'forge-std/Test.sol';

contract HorizonAccountingExtensionForTest is HorizonAccountingExtension {
  using EnumerableSet for EnumerableSet.AddressSet;

  constructor(
    IHorizonStaking _horizonStaking,
    IOracle _oracle,
    IERC20 _grt,
    uint256 _minThawingPeriod
  ) HorizonAccountingExtension(_horizonStaking, _oracle, _grt, _minThawingPeriod) {}

  function approveModuleForTest(address _user, address _module) public {
    _approvals[_user].add(_module);
  }

  function setBondedTokensForTest(address _user, uint256 _amount) public {
    totalBonded[_user] = _amount;
  }

  function setPledgedForTest(bytes32 _disputeId, uint256 _amount) public {
    pledges[_disputeId] = _amount;
  }

  function setEscalationResultForTest(
    bytes32 _disputeId,
    bytes32 _requestId,
    uint256 _amountPerPledger,
    uint256 _bondSize,
    IBondEscalationModule _bondEscalationModule
  ) public {
    escalationResults[_disputeId] = EscalationResult({
      requestId: _requestId,
      amountPerPledger: _amountPerPledger,
      bondSize: _bondSize,
      bondEscalationModule: _bondEscalationModule
    });
  }

  function setPledgerClaimedForTest(bytes32 _requestId, address _pledger, bool _claimed) public {
    pledgerClaimed[_requestId][_pledger] = _claimed;
  }

  function setApprovalForTest(address _bonder, address _caller) public {
    _approvals[_bonder].add(_caller);
  }
}

contract HorizonAccountingExtension_Unit_BaseTest is Test, Helpers {
  /// Contracts
  HorizonAccountingExtensionForTest public horizonAccountingExtension;
  IHorizonStaking public horizonStaking;
  IOracle public oracle;
  IERC20 public grt;
  IBondEscalationModule public bondEscalationModule;

  /// Addresses
  address public user;

  /// Events
  event Paid(bytes32 indexed _requestId, address indexed _beneficiary, address indexed _payer, uint256 _amount);
  event Bonded(bytes32 indexed _requestId, address indexed _bonder, uint256 _amount);
  event Released(bytes32 indexed _requestId, address indexed _beneficiary, uint256 _amount);
  event Pledged(address indexed _pledger, bytes32 indexed _requestId, bytes32 indexed _disputeId, uint256 _amount);
  event WinningPledgersPaid(
    bytes32 indexed _requestId,
    bytes32 indexed _disputeId,
    address[] indexed _winningPledgers,
    uint256 _amountPerPledger
  );
  event BondEscalationSettled(
    bytes32 _requestId, bytes32 _disputeId, uint256 _amountPerPledger, uint256 _winningPledgersLength
  );
  event PledgeReleased(
    bytes32 indexed _requestId, bytes32 indexed _disputeId, address indexed _pledger, uint256 _amount
  );
  event EscalationRewardClaimed(
    bytes32 indexed _requestId, bytes32 indexed _disputeId, address indexed _pledger, uint256 _amount
  );

  function setUp() public {
    horizonStaking = IHorizonStaking(makeAddr('HorizonStaking'));
    oracle = IOracle(makeAddr('Oracle'));
    grt = IERC20(makeAddr('GRT'));
    bondEscalationModule = IBondEscalationModule(makeAddr('BondEscalationModule'));

    user = makeAddr('User');

    horizonAccountingExtension = new HorizonAccountingExtensionForTest(horizonStaking, oracle, grt, 30 days);
  }
}

contract HorizonAccountingExtension_Unit_Constructor is HorizonAccountingExtension_Unit_BaseTest {
  function test_setHorizonStaking() public view {
    assertEq(address(horizonAccountingExtension.HORIZON_STAKING()), address(horizonStaking));
  }

  function test_setOracle() public view {
    assertEq(address(horizonAccountingExtension.ORACLE()), address(oracle));
  }

  function test_setGrt() public view {
    assertEq(address(horizonAccountingExtension.GRT()), address(grt));
  }

  function test_setMinThawingPeriod() public view {
    assertEq(horizonAccountingExtension.MIN_THAWING_PERIOD(), 30 days);
  }
}

contract HorizonAccountingExtension_Unit_ApproveModule is HorizonAccountingExtension_Unit_BaseTest {
  function test_approveModule(address _module) public {
    vm.prank(user);
    horizonAccountingExtension.approveModule(_module);

    address[] memory _approvedModules = horizonAccountingExtension.approvedModules(user);

    assertEq(_approvedModules[0], _module);
  }
}

contract HorizonAccountingExtension_Unit_RevokeModule is HorizonAccountingExtension_Unit_BaseTest {
  function test_revokeModule(address _module) public {
    horizonAccountingExtension.approveModuleForTest(user, _module);

    vm.prank(user);
    horizonAccountingExtension.revokeModule(_module);

    address[] memory _approvedModules = horizonAccountingExtension.approvedModules(user);

    assertEq(_approvedModules.length, 0);
  }
}

contract HorizonAccountingExtension_Unit_Pledge is HorizonAccountingExtension_Unit_BaseTest {
  bytes32 internal _requestId;
  bytes32 internal _disputeId;
  IHorizonStaking.Provision internal _provisionData;
  IOracle.Dispute internal _dispute;

  modifier happyPath(address _pledger, uint128 _amount, uint128 _tokens) {
    vm.assume(_tokens > _amount);

    _provisionData.thawingPeriod = 30 days;
    _provisionData.tokens = _tokens;

    (, _dispute) = _getResponseAndDispute(oracle);
    _requestId = _getId(mockRequest);
    _disputeId = _getId(_dispute);

    // Mock and expect the call to oracle checking if the module is allowed
    _mockAndExpect(
      address(oracle), abi.encodeCall(IOracle.allowedModule, (_requestId, address(this))), abi.encode(true)
    );

    vm.mockCall(
      address(horizonStaking),
      abi.encodeWithSelector(horizonStaking.getProvision.selector, _pledger, horizonAccountingExtension),
      abi.encode(_provisionData)
    );
    _;
  }

  function test_revertIfDisallowedModule(address _pledger, uint256 _amount) public {
    (, _dispute) = _getResponseAndDispute(oracle);

    // Mock and expect the call to oracle checking if the module is allowed
    _mockAndExpect(
      address(oracle), abi.encodeCall(IOracle.allowedModule, (_getId(mockRequest), address(this))), abi.encode(false)
    );

    // Check: does it revert if called by an unauthorized module?
    vm.expectRevert(IHorizonAccountingExtension.HorizonAccountingExtension_UnauthorizedModule.selector);

    horizonAccountingExtension.pledge({_pledger: _pledger, _request: mockRequest, _dispute: _dispute, _amount: _amount});
  }

  function test_invalidThawingPeriod(address _pledger, uint256 _amount) public {
    vm.assume(_amount > 0);
    _provisionData;

    (, _dispute) = _getResponseAndDispute(oracle);
    _requestId = _getId(mockRequest);

    _mockAndExpect(
      address(oracle), abi.encodeCall(IOracle.allowedModule, (_requestId, address(this))), abi.encode(true)
    );

    vm.mockCall(
      address(horizonStaking),
      abi.encodeWithSelector(horizonStaking.getProvision.selector, _pledger, horizonAccountingExtension),
      abi.encode(_provisionData)
    );

    vm.expectRevert(
      abi.encodeWithSelector(IHorizonAccountingExtension.HorizonAccountingExtension_InvalidThawingPeriod.selector)
    );

    horizonAccountingExtension.pledge({_pledger: _pledger, _request: mockRequest, _dispute: _dispute, _amount: _amount});
  }

  function test_insufficientTokens(address _pledger, uint256 _amount) public {
    vm.assume(_amount > 0);

    _provisionData;
    _provisionData.thawingPeriod = 30 days;

    (, _dispute) = _getResponseAndDispute(oracle);
    _requestId = _getId(mockRequest);

    _mockAndExpect(
      address(oracle), abi.encodeCall(IOracle.allowedModule, (_requestId, address(this))), abi.encode(true)
    );

    vm.mockCall(
      address(horizonStaking),
      abi.encodeWithSelector(horizonStaking.getProvision.selector, _pledger, horizonAccountingExtension),
      abi.encode(_provisionData)
    );

    vm.expectRevert(
      abi.encodeWithSelector(IHorizonAccountingExtension.HorizonAccountingExtension_InsufficientTokens.selector)
    );

    horizonAccountingExtension.pledge({_pledger: _pledger, _request: mockRequest, _dispute: _dispute, _amount: _amount});
  }

  function test_insufficientBondedTokens(
    address _pledger,
    uint128 _amount,
    uint128 _tokens,
    uint128 _tokensThawing
  ) public {
    vm.assume(_tokens > _amount);
    vm.assume(_amount > _tokensThawing);

    horizonAccountingExtension.setBondedTokensForTest(_pledger, _tokens);

    _provisionData;
    _provisionData.thawingPeriod = 30 days;
    _provisionData.tokens = _tokens;

    (, _dispute) = _getResponseAndDispute(oracle);
    _requestId = _getId(mockRequest);

    _mockAndExpect(
      address(oracle), abi.encodeCall(IOracle.allowedModule, (_requestId, address(this))), abi.encode(true)
    );

    vm.mockCall(
      address(horizonStaking),
      abi.encodeWithSelector(horizonStaking.getProvision.selector, _pledger, horizonAccountingExtension),
      abi.encode(_provisionData)
    );

    vm.expectRevert(
      abi.encodeWithSelector(IHorizonAccountingExtension.HorizonAccountingExtension_InsufficientBondedTokens.selector)
    );

    horizonAccountingExtension.pledge({_pledger: _pledger, _request: mockRequest, _dispute: _dispute, _amount: _amount});
  }

  function test_successfulCall(
    address _pledger,
    uint128 _amount,
    uint128 _tokens
  ) public happyPath(_pledger, _amount, _tokens) {
    // Check: is the event emitted?
    vm.expectEmit();
    emit Pledged(_pledger, _requestId, _disputeId, _amount);

    uint256 _balanceBeforePledge = horizonAccountingExtension.totalBonded(_pledger);
    uint256 _pledgesBeforePledge = horizonAccountingExtension.pledges(_disputeId);

    horizonAccountingExtension.pledge({_pledger: _pledger, _request: mockRequest, _dispute: _dispute, _amount: _amount});

    uint256 _balanceAfterPledge = horizonAccountingExtension.totalBonded(_pledger);
    uint256 _pledgesAfterPledge = horizonAccountingExtension.pledges(_disputeId);

    // Check: is the balance before decreased?
    assertEq(_balanceAfterPledge, _balanceBeforePledge + _amount);
    // Check: is the balance after increased?
    assertEq(_pledgesAfterPledge, _pledgesBeforePledge + _amount);
  }
}

contract HorizonAccountingExtension_Unit_OnSettleBondEscalation is HorizonAccountingExtension_Unit_BaseTest {
  IOracle.Dispute internal _dispute;
  bytes32 internal _requestId;
  bytes32 internal _disputeId;

  modifier happyPath(uint256 _amountPerPledger, uint256 _winningPledgersLength, uint256 _amount, uint256 _bondSize) {
    vm.assume(_amountPerPledger > 0 && _amountPerPledger < type(uint128).max);
    vm.assume(_winningPledgersLength > 0 && _winningPledgersLength < 1000);

    _requestId = _getId(mockRequest);
    _disputeId = _getId(mockDispute);

    // Mock the decodeRequestData for getting the bondSize
    IBondEscalationModule.RequestParameters memory _requestParameters = IBondEscalationModule.RequestParameters({
      accountingExtension: IBondEscalationAccounting(address(0)),
      bondToken: IERC20(address(0)),
      bondSize: _bondSize,
      maxNumberOfEscalations: 0,
      bondEscalationDeadline: 0,
      tyingBuffer: 0,
      disputeWindow: 0
    });

    vm.mockCall(
      address(bondEscalationModule),
      abi.encodeWithSelector(IBondEscalationModule.decodeRequestData.selector, mockRequest.requestModuleData),
      abi.encode(_requestParameters)
    );

    // Mock and expect the call to oracle checking if the dispute exists
    vm.mockCall(address(oracle), abi.encodeWithSelector(IOracle.disputeCreatedAt.selector, _disputeId), abi.encode(1));

    // Mock and expect the call to oracle checking if the module is allowed
    _mockAndExpect(
      address(oracle),
      abi.encodeCall(IOracle.allowedModule, (_requestId, address(bondEscalationModule))),
      abi.encode(true)
    );

    _;
  }

  function test_revertIfDisallowedModule(uint256 _amountPerPledger, uint256 _winningPledgersLength) public {
    _requestId = _getId(mockRequest);

    vm.mockCall(
      address(oracle), abi.encodeWithSelector(IOracle.disputeCreatedAt.selector, _getId(mockDispute)), abi.encode(1)
    );

    // Mock and expect the call to oracle checking if the module is allowed
    _mockAndExpect(
      address(oracle), abi.encodeCall(IOracle.allowedModule, (_requestId, address(this))), abi.encode(false)
    );

    // Check: does it revert if the module is not allowed?
    vm.expectRevert(IHorizonAccountingExtension.HorizonAccountingExtension_UnauthorizedModule.selector);

    horizonAccountingExtension.onSettleBondEscalation(
      mockRequest, mockDispute, _amountPerPledger, _winningPledgersLength
    );
  }

  function test_revertIfInsufficientFunds(
    uint256 _amountPerPledger,
    uint256 _winningPledgersLength,
    uint256 _amount,
    uint256 _bondSize
  ) public happyPath(_amountPerPledger, _winningPledgersLength, _amount, _bondSize) {
    vm.assume(_amountPerPledger > _amount);

    horizonAccountingExtension.setPledgedForTest(_disputeId, _amount);

    // Check: does it revert if the pledger does not have enough funds?
    vm.expectRevert(IHorizonAccountingExtension.HorizonAccountingExtension_InsufficientFunds.selector);

    vm.prank(address(bondEscalationModule));
    horizonAccountingExtension.onSettleBondEscalation(
      mockRequest, mockDispute, _amountPerPledger, _winningPledgersLength
    );
  }

  function test_revertIfAlreadySettled(
    uint256 _amountPerPledger,
    uint256 _winningPledgersLength,
    uint256 _amount,
    uint256 _bondSize
  ) public happyPath(_amountPerPledger, _winningPledgersLength, _amount, _bondSize) {
    vm.assume(_amount > _amountPerPledger * _winningPledgersLength);

    horizonAccountingExtension.setEscalationResultForTest(
      _disputeId, _requestId, _amountPerPledger, _bondSize, IBondEscalationModule(bondEscalationModule)
    );

    horizonAccountingExtension.setPledgedForTest(_disputeId, _amount);

    // Check: does it revert if the escalation is already settled?
    vm.expectRevert(IHorizonAccountingExtension.HorizonAccountingExtension_AlreadySettled.selector);

    vm.prank(address(bondEscalationModule));
    horizonAccountingExtension.onSettleBondEscalation(
      mockRequest, mockDispute, _amountPerPledger, _winningPledgersLength
    );
  }

  function test_successfulCall(
    uint256 _amountPerPledger,
    uint256 _winningPledgersLength,
    uint256 _amount,
    uint256 _bondSize
  ) public happyPath(_amountPerPledger, _winningPledgersLength, _amount, _bondSize) {
    vm.assume(_amount > _amountPerPledger * _winningPledgersLength);

    horizonAccountingExtension.setPledgedForTest(_disputeId, _amount);

    vm.expectEmit();
    emit BondEscalationSettled(_requestId, _disputeId, _amountPerPledger, _winningPledgersLength);

    vm.prank(address(bondEscalationModule));
    horizonAccountingExtension.onSettleBondEscalation({
      _request: mockRequest,
      _dispute: mockDispute,
      _amountPerPledger: _amountPerPledger,
      _winningPledgersLength: _winningPledgersLength
    });

    (
      bytes32 _requestIdSaved,
      uint256 _amountPerPledgerSaved,
      uint256 _savedBondSize,
      IBondEscalationModule _savedBondEscalationModule
    ) = horizonAccountingExtension.escalationResults(_disputeId);

    assertEq(_savedBondSize, _bondSize);
    assertEq(_requestIdSaved, _requestId);
    assertEq(_amountPerPledgerSaved, _amountPerPledger);
    assertEq(address(_savedBondEscalationModule), address(bondEscalationModule));
  }
}

contract HorizonAccountingExtension_Unit_ClaimEscalationReward is HorizonAccountingExtension_Unit_BaseTest {
  bytes32 internal _requestId;
  bytes32 internal _disputeId;

  modifier happyPath(uint256 _pledgesForDispute, uint256 _pledgesAgainstDispute, uint256 _bondSize, uint256 _amount) {
    vm.assume(_pledgesForDispute > 0 && _pledgesForDispute < type(uint128).max);
    vm.assume(_pledgesAgainstDispute > 0 && _pledgesAgainstDispute < type(uint128).max);
    vm.assume(_amount > 0 && _amount < type(uint128).max);

    _requestId = _getId(mockRequest);
    _disputeId = _getId(mockDispute);

    horizonAccountingExtension.setEscalationResultForTest(
      _disputeId, _requestId, _amount, _bondSize, bondEscalationModule
    );
    _;
  }

  function test_revertIfNoEscalationResult(address _pledger) public {
    vm.expectRevert(IHorizonAccountingExtension.HorizonAccountingExtension_NoEscalationResult.selector);
    horizonAccountingExtension.claimEscalationReward(_disputeId, _pledger);
  }

  function test_revertIfAlreadyClaimed(
    address _pledger,
    uint256 _pledgesForDispute,
    uint256 _pledgesAgainstDispute,
    uint256 _bondSize,
    uint256 _amount
  ) public happyPath(_pledgesForDispute, _pledgesAgainstDispute, _bondSize, _amount) {
    _requestId = _getId(mockRequest);
    _disputeId = _getId(mockDispute);

    horizonAccountingExtension.setPledgerClaimedForTest(_requestId, _pledger, true);

    vm.expectRevert(IHorizonAccountingExtension.HorizonAccountingExtension_AlreadyClaimed.selector);
    horizonAccountingExtension.claimEscalationReward(_disputeId, _pledger);
  }

  function test_successfulCallNoResolution(
    address _pledger,
    uint256 _pledgesForDispute,
    uint256 _pledgesAgainstDispute,
    uint256 _bondSize,
    uint256 _amount
  ) public happyPath(_pledgesForDispute, _pledgesAgainstDispute, _bondSize, _amount) {
    // Mock and expect the call to oracle checking the dispute status
    _mockAndExpect(
      address(oracle),
      abi.encodeWithSelector(IOracle.disputeStatus.selector, _disputeId),
      abi.encode(IOracle.DisputeStatus.NoResolution)
    );

    _mockAndExpect(
      address(bondEscalationModule),
      abi.encodeWithSelector(IBondEscalationModule.pledgesForDispute.selector, _requestId, _pledger),
      abi.encode(_pledgesForDispute)
    );

    _mockAndExpect(
      address(bondEscalationModule),
      abi.encodeWithSelector(IBondEscalationModule.pledgesAgainstDispute.selector, _requestId, _pledger),
      abi.encode(_pledgesAgainstDispute)
    );

    vm.expectEmit();
    emit EscalationRewardClaimed(
      _requestId, _disputeId, _pledger, _amount * (_pledgesForDispute + _pledgesAgainstDispute)
    );

    horizonAccountingExtension.claimEscalationReward(_disputeId, _pledger);
  }

  function test_successfulCallWonForDispute(
    address _pledger,
    uint256 _pledgesForDispute,
    uint256 _pledgesAgainstDispute,
    uint256 _bondSize,
    uint256 _amount
  ) public happyPath(_pledgesForDispute, _pledgesAgainstDispute, _bondSize, _amount) {
    // Mock and expect the call to oracle checking the dispute status
    _mockAndExpect(
      address(oracle),
      abi.encodeWithSelector(IOracle.disputeStatus.selector, _disputeId),
      abi.encode(IOracle.DisputeStatus.Won)
    );

    _mockAndExpect(
      address(bondEscalationModule),
      abi.encodeWithSelector(IBondEscalationModule.pledgesForDispute.selector, _requestId, _pledger),
      abi.encode(_pledgesForDispute)
    );

    vm.expectEmit();
    emit EscalationRewardClaimed(_requestId, _disputeId, _pledger, _amount * _pledgesForDispute);

    horizonAccountingExtension.claimEscalationReward(_disputeId, _pledger);
  }

  function test_successfulCallLostAgainstDispute(
    address _pledger,
    uint256 _pledgesForDispute,
    uint256 _pledgesAgainstDispute,
    uint256 _bondSize,
    uint256 _amount
  ) public happyPath(_pledgesForDispute, _pledgesAgainstDispute, _bondSize, _amount) {
    // Mock and expect the call to oracle checking the dispute status
    _mockAndExpect(
      address(oracle),
      abi.encodeWithSelector(IOracle.disputeStatus.selector, _disputeId),
      abi.encode(IOracle.DisputeStatus.Lost)
    );

    _mockAndExpect(
      address(bondEscalationModule),
      abi.encodeWithSelector(IBondEscalationModule.pledgesAgainstDispute.selector, _requestId, _pledger),
      abi.encode(_pledgesAgainstDispute)
    );

    vm.expectEmit();
    emit EscalationRewardClaimed(_requestId, _disputeId, _pledger, _amount * _pledgesAgainstDispute);

    horizonAccountingExtension.claimEscalationReward(_disputeId, _pledger);
  }
}

contract HorizonAccountingExtension_Unit_ReleasePledge is HorizonAccountingExtension_Unit_BaseTest {
  bytes32 internal _requestId;
  bytes32 internal _disputeId;

  modifier happyPath(address _pledger, uint256 _amount, uint256 _amountPledge) {
    vm.assume(_amount > 0);
    vm.assume(_amountPledge > _amount);

    _requestId = _getId(mockRequest);
    _disputeId = _getId(mockDispute);

    horizonAccountingExtension.setPledgedForTest(_disputeId, _amountPledge);
    horizonAccountingExtension.setBondedTokensForTest(_pledger, _amount);

    vm.mockCall(
      address(oracle), abi.encodeWithSelector(IOracle.disputeCreatedAt.selector, _getId(mockDispute)), abi.encode(1)
    );

    // Mock and expect the call to oracle checking if the module is allowed
    _mockAndExpect(
      address(oracle), abi.encodeCall(IOracle.allowedModule, (_requestId, address(this))), abi.encode(true)
    );

    _;
  }

  function test_revertIfDisallowedModule(address _pledger, uint256 _amount) public {
    _requestId = _getId(mockRequest);

    vm.mockCall(
      address(oracle), abi.encodeWithSelector(IOracle.disputeCreatedAt.selector, _getId(mockDispute)), abi.encode(1)
    );

    // Mock and expect the call to oracle checking if the module is allowed
    _mockAndExpect(
      address(oracle), abi.encodeCall(IOracle.allowedModule, (_requestId, address(this))), abi.encode(false)
    );

    // Check: does it revert if the module is not allowed?
    vm.expectRevert(IHorizonAccountingExtension.HorizonAccountingExtension_UnauthorizedModule.selector);

    horizonAccountingExtension.releasePledge(mockRequest, mockDispute, _pledger, _amount);
  }

  function test_revertIfInsufficientFunds(
    address _pledger,
    uint256 _amount,
    uint256 _amountPledge
  ) public happyPath(_pledger, _amount, _amountPledge) {
    horizonAccountingExtension.setPledgedForTest(_disputeId, 0);

    vm.expectRevert(IHorizonAccountingExtension.HorizonAccountingExtension_InsufficientFunds.selector);
    horizonAccountingExtension.releasePledge(mockRequest, mockDispute, _pledger, _amount);
  }

  function test_revertIfInsufficientBondedTokens(
    address _pledger,
    uint256 _amount,
    uint256 _amountPledge
  ) public happyPath(_pledger, _amount, _amountPledge) {
    horizonAccountingExtension.setBondedTokensForTest(_pledger, 0);

    vm.expectRevert(IHorizonAccountingExtension.HorizonAccountingExtension_InsufficientBondedTokens.selector);
    horizonAccountingExtension.releasePledge(mockRequest, mockDispute, _pledger, _amount);
  }

  function test_successfulCall(
    address _pledger,
    uint256 _amount,
    uint256 _amountPledge
  ) public happyPath(_pledger, _amount, _amountPledge) {
    vm.expectEmit();
    emit PledgeReleased(_requestId, _disputeId, _pledger, _amount);

    horizonAccountingExtension.releasePledge(mockRequest, mockDispute, _pledger, _amount);

    uint256 _pledgesAfter = horizonAccountingExtension.pledges(_disputeId);
    uint256 _totalBondedAfter = horizonAccountingExtension.totalBonded(_pledger);

    assertEq(_pledgesAfter, _amountPledge - _amount);
    assertEq(_totalBondedAfter, _amount - _amount);
  }
}

contract HorizonAccountingExtension_Unit_Pay is HorizonAccountingExtension_Unit_BaseTest {
  modifier happyPath(bytes32 _requestId, address _payer, address _receiver, uint256 _amount) {
    _;
  }

  function test_revertIfDisallowedModule(bytes32 _requestId, address _payer, address _receiver, uint256 _amount) public {
    // Mock and expect the call to oracle checking if the module is allowed
    _mockAndExpect(
      address(oracle), abi.encodeCall(IOracle.allowedModule, (_requestId, address(this))), abi.encode(false)
    );

    // Check: does it revert if the module is not allowed?
    vm.expectRevert(IHorizonAccountingExtension.HorizonAccountingExtension_UnauthorizedModule.selector);

    horizonAccountingExtension.pay(_requestId, _payer, _receiver, _amount);
  }

  function test_revertIfUnauthorizedUserPayer(
    bytes32 _requestId,
    address _payer,
    address _receiver,
    uint256 _amount
  ) public {
    // Mock and expect the call to oracle checking if the module is allowed
    _mockAndExpect(
      address(oracle), abi.encodeCall(IOracle.allowedModule, (_requestId, address(this))), abi.encode(true)
    );

    _mockAndExpect(address(oracle), abi.encodeCall(IOracle.isParticipant, (_requestId, _payer)), abi.encode(false));

    // Check: does it revert if the module is not allowed?
    vm.expectRevert(IHorizonAccountingExtension.HorizonAccountingExtension_UnauthorizedUser.selector);

    horizonAccountingExtension.pay(_requestId, _payer, _receiver, _amount);
  }

  function test_revertIfUnauthorizedUserReceiver(
    bytes32 _requestId,
    address _payer,
    address _receiver,
    uint256 _amount
  ) public {
    vm.assume(_payer != _receiver);

    // Mock and expect the call to oracle checking if the module is allowed
    _mockAndExpect(
      address(oracle), abi.encodeCall(IOracle.allowedModule, (_requestId, address(this))), abi.encode(true)
    );

    _mockAndExpect(address(oracle), abi.encodeCall(IOracle.isParticipant, (_requestId, _payer)), abi.encode(true));
    _mockAndExpect(address(oracle), abi.encodeCall(IOracle.isParticipant, (_requestId, _receiver)), abi.encode(false));

    // Check: does it revert if the module is not allowed?
    vm.expectRevert(IHorizonAccountingExtension.HorizonAccountingExtension_UnauthorizedUser.selector);

    horizonAccountingExtension.pay(_requestId, _payer, _receiver, _amount);
  }
}

contract HorizonAccountingExtension_Unit_Bond is HorizonAccountingExtension_Unit_BaseTest {
  IHorizonStaking.Provision internal _provision;

  modifier happyPath(address _bonder, bytes32 _requestId, uint256 _amount) {
    vm.assume(_amount > 0 && _amount < type(uint128).max);
    // Mock and expect the call to oracle checking if the module is allowed
    _mockAndExpect(
      address(oracle), abi.encodeCall(IOracle.allowedModule, (_requestId, address(this))), abi.encode(true)
    );

    _mockAndExpect(address(oracle), abi.encodeCall(IOracle.isParticipant, (_requestId, _bonder)), abi.encode(true));

    horizonAccountingExtension.setApprovalForTest(_bonder, address(this));

    _provision.thawingPeriod = uint64(horizonAccountingExtension.MIN_THAWING_PERIOD());
    _provision.tokens = _amount;

    _;
  }

  function test_revertIfDisallowedModule(address _bonder, bytes32 _requestId, uint256 _amount) public {
    // Mock and expect the call to oracle checking if the module is allowed
    _mockAndExpect(
      address(oracle), abi.encodeCall(IOracle.allowedModule, (_requestId, address(this))), abi.encode(false)
    );

    // Check: does it revert if the module is not allowed?
    vm.expectRevert(IHorizonAccountingExtension.HorizonAccountingExtension_UnauthorizedModule.selector);

    horizonAccountingExtension.bond(_bonder, _requestId, _amount);
  }

  function test_revertIfUnauthorizedUser(address _bonder, bytes32 _requestId, uint256 _amount) public {
    // Mock and expect the call to oracle checking if the module is allowed
    _mockAndExpect(
      address(oracle), abi.encodeCall(IOracle.allowedModule, (_requestId, address(this))), abi.encode(true)
    );

    _mockAndExpect(address(oracle), abi.encodeCall(IOracle.isParticipant, (_requestId, _bonder)), abi.encode(false));

    // Check: does it revert if the module is not allowed?
    vm.expectRevert(IHorizonAccountingExtension.HorizonAccountingExtension_UnauthorizedUser.selector);

    horizonAccountingExtension.bond(_bonder, _requestId, _amount);
  }

  function test_revertIfNotAllowed(address _bonder, bytes32 _requestId, uint256 _amount) public {
    // Mock and expect the call to oracle checking if the module is allowed
    _mockAndExpect(
      address(oracle), abi.encodeCall(IOracle.allowedModule, (_requestId, address(this))), abi.encode(true)
    );

    _mockAndExpect(address(oracle), abi.encodeCall(IOracle.isParticipant, (_requestId, _bonder)), abi.encode(true));

    vm.expectRevert(IHorizonAccountingExtension.HorizonAccountingExtension_NotAllowed.selector);

    horizonAccountingExtension.bond(_bonder, _requestId, _amount);
  }

  function test_revertIfInvalidThawingPeriod(
    address _bonder,
    bytes32 _requestId,
    uint256 _amount
  ) public happyPath(_bonder, _requestId, _amount) {
    _provision.thawingPeriod = 0;

    _mockAndExpect(
      address(horizonStaking),
      abi.encodeCall(IHorizonStaking.getProvision, (_bonder, address(horizonAccountingExtension))),
      abi.encode(_provision)
    );

    vm.expectRevert(IHorizonAccountingExtension.HorizonAccountingExtension_InvalidThawingPeriod.selector);

    horizonAccountingExtension.bond(_bonder, _requestId, _amount);
  }

  function test_revertIfInsufficientTokens(
    address _bonder,
    bytes32 _requestId,
    uint256 _amount
  ) public happyPath(_bonder, _requestId, _amount) {
    _provision.tokens = 0;

    _mockAndExpect(
      address(horizonStaking),
      abi.encodeCall(IHorizonStaking.getProvision, (_bonder, address(horizonAccountingExtension))),
      abi.encode(_provision)
    );
    vm.expectRevert(IHorizonAccountingExtension.HorizonAccountingExtension_InsufficientTokens.selector);

    horizonAccountingExtension.bond(_bonder, _requestId, _amount);
  }

  function test_revertIfInsufficientBondedTokens(
    address _bonder,
    bytes32 _requestId,
    uint256 _amount
  ) public happyPath(_bonder, _requestId, _amount) {
    _mockAndExpect(
      address(horizonStaking),
      abi.encodeCall(IHorizonStaking.getProvision, (_bonder, address(horizonAccountingExtension))),
      abi.encode(_provision)
    );

    horizonAccountingExtension.setBondedTokensForTest(_bonder, _amount);

    vm.expectRevert(IHorizonAccountingExtension.HorizonAccountingExtension_InsufficientBondedTokens.selector);

    horizonAccountingExtension.bond(_bonder, _requestId, _amount);
  }

  function test_successfulCall(
    address _bonder,
    bytes32 _requestId,
    uint256 _amount
  ) public happyPath(_bonder, _requestId, _amount) {
    _mockAndExpect(
      address(horizonStaking),
      abi.encodeCall(IHorizonStaking.getProvision, (_bonder, address(horizonAccountingExtension))),
      abi.encode(_provision)
    );

    vm.expectEmit();
    emit Bonded(_requestId, _bonder, _amount);

    horizonAccountingExtension.bond(_bonder, _requestId, _amount);

    uint256 _bondedForRequestAfter = horizonAccountingExtension.bondedForRequest(_bonder, _requestId);
    uint256 _totalBondedAfter = horizonAccountingExtension.totalBonded(_bonder);

    assertEq(_bondedForRequestAfter, _amount);
    assertEq(_totalBondedAfter, _amount);
  }
}

contract HorizonAccountingExtension_Unit_BondSender is HorizonAccountingExtension_Unit_BaseTest {
  IHorizonStaking.Provision internal _provision;

  modifier happyPath(address _bonder, bytes32 _requestId, uint256 _amount, address _sender) {
    vm.assume(_amount > 0 && _amount < type(uint128).max);
    // Mock and expect the call to oracle checking if the module is allowed
    _mockAndExpect(
      address(oracle), abi.encodeCall(IOracle.allowedModule, (_requestId, address(this))), abi.encode(true)
    );

    _mockAndExpect(address(oracle), abi.encodeCall(IOracle.isParticipant, (_requestId, _bonder)), abi.encode(true));

    horizonAccountingExtension.setApprovalForTest(_bonder, address(this));
    horizonAccountingExtension.setApprovalForTest(_bonder, _sender);

    _provision.thawingPeriod = uint64(horizonAccountingExtension.MIN_THAWING_PERIOD());
    _provision.tokens = _amount;

    _;
  }

  function test_revertIfDisallowedModule(address _bonder, bytes32 _requestId, uint256 _amount, address _sender) public {
    // Mock and expect the call to oracle checking if the module is allowed
    _mockAndExpect(
      address(oracle), abi.encodeCall(IOracle.allowedModule, (_requestId, address(this))), abi.encode(false)
    );

    // Check: does it revert if the module is not allowed?
    vm.expectRevert(IHorizonAccountingExtension.HorizonAccountingExtension_UnauthorizedModule.selector);

    horizonAccountingExtension.bond(_bonder, _requestId, _amount, _sender);
  }

  function test_revertIfUnauthorizedUser(address _bonder, bytes32 _requestId, uint256 _amount, address _sender) public {
    // Mock and expect the call to oracle checking if the module is allowed
    _mockAndExpect(
      address(oracle), abi.encodeCall(IOracle.allowedModule, (_requestId, address(this))), abi.encode(true)
    );

    _mockAndExpect(address(oracle), abi.encodeCall(IOracle.isParticipant, (_requestId, _bonder)), abi.encode(false));

    // Check: does it revert if the module is not allowed?
    vm.expectRevert(IHorizonAccountingExtension.HorizonAccountingExtension_UnauthorizedUser.selector);

    horizonAccountingExtension.bond(_bonder, _requestId, _amount, _sender);
  }

  function test_revertIfNotAllowedModule(address _bonder, bytes32 _requestId, uint256 _amount, address _sender) public {
    // Mock and expect the call to oracle checking if the module is allowed
    _mockAndExpect(
      address(oracle), abi.encodeCall(IOracle.allowedModule, (_requestId, address(this))), abi.encode(true)
    );

    _mockAndExpect(address(oracle), abi.encodeCall(IOracle.isParticipant, (_requestId, _bonder)), abi.encode(true));

    horizonAccountingExtension.setApprovalForTest(_bonder, _sender);

    vm.expectRevert(IHorizonAccountingExtension.HorizonAccountingExtension_NotAllowed.selector);

    horizonAccountingExtension.bond(_bonder, _requestId, _amount, _sender);
  }

  function test_revertIfNotAllowedSender(address _bonder, bytes32 _requestId, uint256 _amount, address _sender) public {
    vm.assume(_sender != address(this));

    // Mock and expect the call to oracle checking if the module is allowed
    _mockAndExpect(
      address(oracle), abi.encodeCall(IOracle.allowedModule, (_requestId, address(this))), abi.encode(true)
    );

    _mockAndExpect(address(oracle), abi.encodeCall(IOracle.isParticipant, (_requestId, _bonder)), abi.encode(true));

    horizonAccountingExtension.setApprovalForTest(_bonder, address(this));

    vm.expectRevert(IHorizonAccountingExtension.HorizonAccountingExtension_NotAllowed.selector);

    horizonAccountingExtension.bond(_bonder, _requestId, _amount, _sender);
  }

  function test_revertIfInvalidThawingPeriod(
    address _bonder,
    bytes32 _requestId,
    uint256 _amount,
    address _sender
  ) public happyPath(_bonder, _requestId, _amount, _sender) {
    _provision.thawingPeriod = 0;

    _mockAndExpect(
      address(horizonStaking),
      abi.encodeCall(IHorizonStaking.getProvision, (_bonder, address(horizonAccountingExtension))),
      abi.encode(_provision)
    );

    vm.expectRevert(IHorizonAccountingExtension.HorizonAccountingExtension_InvalidThawingPeriod.selector);

    horizonAccountingExtension.bond(_bonder, _requestId, _amount, _sender);
  }

  function test_revertIfInsufficientTokens(
    address _bonder,
    bytes32 _requestId,
    uint256 _amount,
    address _sender
  ) public happyPath(_bonder, _requestId, _amount, _sender) {
    _provision.tokens = 0;

    _mockAndExpect(
      address(horizonStaking),
      abi.encodeCall(IHorizonStaking.getProvision, (_bonder, address(horizonAccountingExtension))),
      abi.encode(_provision)
    );
    vm.expectRevert(IHorizonAccountingExtension.HorizonAccountingExtension_InsufficientTokens.selector);

    horizonAccountingExtension.bond(_bonder, _requestId, _amount, _sender);
  }

  function test_revertIfInsufficientBondedTokens(
    address _bonder,
    bytes32 _requestId,
    uint256 _amount,
    address _sender
  ) public happyPath(_bonder, _requestId, _amount, _sender) {
    _mockAndExpect(
      address(horizonStaking),
      abi.encodeCall(IHorizonStaking.getProvision, (_bonder, address(horizonAccountingExtension))),
      abi.encode(_provision)
    );

    horizonAccountingExtension.setBondedTokensForTest(_bonder, _amount);

    vm.expectRevert(IHorizonAccountingExtension.HorizonAccountingExtension_InsufficientBondedTokens.selector);

    horizonAccountingExtension.bond(_bonder, _requestId, _amount, _sender);
  }

  function test_successfulCall(
    address _bonder,
    bytes32 _requestId,
    uint256 _amount,
    address _sender
  ) public happyPath(_bonder, _requestId, _amount, _sender) {
    _mockAndExpect(
      address(horizonStaking),
      abi.encodeCall(IHorizonStaking.getProvision, (_bonder, address(horizonAccountingExtension))),
      abi.encode(_provision)
    );

    vm.expectEmit();
    emit Bonded(_requestId, _bonder, _amount);

    horizonAccountingExtension.bond(_bonder, _requestId, _amount, _sender);

    uint256 _bondedForRequestAfter = horizonAccountingExtension.bondedForRequest(_bonder, _requestId);
    uint256 _totalBondedAfter = horizonAccountingExtension.totalBonded(_bonder);

    assertEq(_bondedForRequestAfter, _amount);
    assertEq(_totalBondedAfter, _amount);
  }
}

contract HorizonAccountingExtension_Unit_Release is HorizonAccountingExtension_Unit_BaseTest {
  modifier happyPath(address _bonder, bytes32 _requestId, uint256 _amount) {
    _;
  }

  function test_revertIfDisallowedModule(address _bonder, bytes32 _requestId, uint256 _amount) public {
    // Mock and expect the call to oracle checking if the module is allowed
    _mockAndExpect(
      address(oracle), abi.encodeCall(IOracle.allowedModule, (_requestId, address(this))), abi.encode(false)
    );

    // Check: does it revert if the module is not allowed?
    vm.expectRevert(IHorizonAccountingExtension.HorizonAccountingExtension_UnauthorizedModule.selector);

    horizonAccountingExtension.release(_bonder, _requestId, _amount);
  }

  function test_revertIfUnauthorizedUser(address _bonder, bytes32 _requestId, uint256 _amount) public {
    // Mock and expect the call to oracle checking if the module is allowed
    _mockAndExpect(
      address(oracle), abi.encodeCall(IOracle.allowedModule, (_requestId, address(this))), abi.encode(true)
    );

    _mockAndExpect(address(oracle), abi.encodeCall(IOracle.isParticipant, (_requestId, _bonder)), abi.encode(false));

    // Check: does it revert if the module is not allowed?
    vm.expectRevert(IHorizonAccountingExtension.HorizonAccountingExtension_UnauthorizedUser.selector);

    horizonAccountingExtension.release(_bonder, _requestId, _amount);
  }
}
