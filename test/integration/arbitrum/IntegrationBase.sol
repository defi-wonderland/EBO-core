// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.26;

import {ValidatorLib} from '@defi-wonderland/prophet-core/solidity/libraries/ValidatorLib.sol';
import {IController} from 'interfaces/external/IController.sol';

import {_ARBITRUM_SEPOLIA_CONTROLLER, _ARBITRUM_SEPOLIA_GOVERNOR} from 'script/Constants.sol';

import 'script/Deploy.s.sol';

import 'forge-std/Test.sol';

contract IntegrationBase is Deploy, Test {
  using ValidatorLib for IOracle.Request;
  using ValidatorLib for IOracle.Response;
  using ValidatorLib for IOracle.Dispute;

  uint256 internal constant _ARBITRUM_MAINNET_FORK_BLOCK = 240_000_000;
  uint256 internal constant _ARBITRUM_SEPOLIA_FORK_BLOCK = 83_000_000;

  // The Graph
  IController internal _controller;
  address internal _governor;

  // Users
  address internal _requester;
  address internal _proposer;
  address internal _disputer;

  // Data
  mapping(bytes32 _requestId => IOracle.Request _requestData) internal _requests;
  mapping(bytes32 _responseId => IOracle.Response _responseData) internal _responses;
  mapping(bytes32 _disputeId => IOracle.Dispute _disputeData) internal _disputes;
  string internal _chainId;
  uint256 internal _currentEpoch;

  function setUp() public virtual override {
    vm.createSelectFork(vm.rpcUrl('arbitrum'), _ARBITRUM_SEPOLIA_FORK_BLOCK);

    // Run deployment script
    super.setUp();
    run();

    // Define The Graph accounts
    _controller = IController(_ARBITRUM_SEPOLIA_CONTROLLER);
    _governor = _ARBITRUM_SEPOLIA_GOVERNOR;

    // Set user accounts
    _requester = makeAddr('requester');
    _proposer = makeAddr('proposer');
    _disputer = makeAddr('disputer');

    // Set chain ID
    _chainId = 'chainId1';

    // Fetch current epoch
    _currentEpoch = epochManager.currentEpoch();

    // Unpause Graph Horizon
    vm.prank(_governor);
    _controller.setPaused(false);
  }

  function _createRequest() internal returns (bytes32 _requestId) {
    IEBORequestModule.RequestParameters memory _requestParams = _instantiateRequestParams();
    _requestParams.epoch = _currentEpoch;
    _requestParams.chainId = _chainId;

    IOracle.Request memory _requestData = _instantiateRequestData();
    _requestData.requestModuleData = abi.encode(_requestParams);

    vm.prank(_requester);
    eboRequestCreator.createRequest(_currentEpoch, _chainId);

    _requestId = _requestData._getId();
    _requests[_requestId] = _requestData;
  }

  function _proposeResponse(bytes32 _requestId) internal returns (bytes32 _responseId) {
    IOracle.Request memory _requestData = _requests[_requestId];

    IOracle.Response memory _responseData = _instantiateResponseData(_requestId);

    vm.prank(_proposer);
    oracle.proposeResponse(_requestData, _responseData);

    _responseId = _responseData._getId();
    _responses[_responseId] = _responseData;
  }

  function _disputeResponse(bytes32 _requestId, bytes32 _responseId) internal returns (bytes32 _disputeId) {
    IOracle.Request memory _requestData = _requests[_requestId];
    IOracle.Response memory _responseData = _responses[_responseId];

    IOracle.Dispute memory _disputeData = _instantiateDisputeData(_requestId, _responseId);

    vm.prank(_disputer);
    oracle.disputeResponse(_requestData, _responseData, _disputeData);

    _disputeId = _disputeData._getId();
    _disputes[_disputeId] = _disputeData;
  }

  function _escalateDispute(bytes32 _requestId, bytes32 _responseId, bytes32 _disputeId) internal {
    IOracle.Request memory _requestData = _requests[_requestId];
    IOracle.Response memory _responseData = _responses[_responseId];
    IOracle.Dispute memory _disputeData = _disputes[_disputeId];

    oracle.escalateDispute(_requestData, _responseData, _disputeData);
  }

  function _resolveDispute(bytes32 _requestId, bytes32 _responseId, bytes32 _disputeId) internal {
    IOracle.Request memory _requestData = _requests[_requestId];
    IOracle.Response memory _responseData = _responses[_responseId];
    IOracle.Dispute memory _disputeData = _disputes[_disputeId];

    oracle.resolveDispute(_requestData, _responseData, _disputeData);
  }

  function _arbitrateDispute(bytes32 _disputeId, IOracle.DisputeStatus _award) internal {
    vm.prank(arbitrator);
    councilArbitrator.arbitrateDispute(_disputeId, _award);
  }

  function _addChains() internal {
    string[] memory _chainIds = _getChains();

    vm.startPrank(arbitrator);
    for (uint256 _i; _i < _chainIds.length; ++_i) {
      eboRequestCreator.addChain(_chainIds[_i]);
    }
    vm.stopPrank();
  }

  function _setRequestModuleData() internal {
    IEBORequestModule.RequestParameters memory _requestParams = _instantiateRequestParams();

    vm.prank(arbitrator);
    eboRequestCreator.setRequestModuleData(address(eboRequestModule), _requestParams);
  }

  function _setResponseModuleData() internal {
    IBondedResponseModule.RequestParameters memory _responseParams = _instantiateResponseParams();

    vm.prank(arbitrator);
    eboRequestCreator.setResponseModuleData(address(bondedResponseModule), _responseParams);
  }

  function _setDisputeModuleData() internal {
    IBondEscalationModule.RequestParameters memory _disputeParams = _instantiateDisputeParams();

    vm.prank(arbitrator);
    eboRequestCreator.setDisputeModuleData(address(bondEscalationModule), _disputeParams);
  }

  function _setResolutionModuleData() internal {
    IArbitratorModule.RequestParameters memory _resolutionParams = _instantiateResolutionParams();

    vm.prank(arbitrator);
    eboRequestCreator.setResolutionModuleData(address(arbitratorModule), _resolutionParams);
  }

  function _approveModules() internal {
    vm.prank(_requester);
    horizonAccountingExtension.approveModule(address(eboRequestModule));

    vm.prank(_proposer);
    horizonAccountingExtension.approveModule(address(bondedResponseModule));

    vm.prank(_disputer);
    horizonAccountingExtension.approveModule(address(bondEscalationModule));
  }

  function _stakeGRT() internal {
    vm.startPrank(_requester);
    deal(address(graphToken), _requester, paymentAmount, true);
    graphToken.approve(address(horizonStaking), paymentAmount);
    horizonStaking.stake(paymentAmount);

    vm.startPrank(_proposer);
    deal(address(graphToken), _proposer, responseBondSize, true);
    graphToken.approve(address(horizonStaking), responseBondSize);
    horizonStaking.stake(responseBondSize);

    vm.startPrank(_disputer);
    deal(address(graphToken), _disputer, disputeBondSize, true);
    graphToken.approve(address(horizonStaking), disputeBondSize);
    horizonStaking.stake(disputeBondSize);
    vm.stopPrank();
  }

  function _createProvisions() internal {
    vm.startPrank(_requester);
    horizonStaking.provision(
      _requester,
      address(horizonAccountingExtension),
      paymentAmount,
      horizonAccountingExtension.MAX_VERIFIER_CUT(),
      horizonAccountingExtension.MIN_THAWING_PERIOD()
    );

    vm.startPrank(_proposer);
    horizonStaking.provision(
      _proposer,
      address(horizonAccountingExtension),
      responseBondSize,
      horizonAccountingExtension.MAX_VERIFIER_CUT(),
      horizonAccountingExtension.MIN_THAWING_PERIOD()
    );

    vm.startPrank(_disputer);
    horizonStaking.provision(
      _disputer,
      address(horizonAccountingExtension),
      disputeBondSize,
      horizonAccountingExtension.MAX_VERIFIER_CUT(),
      horizonAccountingExtension.MIN_THAWING_PERIOD()
    );
    vm.stopPrank();
  }

  function _instantiateResponseData(bytes32 _requestId) internal view returns (IOracle.Response memory _responseData) {
    _responseData.proposer = _proposer;
    _responseData.requestId = _requestId;
    _responseData.response = abi.encode(''); // TODO: Populate response
  }

  function _instantiateDisputeData(
    bytes32 _requestId,
    bytes32 _responseId
  ) internal view returns (IOracle.Dispute memory _disputeData) {
    _disputeData.disputer = _disputer;
    _disputeData.proposer = _proposer;
    _disputeData.responseId = _responseId;
    _disputeData.requestId = _requestId;
  }

  function _getChains() internal view returns (string[] memory _chainIds) {
    _chainIds = new string[](1);
    _chainIds[0] = _chainId;
  }
}
