// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.26;

import './IntegrationBase.sol';

contract Integration_CreateRequest is IntegrationBase {
  function test_createRequest() public {
    string[] memory _chainIds = new string[](1);
    _chainIds[0] = 'chainId1';

    // Should revert if the epoch is invalid
    vm.expectRevert(IEBORequestCreator.EBORequestCreator_InvalidEpoch.selector);
    vm.prank(_user);
    _eboRequestCreator.createRequests(1, _chainIds);

    // New epoch
    vm.roll(242_000_000);
    // Get the current epoch
    uint256 _currentEpoch = _epochManager.currentEpoch();

    // Create a request without approving the chain id
    vm.expectRevert(IEBORequestCreator.EBORequestCreator_ChainNotAdded.selector);
    vm.prank(_user);
    _eboRequestCreator.createRequests(_currentEpoch, _chainIds);

    // Create a request with an approved chain id
    vm.prank(_arbitrator);
    _eboRequestCreator.addChain('chainId1');

    // Check that oracle is creating the request with the correct chain id and epoch
    IEBORequestModule.RequestParameters memory _requestModuleData;
    _requestModuleData.accountingExtension = _accountingExtension;
    _requestModuleData.chainId = 'chainId1';
    _requestModuleData.epoch = _currentEpoch;

    _requestData.requestModuleData = abi.encode(_requestModuleData);
    _requestData.requestModule = address(_eboRequestModule);
    _requestData.requester = address(_eboRequestCreator);

    // Expect the oracle to create the request
    vm.expectCall(address(_oracle), abi.encodeWithSelector(IOracle.createRequest.selector, _requestData, bytes32(0)));

    vm.prank(_user);
    _eboRequestCreator.createRequests(_currentEpoch, _chainIds);
    bytes32 _requestId = _eboRequestCreator.requestIdPerChainAndEpoch('chainId1', _currentEpoch);

    // Check that the request id is stored correctly
    assertEq(_oracle.requestCreatedAt(_requestId), block.number);

    // Remove the chain id
    vm.prank(_arbitrator);
    _eboRequestCreator.removeChain('chainId1');

    // Create a request without approving the chain id
    vm.expectRevert(IEBORequestCreator.EBORequestCreator_ChainNotAdded.selector);
    vm.prank(_user);
    _eboRequestCreator.createRequests(_currentEpoch, _chainIds);
  }
}
