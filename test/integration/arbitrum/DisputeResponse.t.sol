// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.26;

import './IntegrationBase.sol';

contract IntegrationDisputeResponse is IntegrationBase {
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

  function test_DisputeResponse() public {
    // Create the request
    bytes32 _requestId = _createRequest();
    // Propose the response
    bytes32 _responseId = _proposeResponse(_requestId);
    // Dispute the response
    bytes32 _disputeId = _disputeResponse(_requestId, _responseId);

    assertEq(uint8(oracle.disputeStatus(_disputeId)), uint8(IOracle.DisputeStatus.Active));
    assertEq(oracle.disputeOf(_responseId), _disputeId);
    assertEq(oracle.disputeCreatedAt(_disputeId), block.number);
    assertEq(bondEscalationAccounting.bondedAmountOf(_disputer, graphToken, _requestId), disputeBondSize);

    IBondEscalationModule.BondEscalation memory _escalation = bondEscalationModule.getEscalation(_requestId);
    assertEq(uint8(_escalation.status), uint8(IBondEscalationModule.BondEscalationStatus.Active));
    assertEq(_escalation.disputeId, _disputeId);
  }
}
