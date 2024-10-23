// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.26;

import {ValidatorLib} from '@defi-wonderland/prophet-core/solidity/libraries/ValidatorLib.sol';

import {_ARBITRUM_SEPOLIA_GOVERNOR} from 'script/Constants.sol';

import 'script/Deploy.s.sol';

import 'forge-std/Test.sol';

contract IntegrationBase is Deploy, Test {
  using ValidatorLib for IOracle.Request;
  using ValidatorLib for IOracle.Response;
  using ValidatorLib for IOracle.Dispute;

  uint256 internal constant _ARBITRUM_MAINNET_FORK_BLOCK = 240_000_000;
  uint256 internal constant _ARBITRUM_SEPOLIA_FORK_BLOCK = 83_750_000;

  // The Graph
  address internal _governor; // TODO: Remove if unused

  // Users
  address internal _requester;
  address internal _proposer;
  address internal _disputer;
  address internal _pledgerFor;
  address internal _pledgerAgainst;

  // Data
  mapping(bytes32 _requestId => IOracle.Request _requestData) internal _requests;
  mapping(bytes32 _responseId => IOracle.Response _responseData) internal _responses;
  mapping(bytes32 _disputeId => IOracle.Dispute _disputeData) internal _disputes;
  string internal _chainId;
  string internal _chainId2;
  uint256 internal _currentEpoch;
  uint256 internal _blockNumber;

  function setUp() public virtual override {
    vm.createSelectFork(vm.rpcUrl('arbitrum'), _ARBITRUM_SEPOLIA_FORK_BLOCK);

    // Run deployment script
    super.setUp();
    run();

    // Define The Graph accounts
    _governor = _ARBITRUM_SEPOLIA_GOVERNOR;

    // Set user accounts
    _requester = makeAddr('requester');
    _proposer = makeAddr('proposer');
    _disputer = makeAddr('disputer');
    _pledgerFor = makeAddr('pledgerFor');
    _pledgerAgainst = makeAddr('pledgerAgainst');

    // Set chain ID
    _chainId = 'chainId1';
    _chainId2 = 'chainId2';

    // Fetch current epoch
    _currentEpoch = epochManager.currentEpoch();

    // Set block number
    _blockNumber = block.number;
  }

  function _createRequest() internal returns (bytes32 _requestId) {
    _requestId = _createRequest(_chainId, _currentEpoch);
  }

  function _createRequest(string memory _customChainId, uint256 _customEpoch) internal returns (bytes32 _requestId) {
    IEBORequestModule.RequestParameters memory _requestParams = _instantiateRequestParams();
    _requestParams.epoch = _customEpoch;
    _requestParams.chainId = _customChainId;

    IOracle.Request memory _requestData = _instantiateRequestData();
    _requestData.requestModuleData = abi.encode(_requestParams);
    _requestData.nonce = uint96(oracle.totalRequestCount());

    vm.prank(_requester);
    eboRequestCreator.createRequest(_currentEpoch, _customChainId);

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

  function _pledgeForDispute(bytes32 _requestId, bytes32 _disputeId) internal {
    _pledgeForDispute(_pledgerFor, _requestId, _disputeId);
  }

  function _pledgeForDispute(address _sender, bytes32 _requestId, bytes32 _disputeId) internal {
    vm.prank(_sender);
    bondEscalationModule.pledgeForDispute(_requests[_requestId], _disputes[_disputeId]);
  }

  function _pledgeAgainstDispute(bytes32 _requestId, bytes32 _disputeId) internal {
    _pledgeAgainstDispute(_pledgerAgainst, _requestId, _disputeId);
  }

  function _pledgeAgainstDispute(address _sender, bytes32 _requestId, bytes32 _disputeId) internal {
    vm.prank(_sender);
    bondEscalationModule.pledgeAgainstDispute(_requests[_requestId], _disputes[_disputeId]);
  }

  function _settleBondEscalation(bytes32 _requestId, bytes32 _responseId, bytes32 _disputeId) internal {
    IOracle.Request memory _requestData = _requests[_requestId];
    IOracle.Response memory _responseData = _responses[_responseId];
    IOracle.Dispute memory _disputeData = _disputes[_disputeId];

    bondEscalationModule.settleBondEscalation(_requestData, _responseData, _disputeData);
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

  function _finalizeRequest(bytes32 _requestId, bytes32 _responseId) internal {
    IOracle.Request memory _requestData = _requests[_requestId];
    IOracle.Response memory _responseData = _responses[_responseId];

    oracle.finalize(_requestData, _responseData);
  }

  function _releaseUnfinalizableResponseBond(bytes32 _requestId, bytes32 _responseId) internal {
    IOracle.Request memory _requestData = _requests[_requestId];
    IOracle.Response memory _responseData = _responses[_responseId];

    bondedResponseModule.releaseUnutilizedResponse(_requestData, _responseData);
  }

  function _claimEscalationReward(bytes32 _disputeId, address _pledger) internal {
    horizonAccountingExtension.claimEscalationReward(_disputeId, _pledger);
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
    vm.prank(_proposer);
    horizonAccountingExtension.approveModule(address(bondedResponseModule));

    vm.prank(_disputer);
    horizonAccountingExtension.approveModule(address(bondEscalationModule));
  }

  function _stakeGRT() internal {
    vm.startPrank(_proposer);
    deal(address(graphToken), _proposer, responseBondSize, true);
    graphToken.approve(address(horizonStaking), responseBondSize);
    horizonStaking.stake(responseBondSize);

    vm.startPrank(_disputer);
    deal(address(graphToken), _disputer, disputeBondSize, true);
    graphToken.approve(address(horizonStaking), disputeBondSize);
    horizonStaking.stake(disputeBondSize);

    vm.startPrank(_pledgerFor);
    deal(address(graphToken), _pledgerFor, disputeBondSize * maxNumberOfEscalations, true);
    graphToken.approve(address(horizonStaking), disputeBondSize * maxNumberOfEscalations);
    horizonStaking.stake(disputeBondSize * maxNumberOfEscalations);

    vm.startPrank(_pledgerAgainst);
    deal(address(graphToken), _pledgerAgainst, disputeBondSize * maxNumberOfEscalations, true);
    graphToken.approve(address(horizonStaking), disputeBondSize * maxNumberOfEscalations);
    horizonStaking.stake(disputeBondSize * maxNumberOfEscalations);
    vm.stopPrank();
  }

  function _stakeGRT(address _sender, uint256 _amount) internal {
    vm.startPrank(_sender);
    deal(address(graphToken), _sender, _amount, true);
    graphToken.approve(address(horizonStaking), _amount);
    horizonStaking.stake(_amount);
    vm.stopPrank();
  }

  function _createProvisions() internal {
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

    vm.startPrank(_pledgerFor);
    horizonStaking.provision(
      _pledgerFor,
      address(horizonAccountingExtension),
      disputeBondSize * maxNumberOfEscalations,
      horizonAccountingExtension.MAX_VERIFIER_CUT(),
      horizonAccountingExtension.MIN_THAWING_PERIOD()
    );

    vm.startPrank(_pledgerAgainst);
    horizonStaking.provision(
      _pledgerAgainst,
      address(horizonAccountingExtension),
      disputeBondSize * maxNumberOfEscalations,
      horizonAccountingExtension.MAX_VERIFIER_CUT(),
      horizonAccountingExtension.MIN_THAWING_PERIOD()
    );
    vm.stopPrank();
  }

  function _addToProvisions() internal {
    vm.startPrank(_proposer);
    horizonStaking.addToProvision(_proposer, address(horizonAccountingExtension), responseBondSize);

    vm.startPrank(_disputer);
    horizonStaking.addToProvision(_disputer, address(horizonAccountingExtension), disputeBondSize);

    vm.startPrank(_pledgerFor);
    horizonStaking.addToProvision(
      _pledgerFor, address(horizonAccountingExtension), disputeBondSize * maxNumberOfEscalations
    );

    vm.startPrank(_pledgerAgainst);
    horizonStaking.addToProvision(
      _pledgerAgainst, address(horizonAccountingExtension), disputeBondSize * maxNumberOfEscalations
    );
    vm.stopPrank();
  }

  function _addToProvision(address _sender, uint256 _amount) internal {
    vm.prank(_sender);
    horizonStaking.addToProvision(_sender, address(horizonAccountingExtension), _amount);
  }

  function _createProvision(address _sender, uint256 _amount) internal {
    vm.startPrank(_sender);
    horizonStaking.provision(
      _sender,
      address(horizonAccountingExtension),
      _amount,
      horizonAccountingExtension.MAX_VERIFIER_CUT(),
      horizonAccountingExtension.MIN_THAWING_PERIOD()
    );
    vm.stopPrank();
  }

  function _thaw(address _sender, uint256 _amount) internal {
    vm.prank(_sender);
    horizonStaking.thaw(_sender, address(horizonAccountingExtension), _amount);
  }

  function _instantiateResponseData(bytes32 _requestId) internal view returns (IOracle.Response memory _responseData) {
    _responseData.proposer = _proposer;
    _responseData.requestId = _requestId;
    _responseData.response = abi.encode(_blockNumber);
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
    _chainIds = new string[](2);
    _chainIds[0] = _chainId;
    _chainIds[1] = _chainId2;
  }
}
