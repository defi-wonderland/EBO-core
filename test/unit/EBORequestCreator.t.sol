// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.26;

import {
  EBORequestCreator,
  EnumerableSet,
  IArbitrable,
  IArbitratorModule,
  IBondEscalationModule,
  IBondedResponseModule,
  IEBORequestCreator,
  IEBORequestModule,
  IEpochManager,
  IOracle
} from 'contracts/EBORequestCreator.sol';

import 'forge-std/Test.sol';

contract EBORequestCreatorForTest is EBORequestCreator {
  using EnumerableSet for EnumerableSet.Bytes32Set;

  constructor(
    IOracle _oracle,
    IEpochManager _epochManager,
    IArbitrable _arbitrable,
    IOracle.Request memory _requestData
  ) EBORequestCreator(_oracle, _epochManager, _arbitrable, _requestData) {}

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

  function encodeChainIdForTest(string calldata _chainId) external pure returns (bytes32 _encodedChainId) {
    return _encodeChainId(_chainId);
  }
}

abstract contract EBORequestCreator_Unit_BaseTest is Test {
  /// Events
  event RequestCreated(
    bytes32 indexed _requestId, IOracle.Request _request, uint256 indexed _epoch, string indexed _chainId
  );
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
  IArbitrable public arbitrable;

  /// Variables
  IOracle.Request public requestData;
  uint256 public startEpoch;

  function setUp() external {
    oracle = IOracle(makeAddr('Oracle'));
    epochManager = IEpochManager(makeAddr('EpochManager'));
    eboRequestModule = IEBORequestModule(makeAddr('EBORequestModule'));
    arbitrable = IArbitrable(makeAddr('Arbitrable'));

    vm.mockCall(address(epochManager), abi.encodeWithSelector(IEpochManager.currentEpoch.selector), abi.encode(100));

    requestData.nonce = 0;
    startEpoch = 100;

    eboRequestCreator = new EBORequestCreatorForTest(oracle, epochManager, arbitrable, requestData);
  }
}

contract EBORequestCreator_Unit_Constructor is EBORequestCreator_Unit_BaseTest {
  /**
   * @notice Test arbitrable set in the constructor
   */
  function test_arbitrableSet() external view {
    assertEq(address(eboRequestCreator.ARBITRABLE()), address(arbitrable));
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

    new EBORequestCreatorForTest(oracle, epochManager, arbitrable, requestData);
  }

  /**
   * @notice Test reverts if nonce is not zero
   */
  function test_revertIfNonceIsInvalid(uint96 _nonce, IOracle.Request memory _requestData) external {
    vm.assume(_nonce > 0);

    _requestData.nonce = _nonce;
    vm.expectRevert(abi.encodeWithSelector(IEBORequestCreator.EBORequestCreator_InvalidNonce.selector));
    new EBORequestCreator(oracle, epochManager, arbitrable, _requestData);
  }
}

