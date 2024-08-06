// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.26;

import {EnumerableSet} from '@openzeppelin/contracts/utils/structs/EnumerableSet.sol';

import {EBORequestCreator, IEBORequestCreator, IOracle} from 'contracts/EBORequestCreator.sol';

import {Test} from 'forge-std/Test.sol';
import 'forge-std/console.sol';

contract EBORequestCreatorForTest is EBORequestCreator {
  using EnumerableSet for EnumerableSet.Bytes32Set;

  constructor(IOracle _oracle, address _owner) EBORequestCreator(_oracle, _owner) {}

  function setPendingArbitratorForTest(address _pendingArbitrator) external {
    pendingArbitrator = _pendingArbitrator;
  }

  function setChainIdForTest(string calldata _chainId) external returns (bool _added) {
    _added = _chainIdsAllowed.add(_encodeChainId(_chainId));
  }

  function setRequestIdPerChainAndEpochForTest(string calldata _chainId, uint256 _epoch, bytes32 _requestId) external {
    requestIdPerChainAndEpoch[_chainId][_epoch] = _requestId;
  }
}

abstract contract EBORequestCreator_Unit_BaseTest is Test {
  /// Events
  event PendingArbitratorSetted(address _pendingArbitrator);
  event ArbitratorSetted(address _oldArbitrator, address _newArbitrator);
  event RequestCreated(bytes32 indexed _requestId, uint256 indexed _epoch, string indexed _chainId);
  event ChainAdded(string indexed _chainId);
  event ChainRemoved(string indexed _chainId);
  event RewardSet(uint256 _oldReward, uint256 _newReward);
  event RequestDataSet(EBORequestCreator.RequestData _requestData);

  /// Contracts
  EBORequestCreatorForTest public eboRequestCreator;
  IOracle public oracle;

  /// EOAs
  address public arbitrator;

  function setUp() external {
    arbitrator = makeAddr('Arbitrator');
    oracle = IOracle(makeAddr('Oracle'));

    vm.prank(arbitrator);
    eboRequestCreator = new EBORequestCreatorForTest(oracle, arbitrator);
  }

  function _revertIfNotArbitrator() internal {
    vm.expectRevert(IEBORequestCreator.EBORequestCreator_OnlyArbitrator.selector);
  }
}

contract EBORequestCreator_Unit_Constructor is EBORequestCreator_Unit_BaseTest {
  /**
   * @notice Test the constructor
   */
  function test_constructor() external view {
    assertEq(eboRequestCreator.reward(), 0);
    assertEq(eboRequestCreator.arbitrator(), arbitrator);
    assertEq(eboRequestCreator.pendingArbitrator(), address(0));
    assertEq(address(eboRequestCreator.oracle()), address(oracle));
  }
}

contract EBORequestCreator_Unit_SetPendingArbitrator is EBORequestCreator_Unit_BaseTest {
  modifier happyPath(address _pendingArbitrator) {
    vm.startPrank(arbitrator);
    _;
  }

  /**
   * @notice Test the revert if the caller is not the arbitrator
   */
  function test_revertIfNotArbitrator(address _pendingArbitrator) external {
    vm.expectRevert(IEBORequestCreator.EBORequestCreator_OnlyArbitrator.selector);
    eboRequestCreator.setPendingArbitrator(_pendingArbitrator);
  }

  /**
   * @notice Test the set pending arbitrator
   */
  function test_setPendingArbitrator(address _pendingArbitrator) external happyPath(_pendingArbitrator) {
    eboRequestCreator.setPendingArbitrator(_pendingArbitrator);

    assertEq(eboRequestCreator.pendingArbitrator(), _pendingArbitrator);
  }

  /**
   * @notice Test the emit pending arbitrator setted
   */
  function test_emitPendingArbitratorSetted(address _pendingArbitrator) external happyPath(_pendingArbitrator) {
    vm.expectEmit();
    emit PendingArbitratorSetted(_pendingArbitrator);

    eboRequestCreator.setPendingArbitrator(_pendingArbitrator);
  }
}

