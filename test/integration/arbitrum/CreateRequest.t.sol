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

    vm.prank(_user);
    _eboRequestCreator.createRequests(_currentEpoch, _chainIds);
    assertNotEq(_eboRequestCreator.requestIdPerChainAndEpoch('chainId1', _currentEpoch), bytes32(0));

    // Remove the chain id
    vm.prank(_arbitrator);
    _eboRequestCreator.removeChain('chainId1');

    // Create a request without approving the chain id
    vm.expectRevert(IEBORequestCreator.EBORequestCreator_ChainNotAdded.selector);
    vm.prank(_user);
    _eboRequestCreator.createRequests(_currentEpoch, _chainIds);
  }
}