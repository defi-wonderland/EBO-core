// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.26;

import {EnumerableSet} from '@openzeppelin/contracts/utils/structs/EnumerableSet.sol';

import {EBORequestCreator, IEBORequestCreator, IOracle} from 'contracts/EBORequestCreator.sol';

import {Test} from 'forge-std/Test.sol';
import 'forge-std/console.sol';

contract EBORequestCreatorForTest is EBORequestCreator {
  using EnumerableSet for EnumerableSet.Bytes32Set;

  constructor(IOracle _oracle, address _owner) EBORequestCreator(_oracle, _owner) {}

  function setPendingOwnerForTest(address _pendingOwner) external {
    pendingOwner = _pendingOwner;
  }

  function setChainIdForTest(string calldata _chainId) external returns (bool _added) {
    _added = _chainIdsAllowed.add(_encodeChainId(_chainId));
  }
}

abstract contract EBORequestCreatorUnitTest is Test {
  /// Events
  event PendingOwnerSetted(address _pendingOwner);
  event OwnerSetted(address _oldOwner, address _newOwner);
  event RequestCreated(bytes32 indexed _requestId, uint256 indexed _epoch, string indexed _chainId);
  event ChainAdded(string indexed _chainId);
  event ChainRemoved(string indexed _chainId);
  event RewardSet(uint256 _oldReward, uint256 _newReward);

  /// Contracts
  EBORequestCreatorForTest public eboRequestCreator;
  IOracle public oracle;

  /// EOAs
  address public owner;

  function setUp() external {
    owner = makeAddr('Owner');
    oracle = IOracle(makeAddr('Oracle'));

    vm.prank(owner);
    eboRequestCreator = new EBORequestCreatorForTest(oracle, owner);
  }

  function _revertIfNotOwner() internal {
    vm.expectRevert(IEBORequestCreator.EBORequestCreator_OnlyOwner.selector);
  }
}

contract UnitEBORequestCreatorConstructor is EBORequestCreatorUnitTest {
  /**
   * @notice Test the constructor
   */
  function testConstructor() external view {
    assertEq(eboRequestCreator.reward(), 0);
    assertEq(eboRequestCreator.owner(), owner);
    assertEq(eboRequestCreator.pendingOwner(), address(0));
    assertEq(address(eboRequestCreator.oracle()), address(oracle));
  }
}

contract UnitEBORequestCreatorSetPendingOwner is EBORequestCreatorUnitTest {
  modifier happyPath(address _pendingOwner) {
    vm.startPrank(owner);
    _;
  }

  /**
   * @notice Test the revert if the caller is not the owner
   */
  function testRevertIfNotOwner(address _pendingOwner) external {
    _revertIfNotOwner();
    eboRequestCreator.setPendingOwner(_pendingOwner);
  }

  /**
   * @notice Test the set pending owner
   */
  function testSetPendingOwner(address _pendingOwner) external happyPath(_pendingOwner) {
    eboRequestCreator.setPendingOwner(_pendingOwner);

    assertEq(eboRequestCreator.pendingOwner(), _pendingOwner);
  }

  /**
   * @notice Test the emit pending owner setted
   */
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

  /**
   * @notice Test the revert if the caller is not the pending owner
   */
  function testRevertIfNotPendingOwner() external {
    vm.expectRevert(IEBORequestCreator.EBORequestCreator_OnlyPendingOwner.selector);
    eboRequestCreator.acceptPendingOwner();
  }

  /**
   * @notice Test the accept pending owner
   */
  function testAcceptPendingOwner(address _pendingOwner) external happyPath(_pendingOwner) {
    eboRequestCreator.acceptPendingOwner();

    assertEq(eboRequestCreator.owner(), _pendingOwner);
    assertEq(eboRequestCreator.pendingOwner(), address(0));
  }

  /**
   * @notice Test the emit owner setted
   */
  function testEmitOwnerSetted(address _pendingOwner) external happyPath(_pendingOwner) {
    vm.expectEmit();
    emit OwnerSetted(owner, _pendingOwner);

    eboRequestCreator.acceptPendingOwner();
  }
}