contract EBORequestCreator_Unit_AcceptPendingArbitrator is EBORequestCreator_Unit_BaseTest {
  modifier happyPath(address _pendingArbitrator) {
    eboRequestCreator.setPendingArbitratorForTest(_pendingArbitrator);
    vm.startPrank(_pendingArbitrator);
    _;
  }

  /**
   * @notice Test the revert if the caller is not the pending arbitrator
   */
  function test_revertIfNotPendingArbitrator() external {
    vm.expectRevert(IEBORequestCreator.EBORequestCreator_OnlyPendingArbitrator.selector);
    eboRequestCreator.acceptPendingArbitrator();
  }

  /**
   * @notice Test the accept pending arbitrator
   */
  function test_acceptPendingArbitrator(address _pendingArbitrator) external happyPath(_pendingArbitrator) {
    eboRequestCreator.acceptPendingArbitrator();

    assertEq(eboRequestCreator.arbitrator(), _pendingArbitrator);
    assertEq(eboRequestCreator.pendingArbitrator(), address(0));
  }

  /**
   * @notice Test the emit arbitrator setted
   */
  function test_emitArbitratorSetted(address _pendingArbitrator) external happyPath(_pendingArbitrator) {
    vm.expectEmit();
    emit ArbitratorSetted(arbitrator, _pendingArbitrator);

    eboRequestCreator.acceptPendingArbitrator();
  }
}

contract EBORequestCreator_Unit_CreateRequest is EBORequestCreator_Unit_BaseTest {
  string[] internal _cleanChainIds;

  modifier happyPath(uint256 _epoch, string[] memory _chainId) {
    vm.assume(_epoch > 0);
    vm.assume(_chainId.length > 0 && _chainId.length < 30);

    bool _added;
    for (uint256 _i; _i < _chainId.length; _i++) {
      _added = eboRequestCreator.setChainIdForTest(_chainId[_i]);
      if (_added) {
        _cleanChainIds.push(_chainId[_i]);
      }
    }

    vm.startPrank(arbitrator);
    _;
  }

  /**
   * @notice Test the revert if the caller is not the arbitrator
   */
  function test_revertIfChainNotAdded() external {
    vm.expectRevert(abi.encodeWithSelector(IEBORequestCreator.EBORequestCreator_ChainNotAdded.selector));

    eboRequestCreator.createRequests(0, new string[](1));
  }

  /**
   * @notice Test if the request id exists skip the request creation
   */
  function test_expectNotEmitRequestIdExists(
    uint256 _epoch,
    string calldata _chainId,
    bytes32 _requestId
  ) external happyPath(_epoch, new string[](1)) {
    vm.assume(_requestId != bytes32(0));
    eboRequestCreator.setChainIdForTest(_chainId);
    eboRequestCreator.setRequestIdPerChainAndEpochForTest(_chainId, _epoch, _requestId);

    vm.expectCall(address(oracle), abi.encodeWithSelector(IOracle.createRequest.selector), 0);

    string[] memory _chainIds = new string[](1);
    _chainIds[0] = _chainId;

    eboRequestCreator.createRequests(_epoch, _chainIds);
  }
  /**
   * @notice Test the create requests
   */

  function test_emitCreateRequest(
    uint256 _epoch,
    string[] calldata _chainIds,
    bytes32 _requestId
  ) external happyPath(_epoch, _chainIds) {
    for (uint256 _i; _i < _cleanChainIds.length; _i++) {
      vm.mockCall(address(oracle), abi.encodeWithSelector(IOracle.createRequest.selector), abi.encode(_requestId));
      vm.expectEmit();
      emit RequestCreated(_requestId, _epoch, _cleanChainIds[_i]);
    }

    eboRequestCreator.createRequests(_epoch, _cleanChainIds);
  }
}

contract EBORequestCreator_Unit_AddChain is EBORequestCreator_Unit_BaseTest {
  modifier happyPath() {
    vm.startPrank(arbitrator);
    _;
  }

  /**
   * @notice Test the revert if the caller is not the arbitrator
   */
  function test_revertIfNotArbitrator(string calldata _chainId) external {
    _revertIfNotArbitrator();
    eboRequestCreator.addChain(_chainId);
  }

  /**
   * @notice Test the revert if the chain is already added
   */
  function test_revertIfChainAdded(string calldata _chainId) external happyPath {
    eboRequestCreator.setChainIdForTest(_chainId);

    vm.expectRevert(abi.encodeWithSelector(IEBORequestCreator.EBORequestCreator_ChainAlreadyAdded.selector));
    eboRequestCreator.addChain(_chainId);
  }

  /**
   * @notice Test the emit chain added
   */
  function test_emitChainAdded(string calldata _chainId) external happyPath {
    vm.expectEmit();
    emit ChainAdded(_chainId);

    eboRequestCreator.addChain(_chainId);
  }
}

