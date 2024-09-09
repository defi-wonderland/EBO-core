// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.26;

import {IOracle} from '@defi-wonderland/prophet-core/solidity/interfaces/IOracle.sol';

import {IBondEscalationModule} from
  '@defi-wonderland/prophet-modules/solidity/interfaces/modules/dispute/IBondEscalationModule.sol';
import {IArbitratorModule} from
  '@defi-wonderland/prophet-modules/solidity/interfaces/modules/resolution/IArbitratorModule.sol';
import {IBondedResponseModule} from
  '@defi-wonderland/prophet-modules/solidity/interfaces/modules/response/IBondedResponseModule.sol';
import {EnumerableSet} from '@openzeppelin/contracts/utils/structs/EnumerableSet.sol';
import {IEpochManager} from 'interfaces/external/IEpochManager.sol';

import {IArbitrable} from 'interfaces/IArbitrable.sol';
import {IEBORequestModule} from 'interfaces/IEBORequestModule.sol';

import {EBORequestCreator, IEBORequestCreator} from 'contracts/EBORequestCreator.sol';

import 'forge-std/Test.sol';

contract EBORequestCreatorForTest is EBORequestCreator {
  using EnumerableSet for EnumerableSet.Bytes32Set;

  constructor(
    IOracle _oracle,
    IEpochManager _epochManager,
    address _arbitrator,
    address _council,
    IOracle.Request memory _requestData
  ) EBORequestCreator(_oracle, _epochManager, _arbitrator, _council, _requestData) {}

  function setChainIdForTest(string calldata _chainId) external returns (bool _added) {
    _added = _chainIdsAllowed.add(_encodeChainId(_chainId));
  }

  function setRequestIdPerChainAndEpochForTest(string calldata _chainId, uint256 _epoch, bytes32 _requestId) external {
    requestIdPerChainAndEpoch[_chainId][_epoch] = _requestId;
  }

  function setRequestModuleDataForTest(address _requestModule, bytes calldata _requestModuleData) external {
    requestData.requestModule = _requestModule;
    requestData.requestModuleData = _requestModuleData;
  }
}

abstract contract EBORequestCreator_Unit_BaseTest is Test {
  /// Events

  event RequestCreated(bytes32 indexed _requestId, uint256 indexed _epoch, string indexed _chainId);
  event ChainAdded(string indexed _chainId);
  event ChainRemoved(string indexed _chainId);
  event RequestModuleDataSet(address indexed _requestModule, IEBORequestModule.RequestParameters _requestModuleData);
  event ResponseModuleDataSet(
    address indexed _responseModule, IBondedResponseModule.RequestParameters _responseModuleData
  );
  event DisputeModuleDataSet(
    address indexed _disputeModule, IBondEscalationModule.RequestParameters _disputeModuleData
  );
  event ResolutionModuleDataSet(
    address indexed _resolutionModule, IArbitratorModule.RequestParameters _resolutionModuleData
  );
  event FinalityModuleDataSet(address indexed _finalityModule, bytes _finalityModuleData);
  event EpochManagerSet(IEpochManager indexed _epochManager);

  /// Contracts
  EBORequestCreatorForTest public eboRequestCreator;
  IOracle public oracle;
  IEpochManager public epochManager;
  IEBORequestModule public eboRequestModule;

  /// EOAs
  address public arbitrator;
  address public council;

  /// Variables
  IOracle.Request public requestData;
  uint256 public startEpoch;

  function setUp() external {
    council = makeAddr('Council');
    arbitrator = makeAddr('Arbitrator');
    oracle = IOracle(makeAddr('Oracle'));
    epochManager = IEpochManager(makeAddr('EpochManager'));
    eboRequestModule = IEBORequestModule(makeAddr('EBORequestModule'));

    vm.mockCall(address(epochManager), abi.encodeWithSelector(IEpochManager.currentEpoch.selector), abi.encode(100));

    requestData.nonce = 0;
    startEpoch = 100;

    eboRequestCreator = new EBORequestCreatorForTest(oracle, epochManager, arbitrator, council, requestData);
  }

  function _revertIfNotArbitrator() internal {
    vm.expectRevert(IArbitrable.Arbitrable_OnlyArbitrator.selector);
  }
}

