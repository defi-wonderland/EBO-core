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
    uint256 _minThawingPeriod,
    address[] memory _authorizedCallers
  ) HorizonAccountingExtension(_horizonStaking, _oracle, _grt, _minThawingPeriod, _authorizedCallers) {}

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

  function setBondedForRequestForTest(address _user, bytes32 _requestId, uint256 _amount) public {
    bondedForRequest[_user][_requestId] = _amount;
  }

  function setPledgerClaimedForTest(bytes32 _requestId, address _pledger, bool _claimed) public {
    pledgerClaimed[_requestId][_pledger] = _claimed;
  }

  function setPledgersForTest(bytes32 _disputeId, address _pledger) public {
    _pledgers[_disputeId].add(_pledger);
  }

  function getPledgerForTest(bytes32 _disputeId, uint256 _index) public view returns (address _pledger) {
    _pledger = _pledgers[_disputeId].at(_index);
  }

  function getPledgersLengthForTest(bytes32 _disputeId) public view returns (uint256 _length) {
    _length = _pledgers[_disputeId].length();
  }

  function setApprovalForTest(address _bonder, address _caller) public {
    _approvals[_bonder].add(_caller);
  }

  function setAuthorizedCallerForTest(address _caller) public {
    authorizedCallers[_caller] = true;
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
  address public authorizedCaller;

  /// Constants
  uint32 public constant MAX_VERIFIER_CUT = 1_000_000;
  uint64 public constant MIN_THAWING_PERIOD = 30 days;

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
    bytes32 indexed _requestId, bytes32 indexed _disputeId, address indexed _pledger, uint256 _reward, uint256 _released
  );

  function setUp() public {
    horizonStaking = IHorizonStaking(makeAddr('HorizonStaking'));
    oracle = IOracle(makeAddr('Oracle'));
    grt = IERC20(makeAddr('GRT'));
    bondEscalationModule = IBondEscalationModule(makeAddr('BondEscalationModule'));

    user = makeAddr('User');
    authorizedCaller = makeAddr('AuthorizedCaller');

    address[] memory _authorizedCallers = new address[](1);
    _authorizedCallers[0] = authorizedCaller;

    horizonAccountingExtension =
      new HorizonAccountingExtensionForTest(horizonStaking, oracle, grt, MIN_THAWING_PERIOD, _authorizedCallers);
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
    assertEq(horizonAccountingExtension.MIN_THAWING_PERIOD(), MIN_THAWING_PERIOD);
  }

  function test_setAuthorizedCallers() public view {
    assertEq(horizonAccountingExtension.authorizedCallers(authorizedCaller), true);
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
  IHorizonStaking.Provision internal _provisionData;

  modifier happyPath(address _pledger, uint128 _amount, uint128 _tokens) {
    vm.assume(_tokens > _amount);

    _provisionData.tokens = _tokens;
    _provisionData.thawingPeriod = uint64(horizonAccountingExtension.MIN_THAWING_PERIOD());
    _provisionData.maxVerifierCut = uint32(horizonAccountingExtension.MAX_VERIFIER_CUT());

    // Mock and expect the call to oracle checking if the module is allowed
    _mockAndExpect(
      address(oracle), abi.encodeCall(IOracle.allowedModule, (_mockRequestId, authorizedCaller)), abi.encode(true)
    );

    _mockAndExpect(address(oracle), abi.encodeCall(IOracle.disputeCreatedAt, (_mockDisputeId)), abi.encode(1));

    vm.mockCall(
      address(horizonStaking),
      abi.encodeWithSelector(horizonStaking.getProvision.selector, _pledger, horizonAccountingExtension),
      abi.encode(_provisionData)
    );

    vm.startPrank(authorizedCaller);
    _;
  }

  function test_revertIfUnauthorizedCaller(address _pledger, uint256 _amount) public {
    vm.expectRevert(IHorizonAccountingExtension.HorizonAccountingExtension_UnauthorizedCaller.selector);

    horizonAccountingExtension.pledge({
      _pledger: _pledger,
      _request: mockRequest,
      _dispute: mockDispute,
      _amount: _amount
    });
  }

  function test_revertIfDisallowedModule(address _pledger, uint256 _amount) public {
    // Mock and expect the call to oracle checking if the module is allowed
    _mockAndExpect(
      address(oracle), abi.encodeCall(IOracle.allowedModule, (_getId(mockRequest), authorizedCaller)), abi.encode(false)
    );

    _mockAndExpect(address(oracle), abi.encodeCall(IOracle.disputeCreatedAt, (_mockDisputeId)), abi.encode(1));

    // Check: does it revert if called by an unauthorized module?
    vm.expectRevert(IHorizonAccountingExtension.HorizonAccountingExtension_UnauthorizedModule.selector);

    vm.prank(authorizedCaller);
    horizonAccountingExtension.pledge({
      _pledger: _pledger,
      _request: mockRequest,
      _dispute: mockDispute,
      _amount: _amount
    });
  }

  function test_invalidVerfierCut(address _pledger, uint256 _amount, uint32 _invalidVerfierCut) public {
    vm.assume(_amount > 0);
    vm.assume(_invalidVerfierCut < MAX_VERIFIER_CUT);

    _provisionData.maxVerifierCut = _invalidVerfierCut;

    _mockAndExpect(address(oracle), abi.encodeCall(IOracle.disputeCreatedAt, (_mockDisputeId)), abi.encode(1));

    _mockAndExpect(
      address(oracle), abi.encodeCall(IOracle.allowedModule, (_mockRequestId, authorizedCaller)), abi.encode(true)
    );

    vm.mockCall(
      address(horizonStaking),
      abi.encodeWithSelector(horizonStaking.getProvision.selector, _pledger, horizonAccountingExtension),
      abi.encode(_provisionData)
    );

    vm.expectRevert(
      abi.encodeWithSelector(IHorizonAccountingExtension.HorizonAccountingExtension_InvalidMaxVerifierCut.selector)
    );

    vm.prank(authorizedCaller);
    horizonAccountingExtension.pledge({
      _pledger: _pledger,
      _request: mockRequest,
      _dispute: mockDispute,
      _amount: _amount
    });
  }

  function test_invalidThawingPeriod(address _pledger, uint256 _amount) public {
    vm.assume(_amount > 0);

    _provisionData.maxVerifierCut = MAX_VERIFIER_CUT;

    _mockAndExpect(address(oracle), abi.encodeCall(IOracle.disputeCreatedAt, (_mockDisputeId)), abi.encode(1));

    _mockAndExpect(
      address(oracle), abi.encodeCall(IOracle.allowedModule, (_mockRequestId, authorizedCaller)), abi.encode(true)
    );

    vm.mockCall(
      address(horizonStaking),
      abi.encodeWithSelector(horizonStaking.getProvision.selector, _pledger, horizonAccountingExtension),
      abi.encode(_provisionData)
    );

    vm.expectRevert(
      abi.encodeWithSelector(IHorizonAccountingExtension.HorizonAccountingExtension_InvalidThawingPeriod.selector)
    );

    vm.prank(authorizedCaller);
    horizonAccountingExtension.pledge({
      _pledger: _pledger,
      _request: mockRequest,
      _dispute: mockDispute,
      _amount: _amount
    });
  }

  function test_insufficientTokens(address _pledger, uint256 _amount) public {
    vm.assume(_amount > 0);

    _provisionData.thawingPeriod = MIN_THAWING_PERIOD;
    _provisionData.maxVerifierCut = MAX_VERIFIER_CUT;

    _mockAndExpect(address(oracle), abi.encodeCall(IOracle.disputeCreatedAt, (_mockDisputeId)), abi.encode(1));

    _mockAndExpect(
      address(oracle), abi.encodeCall(IOracle.allowedModule, (_mockRequestId, authorizedCaller)), abi.encode(true)
    );

    vm.mockCall(
      address(horizonStaking),
      abi.encodeWithSelector(horizonStaking.getProvision.selector, _pledger, horizonAccountingExtension),
      abi.encode(_provisionData)
    );

    vm.expectRevert(
      abi.encodeWithSelector(IHorizonAccountingExtension.HorizonAccountingExtension_InsufficientTokens.selector)
    );

    vm.prank(authorizedCaller);
    horizonAccountingExtension.pledge({
      _pledger: _pledger,
      _request: mockRequest,
      _dispute: mockDispute,
      _amount: _amount
    });
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

    _provisionData.tokens = _tokens;
    _provisionData.thawingPeriod = MIN_THAWING_PERIOD;
    _provisionData.maxVerifierCut = MAX_VERIFIER_CUT;

    _mockAndExpect(address(oracle), abi.encodeCall(IOracle.disputeCreatedAt, (_mockDisputeId)), abi.encode(1));

    _mockAndExpect(
      address(oracle), abi.encodeCall(IOracle.allowedModule, (_mockRequestId, authorizedCaller)), abi.encode(true)
    );

    vm.mockCall(
      address(horizonStaking),
      abi.encodeWithSelector(horizonStaking.getProvision.selector, _pledger, horizonAccountingExtension),
      abi.encode(_provisionData)
    );

    vm.expectRevert(
      abi.encodeWithSelector(IHorizonAccountingExtension.HorizonAccountingExtension_InsufficientBondedTokens.selector)
    );

    vm.prank(authorizedCaller);
    horizonAccountingExtension.pledge({
      _pledger: _pledger,
      _request: mockRequest,
      _dispute: mockDispute,
      _amount: _amount
    });
  }

  function test_successfulCall(
    address _pledger,
    uint128 _amount,
    uint128 _tokens
  ) public happyPath(_pledger, _amount, _tokens) {
    // Check: is the event emitted?
    vm.expectEmit();
    emit Pledged(_pledger, _mockRequestId, _mockDisputeId, _amount);

    uint256 _balanceBeforePledge = horizonAccountingExtension.totalBonded(_pledger);
    uint256 _pledgesBeforePledge = horizonAccountingExtension.pledges(_mockDisputeId);

    horizonAccountingExtension.pledge({
      _pledger: _pledger,
      _request: mockRequest,
      _dispute: mockDispute,
      _amount: _amount
    });

    uint256 _balanceAfterPledge = horizonAccountingExtension.totalBonded(_pledger);
    uint256 _pledgesAfterPledge = horizonAccountingExtension.pledges(_mockDisputeId);

    // Check: is the balance before decreased?
    assertEq(_balanceAfterPledge, _balanceBeforePledge + _amount);
    // Check: is the balance after increased?
    assertEq(_pledgesAfterPledge, _pledgesBeforePledge + _amount);
  }
}

