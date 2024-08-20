// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.26;

import {IOracle} from '@defi-wonderland/prophet-core/solidity/interfaces/IOracle.sol';
import {IERC20} from '@openzeppelin/contracts/token/ERC20/IERC20.sol';
import {
  HorizonAccountingExtension,
  IHorizonAccountingExtension,
  IHorizonStaking
} from 'contracts/HorizonAccountingExtension.sol';

import 'forge-std/Test.sol';

contract HorizonAccountingExtensionForTest is HorizonAccountingExtension {
  constructor(
    IHorizonStaking _horizonStaking,
    IOracle _oracle,
    uint256 _minThawingPeriod,
    IERC20 _grt
  ) HorizonAccountingExtension(_horizonStaking, _oracle, _minThawingPeriod, _grt) {}

  function setBondedTokens(address _user, uint256 _amount) public {
    totalBonded[_user] = _amount;
  }
}

contract HorizonAccountingExtension_Unit_BaseTest is Test {
  HorizonAccountingExtensionForTest public horizonAccountingExtension;
  IHorizonStaking public horizonStaking;
  address public prophet;

  event Bonded(address indexed user, uint256 amount);
  event Finalized(address indexed user, uint256 amount);

  function setUp() public {
    horizonStaking = IHorizonStaking(makeAddr('HorizonStaking'));
    prophet = makeAddr('Prophet');

    // horizonAccountingExtension = new HorizonAccountingExtensionForTest(horizonStaking, prophet);
  }
}

contract HorizonAccountingExtension_Unit_Constructor is HorizonAccountingExtension_Unit_BaseTest {
  function test_setHorizonStaking() public view {
    assertEq(address(horizonAccountingExtension.HORIZON_STAKING()), address(horizonStaking));
  }

  function test_setProphet() public view {
    assertEq(address(horizonAccountingExtension.ORACLE()), prophet);
  }
}

contract HorizonAccountingExtension_Unit_BondedAction is HorizonAccountingExtension_Unit_BaseTest {
  function test_invalidThawingPeriod(uint256 _bondedAmount) public {
    IHorizonStaking.Provision memory _provisionData;

    vm.mockCall(
      address(horizonStaking),
      abi.encodeWithSelector(horizonStaking.getProvision.selector, address(this), prophet),
      abi.encode(_provisionData)
    );

    vm.expectRevert(
      abi.encodeWithSelector(IHorizonAccountingExtension.HorizonAccountingExtension_InvalidThawingPeriod.selector)
    );

    // horizonAccountingExtension.bondedAction(_bondedAmount);
  }

  function test_insufficientTokens(uint256 _bondedAmount) public {
    vm.assume(_bondedAmount > 0);
    IHorizonStaking.Provision memory _provisionData;
    _provisionData.thawingPeriod = 30 days;

    vm.mockCall(
      address(horizonStaking),
      abi.encodeWithSelector(horizonStaking.getProvision.selector, address(this), prophet),
      abi.encode(_provisionData)
    );

    vm.expectRevert(
      abi.encodeWithSelector(IHorizonAccountingExtension.HorizonAccountingExtension_InsufficientTokens.selector)
    );

    // horizonAccountingExtension.bondedAction(_bondedAmount);
  }

  function test_insufficientBondedTokens(uint128 _bondedAmount, uint128 _tokens, uint128 _tokensThawing) public {
    vm.assume(_tokens > _bondedAmount);
    vm.assume(_bondedAmount > _tokensThawing);

    horizonAccountingExtension.setBondedTokens(address(this), _tokens);

    IHorizonStaking.Provision memory _provisionData;
    _provisionData.thawingPeriod = 30 days;
    _provisionData.tokens = _tokens;
    _provisionData.tokensThawing = _tokensThawing;

    vm.mockCall(
      address(horizonStaking),
      abi.encodeWithSelector(horizonStaking.getProvision.selector, address(this), prophet),
      abi.encode(_provisionData)
    );

    vm.expectRevert(
      abi.encodeWithSelector(IHorizonAccountingExtension.HorizonAccountingExtension_InsufficientBondedTokens.selector)
    );

    // horizonAccountingExtension.bondedAction(_bondedAmount);
  }

  function test_bondedAction(uint128 _bondedAmount, uint128 _tokens) public {
    vm.assume(_tokens > _bondedAmount);

    IHorizonStaking.Provision memory _provisionData;
    _provisionData.thawingPeriod = 30 days;
    _provisionData.tokens = _tokens;

    vm.mockCall(
      address(horizonStaking),
      abi.encodeWithSelector(horizonStaking.getProvision.selector, address(this), prophet),
      abi.encode(_provisionData)
    );

    // horizonAccountingExtension.bondedAction(_bondedAmount);

    assertEq(horizonAccountingExtension.totalBonded(address(this)), _bondedAmount);
  }

  function test_emitBonded(uint128 _bondedAmount, uint128 _tokens) public {
    vm.assume(_tokens > _bondedAmount);

    IHorizonStaking.Provision memory _provisionData;
    _provisionData.thawingPeriod = 30 days;
    _provisionData.tokens = _tokens;

    vm.mockCall(
      address(horizonStaking),
      abi.encodeWithSelector(horizonStaking.getProvision.selector, address(this), prophet),
      abi.encode(_provisionData)
    );

    vm.expectEmit();
    emit Bonded(address(this), _bondedAmount);

    // horizonAccountingExtension.bondedAction(_bondedAmount);
  }
}

contract HorizonAccountingExtension_Unit_Finalize is HorizonAccountingExtension_Unit_BaseTest {
  function test_insufficientBondedTokens(uint128 _bondedAmount) public {
    vm.assume(_bondedAmount > 0);

    vm.expectRevert(
      abi.encodeWithSelector(IHorizonAccountingExtension.HorizonAccountingExtension_InsufficientBondedTokens.selector)
    );

    // horizonAccountingExtension.finalize(_bondedAmount);
  }

  function test_finalize(uint128 _bondedAmount) public {
    vm.assume(_bondedAmount > 0);

    horizonAccountingExtension.setBondedTokens(address(this), _bondedAmount);

    // horizonAccountingExtension.finalize(_bondedAmount);

    assertEq(horizonAccountingExtension.totalBonded(address(this)), 0);
  }

  function test_emitFinalized(uint128 _bondedAmount) public {
    vm.assume(_bondedAmount > 0);

    horizonAccountingExtension.setBondedTokens(address(this), _bondedAmount);

    vm.expectEmit();
    emit Finalized(address(this), _bondedAmount);

    // horizonAccountingExtension.finalize(_bondedAmount);
  }
}