contract EBORequestCreator_Unit_Constructor is EBORequestCreator_Unit_BaseTest {
  /**
   * @notice Test arbitrator set in the constructor
   */
  function test_arbitratorSet() external view {
    assertEq(eboRequestCreator.arbitrator(), arbitrator);
  }

  /**
   * @notice Test council set in the constructor
   */
  function test_councilSet() external view {
    assertEq(eboRequestCreator.council(), council);
  }

  /**
   * @notice Test oracle set in the constructor
   */
  function test_oracleSet() external view {
    assertEq(address(eboRequestCreator.ORACLE()), address(oracle));
  }

  /**
   * @notice Test epoch manager set in the constructor
   */
  function test_epochManagerSet() external view {
    assertEq(address(eboRequestCreator.epochManager()), address(epochManager));
  }

  /**
   * @notice Test start epoch set in the constructor
   */
  function test_startEpochSet() external view {
    assertEq(eboRequestCreator.START_EPOCH(), startEpoch);
  }

  /**
   * @notice Test request data set in the constructor
   */
  function test_requestDataSet() external view {
    assertEq(requestData.nonce, 0);
  }

  function test_emitEpochManagerSet() external {
    vm.expectEmit();
    emit EpochManagerSet(epochManager);

    new EBORequestCreatorForTest(oracle, epochManager, arbitrator, council, requestData);
  }

  /**
   * @notice Test reverts if nonce is not zero
   */
  function test_revertIfNonceIsInvalid(uint96 _nonce, IOracle.Request memory _requestData) external {
    vm.assume(_nonce > 0);

    _requestData.nonce = _nonce;
    vm.expectRevert(abi.encodeWithSelector(IEBORequestCreator.EBORequestCreator_InvalidNonce.selector));
    new EBORequestCreator(oracle, epochManager, arbitrator, council, _requestData);
  }
}

