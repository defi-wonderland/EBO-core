// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.26;

import './IntegrationBase.sol';

contract IntegrationBondEscalation is IntegrationBase {
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

  function test_PledgeForDispute() public {
    // Create the request
    bytes32 _requestId = _createRequest();
    // Propose the response
    bytes32 _responseId = _proposeResponse(_requestId);
    // Dispute the response
    bytes32 _disputeId = _disputeResponse(_requestId, _responseId);

    // Pass the dispute deadline, but not the tying buffer
    vm.warp(disputeDeadline + 1);

    // Revert if breaking a tie during the tying buffer
    vm.expectRevert(IBondEscalationModule.BondEscalationModule_CannotBreakTieDuringTyingBuffer.selector);
    _pledgeForDispute(_requestId, _disputeId);

    // Pass the dispute deadline and the tying buffer
    vm.warp(disputeDeadline + tyingBuffer + 1);

    // Revert if the bond escalation deadline and the tying buffer have passed
    vm.expectRevert(IBondEscalationModule.BondEscalationModule_BondEscalationOver.selector);
    _pledgeForDispute(_requestId, _disputeId);

    // Do not pass the dispute deadline nor the tying buffer
    vm.warp(disputeDeadline);

    // Pledge for the dispute
    _pledgeForDispute(_requestId, _disputeId);

    // Assert BondEscalationModule::pledgeForDispute
    IBondEscalationModule.BondEscalation memory _escalation = bondEscalationModule.getEscalation(_requestId);
    assertEq(_escalation.disputeId, _disputeId);
    assertEq(_escalation.amountOfPledgesForDispute, 1);
    assertEq(bondEscalationModule.pledgesForDispute(_requestId, _pledgerFor), 1);
    // Assert BondEscalationAccounting::pledge
    assertEq(bondEscalationAccounting.pledges(_disputeId, graphToken), disputeBondSize);
    assertEq(
      bondEscalationAccounting.balanceOf(_pledgerFor, graphToken),
      disputeBondSize * maxNumberOfEscalations - disputeBondSize
    );

    // Revert if the dispute has already been pledged for, but not pledged against
    vm.expectRevert(IBondEscalationModule.BondEscalationModule_CanOnlySurpassByOnePledge.selector);
    _pledgeForDispute(_requestId, _disputeId);
  }

  function test_PledgeAgainstDispute() public {
    // Create the request
    bytes32 _requestId = _createRequest();
    // Propose the response
    bytes32 _responseId = _proposeResponse(_requestId);
    // Dispute the response
    bytes32 _disputeId = _disputeResponse(_requestId, _responseId);

    // Pass the dispute deadline, but not the tying buffer
    vm.warp(disputeDeadline + 1);

    // Revert if breaking a tie during the tying buffer
    vm.expectRevert(IBondEscalationModule.BondEscalationModule_CannotBreakTieDuringTyingBuffer.selector);
    _pledgeAgainstDispute(_requestId, _disputeId);

    // Pass the dispute deadline and the tying buffer
    vm.warp(disputeDeadline + tyingBuffer + 1);

    // Revert if the bond escalation deadline and the tying buffer have passed
    vm.expectRevert(IBondEscalationModule.BondEscalationModule_BondEscalationOver.selector);
    _pledgeAgainstDispute(_requestId, _disputeId);

    // Do not pass the dispute deadline nor the tying buffer
    vm.warp(disputeDeadline);

    // Pledge against the dispute
    _pledgeAgainstDispute(_requestId, _disputeId);

    // Assert BondEscalationModule::pledgeAgainstDispute
    IBondEscalationModule.BondEscalation memory _escalation = bondEscalationModule.getEscalation(_requestId);
    assertEq(_escalation.disputeId, _disputeId);
    assertEq(_escalation.amountOfPledgesAgainstDispute, 1);
    assertEq(bondEscalationModule.pledgesAgainstDispute(_requestId, _pledgerAgainst), 1);
    // Assert BondEscalationAccounting::pledge
    assertEq(bondEscalationAccounting.pledges(_disputeId, graphToken), disputeBondSize);
    assertEq(
      bondEscalationAccounting.balanceOf(_pledgerAgainst, graphToken),
      disputeBondSize * maxNumberOfEscalations - disputeBondSize
    );

    // Revert if the dispute has already been pledged against, but not pledged for
    vm.expectRevert(IBondEscalationModule.BondEscalationModule_CanOnlySurpassByOnePledge.selector);
    _pledgeAgainstDispute(_requestId, _disputeId);
  }

  function test_PledgeForAndAgainstDispute() public {
    // Create the request
    bytes32 _requestId = _createRequest();
    // Propose the response
    bytes32 _responseId = _proposeResponse(_requestId);
    // Dispute the response
    bytes32 _disputeId = _disputeResponse(_requestId, _responseId);

    // Pledge for the dispute
    _pledgeForDispute(_requestId, _disputeId);

    // Pledge against the dispute, twice
    _pledgeAgainstDispute(_requestId, _disputeId);
    _pledgeAgainstDispute(_requestId, _disputeId);

    // Pass the dispute deadline, but not the tying buffer
    vm.warp(disputeDeadline + 1);

    // Pledge for the dispute, again
    _pledgeForDispute(_requestId, _disputeId);

    // Assert BondEscalationModule::pledgeForDispute and BondEscalationModule::pledgeAgainstDispute
    IBondEscalationModule.BondEscalation memory _escalation = bondEscalationModule.getEscalation(_requestId);
    assertEq(_escalation.disputeId, _disputeId);
    assertEq(_escalation.amountOfPledgesForDispute, maxNumberOfEscalations);
    assertEq(_escalation.amountOfPledgesAgainstDispute, maxNumberOfEscalations);
    assertEq(bondEscalationModule.pledgesForDispute(_requestId, _pledgerFor), maxNumberOfEscalations);
    assertEq(bondEscalationModule.pledgesAgainstDispute(_requestId, _pledgerAgainst), maxNumberOfEscalations);
    // Assert BondEscalationAccounting::pledge
    assertEq(bondEscalationAccounting.pledges(_disputeId, graphToken), disputeBondSize * maxNumberOfEscalations * 2);
    assertEq(bondEscalationAccounting.balanceOf(_pledgerFor, graphToken), 0);
    assertEq(bondEscalationAccounting.balanceOf(_pledgerAgainst, graphToken), 0);

    // Revert if the max number of escalations has been reached
    vm.expectRevert(IBondEscalationModule.BondEscalationModule_MaxNumberOfEscalationsReached.selector);
    _pledgeForDispute(_requestId, _disputeId);
    vm.expectRevert(IBondEscalationModule.BondEscalationModule_MaxNumberOfEscalationsReached.selector);
    _pledgeAgainstDispute(_requestId, _disputeId);
  }

  function test_SettleBondEscalation_DisputerWon() public {
    // Create the request
    bytes32 _requestId = _createRequest();
    // Propose the response
    bytes32 _responseId = _proposeResponse(_requestId);
    // Dispute the response
    bytes32 _disputeId = _disputeResponse(_requestId, _responseId);

    // Revert if the bond escalation deadline and the tying buffer have not passed
    vm.expectRevert(IBondEscalationModule.BondEscalationModule_BondEscalationNotOver.selector);
    _settleBondEscalation(_requestId, _responseId, _disputeId);

    // Pass the dispute deadline and the tying buffer
    vm.warp(disputeDeadline + tyingBuffer + 1);

    // Revert if the bond escalation has tied
    vm.expectRevert(IBondEscalationModule.BondEscalationModule_ShouldBeEscalated.selector);
    _settleBondEscalation(_requestId, _responseId, _disputeId);

    // Do not pass the dispute deadline nor the tying buffer
    vm.warp(disputeDeadline);

    // Pledge against the dispute
    _pledgeAgainstDispute(_requestId, _disputeId);

    // Pledge for the dispute, twice
    _pledgeForDispute(_requestId, _disputeId);
    _pledgeForDispute(_requestId, _disputeId);

    // Pass the dispute deadline and the tying buffer
    vm.warp(disputeDeadline + tyingBuffer + 1);

    // Settle the bond escalation
    _settleBondEscalation(_requestId, _responseId, _disputeId);

    // Assert BondEscalationModule::settleBondEscalation
    IBondEscalationModule.BondEscalation memory _escalation = bondEscalationModule.getEscalation(_requestId);
    assertEq(_escalation.disputeId, _disputeId);
    assertEq(uint8(_escalation.status), uint8(IBondEscalationModule.BondEscalationStatus.DisputerWon));
    // Assert Oracle::updateDisputeStatus
    assertEq(uint8(oracle.disputeStatus(_disputeId)), uint8(IOracle.DisputeStatus.Won));
    // Assert BondEscalationAccounting::onSettleBondEscalation
    // IBondEscalationAccounting.EscalationResult memory _escalationResult = bondEscalationAccounting.getEscalationResult(_disputeId);
    (bytes32 __requestId, IERC20 __token, uint256 __amountPerPledger, IBondEscalationModule __bondEscalationModule) =
      bondEscalationAccounting.escalationResults(_disputeId);
    assertEq(__requestId, _requestId);
    assertEq(__amountPerPledger, disputeBondSize + disputeBondSize / 2);
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

    // Revert if the bond escalation has already been settled
    vm.expectRevert(IBondEscalationModule.BondEscalationModule_BondEscalationCantBeSettled.selector);
    _settleBondEscalation(_requestId, _responseId, _disputeId);

    // Revert if the bond escalation has been settled
    vm.expectRevert(abi.encodeWithSelector(IOracle.Oracle_CannotEscalate.selector, _disputeId));
    _escalateDispute(_requestId, _responseId, _disputeId);
  }

  function test_SettleBondEscalation_DisputerLost() public {
    // Create the request
    bytes32 _requestId = _createRequest();
    // Propose the response
    bytes32 _responseId = _proposeResponse(_requestId);
    // Dispute the response
    bytes32 _disputeId = _disputeResponse(_requestId, _responseId);

    // Revert if the bond escalation deadline and the tying buffer have not passed
    vm.expectRevert(IBondEscalationModule.BondEscalationModule_BondEscalationNotOver.selector);
    _settleBondEscalation(_requestId, _responseId, _disputeId);

    // Pass the dispute deadline and the tying buffer
    vm.warp(disputeDeadline + tyingBuffer + 1);

    // Revert if the bond escalation has tied
    vm.expectRevert(IBondEscalationModule.BondEscalationModule_ShouldBeEscalated.selector);
    _settleBondEscalation(_requestId, _responseId, _disputeId);

    // Do not pass the dispute deadline nor the tying buffer
    vm.warp(disputeDeadline);

    // Pledge for the dispute
    _pledgeForDispute(_requestId, _disputeId);

    // Pledge against the dispute, twice
    _pledgeAgainstDispute(_requestId, _disputeId);
    _pledgeAgainstDispute(_requestId, _disputeId);

    // Pass the dispute deadline and the tying buffer
    vm.warp(disputeDeadline + tyingBuffer + 1);

    // Settle the bond escalation
    _settleBondEscalation(_requestId, _responseId, _disputeId);

    // Assert BondEscalationModule::settleBondEscalation
    IBondEscalationModule.BondEscalation memory _escalation = bondEscalationModule.getEscalation(_requestId);
    assertEq(_escalation.disputeId, _disputeId);
    assertEq(uint8(_escalation.status), uint8(IBondEscalationModule.BondEscalationStatus.DisputerLost));
    // Assert Oracle::updateDisputeStatus
    assertEq(uint8(oracle.disputeStatus(_disputeId)), uint8(IOracle.DisputeStatus.Lost));
    // Assert BondEscalationAccounting::onSettleBondEscalation
    // IBondEscalationAccounting.EscalationResult memory _escalationResult = bondEscalationAccounting.getEscalationResult(_disputeId);
    (bytes32 __requestId, IERC20 __token, uint256 __amountPerPledger, IBondEscalationModule __bondEscalationModule) =
      bondEscalationAccounting.escalationResults(_disputeId);
    assertEq(__requestId, _requestId);
    assertEq(__amountPerPledger, disputeBondSize + disputeBondSize / 2);
    assertEq(address(__token), address(graphToken));
    assertEq(address(__bondEscalationModule), address(bondEscalationModule));
    // Assert BondEscalationAccounting::pay
    assertEq(bondEscalationAccounting.bondedAmountOf(_disputer, graphToken, _requestId), 0);
    assertEq(bondEscalationAccounting.balanceOf(_disputer, graphToken), 0);
    assertEq(bondEscalationAccounting.bondedAmountOf(_proposer, graphToken, _requestId), responseBondSize);
    assertEq(bondEscalationAccounting.balanceOf(_proposer, graphToken), disputeBondSize);

    // Revert if the bond escalation has already been settled
    vm.expectRevert(IBondEscalationModule.BondEscalationModule_BondEscalationCantBeSettled.selector);
    _settleBondEscalation(_requestId, _responseId, _disputeId);

    // Revert if the bond escalation has been settled
    vm.expectRevert(abi.encodeWithSelector(IOracle.Oracle_CannotEscalate.selector, _disputeId));
    _escalateDispute(_requestId, _responseId, _disputeId);
  }

  function test_ClaimEscalationReward_DisputerWon() public {
    // Create the request
    bytes32 _requestId = _createRequest();
    // Propose the response
    bytes32 _responseId = _proposeResponse(_requestId);
    // Dispute the response
    bytes32 _disputeId = _disputeResponse(_requestId, _responseId);

    // Revert if the bond escalation has not been settled
    vm.expectRevert(IBondEscalationAccounting.BondEscalationAccounting_NoEscalationResult.selector);
    bondEscalationAccounting.claimEscalationReward(_disputeId, _pledgerFor);

    // Pledge against the dispute
    _pledgeAgainstDispute(_requestId, _disputeId);

    // Pledge for the dispute, twice
    _pledgeForDispute(_requestId, _disputeId);
    _pledgeForDispute(_requestId, _disputeId);

    // Pass the dispute deadline and the tying buffer
    vm.warp(disputeDeadline + tyingBuffer + 1);

    // Settle the bond escalation
    _settleBondEscalation(_requestId, _responseId, _disputeId);

    // Claim the escalation rewards
    bondEscalationAccounting.claimEscalationReward(_disputeId, _pledgerFor);
    bondEscalationAccounting.claimEscalationReward(_disputeId, _pledgerAgainst);

    // Assert BondEscalationAccounting::claimEscalationReward
    assertTrue(bondEscalationAccounting.pledgerClaimed(_requestId, _pledgerFor));
    assertTrue(bondEscalationAccounting.pledgerClaimed(_requestId, _pledgerAgainst));
    assertEq(bondEscalationAccounting.balanceOf(_pledgerFor, graphToken), disputeBondSize * 3);
    assertEq(bondEscalationAccounting.balanceOf(_pledgerAgainst, graphToken), disputeBondSize);
    assertEq(bondEscalationAccounting.pledges(_disputeId, graphToken), 0);

    // Revert if the escalation reward has already been claimed
    vm.expectRevert(IBondEscalationAccounting.BondEscalationAccounting_AlreadyClaimed.selector);
    bondEscalationAccounting.claimEscalationReward(_disputeId, _pledgerFor);
  }

  function test_ClaimEscalationReward_DisputerLost() public {
    // Create the request
    bytes32 _requestId = _createRequest();
    // Propose the response
    bytes32 _responseId = _proposeResponse(_requestId);
    // Dispute the response
    bytes32 _disputeId = _disputeResponse(_requestId, _responseId);

    // Revert if the bond escalation has not been settled
    vm.expectRevert(IBondEscalationAccounting.BondEscalationAccounting_NoEscalationResult.selector);
    bondEscalationAccounting.claimEscalationReward(_disputeId, _pledgerAgainst);

    // Pledge for the dispute
    _pledgeForDispute(_requestId, _disputeId);

    // Pledge against the dispute, twice
    _pledgeAgainstDispute(_requestId, _disputeId);
    _pledgeAgainstDispute(_requestId, _disputeId);

    // Pass the dispute deadline and the tying buffer
    vm.warp(disputeDeadline + tyingBuffer + 1);

    // Settle the bond escalation
    _settleBondEscalation(_requestId, _responseId, _disputeId);

    // Claim the escalation rewards
    bondEscalationAccounting.claimEscalationReward(_disputeId, _pledgerFor);
    bondEscalationAccounting.claimEscalationReward(_disputeId, _pledgerAgainst);

    // Assert BondEscalationAccounting::claimEscalationReward
    assertTrue(bondEscalationAccounting.pledgerClaimed(_requestId, _pledgerFor));
    assertTrue(bondEscalationAccounting.pledgerClaimed(_requestId, _pledgerAgainst));
    assertEq(bondEscalationAccounting.balanceOf(_pledgerFor, graphToken), disputeBondSize);
    assertEq(bondEscalationAccounting.balanceOf(_pledgerAgainst, graphToken), disputeBondSize * 3);
    assertEq(bondEscalationAccounting.pledges(_disputeId, graphToken), 0);

    // Revert if the escalation reward has already been claimed
    vm.expectRevert(IBondEscalationAccounting.BondEscalationAccounting_AlreadyClaimed.selector);
    bondEscalationAccounting.claimEscalationReward(_disputeId, _pledgerAgainst);
  }
}