contract HorizonAccountingExtension_Unit_OnSettleBondEscalation is HorizonAccountingExtension_Unit_BaseTest {
  modifier happyPath(uint256 _amountPerPledger, uint256 _winningPledgersLength, uint256 _bondSize, uint256 _amount) {
    vm.assume(_amountPerPledger > 0 && _amountPerPledger < type(uint128).max);
    vm.assume(_winningPledgersLength > 0 && _winningPledgersLength < 1000);
    vm.assume(_amount > _amountPerPledger * _winningPledgersLength);

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
    vm.mockCall(
      address(oracle), abi.encodeWithSelector(IOracle.disputeCreatedAt.selector, _mockDisputeId), abi.encode(1)
    );

    // Mock and expect the call to oracle checking if the module is allowed
    _mockAndExpect(
      address(oracle),
      abi.encodeCall(IOracle.allowedModule, (_mockRequestId, address(bondEscalationModule))),
      abi.encode(true)
    );

    horizonAccountingExtension.setAuthorizedCallerForTest(address(bondEscalationModule));

    vm.startPrank(address(bondEscalationModule));

    _;
  }

  function test_revertIfUnauthorizedCaller(uint256 _amountPerPledger, uint256 _winningPledgersLength) public {
    vm.expectRevert(IHorizonAccountingExtension.HorizonAccountingExtension_UnauthorizedCaller.selector);

    vm.prank(address(bondEscalationModule));
    horizonAccountingExtension.onSettleBondEscalation(
      mockRequest, mockDispute, _amountPerPledger, _winningPledgersLength
    );
  }

  function test_revertIfDisallowedModule(uint256 _amountPerPledger, uint256 _winningPledgersLength) public {
    vm.mockCall(
      address(oracle), abi.encodeWithSelector(IOracle.disputeCreatedAt.selector, _mockDisputeId), abi.encode(1)
    );

    horizonAccountingExtension.setAuthorizedCallerForTest(address(bondEscalationModule));

    // Mock and expect the call to oracle checking if the module is allowed
    _mockAndExpect(
      address(oracle),
      abi.encodeCall(IOracle.allowedModule, (_mockRequestId, address(bondEscalationModule))),
      abi.encode(false)
    );

    // Check: does it revert if the module is not allowed?
    vm.expectRevert(IHorizonAccountingExtension.HorizonAccountingExtension_UnauthorizedModule.selector);

    vm.prank(address(bondEscalationModule));
    horizonAccountingExtension.onSettleBondEscalation(
      mockRequest, mockDispute, _amountPerPledger, _winningPledgersLength
    );
  }

  function test_revertIfInsufficientFunds(
    uint128 _amountPerPledger,
    uint128 _winningPledgersLength,
    uint128 _amount
  ) public {
    vm.assume(_amountPerPledger > 0 && _winningPledgersLength > 0);
    vm.assume(_amountPerPledger > _amount);

    // Mock and expect the call to oracle checking if the dispute exists
    vm.mockCall(
      address(oracle), abi.encodeWithSelector(IOracle.disputeCreatedAt.selector, _mockDisputeId), abi.encode(1)
    );

    // Mock and expect the call to oracle checking if the module is allowed
    _mockAndExpect(
      address(oracle),
      abi.encodeCall(IOracle.allowedModule, (_mockRequestId, address(bondEscalationModule))),
      abi.encode(true)
    );

    horizonAccountingExtension.setAuthorizedCallerForTest(address(bondEscalationModule));

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
    uint256 _bondSize,
    uint256 _amount
  ) public happyPath(_amountPerPledger, _winningPledgersLength, _bondSize, _amount) {
    horizonAccountingExtension.setEscalationResultForTest(
      _mockDisputeId, _mockRequestId, _amountPerPledger, _bondSize, IBondEscalationModule(address(bondEscalationModule))
    );

    horizonAccountingExtension.setPledgedForTest(_mockDisputeId, _amount);

    horizonAccountingExtension.setAuthorizedCallerForTest(address(bondEscalationModule));

    // Check: does it revert if the escalation is already settled?
    vm.expectRevert(IHorizonAccountingExtension.HorizonAccountingExtension_AlreadySettled.selector);

    horizonAccountingExtension.onSettleBondEscalation(
      mockRequest, mockDispute, _amountPerPledger, _winningPledgersLength
    );
  }

  function test_successfulCall(
    uint256 _amountPerPledger,
    uint256 _winningPledgersLength,
    uint256 _bondSize,
    uint256 _amount
  ) public happyPath(_amountPerPledger, _winningPledgersLength, _bondSize, _amount) {
    horizonAccountingExtension.setPledgedForTest(_mockDisputeId, _amount);

    vm.expectEmit();
    emit BondEscalationSettled(_mockRequestId, _mockDisputeId, _amountPerPledger, _winningPledgersLength);

    horizonAccountingExtension.onSettleBondEscalation({
      _request: mockRequest,
      _dispute: mockDispute,
      _amountPerPledger: _amountPerPledger,
      _winningPledgersLength: _winningPledgersLength
    });

    (
      bytes32 _requestIdSaved,
      uint256 _amountPerPledgerSaved,
      uint256 _bondSizeSaved,
      IBondEscalationModule _bondEscalationModule
    ) = horizonAccountingExtension.escalationResults(_mockDisputeId);

    assertEq(_requestIdSaved, _mockRequestId);
    assertEq(_amountPerPledgerSaved, _amountPerPledger);
    assertEq(address(_bondEscalationModule), address(bondEscalationModule));
    assertEq(_bondSizeSaved, _bondSize);
  }
}

