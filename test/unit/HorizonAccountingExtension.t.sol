// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.26;

import {EnumerableSet} from '@openzeppelin/contracts/utils/structs/EnumerableSet.sol';
import {Helpers} from 'test/utils/Helpers.sol';

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

  function setBondedTokens(address _user, uint256 _amount) public {
    totalBonded[_user] = _amount;
  }
}

contract HorizonAccountingExtension_Unit_BaseTest is Test, Helpers {
  /// Contracts
  HorizonAccountingExtensionForTest public horizonAccountingExtension;
  IHorizonStaking public horizonStaking;
  IOracle public oracle;
  IERC20 public grt;

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
    (, IOracle.Dispute memory _dispute) = _getResponseAndDispute(oracle);

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
    IHorizonStaking.Provision memory _provisionData;

    (, IOracle.Dispute memory _dispute) = _getResponseAndDispute(oracle);
    bytes32 _requestId = _getId(mockRequest);

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

    IHorizonStaking.Provision memory _provisionData;
    _provisionData.thawingPeriod = 30 days;

    (, IOracle.Dispute memory _dispute) = _getResponseAndDispute(oracle);
    bytes32 _requestId = _getId(mockRequest);

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

    horizonAccountingExtension.setBondedTokens(_pledger, _tokens);

    IHorizonStaking.Provision memory _provisionData;
    _provisionData.thawingPeriod = 30 days;
    _provisionData.tokens = _tokens;

    (, IOracle.Dispute memory _dispute) = _getResponseAndDispute(oracle);
    bytes32 _requestId = _getId(mockRequest);

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

// contract HorizonAccountingExtension_Unit_OnSettleBondEscalation is HorizonAccountingExtension_Unit_BaseTest {
//   function test_revertIfDisallowedModule(uint256 _numOfWinningPledgers, uint256 _amountPerPledger) public {
//     (, IOracle.Dispute memory _dispute) = _getResponseAndDispute(oracle);
//     bytes32 _requestId = _getId(mockRequest);

//     // Mock and expect the call to oracle checking if the module is allowed
//     _mockAndExpect(
//       address(oracle), abi.encodeCall(IOracle.allowedModule, (_requestId, address(this))), abi.encode(false)
//     );

//     // Check: does it revert if the module is not allowed?
//     vm.expectRevert(IAccountingExtension.AccountingExtension_UnauthorizedModule.selector);

//     bondEscalationAccounting.onSettleBondEscalation({
//       _request: mockRequest,
//       _dispute: _dispute,
//       _token: token,
//       _amountPerPledger: _amountPerPledger,
//       _winningPledgersLength: _numOfWinningPledgers
//     });
//   }

//   function test_revertIfAlreadySettled(uint256 _numOfWinningPledgers, uint256 _amountPerPledger) public {
//     bytes32 _requestId = _getId(mockRequest);
//     bytes32 _disputeId = _getId(mockDispute);

//     vm.assume(_amountPerPledger > 0);
//     vm.assume(_numOfWinningPledgers > 0);
//     vm.assume(_amountPerPledger < type(uint256).max / _numOfWinningPledgers);

//     // Mock and expect the call to oracle checking if the module is allowed
//     _mockAndExpect(
//       address(oracle), abi.encodeCall(IOracle.allowedModule, (_requestId, address(this))), abi.encode(true)
//     );

//     // Mock and expect the call to oracle checking if the dispute exists
//     _mockAndExpect(address(oracle), abi.encodeCall(IOracle.disputeCreatedAt, (_disputeId)), abi.encode(1));

//     bondEscalationAccounting.forTest_setEscalationResult(
//       _disputeId, _requestId, token, _amountPerPledger, IBondEscalationModule(address(this))
//     );

//     bondEscalationAccounting.forTest_setPledge(_disputeId, token, _amountPerPledger * _numOfWinningPledgers);

//     // Check: does it revert if the escalation is already settled?
//     vm.expectRevert(IBondEscalationAccounting.BondEscalationAccounting_AlreadySettled.selector);

//     bondEscalationAccounting.onSettleBondEscalation({
//       _request: mockRequest,
//       _dispute: mockDispute,
//       _token: token,
//       _amountPerPledger: _amountPerPledger,
//       _winningPledgersLength: _numOfWinningPledgers
//     });
//   }

//   function test_revertIfInsufficientFunds(uint256 _amountPerPledger, uint256 _numOfWinningPledgers) public {
//     (, IOracle.Dispute memory _dispute) = _getResponseAndDispute(oracle);
//     bytes32 _requestId = _getId(mockRequest);
//     bytes32 _disputeId = _getId(_dispute);

//     // Note, bounding to a max of 30 so that the tests doesn't take forever to run
//     _numOfWinningPledgers = bound(_numOfWinningPledgers, 1, 30);
//     _amountPerPledger = bound(_amountPerPledger, 1, type(uint256).max / _numOfWinningPledgers);

//     // Mock and expect the call to oracle checking if the module is allowed
//     _mockAndExpect(
//       address(oracle), abi.encodeCall(IOracle.allowedModule, (_requestId, address(this))), abi.encode(true)
//     );

//     address[] memory _winningPledgers = _createWinningPledgersArray(_numOfWinningPledgers);

//     uint256 _totalAmountToPay = _amountPerPledger * _winningPledgers.length;
//     uint256 _insufficientPledges = _totalAmountToPay - 1;

//     bondEscalationAccounting.forTest_setPledge(_disputeId, token, _insufficientPledges);

//     // Check: does it revert if the pledger does not have enough funds?
//     vm.expectRevert(IBondEscalationAccounting.BondEscalationAccounting_InsufficientFunds.selector);

//     bondEscalationAccounting.onSettleBondEscalation({
//       _request: mockRequest,
//       _dispute: _dispute,
//       _token: token,
//       _amountPerPledger: _amountPerPledger,
//       _winningPledgersLength: _numOfWinningPledgers
//     });
//   }

//   function test_successfulCall(uint256 _numOfWinningPledgers, uint256 _amountPerPledger) public {
//     (, IOracle.Dispute memory _dispute) = _getResponseAndDispute(oracle);
//     bytes32 _requestId = _getId(mockRequest);
//     bytes32 _disputeId = _getId(_dispute);

//     // Note, bounding to a max of 30 so that the tests doesn't take forever to run
//     _numOfWinningPledgers = bound(_numOfWinningPledgers, 1, 30);
//     _amountPerPledger = bound(_amountPerPledger, 1, type(uint256).max / _numOfWinningPledgers);

//     // Mock and expect the call to oracle checking if the module is allowed
//     _mockAndExpect(
//       address(oracle), abi.encodeCall(IOracle.allowedModule, (_requestId, address(this))), abi.encode(true)
//     );

//     address[] memory _winningPledgers = _createWinningPledgersArray(_numOfWinningPledgers);
//     uint256 _totalAmountToPay = _amountPerPledger * _winningPledgers.length;

//     bondEscalationAccounting.forTest_setPledge(_disputeId, token, _totalAmountToPay);

//     // Check: is the event emitted?
//     vm.expectEmit(true, true, true, true, address(bondEscalationAccounting));
//     emit BondEscalationSettled(_requestId, _disputeId, token, _amountPerPledger, _numOfWinningPledgers);

//     bondEscalationAccounting.onSettleBondEscalation({
//       _request: mockRequest,
//       _dispute: _dispute,
//       _token: token,
//       _amountPerPledger: _amountPerPledger,
//       _winningPledgersLength: _numOfWinningPledgers
//     });

//     (
//       bytes32 _requestIdSaved,
//       IERC20 _token,
//       uint256 _amountPerPledgerSaved,
//       IBondEscalationModule _bondEscalationModule
//     ) = bondEscalationAccounting.escalationResults(_disputeId);

//     // Check: are the escalation results properly stored?
//     assertEq(_requestIdSaved, _requestId);
//     assertEq(address(_token), address(token));
//     assertEq(_amountPerPledgerSaved, _amountPerPledger);
//     assertEq(address(_bondEscalationModule), address(this));
//   }
// }

// contract HorizonAccountingExtension_Unit_BondedAction is HorizonAccountingExtension_Unit_BaseTest {
//   function test_invalidThawingPeriod(uint256 _bondedAmount) public {
//     IHorizonStaking.Provision memory _provisionData;

//     vm.mockCall(
//       address(horizonStaking),
//       abi.encodeWithSelector(horizonStaking.getProvision.selector, address(this), prophet),
//       abi.encode(_provisionData)
//     );

//     vm.expectRevert(
//       abi.encodeWithSelector(IHorizonAccountingExtension.HorizonAccountingExtension_InvalidThawingPeriod.selector)
//     );

//     // horizonAccountingExtension.bondedAction(_bondedAmount);
//   }

//   function test_insufficientTokens(uint256 _bondedAmount) public {
//     vm.assume(_bondedAmount > 0);
//     IHorizonStaking.Provision memory _provisionData;
//     _provisionData.thawingPeriod = 30 days;

//     vm.mockCall(
//       address(horizonStaking),
//       abi.encodeWithSelector(horizonStaking.getProvision.selector, address(this), prophet),
//       abi.encode(_provisionData)
//     );

//     vm.expectRevert(
//       abi.encodeWithSelector(IHorizonAccountingExtension.HorizonAccountingExtension_InsufficientTokens.selector)
//     );

//     // horizonAccountingExtension.bondedAction(_bondedAmount);
//   }

//   function test_insufficientBondedTokens(uint128 _bondedAmount, uint128 _tokens, uint128 _tokensThawing) public {
//     vm.assume(_tokens > _bondedAmount);
//     vm.assume(_bondedAmount > _tokensThawing);

//     horizonAccountingExtension.setBondedTokens(address(this), _tokens);

//     IHorizonStaking.Provision memory _provisionData;
//     _provisionData.thawingPeriod = 30 days;
//     _provisionData.tokens = _tokens;
//     _provisionData.tokensThawing = _tokensThawing;

//     vm.mockCall(
//       address(horizonStaking),
//       abi.encodeWithSelector(horizonStaking.getProvision.selector, address(this), prophet),
//       abi.encode(_provisionData)
//     );

//     vm.expectRevert(
//       abi.encodeWithSelector(IHorizonAccountingExtension.HorizonAccountingExtension_InsufficientBondedTokens.selector)
//     );

//     // horizonAccountingExtension.bondedAction(_bondedAmount);
//   }

//   function test_bondedAction(uint128 _bondedAmount, uint128 _tokens) public {
//     vm.assume(_tokens > _bondedAmount);

//     IHorizonStaking.Provision memory _provisionData;
//     _provisionData.thawingPeriod = 30 days;
//     _provisionData.tokens = _tokens;

//     vm.mockCall(
//       address(horizonStaking),
//       abi.encodeWithSelector(horizonStaking.getProvision.selector, address(this), prophet),
//       abi.encode(_provisionData)
//     );

//     // horizonAccountingExtension.bondedAction(_bondedAmount);

//     assertEq(horizonAccountingExtension.totalBonded(address(this)), _bondedAmount);
//   }

//   function test_emitBonded(uint128 _bondedAmount, uint128 _tokens) public {
//     vm.assume(_tokens > _bondedAmount);

//     IHorizonStaking.Provision memory _provisionData;
//     _provisionData.thawingPeriod = 30 days;
//     _provisionData.tokens = _tokens;

//     vm.mockCall(
//       address(horizonStaking),
//       abi.encodeWithSelector(horizonStaking.getProvision.selector, address(this), prophet),
//       abi.encode(_provisionData)
//     );

//     vm.expectEmit();
//     emit Bonded(address(this), _bondedAmount);

//     // horizonAccountingExtension.bondedAction(_bondedAmount);
//   }
// }

// contract HorizonAccountingExtension_Unit_Finalize is HorizonAccountingExtension_Unit_BaseTest {
//   function test_insufficientBondedTokens(uint128 _bondedAmount) public {
//     vm.assume(_bondedAmount > 0);

//     vm.expectRevert(
//       abi.encodeWithSelector(IHorizonAccountingExtension.HorizonAccountingExtension_InsufficientBondedTokens.selector)
//     );

//     // horizonAccountingExtension.finalize(_bondedAmount);
//   }

//   function test_finalize(uint128 _bondedAmount) public {
//     vm.assume(_bondedAmount > 0);

//     horizonAccountingExtension.setBondedTokens(address(this), _bondedAmount);

//     // horizonAccountingExtension.finalize(_bondedAmount);

//     assertEq(horizonAccountingExtension.totalBonded(address(this)), 0);
//   }

//   function test_emitFinalized(uint128 _bondedAmount) public {
//     vm.assume(_bondedAmount > 0);

//     horizonAccountingExtension.setBondedTokens(address(this), _bondedAmount);

//     vm.expectEmit();
//     emit Finalized(address(this), _bondedAmount);

//     // horizonAccountingExtension.finalize(_bondedAmount);
//   }
// }
