// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.26;

import {EnumerableSet} from '@openzeppelin/contracts/utils/structs/EnumerableSet.sol';

import {EBORequestCreator, IEBORequestCreator, IERC20, IOracle, SafeERC20} from 'contracts/EBORequestCreator.sol';
import {IArbitrable} from 'interfaces/IArbitrable.sol';

import {Test} from 'forge-std/Test.sol';
import 'forge-std/console.sol';

contract EBORequestCreatorForTest is EBORequestCreator {
  using EnumerableSet for EnumerableSet.Bytes32Set;

  constructor(IOracle _oracle, address _arbitrator, address _council) EBORequestCreator(_oracle, _arbitrator, _council) {}

  function setChainIdForTest(string calldata _chainId) external returns (bool _added) {
    _added = _chainIdsAllowed.add(_encodeChainId(_chainId));
  }

  function setRequestIdPerChainAndEpochForTest(string calldata _chainId, uint256 _epoch, bytes32 _requestId) external {
    requestIdPerChainAndEpoch[_chainId][_epoch] = _requestId;
  }
}

abstract contract EBORequestCreator_Unit_BaseTest is Test {
  /// Events

  event RequestCreated(bytes32 indexed _requestId, uint256 indexed _epoch, string indexed _chainId);
  event ChainAdded(string indexed _chainId);
  event ChainRemoved(string indexed _chainId);
  event RequestModuleDataSet(address indexed _requestModule, bytes _requestModuleData);
  event ResponseModuleDataSet(address indexed _responseModule, bytes _responseModuleData);
  event DisputeModuleDataSet(address indexed _disputeModule, bytes _disputeModuleData);
  event ResolutionModuleDataSet(address indexed _resolutionModule, bytes _resolutionModuleData);
  event FinalityModuleDataSet(address indexed _finalityModule, bytes _finalityModuleData);
  event DustCollected(IERC20 indexed _token, address indexed _to, uint256 _amount);

  /// Contracts
  EBORequestCreatorForTest public eboRequestCreator;
  IOracle public oracle;

  /// EOAs
  address public arbitrator;
  address public council;

  function setUp() external {
    council = makeAddr('Council');
    arbitrator = makeAddr('Arbitrator');
    oracle = IOracle(makeAddr('Oracle'));

    eboRequestCreator = new EBORequestCreatorForTest(oracle, arbitrator, council);
  }

  function _revertIfNotArbitrator() internal {
    vm.expectRevert(IArbitrable.Arbitrable_OnlyArbitrator.selector);
  }
}