contract HorizonAccountingExtension_Unit_ClaimEscalationReward is HorizonAccountingExtension_Unit_BaseTest {
  modifier happyPath(uint256 _pledgesForDispute, uint256 _pledgesAgainstDispute, uint256 _bondSize, uint256 _amount) {
    vm.assume(_pledgesForDispute > 0 && _pledgesForDispute < type(uint64).max);
    vm.assume(_pledgesAgainstDispute > 0 && _pledgesAgainstDispute < type(uint64).max);
    vm.assume(_amount > type(uint16).max && _amount < type(uint64).max);
    vm.assume(_bondSize > 0 && _bondSize < type(uint16).max);

    horizonAccountingExtension.setEscalationResultForTest(
      _mockDisputeId, _mockRequestId, _amount, _bondSize, bondEscalationModule
    );

    _;
  }

  function test_revertIfNoEscalationResult(address _pledger) public {
    vm.expectRevert(IHorizonAccountingExtension.HorizonAccountingExtension_NoEscalationResult.selector);
    horizonAccountingExtension.claimEscalationReward(_mockDisputeId, _pledger);
  }

  function test_revertIfAlreadyClaimed(
    address _pledger,
    uint256 _pledgesForDispute,
    uint256 _pledgesAgainstDispute,
    uint256 _bondSize,
    uint256 _amount
  ) public happyPath(_pledgesForDispute, _pledgesAgainstDispute, _bondSize, _amount) {
    horizonAccountingExtension.setPledgerClaimedForTest(_mockRequestId, _pledger, true);

    vm.expectRevert(IHorizonAccountingExtension.HorizonAccountingExtension_AlreadyClaimed.selector);
    horizonAccountingExtension.claimEscalationReward(_mockDisputeId, _pledger);
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
      abi.encodeWithSelector(IOracle.disputeStatus.selector, _mockDisputeId),
      abi.encode(IOracle.DisputeStatus.NoResolution)
    );

    _mockAndExpect(
      address(bondEscalationModule),
      abi.encodeWithSelector(IBondEscalationModule.pledgesForDispute.selector, _mockRequestId, _pledger),
      abi.encode(_pledgesForDispute)
    );

    _mockAndExpect(
      address(bondEscalationModule),
      abi.encodeWithSelector(IBondEscalationModule.pledgesAgainstDispute.selector, _mockRequestId, _pledger),
      abi.encode(_pledgesAgainstDispute)
    );

    horizonAccountingExtension.setBondedTokensForTest(
      _pledger, _bondSize * (_pledgesForDispute + _pledgesAgainstDispute)
    );
    horizonAccountingExtension.setPledgedForTest(
      _mockDisputeId, _amount * (_pledgesForDispute + _pledgesAgainstDispute)
    );

    vm.expectEmit();
    emit EscalationRewardClaimed(
      _mockRequestId, _mockDisputeId, _pledger, 0, _bondSize * (_pledgesForDispute + _pledgesAgainstDispute)
    );

    horizonAccountingExtension.claimEscalationReward(_mockDisputeId, _pledger);
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
      abi.encodeWithSelector(IOracle.disputeStatus.selector, _mockDisputeId),
      abi.encode(IOracle.DisputeStatus.Won)
    );

    _mockAndExpect(
      address(bondEscalationModule),
      abi.encodeWithSelector(IBondEscalationModule.pledgesForDispute.selector, _mockRequestId, _pledger),
      abi.encode(_pledgesForDispute)
    );

    vm.mockCall(
      address(grt),
      abi.encodeWithSelector(IERC20.balanceOf.selector),
      abi.encode(_amount * (_pledgesForDispute + _pledgesAgainstDispute))
    );

    // Mock and expect the transfer of the GRT tokens
    _mockAndExpect(
      address(grt),
      abi.encodeWithSelector(
        IERC20.transfer.selector, _pledger, _amount * _pledgesForDispute - _bondSize * _pledgesForDispute
      ),
      abi.encode(true)
    );

    horizonAccountingExtension.setBondedTokensForTest(_pledger, _bondSize * _pledgesForDispute);
    horizonAccountingExtension.setPledgedForTest(_mockDisputeId, _amount * _pledgesForDispute);

    vm.expectEmit();
    emit EscalationRewardClaimed(
      _mockRequestId,
      _mockDisputeId,
      _pledger,
      _amount * _pledgesForDispute - _bondSize * _pledgesForDispute,
      _bondSize * _pledgesForDispute
    );

    horizonAccountingExtension.claimEscalationReward(_mockDisputeId, _pledger);
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
      abi.encodeWithSelector(IOracle.disputeStatus.selector, _mockDisputeId),
      abi.encode(IOracle.DisputeStatus.Lost)
    );

    _mockAndExpect(
      address(bondEscalationModule),
      abi.encodeWithSelector(IBondEscalationModule.pledgesAgainstDispute.selector, _mockRequestId, _pledger),
      abi.encode(_pledgesAgainstDispute)
    );

    vm.mockCall(
      address(grt),
      abi.encodeWithSelector(IERC20.balanceOf.selector),
      abi.encode(_amount * (_pledgesForDispute + _pledgesAgainstDispute))
    );

    // Mock and expect the transfer of the GRT tokens
    _mockAndExpect(
      address(grt),
      abi.encodeWithSelector(
        IERC20.transfer.selector, _pledger, _amount * _pledgesAgainstDispute - _bondSize * _pledgesAgainstDispute
      ),
      abi.encode(true)
    );

    horizonAccountingExtension.setBondedTokensForTest(_pledger, _bondSize * _pledgesAgainstDispute);
    horizonAccountingExtension.setPledgedForTest(_mockDisputeId, _amount * _pledgesAgainstDispute);

    vm.expectEmit();
    emit EscalationRewardClaimed(
      _mockRequestId,
      _mockDisputeId,
      _pledger,
      _amount * _pledgesAgainstDispute - _bondSize * _pledgesAgainstDispute,
      _bondSize * _pledgesAgainstDispute
    );

    horizonAccountingExtension.claimEscalationReward(_mockDisputeId, _pledger);
  }

  function test_successfulCallWinForDisputeSlashing(
    address _pledger,
    address _slashedUser,
    address _notSlashedUser,
    uint256 _pledgesForDispute,
    uint256 _pledgesAgainstDispute,
    uint256 _bondSize,
    uint256 _amount
  ) public happyPath(_pledgesForDispute, _pledgesAgainstDispute, _bondSize, _amount) {
    vm.assume(_pledger != _slashedUser);
    vm.assume(_slashedUser != _notSlashedUser);
    // Mock and expect the call to oracle checking the dispute status
    _mockAndExpect(
      address(oracle),
      abi.encodeWithSelector(IOracle.disputeStatus.selector, _mockDisputeId),
      abi.encode(IOracle.DisputeStatus.Won)
    );

    _mockAndExpect(
      address(bondEscalationModule),
      abi.encodeWithSelector(IBondEscalationModule.pledgesForDispute.selector, _mockRequestId, _pledger),
      abi.encode(_pledgesForDispute)
    );

    _mockAndExpect(
      address(bondEscalationModule),
      abi.encodeWithSelector(IBondEscalationModule.pledgesAgainstDispute.selector, _mockRequestId, _notSlashedUser),
      abi.encode(0)
    );

    _mockAndExpect(
      address(bondEscalationModule),
      abi.encodeWithSelector(IBondEscalationModule.pledgesAgainstDispute.selector, _mockRequestId, _slashedUser),
      abi.encode(_pledgesForDispute * _amount / _bondSize + 1)
    );

    _mockAndExpect(
      address(horizonAccountingExtension.HORIZON_STAKING()),
      abi.encodeWithSelector(IHorizonStaking.slash.selector),
      abi.encode(true)
    );

    vm.mockCall(address(grt), abi.encodeWithSelector(IERC20.balanceOf.selector), abi.encode(0));

    // Mock and expect the transfer of the GRT tokens
    vm.mockCall(
      address(grt),
      abi.encodeWithSelector(
        IERC20.transfer.selector, _pledger, (_amount * _pledgesForDispute) - (_bondSize * _pledgesForDispute)
      ),
      abi.encode(true)
    );

    horizonAccountingExtension.setBondedTokensForTest(_pledger, _bondSize * _pledgesForDispute);

    horizonAccountingExtension.setPledgersForTest(_mockDisputeId, _notSlashedUser);
    horizonAccountingExtension.setPledgersForTest(_mockDisputeId, _slashedUser);
    horizonAccountingExtension.setPledgedForTest(_mockDisputeId, _pledgesForDispute * _amount * _bondSize);

    vm.expectEmit();
    emit EscalationRewardClaimed(
      _mockRequestId,
      _mockDisputeId,
      _pledger,
      (_amount * _pledgesForDispute) - (_bondSize * _pledgesForDispute),
      _bondSize * _pledgesForDispute
    );

    horizonAccountingExtension.claimEscalationReward(_mockDisputeId, _pledger);
  }

  function test_successfulCallLostAgainstDisputeSlashing(
    address _pledger,
    address _slashedUser,
    address _notSlashedUser,
    uint256 _pledgesForDispute,
    uint256 _pledgesAgainstDispute,
    uint256 _bondSize,
    uint256 _amount
  ) public happyPath(_pledgesForDispute, _pledgesAgainstDispute, _bondSize, _amount) {
    vm.assume(_pledger != _slashedUser);
    vm.assume(_slashedUser != _notSlashedUser);
    // Mock and expect the call to oracle checking the dispute status
    _mockAndExpect(
      address(oracle),
      abi.encodeWithSelector(IOracle.disputeStatus.selector, _mockDisputeId),
      abi.encode(IOracle.DisputeStatus.Lost)
    );

    _mockAndExpect(
      address(bondEscalationModule),
      abi.encodeWithSelector(IBondEscalationModule.pledgesAgainstDispute.selector, _mockRequestId, _pledger),
      abi.encode(_pledgesAgainstDispute)
    );

    _mockAndExpect(
      address(bondEscalationModule),
      abi.encodeWithSelector(IBondEscalationModule.pledgesForDispute.selector, _mockRequestId, _notSlashedUser),
      abi.encode(0)
    );

    _mockAndExpect(
      address(bondEscalationModule),
      abi.encodeWithSelector(IBondEscalationModule.pledgesForDispute.selector, _mockRequestId, _slashedUser),
      abi.encode(_pledgesAgainstDispute * _amount / _bondSize + 1)
    );

    _mockAndExpect(
      address(horizonAccountingExtension.HORIZON_STAKING()),
      abi.encodeWithSelector(IHorizonStaking.slash.selector),
      abi.encode(true)
    );

    vm.mockCall(address(grt), abi.encodeWithSelector(IERC20.balanceOf.selector), abi.encode(0));

    // Mock and expect the transfer of the GRT tokens
    vm.mockCall(
      address(grt),
      abi.encodeWithSelector(
        IERC20.transfer.selector, _pledger, (_amount * _pledgesAgainstDispute) - (_bondSize * _pledgesAgainstDispute)
      ),
      abi.encode(true)
    );

    horizonAccountingExtension.setBondedTokensForTest(_pledger, _bondSize * _pledgesAgainstDispute);

    horizonAccountingExtension.setPledgersForTest(_mockDisputeId, _notSlashedUser);
    horizonAccountingExtension.setPledgersForTest(_mockDisputeId, _slashedUser);
    horizonAccountingExtension.setPledgedForTest(_mockDisputeId, _pledgesAgainstDispute * _amount * _bondSize);

    vm.expectEmit();
    emit EscalationRewardClaimed(
      _mockRequestId,
      _mockDisputeId,
      _pledger,
      (_amount * _pledgesAgainstDispute) - (_bondSize * _pledgesAgainstDispute),
      _bondSize * _pledgesAgainstDispute
    );

    horizonAccountingExtension.claimEscalationReward(_mockDisputeId, _pledger);
  }
}

