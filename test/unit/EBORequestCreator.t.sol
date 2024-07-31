// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.26;

import {EnumerableSet} from '@openzeppelin/contracts/utils/structs/EnumerableSet.sol';

import {EBORequestCreator, IEBORequestCreator} from 'contracts/EBORequestCreator.sol';

import {Test} from 'forge-std/Test.sol';

contract EBORequestCreatorForTest is EBORequestCreator {
  using EnumerableSet for EnumerableSet.Bytes32Set;

  constructor() EBORequestCreator(owner) {}

  function setChainIdForTest(string calldata _chainId) external {
    _chainIds.add(_chaindIdToBytes32(_chainId));
  }
}

// abstract contract EBORequestCreatorUnitTest is Test {
//   /// Events
//   event RequestCreated(uint256 _epoch, uint256 _chainId);
//   event ChainAdded(uint256 _chainId);
//   event ChainRemoved(uint256 _chainId);
//   event RewardSet(uint256 _oldReward, uint256 _newReward);

//   /// Contracts
//   EBORequestCreatorForTest public eboRequestCreator;
//   // IOracle public oracle;

//   /// EOAs
//   address public owner;

//   function setUp() external {
//     owner = makeAddr('Owner');
//     // oracle = IOracle(makeAddr('Oracle'));

//     vm.prank(owner);
//     eboRequestCreator = new EBORequestCreatorForTest();
//   }
// }

// contract UnitEBORequestCreatorConstructor is EBORequestCreatorUnitTest {
//   function testConstructor() external view {
//     assertEq(eboRequestCreator.reward(), 0);
//     assertEq(eboRequestCreator.owner(), owner);
//     assertEq(eboRequestCreator.pendingOwner(), address(0));
//     // assertEq(eboRequestCreator.oracle(), oracle);
//   }
// }

// //   contract UnitEBORequestCreatorCreateRequest is EBORequestCreatorUnitTest {
// //     function test_CreateRequest() external {
// //       bytes32 requestId = eboRequestCreator.createRequest(address(this), address(this), '0x', 0, 0);
// //       assertEq(uint256(requestId), uint256(keccak256(abi.encodePacked(address(this), address(this), '0x', 0, 0)));
// //     }
// //   }

// contract UnitEBORequestCreatorAddChain is EBORequestCreatorUnitTest {
//   modifier happyPath() {
//     vm.startPrank(owner);
//     _;
//   }

//   function testRevertIfNotOwner(uint256 _chainId) external {
//     vm.expectRevert();
//     eboRequestCreator.addChain(_chainId);
//   }

//   function testRevertIfChainAdded(uint256 _chainId) external happyPath {
//     eboRequestCreator.setChainIdForTest(_chainId);

//     vm.expectRevert(abi.encodeWithSelector(IEBORequestCreator.EBORequestCreator_ChainAlreadyAdded.selector, _chainId));
//     eboRequestCreator.addChain(_chainId);
//   }

//   function testAddChain(uint256 _chainId) external happyPath {
//     eboRequestCreator.addChain(_chainId);

//     assertEq(eboRequestCreator.getChainIds().length, 1);
//     assertEq(eboRequestCreator.getChainIds()[0], _chainId);
//   }

//   function testEmitChainAdded(uint256 _chainId) external happyPath {
//     vm.expectEmit();
//     emit ChainAdded(_chainId);

//     eboRequestCreator.addChain(_chainId);
//   }
// }

// contract UnitEBORequestCreatorRemoveChain is EBORequestCreatorUnitTest {
//   modifier happyPath(uint256 _chainId) {
//     eboRequestCreator.setChainIdForTest(_chainId);
//     vm.startPrank(owner);
//     _;
//   }

//   function testRevertIfNotOwner(uint256 _chainId) external {
//     vm.expectRevert();
//     eboRequestCreator.removeChain(_chainId);
//   }

//   function testRevertIfChainNotAdded(uint256 _chainId) external {
//     vm.expectRevert(abi.encodeWithSelector(IEBORequestCreator.EBORequestCreator_ChainNotAdded.selector, _chainId));

//     vm.prank(owner);
//     eboRequestCreator.removeChain(_chainId);
//   }

//   function testRemoveChain(uint256 _chainId) external happyPath(_chainId) {
//     eboRequestCreator.removeChain(_chainId);

//     assertEq(eboRequestCreator.getChainIds().length, 0);
//   }

//   function testEmitChainRemoved(uint256 _chainId) external happyPath(_chainId) {
//     vm.expectEmit();
//     emit ChainRemoved(_chainId);

//     eboRequestCreator.removeChain(_chainId);
//   }
// }

// contract UnitEBORequestCreatorSetReward is EBORequestCreatorUnitTest {
//   modifier happyPath(uint256 _reward) {
//     vm.startPrank(owner);
//     _;
//   }

//   function testRevertIfNotOwner(uint256 _reward) external {
//     vm.expectRevert();
//     eboRequestCreator.setReward(_reward);
//   }

//   function testSetReward(uint256 _reward) external happyPath(_reward) {
//     eboRequestCreator.setReward(_reward);

//     assertEq(eboRequestCreator.reward(), _reward);
//   }

//   function testEmitRewardSet(uint256 _reward) external happyPath(_reward) {
//     vm.expectEmit();
//     emit RewardSet(0, _reward);

//     eboRequestCreator.setReward(_reward);
//   }
// }

// contract UnitEBORequestCreatorGetChainIds is EBORequestCreatorUnitTest {
//   using EnumerableSet for EnumerableSet.UintSet;

//   EnumerableSet.UintSet internal _cleanChainIds;

//   modifier happyPath(uint256[] memory _chainIds) {
//     vm.assume(_chainIds.length > 0 && _chainIds.length <= 256);
//     for (uint256 _i; _i < _chainIds.length; ++_i) {
//       eboRequestCreator.setChainIdForTest(_chainIds[_i]);
//       _cleanChainIds.add(_chainIds[_i]);
//     }
//     _;
//   }

//   function testGetChainIds(uint256[] memory _chainIds) external happyPath(_chainIds) {
//     uint256[] memory _getChainIds = eboRequestCreator.getChainIds();
//     assertEq(_getChainIds.length, _cleanChainIds.length());

//     for (uint256 _i; _i < _getChainIds.length; ++_i) {
//       assert(_cleanChainIds.contains(_getChainIds[_i]));
//     }
//   }
// }
