// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.26;

import './IntegrationBase.sol';

contract IntegrationHorizonAccounting is IntegrationBase {
  function setUp() public override {
    super.setUp();

    // Add chain IDs
    _addChains();

    // Set modules data
    _setRequestModuleData();
    _setResponseModuleData();
    _setDisputeModuleData();
    _setResolutionModuleData();

    // Approve modules
    _approveModules();

    // Stake GRT and create provisions
    _stakeGRT();
    _createProvisions();
  }

  function test_ProposeResponseThawingFunds() public {
    // Should be able to create a request easily
    // Create the request
    bytes32 _requestId = _createRequest();

    // Do not pass the response deadline
    vm.warp(responseDeadline - 1);

    // Propose the response
    bytes32 _responseId = _proposeResponse(_requestId);

    // Assert Oracle::proposeResponse
    assertEq(oracle.responseCreatedAt(_responseId), block.number);
    // Assert HorizonAccountingExtension::bond
    assertEq(horizonAccountingExtension.bondedForRequest(_proposer, _requestId), responseBondSize);
    assertEq(horizonAccountingExtension.totalBonded(_proposer), responseBondSize);

    vm.roll(block.number + 1);

    // Reprovision more tokens to try again
    _stakeGRT();
    _addToProvisions();

    // Thaw some tokens
    vm.prank(_proposer);
    horizonStaking.thaw(_proposer, address(horizonAccountingExtension), responseBondSize + 1);

    // Create the request
    bytes32 _requestId2 = _createRequest(_chainId2);

    // Do not pass the response deadline
    vm.warp(responseDeadline - 1);

    // Propose the response reverts because of insufficient funds
    vm.expectRevert(IHorizonAccountingExtension.HorizonAccountingExtension_InsufficientTokens.selector);
    _proposeResponse(_requestId2);
  }
}