contract EBORequestCreator_Unit_Constructor is EBORequestCreator_Unit_BaseTest {
  /**
   * @notice Test the constructor
   */
  function test_constructor() external view {
    assertEq(eboRequestCreator.arbitrator(), arbitrator);
    assertEq(eboRequestCreator.council(), council);
    assertEq(address(eboRequestCreator.oracle()), address(oracle));
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
  function test_revertIfChainNotAdded(uint256 _epoch) external {
    vm.expectRevert(abi.encodeWithSelector(IEBORequestCreator.EBORequestCreator_ChainNotAdded.selector));
    eboRequestCreator.createRequests(_epoch, new string[](1));
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

contract EBORequestCreator_Unit_SetRequestModuleData is EBORequestCreator_Unit_BaseTest {
  modifier happyPath(address _requestModule, bytes calldata _requestModuleData) {
    vm.startPrank(arbitrator);
    _;
  }

  /**
   * @notice Test the revert if the caller is not the arbitrator
   */
  function test_revertIfNotArbitrator(address _requestModule, bytes calldata _requestModuleData) external {
    _revertIfNotArbitrator();
    eboRequestCreator.setRequestModuleData(_requestModule, _requestModuleData);
  }

  /**
   * @notice Test the emit request module data set
   */
  function test_emitRequestModuleDataSet(
    address _requestModule,
    bytes calldata _requestModuleData
  ) external happyPath(_requestModule, _requestModuleData) {
    vm.expectEmit();
    emit RequestModuleDataSet(_requestModule, _requestModuleData);

    eboRequestCreator.setRequestModuleData(_requestModule, _requestModuleData);
  }
}

contract EBORequestCreator_Unit_SetResponseModuleData is EBORequestCreator_Unit_BaseTest {
  modifier happyPath(address _responseModule, bytes calldata _responseModuleData) {
    vm.startPrank(arbitrator);
    _;
  }

  /**
   * @notice Test the revert if the caller is not the arbitrator
   */
  function test_revertIfNotArbitrator(address _responseModule, bytes calldata _responseModuleData) external {
    _revertIfNotArbitrator();
    eboRequestCreator.setResponseModuleData(_responseModule, _responseModuleData);
  }

  /**
   * @notice Test the emit response module data set
   */
  function test_emitResponseModuleDataSet(
    address _responseModule,
    bytes calldata _responseModuleData
  ) external happyPath(_responseModule, _responseModuleData) {
    vm.expectEmit();
    emit ResponseModuleDataSet(_responseModule, _responseModuleData);

    eboRequestCreator.setResponseModuleData(_responseModule, _responseModuleData);
  }
}

contract EBORequestCreator_Unit_SetDisputeModuleData is EBORequestCreator_Unit_BaseTest {
  modifier happyPath(address _disputeModule, bytes calldata _disputeModuleData) {
    vm.startPrank(arbitrator);
    _;
  }

  /**
   * @notice Test the revert if the caller is not the arbitrator
   */
  function test_revertIfNotArbitrator(address _disputeModule, bytes calldata _disputeModuleData) external {
    _revertIfNotArbitrator();
    eboRequestCreator.setDisputeModuleData(_disputeModule, _disputeModuleData);
  }

  /**
   * @notice Test the emit dispute module data set
   */
  function test_emitDisputeModuleDataSet(
    address _disputeModule,
    bytes calldata _disputeModuleData
  ) external happyPath(_disputeModule, _disputeModuleData) {
    vm.expectEmit();
    emit DisputeModuleDataSet(_disputeModule, _disputeModuleData);

    eboRequestCreator.setDisputeModuleData(_disputeModule, _disputeModuleData);
  }
}

contract EBORequestCreator_Unit_SetResolutionModuleData is EBORequestCreator_Unit_BaseTest {
  modifier happyPath(address _resolutionModule, bytes calldata _resolutionModuleData) {
    vm.startPrank(arbitrator);
    _;
  }

  /**
   * @notice Test the revert if the caller is not the arbitrator
   */
  function test_revertIfNotArbitrator(address _resolutionModule, bytes calldata _resolutionModuleData) external {
    _revertIfNotArbitrator();
    eboRequestCreator.setResolutionModuleData(_resolutionModule, _resolutionModuleData);
  }

  /**
   * @notice Test the emit resolution module data set
   */
  function test_emitResolutionModuleDataSet(
    address _resolutionModule,
    bytes calldata _resolutionModuleData
  ) external happyPath(_resolutionModule, _resolutionModuleData) {
    vm.expectEmit();
    emit ResolutionModuleDataSet(_resolutionModule, _resolutionModuleData);

    eboRequestCreator.setResolutionModuleData(_resolutionModule, _resolutionModuleData);
  }
}

contract EBORequestCreator_Unit_SetFinalityModuleData is EBORequestCreator_Unit_BaseTest {
  modifier happyPath(address _finalityModule, bytes calldata _finalityModuleData) {
    vm.startPrank(arbitrator);
    _;
  }

  /**
   * @notice Test the revert if the caller is not the arbitrator
   */
  function test_revertIfNotArbitrator(address _finalityModule, bytes calldata _finalityModuleData) external {
    _revertIfNotArbitrator();
    eboRequestCreator.setFinalityModuleData(_finalityModule, _finalityModuleData);
  }

  /**
   * @notice Test the emit finality module data set
   */
  function test_emitFinalityModuleDataSet(
    address _finalityModule,
    bytes calldata _finalityModuleData
  ) external happyPath(_finalityModule, _finalityModuleData) {
    vm.expectEmit();
    emit FinalityModuleDataSet(_finalityModule, _finalityModuleData);

    eboRequestCreator.setFinalityModuleData(_finalityModule, _finalityModuleData);
  }
}

contract EBORequestCreator_Unit_DustCollector is EBORequestCreator_Unit_BaseTest {
  /**
   * @notice Test the revert if the caller is not the council
   */
  function test_revertIfNotCouncil(IERC20 _token, address _to) external {
    vm.expectRevert(abi.encodeWithSelector(IArbitrable.Arbitrable_OnlyCouncil.selector));
    eboRequestCreator.dustCollector(_token, _to);
  }

  /**
   * @notice Test the emit dust collected
   */
  function test_emitDustCollected(IERC20 _token, address _to, uint256 _amount) external {
    vm.expectEmit();
    emit DustCollected(_token, _to, _amount);

    vm.mockCall(
      address(_token),
      abi.encodeWithSelector(IERC20.balanceOf.selector, address(eboRequestCreator)),
      abi.encode(_amount)
    );

    vm.mockCall(address(_token), abi.encodeWithSelector(IERC20.transfer.selector, _to, _amount), abi.encode(true));

    vm.prank(council);
    eboRequestCreator.dustCollector(_token, _to);
  }
}
