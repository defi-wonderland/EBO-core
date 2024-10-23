// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.26;

import './IntegrationBase.t.sol';

contract IntegrationEscalateDispute is IntegrationBase {
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

  function test_EscalateDispute() public {
    // Create the request
    bytes32 _requestId = _createRequest();
    // Propose the response
    bytes32 _responseId = _proposeResponse(_requestId);
    // Dispute the response
    bytes32 _disputeId = _disputeResponse(_requestId, _responseId);

    // Revert if the bond escalation deadline has not passed
    vm.expectRevert(IBondEscalationModule.BondEscalationModule_BondEscalationNotOver.selector);
    _escalateDispute(_requestId, _responseId, _disputeId);

    // Pledge for the dispute
    _pledgeForDispute(_requestId, _disputeId);

    // Pass the dispute deadline
    vm.warp(oracle.disputeCreatedAt(_disputeId) + disputeDeadline + 1);

    // Revert if the bond escalation has not tied
    vm.expectRevert(IBondEscalationModule.BondEscalationModule_NotEscalatable.selector);
    _escalateDispute(_requestId, _responseId, _disputeId);

    // Do not pass the dispute deadline
    vm.warp(oracle.disputeCreatedAt(_disputeId) + disputeDeadline);

    // Pledge against the dispute
    _pledgeAgainstDispute(_requestId, _disputeId);

    // Pass the dispute deadline
    vm.warp(oracle.disputeCreatedAt(_disputeId) + disputeDeadline + 1);

    // Escalate the dispute
    _escalateDispute(_requestId, _responseId, _disputeId);

    // Assert Oracle::escalateDispute
    assertEq(uint8(oracle.disputeStatus(_disputeId)), uint8(IOracle.DisputeStatus.Escalated));
    // Assert BondEscalationModule::onDisputeStatusChange
    IBondEscalationModule.BondEscalation memory _escalation = bondEscalationModule.getEscalation(_requestId);
    assertEq(_escalation.disputeId, _disputeId);
    assertEq(uint8(_escalation.status), uint8(IBondEscalationModule.BondEscalationStatus.Escalated));
    // Assert ArbitratorModule::startResolution
    IArbitratorModule.ArbitrationStatus _disputeStatus = arbitratorModule.getStatus(_disputeId);
    assertEq(uint8(_disputeStatus), uint8(IArbitratorModule.ArbitrationStatus.Active));
    // Assert CouncilArbitrator::resolve
    ICouncilArbitrator.ResolutionParameters memory _resolutionParams = councilArbitrator.getResolution(_disputeId);
    assertEq(abi.encode(_resolutionParams.request), abi.encode(_requests[_requestId]));
    assertEq(abi.encode(_resolutionParams.response), abi.encode(_responses[_responseId]));
    assertEq(abi.encode(_resolutionParams.dispute), abi.encode(_disputes[_disputeId]));

    // Revert if the dispute has already been escalated
    vm.expectRevert(abi.encodeWithSelector(IOracle.Oracle_CannotEscalate.selector, _disputeId));
    _escalateDispute(_requestId, _responseId, _disputeId);

    // Revert if the dispute has been escalated
    vm.expectRevert(IBondEscalationModule.BondEscalationModule_CannotBreakTieDuringTyingBuffer.selector);
    _pledgeForDispute(_requestId, _disputeId);
    vm.expectRevert(IBondEscalationModule.BondEscalationModule_CannotBreakTieDuringTyingBuffer.selector);
    _pledgeAgainstDispute(_requestId, _disputeId);
    vm.expectRevert(IBondEscalationModule.BondEscalationModule_BondEscalationNotOver.selector);
    _settleBondEscalation(_requestId, _responseId, _disputeId);

    // Pass the dispute deadline and the tying buffer
    vm.warp(oracle.disputeCreatedAt(_disputeId) + disputeDeadline + tyingBuffer + 1);

    // Revert if the dispute has been escalated
    vm.expectRevert(IBondEscalationModule.BondEscalationModule_BondEscalationOver.selector);
    _pledgeForDispute(_requestId, _disputeId);
    vm.expectRevert(IBondEscalationModule.BondEscalationModule_BondEscalationOver.selector);
    _pledgeAgainstDispute(_requestId, _disputeId);
    vm.expectRevert(IBondEscalationModule.BondEscalationModule_BondEscalationCantBeSettled.selector);
    _settleBondEscalation(_requestId, _responseId, _disputeId);
  }
}