contract EBORequestCreator_Unit_CreateRequest is EBORequestCreator_Unit_BaseTest {
  IEBORequestModule.RequestParameters internal _params;

  modifier happyPath(uint256 _epoch, string memory _chainId, address _arbitrator) {
    vm.assume(_epoch > startEpoch);

    vm.mockCall(address(epochManager), abi.encodeWithSelector(IEpochManager.currentEpoch.selector), abi.encode(_epoch));

    eboRequestCreator.setChainIdForTest(_chainId);

    eboRequestCreator.setRequestModuleDataForTest(address(eboRequestModule), '');

    vm.mockCall(
      address(eboRequestModule),
      abi.encodeWithSelector(IEBORequestModule.decodeRequestData.selector),
      abi.encode(_params)
    );

    vm.mockCall(
      address(arbitrable),
      abi.encodeWithSelector(IArbitrable.validateArbitrator.selector, _arbitrator),
      abi.encode(true)
    );

    _params.chainId = _chainId;
    _params.epoch = _epoch;

    vm.startPrank(_arbitrator);
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
    eboRequestCreator.createRequest(_epoch, '');
  }

  /**
   * @notice Test the revert if the epoch is not valid because it is before the start epoch
   */
  function test_revertIfEpochBeforeStart(uint256 _epoch) external {
    vm.assume(_epoch > 0 && _epoch < 100);

    vm.mockCall(address(epochManager), abi.encodeWithSelector(IEpochManager.currentEpoch.selector), abi.encode(_epoch));

    vm.expectRevert(abi.encodeWithSelector(IEBORequestCreator.EBORequestCreator_InvalidEpoch.selector));

    eboRequestCreator.createRequest(_epoch, '');
  }

  /**
   * @notice Test the revert if the epoch is not valid because it is after the current epoch
   */
  function test_revertIfEpochAfterCurrent(uint256 _epoch) external {
    vm.assume(_epoch < type(uint256).max);

    vm.mockCall(address(epochManager), abi.encodeWithSelector(IEpochManager.currentEpoch.selector), abi.encode(_epoch));

    vm.expectRevert(abi.encodeWithSelector(IEBORequestCreator.EBORequestCreator_InvalidEpoch.selector));

    eboRequestCreator.createRequest(_epoch + 1, '');
  }

  /**
   * @notice Test if the request id exists skip the request creation
   */
  function test_revertIfRequestIdExists(
    uint256 _epoch,
    string calldata _chainId,
    bytes32 _requestId,
    address _arbitrator
  ) external happyPath(_epoch, '', _arbitrator) {
    vm.assume(_requestId != bytes32(0));
    eboRequestCreator.setChainIdForTest(_chainId);
    eboRequestCreator.setRequestIdPerChainAndEpochForTest(_chainId, _epoch, _requestId);

    vm.mockCall(address(oracle), abi.encodeWithSelector(IOracle.finalizedAt.selector, _requestId), abi.encode(0));

    vm.expectRevert(abi.encodeWithSelector(IEBORequestCreator.EBORequestCreator_RequestAlreadyCreated.selector));

    eboRequestCreator.createRequest(_epoch, _chainId);

    assertEq(eboRequestCreator.requestIdPerChainAndEpoch(_chainId, _epoch), _requestId);
  }

  /**
   * @notice Test if the request id skip the request creation because the response id is already finalized
   */
  function test_revertIfRequestIdHasResponse(
    uint256 _epoch,
    string calldata _chainId,
    bytes32 _requestId,
    uint96 _finalizedAt,
    address _arbitrator
  ) external happyPath(_epoch, '', _arbitrator) {
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

    vm.expectRevert(abi.encodeWithSelector(IEBORequestCreator.EBORequestCreator_RequestAlreadyCreated.selector));

    eboRequestCreator.createRequest(_epoch, _chainId);

    assertEq(eboRequestCreator.requestIdPerChainAndEpoch(_chainId, _epoch), _requestId);
  }

  /**
   * @notice Test if the request id skip because the request didn't finalize
   */
  function test_revertIfRequestIdExistsBlockNumber(
    uint256 _epoch,
    string calldata _chainId,
    bytes32 _requestId,
    uint96 _finalizedAt,
    address _arbitrator
  ) external happyPath(_epoch, '', _arbitrator) {
    vm.assume(_finalizedAt == 0);
    vm.assume(_requestId != bytes32(0));
    eboRequestCreator.setChainIdForTest(_chainId);
    eboRequestCreator.setRequestIdPerChainAndEpochForTest(_chainId, _epoch, _requestId);

    vm.mockCall(address(oracle), abi.encodeWithSelector(IOracle.finalizedAt.selector, _requestId), abi.encode(0));

    vm.mockCall(
      address(oracle), abi.encodeWithSelector(IOracle.finalizedResponseId.selector, _requestId), abi.encode(bytes32(0))
    );

    vm.expectRevert(abi.encodeWithSelector(IEBORequestCreator.EBORequestCreator_RequestAlreadyCreated.selector));

    eboRequestCreator.createRequest(_epoch, _chainId);

    assertEq(eboRequestCreator.requestIdPerChainAndEpoch(_chainId, _epoch), _requestId);
  }

  /**
   * @notice Test the create requests
   */
  function test_emitCreateRequest(
    uint256 _epoch,
    string calldata _chainId,
    bytes32 _requestId,
    address _arbitrator
  ) external happyPath(_epoch, _chainId, _arbitrator) {
    vm.mockCall(address(oracle), abi.encodeWithSelector(IOracle.createRequest.selector), abi.encode(_requestId));

    // Mock the request data
    // Needed to do like this to avoid stack too deep
    IOracle.Request memory _requestData = requestData;
    _requestData.requester = address(eboRequestCreator);

    // Mock the request module data
    _requestData.requestModule = address(eboRequestModule);
    _requestData.requestModuleData = abi.encode(_params);

    vm.expectEmit();
    emit RequestCreated(_requestId, _requestData, _epoch, _chainId);

    eboRequestCreator.createRequest(_epoch, _chainId);
  }

  /**
   * @notice Test the create requests because finalize with no response
   */
  function test_emitCreateRequestWithNoResponse(
    uint256 _epoch,
    string calldata _chainId,
    bytes32 _requestId,
    uint96 _finalizedAt,
    address _arbitrator
  ) external happyPath(_epoch, _chainId, _arbitrator) {
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

    // Mock the request data
    // Needed to do like this to avoid stack too deep
    IOracle.Request memory _requestData = requestData;
    _requestData.requester = address(eboRequestCreator);

    // Mock the request module data
    _requestData.requestModule = address(eboRequestModule);
    _requestData.requestModuleData = abi.encode(_params);

    vm.expectEmit();
    emit RequestCreated(_requestId, _requestData, _epoch, _chainId);

    eboRequestCreator.createRequest(_epoch, _chainId);
  }
}