contract EBORequestCreator_Unit_CreateRequest is EBORequestCreator_Unit_BaseTest {
  string[] internal _cleanChainIds;
  IEBORequestModule.RequestParameters internal _params;

  modifier happyPath(uint256 _epoch, string[] memory _chainId) {
    vm.assume(_epoch > startEpoch);
    vm.assume(_chainId.length > 0 && _chainId.length < 30);

    vm.mockCall(address(epochManager), abi.encodeWithSelector(IEpochManager.currentEpoch.selector), abi.encode(_epoch));
    bool _added;
    for (uint256 _i; _i < _chainId.length; _i++) {
      _added = eboRequestCreator.setChainIdForTest(_chainId[_i]);
      if (_added) {
        _cleanChainIds.push(_chainId[_i]);
      }
    }

    eboRequestCreator.setRequestModuleDataForTest(address(eboRequestModule), '');

    vm.mockCall(
      address(eboRequestModule),
      abi.encodeWithSelector(IEBORequestModule.decodeRequestData.selector),
      abi.encode(_params)
    );

    vm.startPrank(arbitrator);
    _;
  }

  /**
   * @notice Test the revert if the caller is not the arbitrator
   */
  function test_revertIfChainNotAdded(uint256 _epoch) external {
    vm.assume(_epoch > startEpoch);

    eboRequestCreator.setRequestModuleDataForTest(address(eboRequestModule), '');

    vm.mockCall(
      address(eboRequestModule),
      abi.encodeWithSelector(IEBORequestModule.decodeRequestData.selector),
      abi.encode(_params)
    );

    vm.mockCall(address(epochManager), abi.encodeWithSelector(IEpochManager.currentEpoch.selector), abi.encode(_epoch));

    vm.expectRevert(abi.encodeWithSelector(IEBORequestCreator.EBORequestCreator_ChainNotAdded.selector));
    eboRequestCreator.createRequests(_epoch, new string[](1));
  }

  /**
   * @notice Test the revert if the epoch is not valid because it is before the start epoch
   */
  function test_revertIfEpochBeforeStart(uint256 _epoch) external {
    vm.assume(_epoch > 0 && _epoch < 100);

    vm.mockCall(address(epochManager), abi.encodeWithSelector(IEpochManager.currentEpoch.selector), abi.encode(_epoch));

    vm.expectRevert(abi.encodeWithSelector(IEBORequestCreator.EBORequestCreator_InvalidEpoch.selector));

    eboRequestCreator.createRequests(_epoch, new string[](1));
  }

  /**
   * @notice Test the revert if the epoch is not valid because it is after the current epoch
   */
  function test_revertIfEpochAfterCurrent(uint256 _epoch) external {
    vm.assume(_epoch < type(uint256).max);

    vm.mockCall(address(epochManager), abi.encodeWithSelector(IEpochManager.currentEpoch.selector), abi.encode(_epoch));

    vm.expectRevert(abi.encodeWithSelector(IEBORequestCreator.EBORequestCreator_InvalidEpoch.selector));

    eboRequestCreator.createRequests(_epoch + 1, new string[](1));
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

    vm.mockCall(address(oracle), abi.encodeWithSelector(IOracle.finalizedAt.selector, _requestId), abi.encode(0));

    vm.expectCall(address(oracle), abi.encodeWithSelector(IOracle.createRequest.selector), 0);

    string[] memory _chainIds = new string[](1);
    _chainIds[0] = _chainId;

    eboRequestCreator.createRequests(_epoch, _chainIds);

    assertEq(eboRequestCreator.requestIdPerChainAndEpoch(_chainId, _epoch), _requestId);
  }

  /**
   * @notice Test if the request id skip the request creation because the response id is already finalized
   */
  function test_expectNotEmitRequestIdHasResponse(
    uint256 _epoch,
    string calldata _chainId,
    bytes32 _requestId,
    uint96 _finalizedAt
  ) external happyPath(_epoch, new string[](1)) {
    vm.assume(_finalizedAt > 0);
    vm.assume(_requestId != bytes32(0));
    eboRequestCreator.setChainIdForTest(_chainId);
    eboRequestCreator.setRequestIdPerChainAndEpochForTest(_chainId, _epoch, _requestId);

    vm.mockCall(
      address(oracle), abi.encodeWithSelector(IOracle.finalizedAt.selector, _requestId), abi.encode(_finalizedAt)
    );

    vm.mockCall(
      address(oracle),
      abi.encodeWithSelector(IOracle.finalizedResponseId.selector, _requestId),
      abi.encode(bytes32(keccak256('response')))
    );

    vm.expectCall(address(oracle), abi.encodeWithSelector(IOracle.createRequest.selector), 0);

    string[] memory _chainIds = new string[](1);
    _chainIds[0] = _chainId;

    eboRequestCreator.createRequests(_epoch, _chainIds);

    assertEq(eboRequestCreator.requestIdPerChainAndEpoch(_chainId, _epoch), _requestId);
  }

  /**
   * @notice Test if the request id skip because the request didn't finalize
   */
  function test_expectNotEmitRequestIdExistsBlockNumber(
    uint256 _epoch,
    string calldata _chainId,
    bytes32 _requestId,
    uint96 _finalizedAt
  ) external happyPath(_epoch, new string[](1)) {
    vm.assume(_finalizedAt == 0);
    vm.assume(_requestId != bytes32(0));
    eboRequestCreator.setChainIdForTest(_chainId);
    eboRequestCreator.setRequestIdPerChainAndEpochForTest(_chainId, _epoch, _requestId);

    vm.mockCall(address(oracle), abi.encodeWithSelector(IOracle.finalizedAt.selector, _requestId), abi.encode(0));

    vm.mockCall(
      address(oracle), abi.encodeWithSelector(IOracle.finalizedResponseId.selector, _requestId), abi.encode(bytes32(0))
    );

    vm.expectCall(address(oracle), abi.encodeWithSelector(IOracle.createRequest.selector), 0);

    string[] memory _chainIds = new string[](1);
    _chainIds[0] = _chainId;

    eboRequestCreator.createRequests(_epoch, _chainIds);

    assertEq(eboRequestCreator.requestIdPerChainAndEpoch(_chainId, _epoch), _requestId);
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

  /**
   * @notice Test the create requests because finalize with no response
   */
  function test_emitCreateRequestWithNoResponse(
    uint256 _epoch,
    string calldata _chainId,
    bytes32 _requestId,
    uint96 _finalizedAt
  ) external happyPath(_epoch, new string[](1)) {
    vm.assume(_finalizedAt > 0);
    vm.assume(_requestId != bytes32(0));
    eboRequestCreator.setChainIdForTest(_chainId);
    eboRequestCreator.setRequestIdPerChainAndEpochForTest(_chainId, _epoch, _requestId);

    vm.mockCall(
      address(oracle), abi.encodeWithSelector(IOracle.finalizedAt.selector, _requestId), abi.encode(_finalizedAt)
    );

    vm.mockCall(
      address(oracle), abi.encodeWithSelector(IOracle.finalizedResponseId.selector, _requestId), abi.encode(bytes32(0))
    );

    vm.mockCall(address(oracle), abi.encodeWithSelector(IOracle.createRequest.selector), abi.encode(_requestId));

    string[] memory _chainIds = new string[](1);
    _chainIds[0] = _chainId;

    vm.expectEmit();
    emit RequestCreated(_requestId, _epoch, _chainId);

    eboRequestCreator.createRequests(_epoch, _chainIds);
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
  modifier happyPath(address _requestModule, IEBORequestModule.RequestParameters calldata _requestModuleData) {
    vm.startPrank(arbitrator);
    _;
  }

  /**
   * @notice Test the revert if the caller is not the arbitrator
   */
  function test_revertIfNotArbitrator(
    address _requestModule,
    IEBORequestModule.RequestParameters calldata _requestModuleData
  ) external {
    _revertIfNotArbitrator();
    eboRequestCreator.setRequestModuleData(_requestModule, _requestModuleData);
  }

  // TODO: IF WE USE THIS TEST, WE HAVE TO CHANGE THE SETTINGS TO USE --VIA-IR BECAUSE WE HAVE TO CREATE A LOT OF VARIABLES
  // /**
  //  * @notice Test params are setted properly
  //  */
  // function test_requestModuleDataParams(
  //   address _requestModule,
  //   IEBORequestModule.RequestParameters calldata _requestModuleData
  // ) external happyPath(_requestModule, _requestModuleData) {
  //   eboRequestCreator.setRequestModuleData(_requestModule, _requestModuleData);

  //   (,,,,,,, bytes memory _getRequestModuleData,,,,) = eboRequestCreator.requestData();
  //   assertEq(abi.encode(_requestModuleData), _getRequestModuleData);
  // }

  /**
   * @notice Test the emit request module data set
   */
  function test_emitRequestModuleDataSet(
    address _requestModule,
    IEBORequestModule.RequestParameters calldata _requestModuleData
  ) external happyPath(_requestModule, _requestModuleData) {
    vm.expectEmit();

    emit RequestModuleDataSet(_requestModule, _requestModuleData);

    eboRequestCreator.setRequestModuleData(_requestModule, _requestModuleData);
  }
}

contract EBORequestCreator_Unit_SetResponseModuleData is EBORequestCreator_Unit_BaseTest {
  modifier happyPath(address _responseModule, IBondedResponseModule.RequestParameters calldata _responseModuleData) {
    vm.startPrank(arbitrator);
    _;
  }

  /**
   * @notice Test the revert if the caller is not the arbitrator
   */
  function test_revertIfNotArbitrator(
    address _responseModule,
    IBondedResponseModule.RequestParameters calldata _responseModuleData
  ) external {
    _revertIfNotArbitrator();
    eboRequestCreator.setResponseModuleData(_responseModule, _responseModuleData);
  }

  /**
   * @notice Test the emit response module data set
   */
  function test_emitResponseModuleDataSet(
    address _responseModule,
    IBondedResponseModule.RequestParameters calldata _responseModuleData
  ) external happyPath(_responseModule, _responseModuleData) {
    vm.expectEmit();
    emit ResponseModuleDataSet(_responseModule, _responseModuleData);

    eboRequestCreator.setResponseModuleData(_responseModule, _responseModuleData);
  }
}

contract EBORequestCreator_Unit_SetDisputeModuleData is EBORequestCreator_Unit_BaseTest {
  modifier happyPath(address _disputeModule, IBondEscalationModule.RequestParameters calldata _disputeModuleData) {
    vm.startPrank(arbitrator);
    _;
  }

  /**
   * @notice Test the revert if the caller is not the arbitrator
   */
  function test_revertIfNotArbitrator(
    address _disputeModule,
    IBondEscalationModule.RequestParameters calldata _disputeModuleData
  ) external {
    _revertIfNotArbitrator();
    eboRequestCreator.setDisputeModuleData(_disputeModule, _disputeModuleData);
  }

  /**
   * @notice Test the emit dispute module data set
   */
  function test_emitDisputeModuleDataSet(
    address _disputeModule,
    IBondEscalationModule.RequestParameters calldata _disputeModuleData
  ) external happyPath(_disputeModule, _disputeModuleData) {
    vm.expectEmit();
    emit DisputeModuleDataSet(_disputeModule, _disputeModuleData);

    eboRequestCreator.setDisputeModuleData(_disputeModule, _disputeModuleData);
  }
}

contract EBORequestCreator_Unit_SetResolutionModuleData is EBORequestCreator_Unit_BaseTest {
  modifier happyPath(address _resolutionModule, IArbitratorModule.RequestParameters calldata _resolutionModuleData) {
    vm.startPrank(arbitrator);
    _;
  }

  /**
   * @notice Test the revert if the caller is not the arbitrator
   */
  function test_revertIfNotArbitrator(
    address _resolutionModule,
    IArbitratorModule.RequestParameters calldata _resolutionModuleData
  ) external {
    _revertIfNotArbitrator();
    eboRequestCreator.setResolutionModuleData(_resolutionModule, _resolutionModuleData);
  }

  /**
   * @notice Test the emit resolution module data set
   */
  function test_emitResolutionModuleDataSet(
    address _resolutionModule,
    IArbitratorModule.RequestParameters calldata _resolutionModuleData
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

contract EBORequestCreator_Unit_SetEpochManager is EBORequestCreator_Unit_BaseTest {
  modifier happyPath(IEpochManager _epochManager) {
    vm.assume(address(_epochManager) != address(0));
    vm.startPrank(arbitrator);
    _;
  }

  /**
   * @notice Test the revert if the caller is not the arbitrator
   */
  function test_revertIfNotArbitrator(IEpochManager _epochManager) external {
    _revertIfNotArbitrator();
    eboRequestCreator.setEpochManager(_epochManager);
  }

  /**
   * @notice Test the emit epoch manager set
   */
  function test_emitEpochManagerSet(IEpochManager _epochManager) external happyPath(_epochManager) {
    vm.expectEmit();
    emit EpochManagerSet(_epochManager);

    eboRequestCreator.setEpochManager(_epochManager);
  }
}
