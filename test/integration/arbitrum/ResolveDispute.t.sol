// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.26;

import './IntegrationBase.sol';

contract IntegrationResolveDispute is IntegrationBase {
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

  function test_ResolveDispute_Won() public {
    // Create the request
    bytes32 _requestId = _createRequest();
    // Propose the response
    bytes32 _responseId = _proposeResponse(_requestId);
    // Dispute the response
    bytes32 _disputeId = _disputeResponse(_requestId, _responseId);

    // Revert if the dispute has not been escalated
    vm.expectRevert(ICouncilArbitrator.CouncilArbitrator_InvalidResolution.selector);
    _arbitrateDispute(_disputeId, IOracle.DisputeStatus.Escalated);
    vm.expectRevert(IArbitratorModule.ArbitratorModule_InvalidDisputeId.selector);
    _resolveDispute(_requestId, _responseId, _disputeId);

    // Pass the dispute deadline
    vm.warp(disputeDeadline + 1);

    // Escalate the dispute
    _escalateDispute(_requestId, _responseId, _disputeId);

    // Revert if the dispute has not been arbitrated
    vm.expectRevert(IArbitratorModule.ArbitratorModule_InvalidResolutionStatus.selector);
    _resolveDispute(_requestId, _responseId, _disputeId);

    // Revert if the arbitration award is invalid
    vm.expectRevert(ICouncilArbitrator.CouncilArbitrator_InvalidResolutionStatus.selector);
    _arbitrateDispute(_disputeId, IOracle.DisputeStatus.Escalated);

    // TODO: Do not revert with `Oracle_InvalidFinalizedResponse` if the arbitration award is `Won`
    vm.skip(true);
    _arbitrateDispute(_disputeId, IOracle.DisputeStatus.Won);
  }

  function test_ResolveDispute_Lost() public {
    // Create the request
    bytes32 _requestId = _createRequest();
    // Propose the response
    bytes32 _responseId = _proposeResponse(_requestId);
    // Dispute the response
    bytes32 _disputeId = _disputeResponse(_requestId, _responseId);

    // Revert if the dispute has not been escalated
    vm.expectRevert(ICouncilArbitrator.CouncilArbitrator_InvalidResolution.selector);
    _arbitrateDispute(_disputeId, IOracle.DisputeStatus.Escalated);
    vm.expectRevert(IArbitratorModule.ArbitratorModule_InvalidDisputeId.selector);
    _resolveDispute(_requestId, _responseId, _disputeId);

    // Pass the dispute deadline
    vm.warp(disputeDeadline + 1);

    // Escalate the dispute
    _escalateDispute(_requestId, _responseId, _disputeId);

    // Revert if the dispute has not been arbitrated
    vm.expectRevert(IArbitratorModule.ArbitratorModule_InvalidResolutionStatus.selector);
    _resolveDispute(_requestId, _responseId, _disputeId);

    // Revert if the arbitration award is invalid
    vm.expectRevert(ICouncilArbitrator.CouncilArbitrator_InvalidResolutionStatus.selector);
    _arbitrateDispute(_disputeId, IOracle.DisputeStatus.Escalated);

    // Revert if the request is finalized before the response deadline
    vm.expectRevert(IBondedResponseModule.BondedResponseModule_TooEarlyToFinalize.selector);
    _arbitrateDispute(_disputeId, IOracle.DisputeStatus.Lost);

    // Pass the response deadline
    vm.roll(block.number + responseDeadline);

    // Revert if the request is finalized before the dispute window
    vm.expectRevert(IBondedResponseModule.BondedResponseModule_TooEarlyToFinalize.selector);
    _arbitrateDispute(_disputeId, IOracle.DisputeStatus.Lost);

    // Pass the dispute window
    vm.roll(block.number + responseDisputeWindow - responseDeadline);

    // Arbitrate and resolve the dispute
    _arbitrateDispute(_disputeId, IOracle.DisputeStatus.Lost);

    // Assert CouncilArbitrator::resolveDispute
    IOracle.DisputeStatus _status = councilArbitrator.getAnswer(_disputeId);
    assertEq(uint8(_status), uint8(IOracle.DisputeStatus.Lost));
    // Assert ArbitratorModule::resolveDispute
    IArbitratorModule.ArbitrationStatus _disputeStatus = arbitratorModule.getStatus(_disputeId);
    assertEq(uint8(_disputeStatus), uint8(IArbitratorModule.ArbitrationStatus.Resolved));
    // Assert Oracle::updateDisputeStatus
    assertEq(uint8(oracle.disputeStatus(_disputeId)), uint8(IOracle.DisputeStatus.Lost));
    // Assert BondEscalationModule::onDisputeStatusChange
    IBondEscalationModule.BondEscalation memory _escalation = bondEscalationModule.getEscalation(_requestId);
    assertEq(_escalation.disputeId, _disputeId);
    assertEq(uint8(_escalation.status), uint8(IBondEscalationModule.BondEscalationStatus.DisputerLost));
    // Assert BondEscalationAccounting::pay
    assertEq(bondEscalationAccounting.bondedAmountOf(_disputer, graphToken, _requestId), 0);
    assertEq(bondEscalationAccounting.balanceOf(_disputer, graphToken), 0);
    // Assert Oracle::finalize
    assertEq(oracle.finalizedAt(_requestId), block.number);
    assertEq(oracle.finalizedResponseId(_requestId), _responseId);
    // Assert BondEscalationAccounting::release
    assertEq(bondEscalationAccounting.bondedAmountOf(_proposer, graphToken, _requestId), 0);
    assertEq(bondEscalationAccounting.balanceOf(_proposer, graphToken), responseBondSize + disputeBondSize);

    // Revert if the dispute has already been arbitrated
    vm.expectRevert(ICouncilArbitrator.CouncilArbitrator_DisputeAlreadyResolved.selector);
    _arbitrateDispute(_disputeId, IOracle.DisputeStatus.Won);

    // Revert if the dispute has already been resolved
    vm.expectRevert(abi.encodeWithSelector(IOracle.Oracle_CannotResolve.selector, _disputeId));
    _resolveDispute(_requestId, _responseId, _disputeId);
  }

  function test_ResolveDispute_NoResolution() public {
    // Create the request
    bytes32 _requestId = _createRequest();
    // Propose the response
    bytes32 _responseId = _proposeResponse(_requestId);
    // Dispute the response
    bytes32 _disputeId = _disputeResponse(_requestId, _responseId);

    // Revert if the dispute has not been escalated
    vm.expectRevert(ICouncilArbitrator.CouncilArbitrator_InvalidResolution.selector);
    _arbitrateDispute(_disputeId, IOracle.DisputeStatus.Escalated);
    vm.expectRevert(IArbitratorModule.ArbitratorModule_InvalidDisputeId.selector);
    _resolveDispute(_requestId, _responseId, _disputeId);

    // Pass the dispute deadline
    vm.warp(disputeDeadline + 1);

    // Escalate the dispute
    _escalateDispute(_requestId, _responseId, _disputeId);

    // Revert if the dispute has not been arbitrated
    vm.expectRevert(IArbitratorModule.ArbitratorModule_InvalidResolutionStatus.selector);
    _resolveDispute(_requestId, _responseId, _disputeId);

    // Revert if the arbitration award is invalid
    vm.expectRevert(ICouncilArbitrator.CouncilArbitrator_InvalidResolutionStatus.selector);
    _arbitrateDispute(_disputeId, IOracle.DisputeStatus.Escalated);

    // TODO: Do not revert with `Oracle_InvalidFinalizedResponse` if the arbitration award is `NoResolution`
    vm.skip(true);
    _arbitrateDispute(_disputeId, IOracle.DisputeStatus.NoResolution);
  }
}
