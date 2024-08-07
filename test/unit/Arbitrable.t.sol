// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {IArbitrable} from 'interfaces/IArbitrable.sol';

import {Arbitrable} from 'contracts/Arbitrable.sol';

import 'forge-std/Test.sol';

contract ArbitrableMock is Arbitrable {
  constructor(address _arbitrator, address _council) Arbitrable(_arbitrator, _council) {}

  // solhint-disable-next-line no-empty-blocks
  function mockOnlyArbitrator() external onlyArbitrator {}

  // solhint-disable-next-line no-empty-blocks
  function mockOnlyCouncil() external onlyCouncil {}

  // solhint-disable-next-line no-empty-blocks
  function mockOnlyPendingCouncil() external onlyPendingCouncil {}
}

contract Arbitrable_Unit_BaseTest is Test {
  using stdStorage for StdStorage;

  ArbitrableMock public arbitrable;

  address public arbitrator;
  address public council;
  address public pendingCouncil;

  event SetArbitrator(address _arbitrator);
  event SetCouncil(address _council);
  event SetPendingCouncil(address _pendingCouncil);

  function setUp() public {
    arbitrator = makeAddr('Arbitrator');
    council = makeAddr('Council');
    pendingCouncil = makeAddr('PendingCouncil');

    arbitrable = new ArbitrableMock(arbitrator, council);
  }

  function _mockPendingCouncil(address _pendingCouncil) internal {
    stdstore.target(address(arbitrable)).sig(IArbitrable.pendingCouncil.selector).checked_write(_pendingCouncil);
  }
}

contract Arbitrable_Unit_Constructor is Arbitrable_Unit_BaseTest {
  function test_setArbitrator(address _arbitrator, address _council) public {
    arbitrable = new ArbitrableMock(_arbitrator, _council);

    assertEq(arbitrable.arbitrator(), _arbitrator);
  }

  function test_emitSetArbitrator(address _arbitrator, address _council) public {
    vm.expectEmit();
    emit SetArbitrator(_arbitrator);
    new ArbitrableMock(_arbitrator, _council);
  }

  function test_setCouncil(address _arbitrator, address _council) public {
    arbitrable = new ArbitrableMock(_arbitrator, _council);

    assertEq(arbitrable.council(), _council);
  }

  function test_emitSetCouncil(address _arbitrator, address _council) public {
    vm.expectEmit();
    emit SetCouncil(_council);
    new ArbitrableMock(_arbitrator, _council);
  }
}

contract Arbitrable_Unit_SetArbitrator is Arbitrable_Unit_BaseTest {
  modifier happyPath() {
    vm.startPrank(council);
    _;
  }

  function test_revertOnlyCouncil(address _arbitrator) public happyPath {
    vm.stopPrank();
    vm.expectRevert(IArbitrable.Arbitrable_OnlyCouncil.selector);
    arbitrable.setArbitrator(_arbitrator);
  }

  function test_setArbitrator(address _arbitrator) public happyPath {
    arbitrable.setArbitrator(_arbitrator);

    assertEq(arbitrable.arbitrator(), _arbitrator);
  }

  function test_emitSetArbitrator(address _arbitrator) public happyPath {
    vm.expectEmit();
    emit SetArbitrator(_arbitrator);
    arbitrable.setArbitrator(_arbitrator);
  }
}

contract Arbitrable_Unit_SetPendingCouncil is Arbitrable_Unit_BaseTest {
  modifier happyPath() {
    vm.startPrank(council);
    _;
  }

  function test_revertOnlyCouncil(address _pendingCouncil) public happyPath {
    vm.stopPrank();
    vm.expectRevert(IArbitrable.Arbitrable_OnlyCouncil.selector);
    arbitrable.setPendingCouncil(_pendingCouncil);
  }

  function test_setPendingCouncil(address _pendingCouncil) public happyPath {
    arbitrable.setPendingCouncil(_pendingCouncil);

    assertEq(arbitrable.pendingCouncil(), _pendingCouncil);
  }

  function test_emitSetPendingCouncil(address _pendingCouncil) public happyPath {
    vm.expectEmit();
    emit SetPendingCouncil(_pendingCouncil);
    arbitrable.setPendingCouncil(_pendingCouncil);
  }
}

contract Arbitrable_Unit_ConfirmCouncil is Arbitrable_Unit_BaseTest {
  modifier happyPath() {
    _mockPendingCouncil(pendingCouncil);

    vm.startPrank(pendingCouncil);
    _;
  }

  function test_revertOnlyPendingCouncil() public happyPath {
    vm.stopPrank();
    vm.expectRevert(IArbitrable.Arbitrable_OnlyPendingCouncil.selector);
    arbitrable.confirmCouncil();
  }

  function test_setCouncil() public happyPath {
    arbitrable.confirmCouncil();

    assertEq(arbitrable.council(), pendingCouncil);
  }

  function test_emitSetCouncil() public happyPath {
    vm.expectEmit();
    emit SetCouncil(pendingCouncil);
    arbitrable.confirmCouncil();
  }

  function test_deletePendingCouncil() public happyPath {
    arbitrable.confirmCouncil();

    assertEq(arbitrable.pendingCouncil(), address(0));
  }
}

contract Arbitrable_Unit_OnlyArbitrator is Arbitrable_Unit_BaseTest {
  modifier happyPath() {
    vm.startPrank(arbitrator);
    _;
  }

  function test_revertOnlyArbitrator() public {
    vm.stopPrank();
    vm.expectRevert(IArbitrable.Arbitrable_OnlyArbitrator.selector);
    arbitrable.mockOnlyArbitrator();
  }

  function test_onlyArbitrator() public happyPath {
    arbitrable.mockOnlyArbitrator();
  }
}

contract Arbitrable_Unit_OnlyCouncil is Arbitrable_Unit_BaseTest {
  modifier happyPath() {
    vm.startPrank(council);
    _;
  }

  function test_revertOnlyCouncil() public {
    vm.stopPrank();
    vm.expectRevert(IArbitrable.Arbitrable_OnlyCouncil.selector);
    arbitrable.mockOnlyCouncil();
  }

  function test_onlyCouncil() public happyPath {
    arbitrable.mockOnlyCouncil();
  }
}

contract Arbitrable_Unit_OnlyPendingCouncil is Arbitrable_Unit_BaseTest {
  modifier happyPath() {
    _mockPendingCouncil(pendingCouncil);

    vm.startPrank(pendingCouncil);
    _;
  }

  function test_revertOnlyPendingCouncil() public {
    vm.stopPrank();
    vm.expectRevert(IArbitrable.Arbitrable_OnlyPendingCouncil.selector);
    arbitrable.mockOnlyPendingCouncil();
  }

  function test_onlyPendingCouncil() public happyPath {
    arbitrable.mockOnlyPendingCouncil();
  }
}