contract HorizonAccountingExtension_Unit_ReleasePledge is HorizonAccountingExtension_Unit_BaseTest {
  modifier happyPath(address _pledger, uint256 _amount, uint256 _amountPledge) {
    vm.assume(_amount > 0);
    vm.assume(_amountPledge > _amount);

    horizonAccountingExtension.setPledgedForTest(_mockDisputeId, _amountPledge);
    horizonAccountingExtension.setBondedTokensForTest(_pledger, _amount);

    vm.mockCall(
      address(oracle), abi.encodeWithSelector(IOracle.disputeCreatedAt.selector, _mockDisputeId), abi.encode(1)
    );

    // Mock and expect the call to oracle checking if the module is allowed
    _mockAndExpect(
      address(oracle), abi.encodeCall(IOracle.allowedModule, (_mockRequestId, authorizedCaller)), abi.encode(true)
    );

    vm.startPrank(authorizedCaller);
    _;
  }

  function test_revertIfUnauthorizedCaller(address _pledger, uint256 _amount) public {
    vm.expectRevert(IHorizonAccountingExtension.HorizonAccountingExtension_UnauthorizedCaller.selector);

    vm.prank(address(bondEscalationModule));
    horizonAccountingExtension.releasePledge(mockRequest, mockDispute, _pledger, _amount);
  }

  function test_revertIfDisallowedModule(address _pledger, uint256 _amount) public {
    vm.mockCall(
      address(oracle), abi.encodeWithSelector(IOracle.disputeCreatedAt.selector, _mockDisputeId), abi.encode(1)
    );

    // Mock and expect the call to oracle checking if the module is allowed
    _mockAndExpect(
      address(oracle), abi.encodeCall(IOracle.allowedModule, (_mockRequestId, authorizedCaller)), abi.encode(false)
    );

    // Check: does it revert if the module is not allowed?
    vm.expectRevert(IHorizonAccountingExtension.HorizonAccountingExtension_UnauthorizedModule.selector);

    vm.prank(authorizedCaller);
    horizonAccountingExtension.releasePledge(mockRequest, mockDispute, _pledger, _amount);
  }

  function test_revertIfInsufficientFunds(
    address _pledger,
    uint256 _amount,
    uint256 _amountPledge
  ) public happyPath(_pledger, _amount, _amountPledge) {
    horizonAccountingExtension.setPledgedForTest(_mockDisputeId, 0);

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
    emit PledgeReleased(_mockRequestId, _mockDisputeId, _pledger, _amount);

    horizonAccountingExtension.releasePledge(mockRequest, mockDispute, _pledger, _amount);

    uint256 _pledgesAfter = horizonAccountingExtension.pledges(_mockDisputeId);
    uint256 _totalBondedAfter = horizonAccountingExtension.totalBonded(_pledger);

    assertEq(_pledgesAfter, _amountPledge - _amount);
    assertEq(_totalBondedAfter, _amount - _amount);
  }
}

