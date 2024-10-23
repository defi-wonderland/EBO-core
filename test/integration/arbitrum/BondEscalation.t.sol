// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.26;

import './IntegrationBase.t.sol';

contract IntegrationBondEscalation is IntegrationBase {
  bytes32 internal _requestId;
  bytes32 internal _responseId;
  bytes32 internal _disputeId;
  uint256 internal _disputeCreatedAt;

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

    // Create the request
    _requestId = _createRequest();
    // Propose the response
    _responseId = _proposeResponse(_requestId);
    // Dispute the response
    _disputeId = _disputeResponse(_requestId, _responseId);

    _disputeCreatedAt = oracle.disputeCreatedAt(_disputeId);
  }

  function test_PledgeForDispute() public {
    // Pass the dispute deadline, but not the tying buffer
    vm.warp(_disputeCreatedAt + disputeDeadline + 1);

    // Revert if breaking a tie during the tying buffer
    vm.expectRevert(IBondEscalationModule.BondEscalationModule_CannotBreakTieDuringTyingBuffer.selector);
    _pledgeForDispute(_requestId, _disputeId);

    // Pass the dispute deadline and the tying buffer
    vm.warp(_disputeCreatedAt + disputeDeadline + tyingBuffer + 1);

    // Revert if the bond escalation deadline and the tying buffer have passed
    vm.expectRevert(IBondEscalationModule.BondEscalationModule_BondEscalationOver.selector);
    _pledgeForDispute(_requestId, _disputeId);

    // Do not pass the dispute deadline nor the tying buffer
    vm.warp(_disputeCreatedAt + disputeDeadline);

    // Thaw some tokens
    uint256 _tokensToThaw = disputeBondSize * (maxNumberOfEscalations - 1) + 1;
    _thaw(_pledgerFor, _tokensToThaw);

    // Pledging for dispute reverts because of insufficient funds as the pledgerFor thawed some tokens
    vm.expectRevert(IHorizonAccountingExtension.HorizonAccountingExtension_InsufficientTokens.selector);
    _pledgeForDispute(_requestId, _disputeId);

    // Reprovision the thawed token
    _stakeGRT();
    _addToProvision(_pledgerFor, _tokensToThaw);

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

    // Revert if the dispute has already been pledged for, but not pledged against
    vm.expectRevert(IBondEscalationModule.BondEscalationModule_CanOnlySurpassByOnePledge.selector);
    _pledgeForDispute(_requestId, _disputeId);
  }

  function test_PledgeAgainstDispute() public {
    // Pass the dispute deadline, but not the tying buffer
    vm.warp(_disputeCreatedAt + disputeDeadline + 1);

    // Revert if breaking a tie during the tying buffer
    vm.expectRevert(IBondEscalationModule.BondEscalationModule_CannotBreakTieDuringTyingBuffer.selector);
    _pledgeAgainstDispute(_requestId, _disputeId);

    // Pass the dispute deadline and the tying buffer
    vm.warp(_disputeCreatedAt + disputeDeadline + tyingBuffer + 1);

    // Revert if the bond escalation deadline and the tying buffer have passed
    vm.expectRevert(IBondEscalationModule.BondEscalationModule_BondEscalationOver.selector);
    _pledgeAgainstDispute(_requestId, _disputeId);

    // Do not pass the dispute deadline nor the tying buffer
    vm.warp(_disputeCreatedAt + disputeDeadline);

    // Thaw some tokens
    uint256 _tokensToThaw = disputeBondSize * (maxNumberOfEscalations - 1) + 1;
    _thaw(_pledgerAgainst, _tokensToThaw);

    // Pledging against dispute reverts because of insufficient funds as the pledgerAgainst thawed some tokens
    vm.expectRevert(IHorizonAccountingExtension.HorizonAccountingExtension_InsufficientTokens.selector);
    _pledgeAgainstDispute(_requestId, _disputeId);

    // Reprovision the thawed token
    _stakeGRT();
    _addToProvision(_pledgerAgainst, _tokensToThaw);

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

    // Revert if the dispute has already been pledged against, but not pledged for
    vm.expectRevert(IBondEscalationModule.BondEscalationModule_CanOnlySurpassByOnePledge.selector);
    _pledgeAgainstDispute(_requestId, _disputeId);
  }

  function test_PledgeForAndAgainstDispute() public {
    // Pledge for the dispute
    _pledgeForDispute(_requestId, _disputeId);

    // Pledge against the dispute, twice
    _pledgeAgainstDispute(_requestId, _disputeId);
    _pledgeAgainstDispute(_requestId, _disputeId);

    // Pass the dispute deadline, but not the tying buffer
    vm.warp(_disputeCreatedAt + disputeDeadline + 1);

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

    // Revert if the max number of escalations has been reached
    vm.expectRevert(IBondEscalationModule.BondEscalationModule_MaxNumberOfEscalationsReached.selector);
    _pledgeForDispute(_requestId, _disputeId);
    vm.expectRevert(IBondEscalationModule.BondEscalationModule_MaxNumberOfEscalationsReached.selector);
    _pledgeAgainstDispute(_requestId, _disputeId);
  }

  function test_InsufficientBondedTokens() public {
    // Disputer tries to pledge for or against dispute after adding to their provision.
    _stakeGRT();
    _addToProvision(_disputer, disputeBondSize - 1);

    // Reverts because they don't have enough tokens to pledge
    vm.expectRevert(IHorizonAccountingExtension.HorizonAccountingExtension_InsufficientBondedTokens.selector);
    _pledgeAgainstDispute(_disputer, _requestId, _disputeId);

    vm.expectRevert(IHorizonAccountingExtension.HorizonAccountingExtension_InsufficientBondedTokens.selector);
    _pledgeForDispute(_disputer, _requestId, _disputeId);

    // Add one more token to their provision
    _addToProvision(_disputer, 1);

    // Pledge for the dispute
    _pledgeForDispute(_disputer, _requestId, _disputeId);

    // Pledge against the dispute, twice
    _pledgeAgainstDispute(_requestId, _disputeId);
    _pledgeAgainstDispute(_requestId, _disputeId);

    // Pass the dispute deadline, but not the tying buffer
    vm.warp(disputeDeadline + 1);

    vm.expectRevert(IHorizonAccountingExtension.HorizonAccountingExtension_InsufficientBondedTokens.selector);
    _pledgeForDispute(_disputer, _requestId, _disputeId);

    // Add enough to pledge again
    _stakeGRT();
    _addToProvision(_disputer, disputeBondSize);

    // Pledge for the dispute, again
    _pledgeForDispute(_disputer, _requestId, _disputeId);

    // Assert BondEscalationModule::pledgeForDispute and BondEscalationModule::pledgeAgainstDispute
    IBondEscalationModule.BondEscalation memory _escalation = bondEscalationModule.getEscalation(_requestId);
    assertEq(_escalation.disputeId, _disputeId);
    assertEq(_escalation.amountOfPledgesForDispute, maxNumberOfEscalations);
    assertEq(_escalation.amountOfPledgesAgainstDispute, maxNumberOfEscalations);
    assertEq(bondEscalationModule.pledgesForDispute(_requestId, _disputer), maxNumberOfEscalations);
    assertEq(bondEscalationModule.pledgesAgainstDispute(_requestId, _pledgerAgainst), maxNumberOfEscalations);
    // Assert HorizonAccountingExtension::pledge
    assertEq(horizonAccountingExtension.pledges(_disputeId), disputeBondSize * maxNumberOfEscalations * 2);
    assertEq(horizonAccountingExtension.totalBonded(_disputer), disputeBondSize * (maxNumberOfEscalations + 1));
    assertEq(horizonAccountingExtension.totalBonded(_pledgerAgainst), disputeBondSize * maxNumberOfEscalations);
  }

  function test_SettleBondEscalation_DisputerWon() public {
    // Revert if the bond escalation deadline and the tying buffer have not passed
    vm.expectRevert(IBondEscalationModule.BondEscalationModule_BondEscalationNotOver.selector);
    _settleBondEscalation(_requestId, _responseId, _disputeId);

    // Pass the dispute deadline and the tying buffer
    vm.warp(_disputeCreatedAt + disputeDeadline + tyingBuffer + 1);

    // Revert if the bond escalation has tied
    vm.expectRevert(IBondEscalationModule.BondEscalationModule_ShouldBeEscalated.selector);
    _settleBondEscalation(_requestId, _responseId, _disputeId);

    // Do not pass the dispute deadline nor the tying buffer
    vm.warp(_disputeCreatedAt + disputeDeadline);

    // Pledge against the dispute
    _pledgeAgainstDispute(_requestId, _disputeId);

    // Pledge for the dispute, twice
    _pledgeForDispute(_requestId, _disputeId);
    _pledgeForDispute(_requestId, _disputeId);

    // Pass the dispute deadline and the tying buffer
    vm.warp(_disputeCreatedAt + disputeDeadline + tyingBuffer + 1);

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
    vm.expectRevert(abi.encodeWithSelector(IOracle.Oracle_CannotEscalate.selector, _disputeId));
    _escalateDispute(_requestId, _responseId, _disputeId);
  }

  function test_SettleBondEscalation_DisputerLost() public {
    // Revert if the bond escalation deadline and the tying buffer have not passed
    vm.expectRevert(IBondEscalationModule.BondEscalationModule_BondEscalationNotOver.selector);
    _settleBondEscalation(_requestId, _responseId, _disputeId);

    // Pass the dispute deadline and the tying buffer
    vm.warp(_disputeCreatedAt + disputeDeadline + tyingBuffer + 1);

    // Revert if the bond escalation has tied
    vm.expectRevert(IBondEscalationModule.BondEscalationModule_ShouldBeEscalated.selector);
    _settleBondEscalation(_requestId, _responseId, _disputeId);

    // Do not pass the dispute deadline nor the tying buffer
    vm.warp(_disputeCreatedAt + disputeDeadline);

    // Pledge for the dispute
    _pledgeForDispute(_requestId, _disputeId);

    // Pledge against the dispute, twice
    _pledgeAgainstDispute(_requestId, _disputeId);
    _pledgeAgainstDispute(_requestId, _disputeId);

    // Pass the dispute deadline and the tying buffer
    vm.warp(_disputeCreatedAt + disputeDeadline + tyingBuffer + 1);

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
    vm.expectRevert(abi.encodeWithSelector(IOracle.Oracle_CannotEscalate.selector, _disputeId));
    _escalateDispute(_requestId, _responseId, _disputeId);
  }

  function test_ClaimEscalationReward_DisputerWon() public {
    // Revert if the bond escalation has not been settled
    vm.expectRevert(IHorizonAccountingExtension.HorizonAccountingExtension_NoEscalationResult.selector);
    _claimEscalationReward(_disputeId, _pledgerFor);

    // Pledge against the dispute
    _pledgeAgainstDispute(_requestId, _disputeId);

    // Pledge for the dispute, twice
    _pledgeForDispute(_requestId, _disputeId);
    _pledgeForDispute(_requestId, _disputeId);

    // Pass the dispute deadline and the tying buffer
    vm.warp(_disputeCreatedAt + disputeDeadline + tyingBuffer + 1);

    // Settle the bond escalation
    _settleBondEscalation(_requestId, _responseId, _disputeId);

    // Claim the escalation rewards
    _claimEscalationReward(_disputeId, _pledgerFor);
    _claimEscalationReward(_disputeId, _pledgerAgainst);

    // Assert HorizonAccountingExtension::claimEscalationReward
    assertTrue(horizonAccountingExtension.pledgerClaimed(_requestId, _pledgerFor));
    assertTrue(horizonAccountingExtension.pledgerClaimed(_requestId, _pledgerAgainst));
    assertEq(horizonAccountingExtension.pledges(_disputeId), 0);
    assertEq(horizonAccountingExtension.totalBonded(_pledgerFor), 0);
    assertEq(horizonAccountingExtension.totalBonded(_pledgerAgainst), 0);
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
    _claimEscalationReward(_disputeId, _pledgerFor);
  }

  function test_ClaimEscalationReward_DisputerWon_ManualSlash() public {
    // Create a new pledger
    address _pledgerFor2 = makeAddr('pledgerFor2');
    _stakeGRT(_pledgerFor2, disputeBondSize * maxNumberOfEscalations);
    _createProvision(_pledgerFor2, disputeBondSize * maxNumberOfEscalations);

    // Pledge against the dispute
    _pledgeAgainstDispute(_requestId, _disputeId);

    // Pledge for the dispute, twice
    _pledgeForDispute(_requestId, _disputeId);
    _pledgeForDispute(_pledgerFor2, _requestId, _disputeId);

    // Pass the dispute deadline and the tying buffer
    vm.warp(_disputeCreatedAt + disputeDeadline + tyingBuffer + 1);

    // Settle the bond escalation
    _settleBondEscalation(_requestId, _responseId, _disputeId);

    assertEq(graphToken.balanceOf(address(horizonAccountingExtension)), 0);

    horizonAccountingExtension.slash(_disputeId, 1, 1);

    assertEq(graphToken.balanceOf(address(horizonAccountingExtension)), disputeBondSize);

    // Slashing manually should increase the balance for the dispute
    assertEq(horizonAccountingExtension.disputeBalance(_disputeId), disputeBondSize);

    // Try to slash a lot of people
    horizonAccountingExtension.slash(_disputeId, 100, 100);

    // Dispute balance should remain equal
    assertEq(horizonAccountingExtension.disputeBalance(_disputeId), disputeBondSize);

    // Claim the escalation rewards
    horizonAccountingExtension.claimEscalationReward(_disputeId, _pledgerAgainst);

    // Pledger against doesn't get any reward so the disputeBalance should remain the same
    assertEq(horizonAccountingExtension.disputeBalance(_disputeId), disputeBondSize);

    // The first pledger for claims their reward and gets half the total amount from the pledger against
    horizonAccountingExtension.claimEscalationReward(_disputeId, _pledgerFor);
    assertEq(horizonAccountingExtension.disputeBalance(_disputeId), disputeBondSize / 2);

    // The pledges for the pledgerFor2 and half of the pledge from the pledgerAgainst are still in the contract
    assertEq(horizonAccountingExtension.pledges(_disputeId), disputeBondSize + disputeBondSize / 2);

    // The second pledger for claims their reward and gets half the total amount from the pledger against
    horizonAccountingExtension.claimEscalationReward(_disputeId, _pledgerFor2);
    assertEq(horizonAccountingExtension.disputeBalance(_disputeId), 0);

    // Assert HorizonAccountingExtension::claimEscalationReward
    assertTrue(horizonAccountingExtension.pledgerClaimed(_requestId, _pledgerFor));
    assertTrue(horizonAccountingExtension.pledgerClaimed(_requestId, _pledgerAgainst));
    assertTrue(horizonAccountingExtension.pledgerClaimed(_requestId, _pledgerFor2));
    assertEq(horizonAccountingExtension.pledges(_disputeId), 0);
    assertEq(horizonAccountingExtension.totalBonded(_pledgerFor), 0);
    assertEq(horizonAccountingExtension.totalBonded(_pledgerAgainst), 0);
    assertEq(horizonAccountingExtension.totalBonded(_pledgerFor2), 0);

    // Assert HorizonStaking::slash
    IHorizonStaking.Provision memory _pledgerForProvision =
      horizonStaking.getProvision(_pledgerFor, address(horizonAccountingExtension));
    IHorizonStaking.Provision memory _pledgerAgainstProvision =
      horizonStaking.getProvision(_pledgerAgainst, address(horizonAccountingExtension));
    assertEq(_pledgerForProvision.tokens, disputeBondSize * maxNumberOfEscalations);
    assertEq(_pledgerAgainstProvision.tokens, disputeBondSize * maxNumberOfEscalations - disputeBondSize);

    // Assert GraphToken::transfer
    assertEq(graphToken.balanceOf(_pledgerFor), disputeBondSize / 2);
    assertEq(graphToken.balanceOf(_pledgerFor2), disputeBondSize / 2);
    assertEq(graphToken.balanceOf(_pledgerAgainst), 0);
  }

  function test_ClaimEscalationReward_DisputerLost() public {
    // Revert if the bond escalation has not been settled
    vm.expectRevert(IHorizonAccountingExtension.HorizonAccountingExtension_NoEscalationResult.selector);
    _claimEscalationReward(_disputeId, _pledgerAgainst);

    // Pledge for the dispute
    _pledgeForDispute(_requestId, _disputeId);

    // Pledge against the dispute, twice
    _pledgeAgainstDispute(_requestId, _disputeId);
    _pledgeAgainstDispute(_requestId, _disputeId);

    // Pass the dispute deadline and the tying buffer
    vm.warp(_disputeCreatedAt + disputeDeadline + tyingBuffer + 1);

    // Settle the bond escalation
    _settleBondEscalation(_requestId, _responseId, _disputeId);

    // Claim the escalation rewards
    _claimEscalationReward(_disputeId, _pledgerFor);
    _claimEscalationReward(_disputeId, _pledgerAgainst);

    // Assert HorizonAccountingExtension::claimEscalationReward
    assertTrue(horizonAccountingExtension.pledgerClaimed(_requestId, _pledgerFor));
    assertTrue(horizonAccountingExtension.pledgerClaimed(_requestId, _pledgerAgainst));
    assertEq(horizonAccountingExtension.pledges(_disputeId), 0);
    assertEq(horizonAccountingExtension.totalBonded(_pledgerFor), 0);
    assertEq(horizonAccountingExtension.totalBonded(_pledgerAgainst), 0);
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
    _claimEscalationReward(_disputeId, _pledgerAgainst);
  }
}
