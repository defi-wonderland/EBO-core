// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.26;

import './IntegrationBase.sol';

contract IntegrationArbitrateDispute is IntegrationBase {
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
    vm.warp(disputeDeadline + 1);

    // Escalate the dispute
    _escalateDispute(_requestId, _responseId, _disputeId);

    // Revert if the dispute has not been arbitrated
    vm.expectRevert(IArbitratorModule.ArbitratorModule_InvalidResolutionStatus.selector);
    _resolveDispute(_requestId, _responseId, _disputeId);

    // Revert if the arbitration award is invalid
    vm.expectRevert(ICouncilArbitrator.CouncilArbitrator_InvalidAward.selector);
    _arbitrateDispute(_disputeId, IOracle.DisputeStatus.Escalated);

    // Revert if the request is finalized before the response deadline
    vm.expectRevert(IBondedResponseModule.BondedResponseModule_TooEarlyToFinalize.selector);
    _arbitrateDispute(_disputeId, IOracle.DisputeStatus.Won);

    // Pass the response deadline
    vm.roll(block.number + responseDeadline);

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
    // Assert BondEscalationAccounting::onSettleBondEscalation
    // IBondEscalationAccounting.EscalationResult memory _escalationResult = bondEscalationAccounting.getEscalationResult(_disputeId);
    (bytes32 __requestId, IERC20 __token, uint256 __amountPerPledger, IBondEscalationModule __bondEscalationModule) =
      bondEscalationAccounting.escalationResults(_disputeId);
    assertEq(__requestId, _requestId);
    assertEq(__amountPerPledger, disputeBondSize * 2);
    assertEq(address(__token), address(graphToken));
    assertEq(address(__bondEscalationModule), address(bondEscalationModule));
    // Assert BondEscalationAccounting::pay
    assertEq(
      bondEscalationAccounting.bondedAmountOf(_proposer, graphToken, _requestId), responseBondSize - disputeBondSize
    );
    assertEq(bondEscalationAccounting.balanceOf(_proposer, graphToken), 0);
    // Assert BondEscalationAccounting::release
    assertEq(bondEscalationAccounting.bondedAmountOf(_disputer, graphToken, _requestId), 0);
    assertEq(bondEscalationAccounting.balanceOf(_disputer, graphToken), disputeBondSize * 2);
    // Assert Oracle::finalize
    assertEq(oracle.finalizedAt(_requestId), block.number);
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
    vm.warp(disputeDeadline + 1);

    // Escalate the dispute
    _escalateDispute(_requestId, _responseId, _disputeId);

    // Revert if the dispute has not been arbitrated
    vm.expectRevert(IArbitratorModule.ArbitratorModule_InvalidResolutionStatus.selector);
    _resolveDispute(_requestId, _responseId, _disputeId);

    // Revert if the arbitration award is invalid
    vm.expectRevert(ICouncilArbitrator.CouncilArbitrator_InvalidAward.selector);
    _arbitrateDispute(_disputeId, IOracle.DisputeStatus.Escalated);

    // Revert if the request is finalized before the response deadline
    vm.expectRevert(IBondedResponseModule.BondedResponseModule_TooEarlyToFinalize.selector);
    _arbitrateDispute(_disputeId, IOracle.DisputeStatus.Lost);

    // Pass the response deadline
    vm.roll(block.number + responseDeadline);

    // Revert if the request is finalized with response before the dispute window
    vm.expectRevert(IBondedResponseModule.BondedResponseModule_TooEarlyToFinalize.selector);
    _arbitrateDispute(_disputeId, IOracle.DisputeStatus.Lost);

    // Pass the dispute window
    vm.roll(block.number + responseDisputeWindow - responseDeadline);

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
    // Assert BondEscalationAccounting::onSettleBondEscalation
    // IBondEscalationAccounting.EscalationResult memory _escalationResult = bondEscalationAccounting.getEscalationResult(_disputeId);
    (bytes32 __requestId, IERC20 __token, uint256 __amountPerPledger, IBondEscalationModule __bondEscalationModule) =
      bondEscalationAccounting.escalationResults(_disputeId);
    assertEq(__requestId, _requestId);
    assertEq(__amountPerPledger, disputeBondSize * 2);
    assertEq(address(__token), address(graphToken));
    assertEq(address(__bondEscalationModule), address(bondEscalationModule));
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
    vm.warp(disputeDeadline + 1);

    // Escalate the dispute
    _escalateDispute(_requestId, _responseId, _disputeId);

    // Revert if the dispute has not been arbitrated
    vm.expectRevert(IArbitratorModule.ArbitratorModule_InvalidResolutionStatus.selector);
    _resolveDispute(_requestId, _responseId, _disputeId);

    // Revert if the arbitration award is invalid
    vm.expectRevert(ICouncilArbitrator.CouncilArbitrator_InvalidAward.selector);
    _arbitrateDispute(_disputeId, IOracle.DisputeStatus.Escalated);

    // Revert if the request is finalized before the response deadline
    vm.expectRevert(IBondedResponseModule.BondedResponseModule_TooEarlyToFinalize.selector);
    _arbitrateDispute(_disputeId, IOracle.DisputeStatus.NoResolution);

    // Pass the response deadline
    vm.roll(block.number + responseDeadline);

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
    // Assert BondEscalationAccounting::onSettleBondEscalation
    // IBondEscalationAccounting.EscalationResult memory _escalationResult = bondEscalationAccounting.getEscalationResult(_disputeId);
    (bytes32 __requestId, IERC20 __token, uint256 __amountPerPledger, IBondEscalationModule __bondEscalationModule) =
      bondEscalationAccounting.escalationResults(_disputeId);
    assertEq(__requestId, _requestId);
    assertEq(__amountPerPledger, disputeBondSize);
    assertEq(address(__token), address(graphToken));
    assertEq(address(__bondEscalationModule), address(bondEscalationModule));
    // Assert BondEscalationAccounting::release
    assertEq(bondEscalationAccounting.bondedAmountOf(_disputer, graphToken, _requestId), 0);
    assertEq(bondEscalationAccounting.balanceOf(_disputer, graphToken), disputeBondSize);
    assertEq(bondEscalationAccounting.bondedAmountOf(_proposer, graphToken, _requestId), responseBondSize);
    assertEq(bondEscalationAccounting.balanceOf(_proposer, graphToken), 0);
    // Assert Oracle::finalize
    assertEq(oracle.finalizedAt(_requestId), block.number);
    assertEq(oracle.finalizedResponseId(_requestId), 0);

    // Revert if the dispute has already been arbitrated
    vm.expectRevert(ICouncilArbitrator.CouncilArbitrator_DisputeAlreadyArbitrated.selector);
    _arbitrateDispute(_disputeId, IOracle.DisputeStatus.NoResolution);

    // Revert if the dispute has already been resolved
    vm.expectRevert(abi.encodeWithSelector(IOracle.Oracle_CannotResolve.selector, _disputeId));
    _resolveDispute(_requestId, _responseId, _disputeId);
  }
}