contract HorizonAccountingExtension_Unit_Pay is HorizonAccountingExtension_Unit_BaseTest {
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

  function test_successfulCall(
    bytes32 _requestId,
    address _payer,
    address _receiver,
    uint256 _amount,
    uint256 _bonded
  ) public {
    vm.assume(_bonded > _amount);
    vm.assume(_payer != _receiver);

    // Mock and expect the call to oracle checking if the module is allowed
    _mockAndExpect(
      address(oracle), abi.encodeCall(IOracle.allowedModule, (_requestId, address(this))), abi.encode(true)
    );
    _mockAndExpect(address(oracle), abi.encodeCall(IOracle.isParticipant, (_requestId, _payer)), abi.encode(true));
    _mockAndExpect(address(oracle), abi.encodeCall(IOracle.isParticipant, (_requestId, _receiver)), abi.encode(true));

    _mockAndExpect(
      address(horizonStaking),
      abi.encodeCall(IHorizonStaking.slash, (_payer, _amount, _amount, _receiver)),
      abi.encode(true)
    );

    horizonAccountingExtension.setBondedTokensForTest(_payer, _bonded);
    horizonAccountingExtension.setBondedForRequestForTest(_payer, _requestId, _bonded);

    vm.expectEmit();
    emit Paid(_requestId, _receiver, _payer, _amount);

    horizonAccountingExtension.pay(_requestId, _payer, _receiver, _amount);

    uint256 _bondedAfter = horizonAccountingExtension.bondedForRequest(_payer, _requestId);
    uint256 _totalBondedAfter = horizonAccountingExtension.totalBonded(_payer);

    assertEq(_bondedAfter, _bonded - _amount);
    assertEq(_totalBondedAfter, _bonded - _amount);
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
    _provision.maxVerifierCut = uint32(horizonAccountingExtension.MAX_VERIFIER_CUT());
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

  function test_revertIfInvalidMaxVerifierCut(
    address _bonder,
    bytes32 _requestId,
    uint256 _amount
  ) public happyPath(_bonder, _requestId, _amount) {
    _provision.maxVerifierCut = 0;

    _mockAndExpect(
      address(horizonStaking),
      abi.encodeCall(IHorizonStaking.getProvision, (_bonder, address(horizonAccountingExtension))),
      abi.encode(_provision)
    );

    vm.expectRevert(IHorizonAccountingExtension.HorizonAccountingExtension_InvalidMaxVerifierCut.selector);

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

    _provision.tokens = _amount;
    _provision.thawingPeriod = uint64(horizonAccountingExtension.MIN_THAWING_PERIOD());
    _provision.maxVerifierCut = uint32(horizonAccountingExtension.MAX_VERIFIER_CUT());

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
    vm.assume(_sender != address(this));

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

  function test_revertIfInvalidMaxVerifierCut(
    address _bonder,
    bytes32 _requestId,
    uint256 _amount,
    address _sender
  ) public happyPath(_bonder, _requestId, _amount, _sender) {
    _provision.maxVerifierCut = 0;

    _mockAndExpect(
      address(horizonStaking),
      abi.encodeCall(IHorizonStaking.getProvision, (_bonder, address(horizonAccountingExtension))),
      abi.encode(_provision)
    );

    vm.expectRevert(IHorizonAccountingExtension.HorizonAccountingExtension_InvalidMaxVerifierCut.selector);

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
    vm.assume(_amount > 0 && _amount < type(uint128).max);
    // Mock and expect the call to oracle checking if the module is allowed
    _mockAndExpect(
      address(oracle), abi.encodeCall(IOracle.allowedModule, (_requestId, address(this))), abi.encode(true)
    );

    _mockAndExpect(address(oracle), abi.encodeCall(IOracle.isParticipant, (_requestId, _bonder)), abi.encode(true));

    horizonAccountingExtension.setBondedForRequestForTest(_bonder, _requestId, _amount);
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

  function test_revertIfInsufficientBondedTokens(
    address _bonder,
    bytes32 _requestId,
    uint256 _amount
  ) public happyPath(_bonder, _requestId, _amount) {
    horizonAccountingExtension.setBondedTokensForTest(_bonder, 0);

    vm.expectRevert(IHorizonAccountingExtension.HorizonAccountingExtension_InsufficientBondedTokens.selector);

    horizonAccountingExtension.release(_bonder, _requestId, _amount);
  }

  function test_successfulCall(
    address _bonder,
    bytes32 _requestId,
    uint256 _amount
  ) public happyPath(_bonder, _requestId, _amount) {
    horizonAccountingExtension.setBondedTokensForTest(_bonder, _amount);

    vm.expectEmit();
    emit Released(_requestId, _bonder, _amount);

    horizonAccountingExtension.release(_bonder, _requestId, _amount);

    uint256 _bondedForRequestAfter = horizonAccountingExtension.bondedForRequest(_bonder, _requestId);
    uint256 _totalBondedAfter = horizonAccountingExtension.totalBonded(_bonder);

    assertEq(_bondedForRequestAfter, 0);
    assertEq(_totalBondedAfter, 0);
  }
}

contract HorizonAccountingExtension_Unit_Slash is HorizonAccountingExtension_Unit_BaseTest {
  using EnumerableSet for EnumerableSet.AddressSet;

  EnumerableSet.AddressSet internal _cleanPledgers;

  modifier happyPath(
    uint256 _usersToSlash,
    uint256 _maxUsersToCheck,
    address[] memory _users,
    uint256 _pledgesForDispute,
    uint256 _bondSize
  ) {
    vm.assume(_usersToSlash > 0 && _usersToSlash < type(uint16).max);
    vm.assume(_maxUsersToCheck > 0 && _maxUsersToCheck < type(uint16).max);
    vm.assume(_users.length > 0 && _users.length < type(uint16).max);
    vm.assume(_pledgesForDispute > 0 && _pledgesForDispute < type(uint16).max);
    vm.assume(_bondSize > 0 && _bondSize < type(uint16).max);

    for (uint256 _i; _i < _users.length; _i++) {
      horizonAccountingExtension.setPledgersForTest(_mockDisputeId, _users[_i]);
      _cleanPledgers.add(_users[_i]);
    }

    for (uint256 _i; _i < _cleanPledgers.length(); _i++) {
      assertEq(horizonAccountingExtension.getPledgerForTest(_mockDisputeId, _i), _cleanPledgers.at(_i));
    }

    horizonAccountingExtension.setEscalationResultForTest(
      _mockDisputeId, _mockRequestId, 1, _bondSize, bondEscalationModule
    );
    _;
  }

  function test_revertIfNoEscalationResult(uint256 _usersToSlash, uint256 _maxUsersToCheck, address _pledger) public {
    vm.assume(_usersToSlash > 0 && _usersToSlash < type(uint16).max);
    vm.assume(_maxUsersToCheck > 0 && _maxUsersToCheck < type(uint16).max);

    horizonAccountingExtension.setPledgersForTest(_mockDisputeId, _pledger);
    // Check: does it revert if the module is not allowed?
    vm.expectRevert(IHorizonAccountingExtension.HorizonAccountingExtension_NoEscalationResult.selector);

    horizonAccountingExtension.slash(_mockDisputeId, _usersToSlash, _maxUsersToCheck);
  }

  function test_successfulCallResultionWon(
    uint256 _usersToSlash,
    uint256 _maxUsersToCheck,
    address[] memory _users,
    uint256 _pledgesAgainstDispute,
    uint256 _bondSize
  ) public happyPath(_usersToSlash, _maxUsersToCheck, _users, _pledgesAgainstDispute, _bondSize) {
    // Mock and expect the call to oracle checking the dispute status
    _mockAndExpect(
      address(oracle),
      abi.encodeWithSelector(IOracle.disputeStatus.selector, _mockDisputeId),
      abi.encode(IOracle.DisputeStatus.Won)
    );

    uint256 _length = _cleanPledgers.length();

    uint256 _slashAmount;
    for (uint256 _i; _i < _length; _i++) {
      _mockAndExpect(
        address(bondEscalationModule),
        abi.encodeCall(IBondEscalationModule.pledgesAgainstDispute, (_mockRequestId, _cleanPledgers.at(_i))),
        abi.encode(_pledgesAgainstDispute)
      );

      _slashAmount = _pledgesAgainstDispute * _bondSize;

      _mockAndExpect(
        address(horizonStaking),
        abi.encodeCall(
          IHorizonStaking.slash,
          (_cleanPledgers.at(_i), _slashAmount, _slashAmount, address(horizonAccountingExtension))
        ),
        abi.encode(true)
      );
    }

    horizonAccountingExtension.slash(_mockDisputeId, _length, _length);
  }

  function test_successfulCallResultionLost(
    uint256 _usersToSlash,
    uint256 _maxUsersToCheck,
    address[] memory _users,
    uint256 _pledgesForDispute,
    uint256 _bondSize
  ) public happyPath(_usersToSlash, _maxUsersToCheck, _users, _pledgesForDispute, _bondSize) {
    // Mock and expect the call to oracle checking the dispute status
    _mockAndExpect(
      address(oracle),
      abi.encodeWithSelector(IOracle.disputeStatus.selector, _mockDisputeId),
      abi.encode(IOracle.DisputeStatus.Lost)
    );

    uint256 _length = _cleanPledgers.length();

    uint256 _slashAmount;
    for (uint256 _i; _i < _length; _i++) {
      _mockAndExpect(
        address(bondEscalationModule),
        abi.encodeCall(IBondEscalationModule.pledgesForDispute, (_mockRequestId, _cleanPledgers.at(_i))),
        abi.encode(_pledgesForDispute)
      );

      _slashAmount = _pledgesForDispute * _bondSize;

      _mockAndExpect(
        address(horizonStaking),
        abi.encodeCall(
          IHorizonStaking.slash,
          (_cleanPledgers.at(_i), _slashAmount, _slashAmount, address(horizonAccountingExtension))
        ),
        abi.encode(true)
      );
    }

    horizonAccountingExtension.slash(_mockDisputeId, _length, _length);
  }

  function test_successfulCallNoResultion(
    uint256 _usersToSlash,
    uint256 _maxUsersToCheck,
    address[] memory _users,
    uint256 _pledgesForDispute,
    uint256 _bondSize
  ) public happyPath(_usersToSlash, _maxUsersToCheck, _users, _pledgesForDispute, _bondSize) {
    // Mock and expect the call to oracle checking the dispute status
    _mockAndExpect(
      address(oracle),
      abi.encodeWithSelector(IOracle.disputeStatus.selector, _mockDisputeId),
      abi.encode(IOracle.DisputeStatus.NoResolution)
    );

    vm.expectCall(
      address(bondEscalationModule), abi.encodeWithSelector(IBondEscalationModule.pledgeAgainstDispute.selector), 0
    );
    vm.expectCall(address(horizonStaking), abi.encodeWithSelector(IHorizonStaking.slash.selector), 0);

    horizonAccountingExtension.slash(_mockDisputeId, _usersToSlash, _maxUsersToCheck);
  }
}