contract EBORequestCreator_Unit_AddChain is EBORequestCreator_Unit_BaseTest {
  modifier happyPath(address _arbitrator) {
    vm.mockCall(
      address(arbitrable),
      abi.encodeWithSelector(IArbitrable.validateArbitrator.selector, _arbitrator),
      abi.encode(true)
    );
    vm.startPrank(_arbitrator);
    _;
  }

  /**
   * @notice Test the revert if the chain is already added
   */
  function test_revertIfChainAdded(string calldata _chainId, address _arbitrator) external happyPath(_arbitrator) {
    eboRequestCreator.setChainIdForTest(_chainId);

    vm.expectRevert(abi.encodeWithSelector(IEBORequestCreator.EBORequestCreator_ChainAlreadyAdded.selector));
    eboRequestCreator.addChain(_chainId);
  }

  /**
   * @notice Test the emit chain added
   */
  function test_emitChainAdded(string calldata _chainId, address _arbitrator) external happyPath(_arbitrator) {
    vm.expectEmit();
    emit ChainAdded(_chainId);

    eboRequestCreator.addChain(_chainId);
  }
}

contract EBORequestCreator_Unit_RemoveChain is EBORequestCreator_Unit_BaseTest {
  modifier happyPath(string calldata _chainId, address _arbitrator) {
    eboRequestCreator.setChainIdForTest(_chainId);
    vm.mockCall(
      address(arbitrable),
      abi.encodeWithSelector(IArbitrable.validateArbitrator.selector, _arbitrator),
      abi.encode(true)
    );
    vm.startPrank(_arbitrator);
    _;
  }

  /**
   * @notice Test the revert if the chain is not added
   */
  function test_revertIfChainNotAdded(string calldata _chainId, address _arbitrator) external {
    vm.expectRevert(abi.encodeWithSelector(IEBORequestCreator.EBORequestCreator_ChainNotAdded.selector));

    vm.mockCall(
      address(arbitrable),
      abi.encodeWithSelector(IArbitrable.validateArbitrator.selector, _arbitrator),
      abi.encode(true)
    );
    vm.startPrank(_arbitrator);

    eboRequestCreator.removeChain(_chainId);
  }

  /**
   * @notice Test the emit chain removed
   */
  function test_emitChainRemoved(
    string calldata _chainId,
    address _arbitrator
  ) external happyPath(_chainId, _arbitrator) {
    vm.expectEmit();
    emit ChainRemoved(_chainId);

    eboRequestCreator.removeChain(_chainId);
  }
}

contract EBORequestCreator_Unit_SetRequestModuleData is EBORequestCreator_Unit_BaseTest {
  modifier happyPath(address _arbitrator) {
    vm.mockCall(
      address(arbitrable),
      abi.encodeWithSelector(IArbitrable.validateArbitrator.selector, _arbitrator),
      abi.encode(true)
    );
    vm.startPrank(_arbitrator);
    _;
  }

  /**
   * @notice Test params are setted properly
   */
  function test_requestModuleDataParams(
    address _requestModule,
    IEBORequestModule.RequestParameters calldata _requestModuleData,
    address _arbitrator
  ) external happyPath(_arbitrator) {
    eboRequestCreator.setRequestModuleData(_requestModule, _requestModuleData);

    IOracle.Request memory _requestData = eboRequestCreator.getRequestData();
    assertEq(abi.encode(_requestModuleData), _requestData.requestModuleData);
  }

  /**
   * @notice Test the emit request module data set
   */
  function test_emitRequestModuleDataSet(
    address _requestModule,
    IEBORequestModule.RequestParameters calldata _requestModuleData,
    address _arbitrator
  ) external happyPath(_arbitrator) {
    vm.expectEmit();

    emit RequestModuleDataSet(_requestModule, _requestModuleData);

    eboRequestCreator.setRequestModuleData(_requestModule, _requestModuleData);
  }
}

contract EBORequestCreator_Unit_SetResponseModuleData is EBORequestCreator_Unit_BaseTest {
  modifier happyPath(address _arbitrator) {
    vm.mockCall(
      address(arbitrable),
      abi.encodeWithSelector(IArbitrable.validateArbitrator.selector, _arbitrator),
      abi.encode(true)
    );
    vm.startPrank(_arbitrator);
    _;
  }

  /**
   * @notice Test the emit response module data set
   */
  function test_emitResponseModuleDataSet(
    address _responseModule,
    IBondedResponseModule.RequestParameters calldata _responseModuleData,
    address _arbitrator
  ) external happyPath(_arbitrator) {
    vm.expectEmit();
    emit ResponseModuleDataSet(_responseModule, _responseModuleData);

    eboRequestCreator.setResponseModuleData(_responseModule, _responseModuleData);
  }
}

