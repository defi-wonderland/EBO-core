// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.26;

import './IntegrationBase.t.sol';

contract IntegrationArbitrateDispute is IntegrationBase {
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

  function test_ArbitrateDispute_Won() public {
    // Create the request
    bytes32 _requestId = _createRequest();
    // Propose the response
    bytes32 _responseId = _proposeResponse(_requestId);
    // Dispute the response
    bytes32 _disputeId = _disputeResponse(_requestId, _responseId);

    // Revert if the dispute has not been escalated
    vm.expectRevert(ICouncilArbitrator.CouncilArbitrator_InvalidDispute.selector);
    _arbitrateDispute(_disputeId, IOracle.DisputeStatus.Escalated);
    vm.expectRevert(IArbitratorModule.ArbitratorModule_InvalidDisputeId.selector);
    _resolveDispute(_requestId, _responseId, _disputeId);

    // Pledge for the dispute
    _pledgeForDispute(_requestId, _disputeId);
    // Pledge against the dispute
    _pledgeAgainstDispute(_requestId, _disputeId);

    // Pass the dispute deadline
    vm.warp(oracle.disputeCreatedAt(_disputeId) + disputeDeadline + 1);

    // Escalate the dispute
    _escalateDispute(_requestId, _responseId, _disputeId);

    // Revert if the dispute has not been arbitrated
    vm.expectRevert(IArbitratorModule.ArbitratorModule_InvalidResolutionStatus.selector);
    _resolveDispute(_requestId, _responseId, _disputeId);

    // Revert if the arbitration award is invalid
    vm.expectRevert(ICouncilArbitrator.CouncilArbitrator_InvalidAward.selector);
    _arbitrateDispute(_disputeId, IOracle.DisputeStatus.Escalated);

    // Arbitrate and resolve the dispute, and finalize the request without response
    _arbitrateDispute(_disputeId, IOracle.DisputeStatus.Won);

    // Assert CouncilArbitrator::resolveDispute
    IOracle.DisputeStatus _status = councilArbitrator.getAnswer(_disputeId);
    assertEq(uint8(_status), uint8(IOracle.DisputeStatus.Won));
    // Assert ArbitratorModule::resolveDispute
    IArbitratorModule.ArbitrationStatus _disputeStatus = arbitratorModule.getStatus(_disputeId);
    assertEq(uint8(_disputeStatus), uint8(IArbitratorModule.ArbitrationStatus.Resolved));
    // Assert Oracle::updateDisputeStatus
    assertEq(uint8(oracle.disputeStatus(_disputeId)), uint8(IOracle.DisputeStatus.Won));
    // Assert BondEscalationModule::onDisputeStatusChange
    IBondEscalationModule.BondEscalation memory _escalation = bondEscalationModule.getEscalation(_requestId);
    assertEq(_escalation.disputeId, _disputeId);
    assertEq(uint8(_escalation.status), uint8(IBondEscalationModule.BondEscalationStatus.DisputerWon));
    // Assert HorizonAccountingExtension::onSettleBondEscalation
    IHorizonAccountingExtension.EscalationResult memory _escalationResult =
      horizonAccountingExtension.getEscalationResult(_disputeId);
    assertEq(_escalationResult.requestId, _requestId);
    assertEq(_escalationResult.amountPerPledger, disputeBondSize * 2);
    assertEq(_escalationResult.bondSize, disputeBondSize);
    assertEq(address(_escalationResult.bondEscalationModule), address(bondEscalationModule));
    // Assert HorizonAccountingExtension::pay
    assertEq(horizonAccountingExtension.bondedForRequest(_proposer, _requestId), responseBondSize - disputeBondSize);
    assertEq(horizonAccountingExtension.totalBonded(_proposer), responseBondSize - disputeBondSize);
    // Assert HorizonStaking::slash
    IHorizonStaking.Provision memory _proposerProvision =
      horizonStaking.getProvision(_proposer, address(horizonAccountingExtension));
    IHorizonStaking.Provision memory _disputerProvision =
      horizonStaking.getProvision(_disputer, address(horizonAccountingExtension));
    assertEq(_proposerProvision.tokens, responseBondSize - disputeBondSize);
    assertEq(_disputerProvision.tokens, disputeBondSize);
    // Assert GraphToken::transfer
    assertEq(graphToken.balanceOf(_disputer), disputeBondSize);
    assertEq(graphToken.balanceOf(_proposer), 0);
    // Assert HorizonAccountingExtension::release
    assertEq(horizonAccountingExtension.bondedForRequest(_disputer, _requestId), 0);
    assertEq(horizonAccountingExtension.totalBonded(_disputer), 0);
    // Assert Oracle::finalize
    assertEq(oracle.finalizedAt(_requestId), block.timestamp);
    assertEq(oracle.finalizedResponseId(_requestId), 0);

    // Revert if the dispute has already been arbitrated
    vm.expectRevert(ICouncilArbitrator.CouncilArbitrator_DisputeAlreadyArbitrated.selector);
    _arbitrateDispute(_disputeId, IOracle.DisputeStatus.Lost);

    // Revert if the dispute has already been resolved
    vm.expectRevert(abi.encodeWithSelector(IOracle.Oracle_CannotResolve.selector, _disputeId));
    _resolveDispute(_requestId, _responseId, _disputeId);
  }

  function test_ArbitrateDispute_Lost() public {
    // Create the request
    bytes32 _requestId = _createRequest();
    // Propose the response
    bytes32 _responseId = _proposeResponse(_requestId);
    // Dispute the response
    bytes32 _disputeId = _disputeResponse(_requestId, _responseId);

    // Revert if the dispute has not been escalated
    vm.expectRevert(ICouncilArbitrator.CouncilArbitrator_InvalidDispute.selector);
    _arbitrateDispute(_disputeId, IOracle.DisputeStatus.Escalated);
    vm.expectRevert(IArbitratorModule.ArbitratorModule_InvalidDisputeId.selector);
    _resolveDispute(_requestId, _responseId, _disputeId);

    // Pledge for the dispute
    _pledgeForDispute(_requestId, _disputeId);
    // Pledge against the dispute
    _pledgeAgainstDispute(_requestId, _disputeId);

    // Pass the dispute deadline
    vm.warp(oracle.disputeCreatedAt(_disputeId) + disputeDeadline + 1);

    // Escalate the dispute
    _escalateDispute(_requestId, _responseId, _disputeId);

    // Revert if the dispute has not been arbitrated
    vm.expectRevert(IArbitratorModule.ArbitratorModule_InvalidResolutionStatus.selector);
    _resolveDispute(_requestId, _responseId, _disputeId);

    // Revert if the arbitration award is invalid
    vm.expectRevert(ICouncilArbitrator.CouncilArbitrator_InvalidAward.selector);
    _arbitrateDispute(_disputeId, IOracle.DisputeStatus.Escalated);

    // Pass the response deadline
    vm.warp(oracle.requestCreatedAt(_requestId) + responseDeadline);

    // Revert if the request is finalized with response before the dispute window
    vm.expectRevert(IBondedResponseModule.BondedResponseModule_TooEarlyToFinalize.selector);
    _arbitrateDispute(_disputeId, IOracle.DisputeStatus.Lost);

    // Pass the dispute window
    vm.warp(oracle.responseCreatedAt(_responseId) + responseDisputeWindow);

    // Arbitrate and resolve the dispute, and finalize the request with response
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
    // Assert HorizonAccountingExtension::onSettleBondEscalation
    IHorizonAccountingExtension.EscalationResult memory _escalationResult =
      horizonAccountingExtension.getEscalationResult(_disputeId);
    assertEq(_escalationResult.requestId, _requestId);
    assertEq(_escalationResult.amountPerPledger, disputeBondSize * 2);
    assertEq(_escalationResult.bondSize, disputeBondSize);
    assertEq(address(_escalationResult.bondEscalationModule), address(bondEscalationModule));
    // Assert HorizonAccountingExtension::pay
    assertEq(horizonAccountingExtension.bondedForRequest(_disputer, _requestId), 0);
    assertEq(horizonAccountingExtension.totalBonded(_disputer), 0);
    // Assert HorizonStaking::slash
    IHorizonStaking.Provision memory _disputerProvision =
      horizonStaking.getProvision(_disputer, address(horizonAccountingExtension));
    IHorizonStaking.Provision memory _proposerProvision =
      horizonStaking.getProvision(_proposer, address(horizonAccountingExtension));
    assertEq(_disputerProvision.tokens, 0);
    assertEq(_proposerProvision.tokens, responseBondSize);
    // Assert GraphToken::transfer
    assertEq(graphToken.balanceOf(_proposer), disputeBondSize);
    assertEq(graphToken.balanceOf(_disputer), 0);
    // Assert Oracle::finalize
    assertEq(oracle.finalizedAt(_requestId), block.timestamp);
    assertEq(oracle.finalizedResponseId(_requestId), _responseId);
    // Assert HorizonAccountingExtension::release
    assertEq(horizonAccountingExtension.bondedForRequest(_proposer, _requestId), 0);
    assertEq(horizonAccountingExtension.totalBonded(_proposer), 0);

    // Revert if the dispute has already been arbitrated
    vm.expectRevert(ICouncilArbitrator.CouncilArbitrator_DisputeAlreadyArbitrated.selector);
    _arbitrateDispute(_disputeId, IOracle.DisputeStatus.Won);

    // Revert if the dispute has already been resolved
    vm.expectRevert(abi.encodeWithSelector(IOracle.Oracle_CannotResolve.selector, _disputeId));
    _resolveDispute(_requestId, _responseId, _disputeId);
  }

  function test_ArbitrateDispute_NoResolution() public {
    // Create the request
    bytes32 _requestId = _createRequest();
    // Propose the response
    bytes32 _responseId = _proposeResponse(_requestId);
    // Dispute the response
    bytes32 _disputeId = _disputeResponse(_requestId, _responseId);

    // Revert if the dispute has not been escalated
    vm.expectRevert(ICouncilArbitrator.CouncilArbitrator_InvalidDispute.selector);
    _arbitrateDispute(_disputeId, IOracle.DisputeStatus.Escalated);
    vm.expectRevert(IArbitratorModule.ArbitratorModule_InvalidDisputeId.selector);
    _resolveDispute(_requestId, _responseId, _disputeId);

    // Pledge for the dispute
    _pledgeForDispute(_requestId, _disputeId);
    // Pledge against the dispute
    _pledgeAgainstDispute(_requestId, _disputeId);

    // Pass the dispute deadline
    vm.warp(oracle.disputeCreatedAt(_disputeId) + disputeDeadline + 1);

    // Escalate the dispute
    _escalateDispute(_requestId, _responseId, _disputeId);

    // Revert if the dispute has not been arbitrated
    vm.expectRevert(IArbitratorModule.ArbitratorModule_InvalidResolutionStatus.selector);
    _resolveDispute(_requestId, _responseId, _disputeId);

    // Revert if the arbitration award is invalid
    vm.expectRevert(ICouncilArbitrator.CouncilArbitrator_InvalidAward.selector);
    _arbitrateDispute(_disputeId, IOracle.DisputeStatus.Escalated);

    // Arbitrate and resolve the dispute, and finalize the request without response
    _arbitrateDispute(_disputeId, IOracle.DisputeStatus.NoResolution);

    // Assert CouncilArbitrator::resolveDispute
    IOracle.DisputeStatus _status = councilArbitrator.getAnswer(_disputeId);
    assertEq(uint8(_status), uint8(IOracle.DisputeStatus.NoResolution));
    // Assert ArbitratorModule::resolveDispute
    IArbitratorModule.ArbitrationStatus _disputeStatus = arbitratorModule.getStatus(_disputeId);
    assertEq(uint8(_disputeStatus), uint8(IArbitratorModule.ArbitrationStatus.Resolved));
    // Assert Oracle::updateDisputeStatus
    assertEq(uint8(oracle.disputeStatus(_disputeId)), uint8(IOracle.DisputeStatus.NoResolution));
    // Assert BondEscalationModule::onDisputeStatusChange
    IBondEscalationModule.BondEscalation memory _escalation = bondEscalationModule.getEscalation(_requestId);
    assertEq(_escalation.disputeId, _disputeId);
    assertEq(uint8(_escalation.status), uint8(IBondEscalationModule.BondEscalationStatus.Escalated));
    // Assert HorizonAccountingExtension::onSettleBondEscalation
    IHorizonAccountingExtension.EscalationResult memory _escalationResult =
      horizonAccountingExtension.getEscalationResult(_disputeId);
    assertEq(_escalationResult.requestId, _requestId);
    assertEq(_escalationResult.amountPerPledger, disputeBondSize);
    assertEq(_escalationResult.bondSize, disputeBondSize);
    assertEq(address(_escalationResult.bondEscalationModule), address(bondEscalationModule));
    // Assert HorizonAccountingExtension::release
    assertEq(horizonAccountingExtension.bondedForRequest(_disputer, _requestId), 0);
    assertEq(horizonAccountingExtension.totalBonded(_disputer), 0);
    assertEq(horizonAccountingExtension.bondedForRequest(_proposer, _requestId), responseBondSize);
    assertEq(horizonAccountingExtension.totalBonded(_proposer), responseBondSize);
    // Assert Oracle::finalize
    assertEq(oracle.finalizedAt(_requestId), block.timestamp);
    assertEq(oracle.finalizedResponseId(_requestId), 0);

    // Revert if the dispute has already been arbitrated
    vm.expectRevert(ICouncilArbitrator.CouncilArbitrator_DisputeAlreadyArbitrated.selector);
    _arbitrateDispute(_disputeId, IOracle.DisputeStatus.NoResolution);

    // Revert if the dispute has already been resolved
    vm.expectRevert(abi.encodeWithSelector(IOracle.Oracle_CannotResolve.selector, _disputeId));
    _resolveDispute(_requestId, _responseId, _disputeId);
  }
}
