// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.26;

import './IntegrationBase.sol';

contract Integration_CreateRequest is IntegrationBase {
  function setUp() public override {
    super.setUp();

    // Create data
    _setRequestModuleData();
  }

  function test_createRequest() public {
    // Should revert if the epoch is invalid
    vm.expectRevert(IEBORequestCreator.EBORequestCreator_InvalidEpoch.selector);
    vm.prank(_user);
    _eboRequestCreator.createRequest(1, _chainId);

    // Create a request without approving the chain id
    vm.expectRevert(IEBORequestCreator.EBORequestCreator_ChainNotAdded.selector);
    vm.prank(_user);
    _eboRequestCreator.createRequest(_currentEpoch, _chainId);

    // Create a request with an approved chain id
    _addChains();

    // Check that oracle is creating the request with the correct chain id and epoch
    _requestParams.chainId = _chainId;
    _requestParams.epoch = _currentEpoch;
    _requestData.requestModuleData = abi.encode(_requestParams);

    // Expect the oracle to create the request
    vm.expectCall(address(_oracle), abi.encodeWithSelector(IOracle.createRequest.selector, _requestData, bytes32(0)));

    vm.prank(_user);
    _eboRequestCreator.createRequest(_currentEpoch, _chainId);
    bytes32 _requestId = _eboRequestCreator.requestIdPerChainAndEpoch(_chainId, _currentEpoch);

    // Check that the request id is stored correctly
    assertEq(_oracle.requestCreatedAt(_requestId), block.number);

    // Revert if the request is already created
    vm.prank(_user);
    vm.expectRevert(IEBORequestCreator.EBORequestCreator_RequestAlreadyCreated.selector);
    _eboRequestCreator.createRequest(_currentEpoch, _chainId);

    // Remove the chain id
    vm.prank(_arbitrator);
    _eboRequestCreator.removeChain(_chainId);

    // Create a request without approving the chain id
    vm.expectRevert(IEBORequestCreator.EBORequestCreator_ChainNotAdded.selector);
    vm.prank(_user);
    _eboRequestCreator.createRequest(_currentEpoch, _chainId);
  }
}
