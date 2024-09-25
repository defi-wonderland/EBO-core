// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.26;

import './IntegrationBase.sol';

contract IntegrationDisputeResponse is IntegrationBase {
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

  function test_DisputeResponse() public {
    // Create the request
    bytes32 _requestId = _createRequest();
    // Propose the response
    bytes32 _responseId = _proposeResponse(_requestId);

    // Pass the dispute window
    vm.roll(block.number + disputeDisputeWindow + 1);

    // Revert if the dispute window has passed
    vm.expectRevert(IBondEscalationModule.BondEscalationModule_DisputeWindowOver.selector);
    _disputeResponse(_requestId, _responseId);

    // Do not pass the dispute window
    vm.roll(block.number - disputeDisputeWindow - 1);

    // Pass the dispute deadline
    vm.warp(disputeDeadline + 1);

    // Revert if the bond escalation deadline has passed
    vm.expectRevert(IBondEscalationModule.BondEscalationModule_BondEscalationOver.selector);
    _disputeResponse(_requestId, _responseId);

    // Do not pass the dispute deadline
    vm.warp(disputeDeadline);

    // Dispute the response
    bytes32 _disputeId = _disputeResponse(_requestId, _responseId);

    // Assert Oracle::disputeResponse
    assertEq(uint8(oracle.disputeStatus(_disputeId)), uint8(IOracle.DisputeStatus.Active));
    assertEq(oracle.disputeOf(_responseId), _disputeId);
    assertEq(oracle.disputeCreatedAt(_disputeId), block.number);
    // Assert BondEscalationModule::disputeResponse
    IBondEscalationModule.BondEscalation memory _escalation = bondEscalationModule.getEscalation(_requestId);
    assertEq(_escalation.disputeId, _disputeId);
    assertEq(uint8(_escalation.status), uint8(IBondEscalationModule.BondEscalationStatus.Active));
    // Assert BondEscalationAccounting::bond
    assertEq(bondEscalationAccounting.bondedAmountOf(_disputer, graphToken, _requestId), disputeBondSize);
    assertEq(bondEscalationAccounting.balanceOf(_disputer, graphToken), 0);

    // Revert if the response has already been disputed
    vm.expectRevert(abi.encodeWithSelector(IOracle.Oracle_ResponseAlreadyDisputed.selector, _responseId));
    _disputeResponse(_requestId, _responseId);
  }
}
