// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.26;

import {EnumerableSet} from '@openzeppelin/contracts/utils/structs/EnumerableSet.sol';

import {EBORequestCreator, IEBORequestCreator} from 'contracts/EBORequestCreator.sol';

import {Test} from 'forge-std/Test.sol';

contract EBORequestCreatorForTest is EBORequestCreator {
  using EnumerableSet for EnumerableSet.Bytes32Set;

  constructor(address _owner) EBORequestCreator(_owner) {}

  function setPendingOwnerForTest(address _pendingOwner) external {
    pendingOwner = _pendingOwner;
  }

  function setChainIdForTest(string calldata _chainId) external {
    chainIds[_chainId] = true;
  }
}

abstract contract EBORequestCreatorUnitTest is Test {
  /// Events
  event PendingOwnerSetted(address _pendingOwner);
  event OwnerSetted(address _oldOwner, address _newOwner);
  event RequestCreated(uint256 indexed _epoch, string indexed _chainId);
  event ChainAdded(string indexed _chainId);
  event ChainRemoved(string indexed _chainId);
  event RewardSet(uint256 _oldReward, uint256 _newReward);

  /// Contracts
  EBORequestCreatorForTest public eboRequestCreator;
  // IOracle public oracle;

  /// EOAs
  address public owner;

  function setUp() external {
    owner = makeAddr('Owner');
    // oracle = IOracle(makeAddr('Oracle'));

    vm.prank(owner);
    eboRequestCreator = new EBORequestCreatorForTest(owner);
  }

  function _revertIfNotOwner() internal {
    vm.expectRevert(IEBORequestCreator.EBORequestCreator_OnlyOwner.selector);
  }
}

contract UnitEBORequestCreatorConstructor is EBORequestCreatorUnitTest {
  function testConstructor() external view {
    assertEq(eboRequestCreator.reward(), 0);
    assertEq(eboRequestCreator.owner(), owner);
    assertEq(eboRequestCreator.pendingOwner(), address(0));
    // assertEq(eboRequestCreator.oracle(), oracle);
  }
}

contract UnitEBORequestCreatorSetPendingOwner is EBORequestCreatorUnitTest {
  modifier happyPath(address _pendingOwner) {
    vm.startPrank(owner);
    _;
  }

  function testRevertIfNotOwner(address _pendingOwner) external {
    _revertIfNotOwner();
    eboRequestCreator.setPendingOwner(_pendingOwner);
  }

  function testSetPendingOwner(address _pendingOwner) external happyPath(_pendingOwner) {
    eboRequestCreator.setPendingOwner(_pendingOwner);

    assertEq(eboRequestCreator.pendingOwner(), _pendingOwner);
  }

  function testEmitPendingOwnerSetted(address _pendingOwner) external happyPath(_pendingOwner) {
    vm.expectEmit();
    emit PendingOwnerSetted(_pendingOwner);

    eboRequestCreator.setPendingOwner(_pendingOwner);
  }
}

contract UnitEBORequestCreatorAcceptPendingOwner is EBORequestCreatorUnitTest {
  modifier happyPath(address _pendingOwner) {
    eboRequestCreator.setPendingOwnerForTest(_pendingOwner);
    vm.startPrank(_pendingOwner);
    _;
  }

  function testRevertIfNotPendingOwner(address _pendingOwner) external {
    vm.expectRevert(IEBORequestCreator.EBORequestCreator_OnlyPendingOwner.selector);
    eboRequestCreator.acceptPendingOwner();
  }

  function testAcceptPendingOwner(address _pendingOwner) external happyPath(_pendingOwner) {
    eboRequestCreator.acceptPendingOwner();

    assertEq(eboRequestCreator.owner(), _pendingOwner);
    assertEq(eboRequestCreator.pendingOwner(), address(0));
  }

  function testEmitOwnerSetted(address _pendingOwner) external happyPath(_pendingOwner) {
    vm.expectEmit();
    emit OwnerSetted(owner, _pendingOwner);

    eboRequestCreator.acceptPendingOwner();
  }
}

//   contract UnitEBORequestCreatorCreateRequest is EBORequestCreatorUnitTest {
//     function test_CreateRequest() external {
//       bytes32 requestId = eboRequestCreator.createRequest(address(this), address(this), '0x', 0, 0);
//       assertEq(uint256(requestId), uint256(keccak256(abi.encodePacked(address(this), address(this), '0x', 0, 0)));
//     }
//   }

contract UnitEBORequestCreatorAddChain is EBORequestCreatorUnitTest {
  modifier happyPath() {
    vm.startPrank(owner);
    _;
  }

  function testRevertIfNotOwner(string calldata _chainId) external {
    _revertIfNotOwner();
    eboRequestCreator.addChain(_chainId);
  }

  function testRevertIfChainAdded(string calldata _chainId) external happyPath {
    eboRequestCreator.setChainIdForTest(_chainId);

    vm.expectRevert(abi.encodeWithSelector(IEBORequestCreator.EBORequestCreator_ChainAlreadyAdded.selector));
    eboRequestCreator.addChain(_chainId);
  }

  function testAddChain(string calldata _chainId) external happyPath {
    eboRequestCreator.addChain(_chainId);

    assertEq(eboRequestCreator.chainIds(_chainId), true);
  }

  function testEmitChainAdded(string calldata _chainId) external happyPath {
    vm.expectEmit();
    emit ChainAdded(_chainId);

    eboRequestCreator.addChain(_chainId);
  }
}

contract UnitEBORequestCreatorRemoveChain is EBORequestCreatorUnitTest {
  modifier happyPath(string calldata _chainId) {
    eboRequestCreator.setChainIdForTest(_chainId);
    vm.startPrank(owner);
    _;
  }

  function testRevertIfNotOwner(string calldata _chainId) external {
    _revertIfNotOwner();
    eboRequestCreator.removeChain(_chainId);
  }

  function testRevertIfChainNotAdded(string calldata _chainId) external {
    vm.expectRevert(abi.encodeWithSelector(IEBORequestCreator.EBORequestCreator_ChainNotAdded.selector));

    vm.prank(owner);
    eboRequestCreator.removeChain(_chainId);
  }

  function testRemoveChain(string calldata _chainId) external happyPath(_chainId) {
    eboRequestCreator.removeChain(_chainId);

    assertEq(eboRequestCreator.chainIds(_chainId), false);
  }

  function testEmitChainRemoved(string calldata _chainId) external happyPath(_chainId) {
    vm.expectEmit();
    emit ChainRemoved(_chainId);

    eboRequestCreator.removeChain(_chainId);
  }
}

contract UnitEBORequestCreatorSetReward is EBORequestCreatorUnitTest {
  modifier happyPath(uint256 _reward) {
    vm.startPrank(owner);
    _;
  }

  function testRevertIfNotOwner(uint256 _reward) external {
    vm.expectRevert();
    eboRequestCreator.setReward(_reward);
  }

  function testSetReward(uint256 _reward) external happyPath(_reward) {
    eboRequestCreator.setReward(_reward);

    assertEq(eboRequestCreator.reward(), _reward);
  }

  function testEmitRewardSet(uint256 _reward) external happyPath(_reward) {
    vm.expectEmit();
    emit RewardSet(0, _reward);

    eboRequestCreator.setReward(_reward);
  }
}
