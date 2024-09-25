// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.26;

import './IntegrationBase.sol';

contract IntegrationProposeResponse is IntegrationBase {
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

  function test_ProposeResponse() public {
    // Create the request
    bytes32 _requestId = _createRequest();

    // Pass the response deadline
    vm.warp(responseDeadline);

    // Revert if the response is proposed after the response deadline
    vm.expectRevert(IBondedResponseModule.BondedResponseModule_TooLateToPropose.selector);
    _proposeResponse(_requestId);

    // Do not pass the response deadline
    vm.warp(responseDeadline - 1);

    // Propose the response
    bytes32 _responseId = _proposeResponse(_requestId);

    // Assert Oracle::proposeResponse
    assertEq(oracle.responseCreatedAt(_responseId), block.number);
    // Assert HorizonAccountingExtension::bond
    assertEq(horizonAccountingExtension.bondedForRequest(_proposer, _requestId), responseBondSize);
    assertEq(horizonAccountingExtension.totalBonded(_proposer), responseBondSize);

    // Revert if the response has already been proposed
    vm.expectRevert(IOracle.Oracle_InvalidResponseBody.selector);
    _proposeResponse(_requestId);
  }
}