contract EBORequestCreator_Unit_RemoveChain is EBORequestCreator_Unit_BaseTest {
  modifier happyPath(string calldata _chainId) {
    eboRequestCreator.setChainIdForTest(_chainId);
    vm.startPrank(arbitrator);
    _;
  }

  /**
   * @notice Test the revert if the caller is not the arbitrator
   */
  function test_revertIfNotArbitrator(string calldata _chainId) external {
    _revertIfNotArbitrator();
    eboRequestCreator.removeChain(_chainId);
  }

  /**
   * @notice Test the revert if the chain is not added
   */
  function test_revertIfChainNotAdded(string calldata _chainId) external {
    vm.expectRevert(abi.encodeWithSelector(IEBORequestCreator.EBORequestCreator_ChainNotAdded.selector));

    vm.prank(arbitrator);
    eboRequestCreator.removeChain(_chainId);
  }

  /**
   * @notice Test the emit chain removed
   */
  function test_emitChainRemoved(string calldata _chainId) external happyPath(_chainId) {
    vm.expectEmit();
    emit ChainRemoved(_chainId);

    eboRequestCreator.removeChain(_chainId);
  }
}

contract EBORequestCreator_Unit_SetReward is EBORequestCreator_Unit_BaseTest {
  modifier happyPath(uint256 _reward) {
    vm.startPrank(arbitrator);
    _;
  }

  /**
   * @notice Test the revert if the caller is not the arbitrator
   */
  function test_revertIfNotArbitrator(uint256 _reward) external {
    _revertIfNotArbitrator();
    eboRequestCreator.setReward(_reward);
  }

  /**
   * @notice Test the set reward
   */
  function test_setReward(uint256 _reward) external happyPath(_reward) {
    eboRequestCreator.setReward(_reward);

    assertEq(eboRequestCreator.reward(), _reward);
  }

  /**
   * @notice Test the emit reward set
   */
  function test_emitRewardSet(uint256 _reward) external happyPath(_reward) {
    vm.expectEmit();
    emit RewardSet(0, _reward);

    eboRequestCreator.setReward(_reward);
  }
}

contract EBORequestCreator_Unit_SetRequestData is EBORequestCreator_Unit_BaseTest {
  modifier happyPath(EBORequestCreator.RequestData calldata _requestData) {
    vm.startPrank(arbitrator);
    _;
  }

  /**
   * @notice Test the revert if the caller is not the arbitrator
   */
  function test_revertIfNotArbitrator(EBORequestCreator.RequestData calldata _requestData) external {
    _revertIfNotArbitrator();
    eboRequestCreator.setRequestData(_requestData);
  }

  /**
   * @notice Test the set request data
   */
  function test_setRequestData(EBORequestCreator.RequestData calldata _requestData) external happyPath(_requestData) {
    eboRequestCreator.setRequestData(_requestData);

    (
      address _requestModule,
      address _responseModule,
      address _disputeModule,
      address _resolutionModule,
      address _finalityModule,
      bytes memory _requestModuleData,
      bytes memory _responseModuleData,
      bytes memory _disputeModuleData,
      bytes memory _resolutionModuleData,
      bytes memory _finalityModuleData
    ) = eboRequestCreator.requestData();

    assertEq(_requestModule, _requestData.requestModule);
    assertEq(_responseModule, _requestData.responseModule);
    assertEq(_disputeModule, _requestData.disputeModule);
    assertEq(_resolutionModule, _requestData.resolutionModule);
    assertEq(_finalityModule, _requestData.finalityModule);
    assertEq(_requestModuleData, _requestData.requestModuleData);
    assertEq(_responseModuleData, _requestData.responseModuleData);
    assertEq(_disputeModuleData, _requestData.disputeModuleData);
    assertEq(_resolutionModuleData, _requestData.resolutionModuleData);
    assertEq(_finalityModuleData, _requestData.finalityModuleData);
  }

  /**
   * @notice Test the emit request data set
   */
  function test_emitRequestDataSet(EBORequestCreator.RequestData calldata _requestData)
    external
    happyPath(_requestData)
  {
    vm.expectEmit();
    emit RequestDataSet(_requestData);

    eboRequestCreator.setRequestData(_requestData);
  }
}
