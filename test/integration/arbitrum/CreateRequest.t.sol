// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

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

    bytes32 _requestId = keccak256('requestId');
    // TODO: Remove the mock when the Oracle contract is implemented
    vm.mockCall(address(_oracle), abi.encodeWithSelector(IOracle.createRequest.selector), abi.encode(_requestId));

    vm.prank(_user);
    _eboRequestCreator.createRequests(_currentEpoch, _chainIds);
    assertEq(_eboRequestCreator.requestIdPerChainAndEpoch('chainId1', _currentEpoch), _requestId);

    // Remove the chain id
    vm.prank(_arbitrator);
    _eboRequestCreator.removeChain('chainId1');

    // Create a request without approving the chain id
    vm.expectRevert(IEBORequestCreator.EBORequestCreator_ChainNotAdded.selector);
    vm.prank(_user);
    _eboRequestCreator.createRequests(_currentEpoch, _chainIds);
  }
}
