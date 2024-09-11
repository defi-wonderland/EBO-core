// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.26;

import {IArbitrable} from 'interfaces/IArbitrable.sol';

import {Arbitrable} from 'contracts/Arbitrable.sol';

import 'forge-std/Test.sol';

contract MockArbitrable is Arbitrable {
  constructor(address _arbitrator, address _council) Arbitrable(_arbitrator, _council) {}

  // solhint-disable-next-line no-empty-blocks
  function mock_onlyArbitrator() external {
    isArbitrator(msg.sender);
  }

  // solhint-disable-next-line no-empty-blocks
  function mock_onlyCouncil() external onlyCouncil {}

  // solhint-disable-next-line no-empty-blocks
  function mock_onlyPendingCouncil() external onlyPendingCouncil {}
}

contract Arbitrable_Unit_BaseTest is Test {
  using stdStorage for StdStorage;

  MockArbitrable public arbitrable;

  address public arbitrator;
  address public council;
  address public pendingCouncil;

  event SetArbitrator(address indexed _arbitrator);
  event SetCouncil(address indexed _council);
  event SetPendingCouncil(address indexed _pendingCouncil);

  function setUp() public {
    arbitrator = makeAddr('Arbitrator');
    council = makeAddr('Council');
    pendingCouncil = makeAddr('PendingCouncil');

    arbitrable = new MockArbitrable(arbitrator, council);
  }

  function _mockPendingCouncil(address _pendingCouncil) internal {
    stdstore.target(address(arbitrable)).sig(IArbitrable.pendingCouncil.selector).checked_write(_pendingCouncil);
  }
}

contract Arbitrable_Unit_Constructor is Arbitrable_Unit_BaseTest {
  function test_setArbitrator(address _arbitrator, address _council) public {
    arbitrable = new MockArbitrable(_arbitrator, _council);

    assertEq(arbitrable.arbitrator(), _arbitrator);
  }

  function test_emitSetArbitrator(address _arbitrator, address _council) public {
    vm.expectEmit();
    emit SetArbitrator(_arbitrator);
    new MockArbitrable(_arbitrator, _council);
  }

  function test_setCouncil(address _arbitrator, address _council) public {
    arbitrable = new MockArbitrable(_arbitrator, _council);

    assertEq(arbitrable.council(), _council);
  }

  function test_emitSetCouncil(address _arbitrator, address _council) public {
    vm.expectEmit();
    emit SetCouncil(_council);
    new MockArbitrable(_arbitrator, _council);
  }
}

contract Arbitrable_Unit_SetArbitrator is Arbitrable_Unit_BaseTest {
  modifier happyPath() {
    vm.startPrank(council);
    _;
  }

  function test_revertOnlyCouncil(address _arbitrator, address _caller) public happyPath {
    vm.assume(_caller != council);
    changePrank(_caller);

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

  function test_revertOnlyCouncil(address _pendingCouncil, address _caller) public happyPath {
    vm.assume(_caller != council);
    changePrank(_caller);

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

  function test_revertOnlyPendingCouncil(address _caller) public happyPath {
    vm.assume(_caller != pendingCouncil);
    changePrank(_caller);

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

  function test_revertOnlyArbitrator(address _caller) public happyPath {
    vm.assume(_caller != arbitrator);
    changePrank(_caller);

    vm.expectRevert(IArbitrable.Arbitrable_OnlyArbitrator.selector);
    arbitrable.mock_onlyArbitrator();
  }

  function test_onlyArbitrator() public happyPath {
    arbitrable.mock_onlyArbitrator();
  }
}

contract Arbitrable_Unit_OnlyCouncil is Arbitrable_Unit_BaseTest {
  modifier happyPath() {
    vm.startPrank(council);
    _;
  }

  function test_revertOnlyCouncil(address _caller) public happyPath {
    vm.assume(_caller != council);
    changePrank(_caller);

    vm.expectRevert(IArbitrable.Arbitrable_OnlyCouncil.selector);
    arbitrable.mock_onlyCouncil();
  }

  function test_onlyCouncil() public happyPath {
    arbitrable.mock_onlyCouncil();
  }
}

contract Arbitrable_Unit_OnlyPendingCouncil is Arbitrable_Unit_BaseTest {
  modifier happyPath() {
    _mockPendingCouncil(pendingCouncil);

    vm.startPrank(pendingCouncil);
    _;
  }

  function test_revertOnlyPendingCouncil(address _caller) public happyPath {
    vm.assume(_caller != pendingCouncil);
    changePrank(_caller);

    vm.expectRevert(IArbitrable.Arbitrable_OnlyPendingCouncil.selector);
    arbitrable.mock_onlyPendingCouncil();
  }

  function test_onlyPendingCouncil() public happyPath {
    arbitrable.mock_onlyPendingCouncil();
  }
}