contract EBORequestCreator_Unit_SetDisputeModuleData is EBORequestCreator_Unit_BaseTest {
  modifier happyPath(address _arbitrator) {
    vm.mockCall(
      address(arbitrable),
      abi.encodeWithSelector(IArbitrable.validateArbitrator.selector, _arbitrator),
      abi.encode(true)
    );
    vm.startPrank(_arbitrator);
    _;
  }

  /**
   * @notice Test the emit dispute module data set
   */
  function test_emitDisputeModuleDataSet(
    address _disputeModule,
    IBondEscalationModule.RequestParameters calldata _disputeModuleData,
    address _arbitrator
  ) external happyPath(_arbitrator) {
    vm.expectEmit();
    emit DisputeModuleDataSet(_disputeModule, _disputeModuleData);

    eboRequestCreator.setDisputeModuleData(_disputeModule, _disputeModuleData);
  }
}

contract EBORequestCreator_Unit_SetResolutionModuleData is EBORequestCreator_Unit_BaseTest {
  modifier happyPath(address _arbitrator) {
    vm.mockCall(
      address(arbitrable),
      abi.encodeWithSelector(IArbitrable.validateArbitrator.selector, _arbitrator),
      abi.encode(true)
    );
    vm.startPrank(_arbitrator);
    _;
  }

  /**
   * @notice Test the emit resolution module data set
   */
  function test_emitResolutionModuleDataSet(
    address _resolutionModule,
    IArbitratorModule.RequestParameters calldata _resolutionModuleData,
    address _arbitrator
  ) external happyPath(_arbitrator) {
    vm.expectEmit();
    emit ResolutionModuleDataSet(_resolutionModule, _resolutionModuleData);

    eboRequestCreator.setResolutionModuleData(_resolutionModule, _resolutionModuleData);
  }
}

contract EBORequestCreator_Unit_SetFinalityModuleData is EBORequestCreator_Unit_BaseTest {
  modifier happyPath(address _arbitrator) {
    vm.mockCall(
      address(arbitrable),
      abi.encodeWithSelector(IArbitrable.validateArbitrator.selector, _arbitrator),
      abi.encode(true)
    );
    vm.startPrank(_arbitrator);
    _;
  }

  /**
   * @notice Test the emit finality module data set
   */
  function test_emitFinalityModuleDataSet(address _finalityModule, address _arbitrator) external happyPath(_arbitrator) {
    vm.expectEmit();
    emit FinalityModuleDataSet(_finalityModule, new bytes(0));

    eboRequestCreator.setFinalityModuleData(_finalityModule);
  }
}

contract EBORequestCreator_Unit_SetEpochManager is EBORequestCreator_Unit_BaseTest {
  modifier happyPath(IEpochManager _epochManager, address _arbitrator) {
    vm.assume(address(_epochManager) != address(0));

    vm.mockCall(
      address(arbitrable),
      abi.encodeWithSelector(IArbitrable.validateArbitrator.selector, _arbitrator),
      abi.encode(true)
    );
    vm.startPrank(_arbitrator);
    _;
  }

  /**
   * @notice Test the emit epoch manager set
   */
  function test_emitEpochManagerSet(
    IEpochManager _epochManager,
    address _arbitrator
  ) external happyPath(_epochManager, _arbitrator) {
    vm.expectEmit();
    emit EpochManagerSet(_epochManager);

    eboRequestCreator.setEpochManager(_epochManager);
  }
}

contract EBORequestCreator_Unit_GetAllowedChains is EBORequestCreator_Unit_BaseTest {
  /**
   * @notice Test returns the correct chain ids
   */
  function test_getChains() external {
    string[] memory _chainsToAdd = new string[](3);
    _chainsToAdd[0] = '1';
    _chainsToAdd[1] = '2';
    _chainsToAdd[2] = '3';

    for (uint256 i = 0; i < _chainsToAdd.length; i++) {
      eboRequestCreator.setChainIdForTest(_chainsToAdd[i]);
    }

    bytes32[] memory _allowedChains = eboRequestCreator.getAllowedChainIds();
    assertEq(_allowedChains.length, _chainsToAdd.length);

    for (uint256 i = 0; i < _allowedChains.length; i++) {
      assertEq(_allowedChains[i], eboRequestCreator.encodeChainIdForTest(_chainsToAdd[i]));
    }
  }
}
