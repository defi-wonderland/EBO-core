// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.26;

import './IntegrationBase.sol';

contract IntegrationProposeResponse is IntegrationBase {
  using ValidatorLib for IOracle.Request;

  function setUp() public override {
    super.setUp();

    // Set modules data
    _setRequestModuleData();
    _setResponseModuleData();
    _setDisputeModuleData();
    _setResolutionModuleData();

    // Deposit GRT and approve modules
    _depositGRT();
    _approveModules();

    // Add chain IDs
    _addChains();
  }

  function test_ProposeResponse() public {
    // Create the request
    bytes32 _requestId = _createRequest();

    // Pass the response deadline
    vm.warp(responseDeadline);

    // Revert if the response is proposed after the deadline
    vm.expectRevert(IBondedResponseModule.BondedResponseModule_TooLateToPropose.selector);
    _proposeResponse(_requestId);

    // Do not pass the response deadline
    vm.warp(responseDeadline - 1);

    // Propose the response
    bytes32 _responseId = _proposeResponse(_requestId);

    assertEq(oracle.responseCreatedAt(_responseId), block.number);
    assertEq(bondEscalationAccounting.bondedAmountOf(_proposer, graphToken, _requestId), responseBondSize);

    // Revert if the response has already been proposed
    vm.expectRevert(IOracle.Oracle_InvalidResponseBody.selector);
    _proposeResponse(_requestId);
  }
}
