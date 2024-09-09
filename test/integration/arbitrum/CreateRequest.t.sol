// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.26;

import './IntegrationBase.sol';

contract IntegrationCreateRequest is IntegrationBase {
  function setUp() public override {
    super.setUp();

    // Set modules data
    _setRequestModuleData();
    _setResponseModuleData();
    _setDisputeModuleData();
    _setResolutionModuleData();
  }

  function test_CreateRequest() public {
    string[] memory _chainIds = _getChainIds();

    // Should revert if the epoch is invalid
    vm.expectRevert(IEBORequestCreator.EBORequestCreator_InvalidEpoch.selector);
    vm.prank(_requester);
    eboRequestCreator.createRequests(1, _chainIds);

    // Create a request without approving the chain ID
    vm.expectRevert(IEBORequestCreator.EBORequestCreator_ChainNotAdded.selector);
    vm.prank(_requester);
    eboRequestCreator.createRequests(_currentEpoch, _chainIds);

    // Add chain IDs
    _addChains();

    // Check that oracle is creating the request with the correct chain ID and epoch
    IEBORequestModule.RequestParameters memory _requestParams = _instantiateRequestParams();
    _requestParams.epoch = _currentEpoch;
    _requestParams.chainId = _chainId;

    IOracle.Request memory _requestData = _instantiateRequestData();
    _requestData.requestModuleData = abi.encode(_requestParams);

    // Expect the oracle to create the request
    vm.expectCall(address(oracle), abi.encodeWithSelector(IOracle.createRequest.selector, _requestData, bytes32(0)));

    vm.prank(_requester);
    eboRequestCreator.createRequests(_currentEpoch, _chainIds);
    bytes32 _requestId = eboRequestCreator.requestIdPerChainAndEpoch(_chainId, _currentEpoch);

    // Check that the request ID is stored correctly
    assertEq(oracle.requestCreatedAt(_requestId), block.number);

    // Remove the chain ID
    vm.prank(arbitrator);
    eboRequestCreator.removeChain(_chainId);

    // Create a request without approving the chain ID
    vm.expectRevert(IEBORequestCreator.EBORequestCreator_ChainNotAdded.selector);
    vm.prank(_requester);
    eboRequestCreator.createRequests(_currentEpoch, _chainIds);
  }
}
