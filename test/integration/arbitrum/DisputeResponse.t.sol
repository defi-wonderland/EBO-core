// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.26;

import './IntegrationBase.sol';

contract Integration_DisputeResponse is IntegrationBase {
  function setUp() public override {
    super.setUp();

    // Create data
    _setRequestModuleData();
    _setResponseModuleData();
    _setDisputeModuleData();

    // Approve modules and chain IDs
    _approveModules(_user);
    _addChains();

    // Create the requests
    _createRequest();
    // Propose the response
    _proposeResponse();
  }

  function test_disputeResponse() public {
    _disputeResponse();

    assertEq(uint8(_oracle.disputeStatus(_disputeId)), uint8(IOracle.DisputeStatus.Active));
    assertEq(_oracle.disputeOf(_responseId), _disputeId);
    assertEq(_oracle.disputeCreatedAt(_disputeId), block.number);
    assertEq(_accountingExtension.bondedAmountOf(_user, _graphToken, _requestId), _bondSize);

    IBondEscalationModule.BondEscalation memory _escalation = _bondEscalationModule.getEscalation(_requestId);
    assertEq(uint8(_escalation.status), uint8(IBondEscalationModule.BondEscalationStatus.Active));
    assertEq(_escalation.disputeId, _disputeId);
  }
}
