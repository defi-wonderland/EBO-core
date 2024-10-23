// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.26;

import './IntegrationBase.t.sol';

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

    uint256 _responseCreation = oracle.responseCreatedAt(_responseId);

    // Pass the dispute window
    vm.warp(_responseCreation + disputeDisputeWindow + 1);

    // Revert if the dispute window has passed
    vm.expectRevert(IBondEscalationModule.BondEscalationModule_DisputeWindowOver.selector);
    _disputeResponse(_requestId, _responseId);

    // Do not pass the dispute window
    vm.warp(_responseCreation + disputeDisputeWindow);

    // Thaw some tokens
    _thaw(_disputer, 1);

    // Disputing the response reverts because of insufficient funds as the disputer thawed some tokens
    vm.expectRevert(IHorizonAccountingExtension.HorizonAccountingExtension_InsufficientTokens.selector);
    _disputeResponse(_requestId, _responseId);

    // Reprovision the thawed token
    _stakeGRT();
    _addToProvision(_disputer, 1);

    // Dispute the response
    bytes32 _disputeId = _disputeResponse(_requestId, _responseId);

    // Assert Oracle::disputeResponse
    assertEq(uint8(oracle.disputeStatus(_disputeId)), uint8(IOracle.DisputeStatus.Active));
    assertEq(oracle.disputeOf(_responseId), _disputeId);
    assertEq(oracle.disputeCreatedAt(_disputeId), block.timestamp);
    // Assert BondEscalationModule::disputeResponse
    IBondEscalationModule.BondEscalation memory _escalation = bondEscalationModule.getEscalation(_requestId);
    assertEq(_escalation.disputeId, _disputeId);
    assertEq(uint8(_escalation.status), uint8(IBondEscalationModule.BondEscalationStatus.Active));
    // Assert HorizonAccountingExtension::bond
    assertEq(horizonAccountingExtension.bondedForRequest(_disputer, _requestId), disputeBondSize);
    assertEq(horizonAccountingExtension.totalBonded(_disputer), disputeBondSize);

    // Revert if the response has already been disputed
    vm.expectRevert(abi.encodeWithSelector(IOracle.Oracle_ResponseAlreadyDisputed.selector, _responseId));
    _disputeResponse(_requestId, _responseId);
  }
}
