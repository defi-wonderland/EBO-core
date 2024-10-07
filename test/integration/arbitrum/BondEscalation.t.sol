// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.26;

import './IntegrationBase.sol';

contract IntegrationBondEscalation is IntegrationBase {
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
    // Assert HorizonAccountingExtension::pledge
    assertEq(horizonAccountingExtension.pledges(_disputeId), disputeBondSize);
    assertEq(horizonAccountingExtension.totalBonded(_pledgerFor), disputeBondSize);
    address[] memory _pledgers = horizonAccountingExtension.getPledgers(_disputeId);
    assertEq(_pledgers[0], _pledgerFor);
    assertEq(_pledgers.length, 1);

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
    // Assert HorizonAccountingExtension::pledge
    assertEq(horizonAccountingExtension.pledges(_disputeId), disputeBondSize);
    assertEq(horizonAccountingExtension.totalBonded(_pledgerAgainst), disputeBondSize);
    address[] memory _pledgers = horizonAccountingExtension.getPledgers(_disputeId);
    assertEq(_pledgers[0], _pledgerAgainst);
    assertEq(_pledgers.length, 1);

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
    // Assert HorizonAccountingExtension::pledge
    assertEq(horizonAccountingExtension.pledges(_disputeId), disputeBondSize * maxNumberOfEscalations * 2);
    assertEq(horizonAccountingExtension.totalBonded(_pledgerFor), disputeBondSize * maxNumberOfEscalations);
    assertEq(horizonAccountingExtension.totalBonded(_pledgerAgainst), disputeBondSize * maxNumberOfEscalations);
    address[] memory _pledgers = horizonAccountingExtension.getPledgers(_disputeId);
    assertEq(_pledgers[0], _pledgerFor);
    assertEq(_pledgers[1], _pledgerAgainst);
    assertEq(_pledgers.length, 2);

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
    // Assert HorizonAccountingExtension::onSettleBondEscalation
    IHorizonAccountingExtension.EscalationResult memory _escalationResult =
      horizonAccountingExtension.getEscalationResult(_disputeId);
    assertEq(_escalationResult.requestId, _requestId);
    assertEq(_escalationResult.amountPerPledger, disputeBondSize + disputeBondSize / 2);
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
    // Assert HorizonAccountingExtension::onSettleBondEscalation
    IHorizonAccountingExtension.EscalationResult memory _escalationResult =
      horizonAccountingExtension.getEscalationResult(_disputeId);
    assertEq(_escalationResult.requestId, _requestId);
    assertEq(_escalationResult.amountPerPledger, disputeBondSize + disputeBondSize / 2);
    assertEq(_escalationResult.bondSize, disputeBondSize);
    assertEq(address(_escalationResult.bondEscalationModule), address(bondEscalationModule));
    // Assert HorizonAccountingExtension::pay
    assertEq(horizonAccountingExtension.bondedForRequest(_disputer, _requestId), 0);
    assertEq(horizonAccountingExtension.totalBonded(_disputer), 0);
    assertEq(horizonAccountingExtension.bondedForRequest(_proposer, _requestId), responseBondSize);
    assertEq(horizonAccountingExtension.totalBonded(_proposer), responseBondSize);
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
    vm.expectRevert(IHorizonAccountingExtension.HorizonAccountingExtension_NoEscalationResult.selector);
    horizonAccountingExtension.claimEscalationReward(_disputeId, _pledgerFor);

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
    horizonAccountingExtension.claimEscalationReward(_disputeId, _pledgerFor);
    horizonAccountingExtension.claimEscalationReward(_disputeId, _pledgerAgainst);

    // Assert HorizonAccountingExtension::claimEscalationReward
    assertTrue(horizonAccountingExtension.pledgerClaimed(_requestId, _pledgerFor));
    assertTrue(horizonAccountingExtension.pledgerClaimed(_requestId, _pledgerAgainst));
    assertEq(horizonAccountingExtension.pledges(_disputeId), 0);
    assertEq(horizonAccountingExtension.totalBonded(_pledgerFor), 0);
    assertEq(horizonAccountingExtension.totalBonded(_pledgerAgainst), 0);
    address[] memory _pledgers = horizonAccountingExtension.getPledgers(_disputeId);
    assertEq(_pledgers[0], _pledgerFor); // TODO: `_pledgerFor` remains in the pledgers list
    assertEq(_pledgers.length, 1);
    // Assert HorizonStaking::slash
    IHorizonStaking.Provision memory _pledgerForProvision =
      horizonStaking.getProvision(_pledgerFor, address(horizonAccountingExtension));
    IHorizonStaking.Provision memory _pledgerAgainstProvision =
      horizonStaking.getProvision(_pledgerAgainst, address(horizonAccountingExtension));
    assertEq(_pledgerForProvision.tokens, disputeBondSize * maxNumberOfEscalations);
    assertEq(_pledgerAgainstProvision.tokens, disputeBondSize * maxNumberOfEscalations - disputeBondSize);
    // Assert GraphToken::transfer
    assertEq(graphToken.balanceOf(_pledgerFor), disputeBondSize);
    assertEq(graphToken.balanceOf(_pledgerAgainst), 0);

    // Revert if the escalation reward has already been claimed
    vm.expectRevert(IHorizonAccountingExtension.HorizonAccountingExtension_AlreadyClaimed.selector);
    horizonAccountingExtension.claimEscalationReward(_disputeId, _pledgerFor);
  }

  function test_ClaimEscalationReward_DisputerLost() public {
    // Create the request
    bytes32 _requestId = _createRequest();
    // Propose the response
    bytes32 _responseId = _proposeResponse(_requestId);
    // Dispute the response
    bytes32 _disputeId = _disputeResponse(_requestId, _responseId);

    // Revert if the bond escalation has not been settled
    vm.expectRevert(IHorizonAccountingExtension.HorizonAccountingExtension_NoEscalationResult.selector);
    horizonAccountingExtension.claimEscalationReward(_disputeId, _pledgerAgainst);

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
    horizonAccountingExtension.claimEscalationReward(_disputeId, _pledgerFor);
    horizonAccountingExtension.claimEscalationReward(_disputeId, _pledgerAgainst);

    // Assert HorizonAccountingExtension::claimEscalationReward
    assertTrue(horizonAccountingExtension.pledgerClaimed(_requestId, _pledgerFor));
    assertTrue(horizonAccountingExtension.pledgerClaimed(_requestId, _pledgerAgainst));
    assertEq(horizonAccountingExtension.pledges(_disputeId), 0);
    assertEq(horizonAccountingExtension.totalBonded(_pledgerFor), 0);
    assertEq(horizonAccountingExtension.totalBonded(_pledgerAgainst), 0);
    address[] memory _pledgers = horizonAccountingExtension.getPledgers(_disputeId);
    assertEq(_pledgers[0], _pledgerAgainst); // TODO: `_pledgerAgainst` remains in the pledgers list
    assertEq(_pledgers.length, 1);
    // Assert HorizonStaking::slash
    IHorizonStaking.Provision memory _pledgerForProvision =
      horizonStaking.getProvision(_pledgerFor, address(horizonAccountingExtension));
    IHorizonStaking.Provision memory _pledgerAgainstProvision =
      horizonStaking.getProvision(_pledgerAgainst, address(horizonAccountingExtension));
    assertEq(_pledgerForProvision.tokens, disputeBondSize * maxNumberOfEscalations - disputeBondSize);
    assertEq(_pledgerAgainstProvision.tokens, disputeBondSize * maxNumberOfEscalations);
    // Assert GraphToken::transfer
    assertEq(graphToken.balanceOf(_pledgerFor), 0);
    assertEq(graphToken.balanceOf(_pledgerAgainst), disputeBondSize);

    // Revert if the escalation reward has already been claimed
    vm.expectRevert(IHorizonAccountingExtension.HorizonAccountingExtension_AlreadyClaimed.selector);
    horizonAccountingExtension.claimEscalationReward(_disputeId, _pledgerAgainst);
  }
}