contract UnitEBORequestCreatorCreateRequest is EBORequestCreatorUnitTest {
  string[] internal _cleanChainIds;

  modifier happyPath(uint256 _epoch, string[] calldata _chainId) {
    vm.assume(_epoch > 0);
    vm.assume(_chainId.length > 0 && _chainId.length < 30);

    bool _added;
    for (uint256 _i; _i < _chainId.length; _i++) {
      _added = eboRequestCreator.setChainIdForTest(_chainId[_i]);
      if (_added) {
        _cleanChainIds.push(_chainId[_i]);
      }
    }

    vm.startPrank(owner);
    _;
  }

  /**
   * @notice Test the revert if the caller is not the owner
   */
  function testRevertIfChainNotAdded() external {
    vm.expectRevert(abi.encodeWithSelector(IEBORequestCreator.EBORequestCreator_ChainNotAdded.selector));

    eboRequestCreator.createRequests(0, new string[](1));
  }

  /**
   * @notice Test the create requests
   */
  function testEmitCreateRequest(
    uint256 _epoch,
    string[] calldata _chainIds,
    bytes32 _requestId
  ) external happyPath(_epoch, _chainIds) {
    for (uint256 _i; _i < _cleanChainIds.length; _i++) {
      console.log(_cleanChainIds[_i]);
      vm.mockCall(address(oracle), abi.encodeWithSelector(IOracle.createRequest.selector), abi.encode(_requestId));
      vm.expectEmit();
      emit RequestCreated(_requestId, _epoch, _cleanChainIds[_i]);
    }

    eboRequestCreator.createRequests(_epoch, _cleanChainIds);
  }
}

contract UnitEBORequestCreatorAddChain is EBORequestCreatorUnitTest {
  modifier happyPath() {
    vm.startPrank(owner);
    _;
  }

  /**
   * @notice Test the revert if the caller is not the owner
   */
  function testRevertIfNotOwner(string calldata _chainId) external {
    _revertIfNotOwner();
    eboRequestCreator.addChain(_chainId);
  }

  /**
   * @notice Test the revert if the chain is already added
   */
  function testRevertIfChainAdded(string calldata _chainId) external happyPath {
    eboRequestCreator.setChainIdForTest(_chainId);

    vm.expectRevert(abi.encodeWithSelector(IEBORequestCreator.EBORequestCreator_ChainAlreadyAdded.selector));
    eboRequestCreator.addChain(_chainId);
  }

  /**
   * @notice Test the emit chain added
   */
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

  /**
   * @notice Test the revert if the caller is not the owner
   */
  function testRevertIfNotOwner(string calldata _chainId) external {
    _revertIfNotOwner();
    eboRequestCreator.removeChain(_chainId);
  }

  /**
   * @notice Test the revert if the chain is not added
   */
  function testRevertIfChainNotAdded(string calldata _chainId) external {
    vm.expectRevert(abi.encodeWithSelector(IEBORequestCreator.EBORequestCreator_ChainNotAdded.selector));

    vm.prank(owner);
    eboRequestCreator.removeChain(_chainId);
  }

  /**
   * @notice Test the emit chain removed
   */
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

  /**
   * @notice Test the revert if the caller is not the owner
   */
  function testRevertIfNotOwner(uint256 _reward) external {
    vm.expectRevert();
    eboRequestCreator.setReward(_reward);
  }

  /**
   * @notice Test the set reward
   */
  function testSetReward(uint256 _reward) external happyPath(_reward) {
    eboRequestCreator.setReward(_reward);

    assertEq(eboRequestCreator.reward(), _reward);
  }

  /**
   * @notice Test the emit reward set
   */
  function testEmitRewardSet(uint256 _reward) external happyPath(_reward) {
    vm.expectEmit();
    emit RewardSet(0, _reward);

    eboRequestCreator.setReward(_reward);
  }
}
