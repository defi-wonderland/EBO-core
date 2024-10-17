// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.26;

import './IntegrationBase.t.sol';

contract IntegrationFinalizeRequest is IntegrationBase {
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

  function test_FinalizeRequest_TooEarlyToFinalize() public {
    // Create the request
    bytes32 _requestId = _createRequest();

    // Revert if the request is finalized without response before the response deadline
    vm.expectRevert(IBondedResponseModule.BondedResponseModule_TooEarlyToFinalize.selector);
    _finalizeRequest(_requestId, 0);

    // Propose the response
    bytes32 _responseId = _proposeResponse(_requestId);

    // Revert if the request is finalized with response before the response deadline
    vm.expectRevert(IBondedResponseModule.BondedResponseModule_TooEarlyToFinalize.selector);
    _finalizeRequest(_requestId, _responseId);

    // Pass the response deadline
    vm.roll(block.number + responseDeadline);

    // Revert if the request is finalized with response before the dispute window
    vm.expectRevert(IBondedResponseModule.BondedResponseModule_TooEarlyToFinalize.selector);
    _finalizeRequest(_requestId, _responseId);
  }

  function test_FinalizeRequest_NoResponse() public {
    // Create the request
    bytes32 _requestId = _createRequest();

    // Pass the response deadline
    vm.roll(block.number + responseDeadline);

    // Finalize the request without response
    _finalizeRequest(_requestId, 0);

    // Assert Oracle::finalize
    assertEq(oracle.finalizedAt(_requestId), block.number);
    assertEq(oracle.finalizedResponseId(_requestId), 0);

    // Revert if the request has already been finalized
    vm.expectRevert(abi.encodeWithSelector(IOracle.Oracle_AlreadyFinalized.selector, _requestId));
    _proposeResponse(_requestId);
    vm.expectRevert(abi.encodeWithSelector(IOracle.Oracle_AlreadyFinalized.selector, _requestId));
    _finalizeRequest(_requestId, 0);
  }

  function test_FinalizeRequest_NoEscalation() public {
    // Create the request
    bytes32 _requestId = _createRequest();
    // Propose the response
    bytes32 _responseId = _proposeResponse(_requestId);

    // Pass the response deadline
    vm.roll(block.number + responseDeadline);

    // Revert if the request is finalized without response when a response without dispute exists
    vm.expectRevert(abi.encodeWithSelector(IOracle.Oracle_FinalizableResponseExists.selector, _responseId));
    _finalizeRequest(_requestId, 0);

    // Pass the response dispute window
    vm.roll(block.number + responseDisputeWindow - responseDeadline);

    // Finalize the request with response
    _finalizeRequest(_requestId, _responseId);

    // Assert Oracle::finalize
    assertEq(oracle.finalizedAt(_requestId), block.number);
    assertEq(oracle.finalizedResponseId(_requestId), _responseId);
    // Assert HorizonAccountingExtension::release
    assertEq(horizonAccountingExtension.bondedForRequest(_proposer, _requestId), 0);
    assertEq(horizonAccountingExtension.totalBonded(_proposer), 0);

    // Revert if the request has already been finalized
    vm.expectRevert(abi.encodeWithSelector(IOracle.Oracle_AlreadyFinalized.selector, _requestId));
    _disputeResponse(_requestId, _responseId);
    vm.expectRevert(abi.encodeWithSelector(IOracle.Oracle_FinalizableResponseExists.selector, _responseId));
    _finalizeRequest(_requestId, 0);
    vm.expectRevert(abi.encodeWithSelector(IOracle.Oracle_AlreadyFinalized.selector, _requestId));
    _finalizeRequest(_requestId, _responseId);
  }

  function test_FinalizeRequest_BondEscalation_DisputerWon() public {
    // Create the request
    bytes32 _requestId = _createRequest();
    // Propose the response
    bytes32 _responseId = _proposeResponse(_requestId);

    // Pass the response deadline
    vm.roll(block.number + responseDeadline);

    // Revert if the request is finalized without response when a response without dispute exists
    vm.expectRevert(abi.encodeWithSelector(IOracle.Oracle_FinalizableResponseExists.selector, _responseId));
    _finalizeRequest(_requestId, 0);

    // Pass the response dispute window
    vm.roll(block.number + responseDisputeWindow - responseDeadline);

    // Dispute the response
    bytes32 _disputeId = _disputeResponse(_requestId, _responseId);

    // TODO: Request can be finalized without response here
    // _finalizeRequest(_requestId, 0);

    // Revert if the request is finalized with response with unresolved dispute
    vm.expectRevert(IOracle.Oracle_InvalidFinalizedResponse.selector);
    _finalizeRequest(_requestId, _responseId);

    // Pledge against the dispute
    _pledgeAgainstDispute(_requestId, _disputeId);

    // Pledge for the dispute, twice
    _pledgeForDispute(_requestId, _disputeId);
    _pledgeForDispute(_requestId, _disputeId);

    // Pass the dispute deadline and the tying buffer
    vm.warp(disputeDeadline + tyingBuffer + 1);

    // Settle the bond escalation
    _settleBondEscalation(_requestId, _responseId, _disputeId);

    // Revert if the request is finalized with response with won dispute
    vm.expectRevert(IOracle.Oracle_InvalidFinalizedResponse.selector);
    _finalizeRequest(_requestId, _responseId);

    // Finalize the request without response
    _finalizeRequest(_requestId, 0);

    // Assert Oracle::finalize
    assertEq(oracle.finalizedAt(_requestId), block.number);
    assertEq(oracle.finalizedResponseId(_requestId), 0);

    // Revert if the request has already been finalized
    vm.expectRevert(abi.encodeWithSelector(IOracle.Oracle_AlreadyFinalized.selector, _requestId));
    _finalizeRequest(_requestId, 0);
    vm.expectRevert(IOracle.Oracle_InvalidFinalizedResponse.selector);
    _finalizeRequest(_requestId, _responseId);
  }

  function test_FinalizeRequest_BondEscalation_DisputerLost() public {
    // Create the request
    bytes32 _requestId = _createRequest();
    // Propose the response
    bytes32 _responseId = _proposeResponse(_requestId);

    // Pass the response deadline
    vm.roll(block.number + responseDeadline);

    // Revert if the request is finalized without response when a response without dispute exists
    vm.expectRevert(abi.encodeWithSelector(IOracle.Oracle_FinalizableResponseExists.selector, _responseId));
    _finalizeRequest(_requestId, 0);

    // Pass the response dispute window
    vm.roll(block.number + responseDisputeWindow - responseDeadline);

    // Dispute the response
    bytes32 _disputeId = _disputeResponse(_requestId, _responseId);

    // TODO: Request can be finalized without response here
    // _finalizeRequest(_requestId, 0);

    // Revert if the request is finalized with response with unresolved dispute
    vm.expectRevert(IOracle.Oracle_InvalidFinalizedResponse.selector);
    _finalizeRequest(_requestId, _responseId);

    // Pledge for the dispute
    _pledgeForDispute(_requestId, _disputeId);

    // Pledge against the dispute, twice
    _pledgeAgainstDispute(_requestId, _disputeId);
    _pledgeAgainstDispute(_requestId, _disputeId);

    // Pass the dispute deadline and the tying buffer
    vm.warp(disputeDeadline + tyingBuffer + 1);

    // Settle the bond escalation
    _settleBondEscalation(_requestId, _responseId, _disputeId);

    // Revert if the request is finalized without response when a response with lost dispute exists
    vm.expectRevert(abi.encodeWithSelector(IOracle.Oracle_FinalizableResponseExists.selector, _responseId));
    _finalizeRequest(_requestId, 0);

    // Finalize the request with response
    _finalizeRequest(_requestId, _responseId);

    // Assert Oracle::finalize
    assertEq(oracle.finalizedAt(_requestId), block.number);
    assertEq(oracle.finalizedResponseId(_requestId), _responseId);
    // Assert HorizonAccountingExtension::release
    assertEq(horizonAccountingExtension.bondedForRequest(_proposer, _requestId), 0);
    assertEq(horizonAccountingExtension.totalBonded(_proposer), 0);

    // Revert if the request has already been finalized
    vm.expectRevert(abi.encodeWithSelector(IOracle.Oracle_FinalizableResponseExists.selector, _responseId));
    _finalizeRequest(_requestId, 0);
    vm.expectRevert(abi.encodeWithSelector(IOracle.Oracle_AlreadyFinalized.selector, _requestId));
    _finalizeRequest(_requestId, _responseId);
  }

  function test_FinalizeRequest_Arbitration_Won() public {
    // Create the request
    bytes32 _requestId = _createRequest();
    // Propose the response
    bytes32 _responseId = _proposeResponse(_requestId);

    // Pass the response deadline
    vm.roll(block.number + responseDeadline);

    // Revert if the request is finalized without response when a response without dispute exists
    vm.expectRevert(abi.encodeWithSelector(IOracle.Oracle_FinalizableResponseExists.selector, _responseId));
    _finalizeRequest(_requestId, 0);

    // Pass the response dispute window
    vm.roll(block.number + responseDisputeWindow - responseDeadline);

    // Dispute the response
    bytes32 _disputeId = _disputeResponse(_requestId, _responseId);

    // TODO: Request can be finalized without response here
    // _finalizeRequest(_requestId, 0);

    // Revert if the request is finalized with response with unresolved dispute
    vm.expectRevert(IOracle.Oracle_InvalidFinalizedResponse.selector);
    _finalizeRequest(_requestId, _responseId);

    // Pledge for the dispute
    _pledgeForDispute(_requestId, _disputeId);
    // Pledge against the dispute
    _pledgeAgainstDispute(_requestId, _disputeId);

    // Pass the dispute deadline
    vm.warp(disputeDeadline + 1);

    // Escalate the dispute
    _escalateDispute(_requestId, _responseId, _disputeId);

    // Arbitrate and resolve the dispute, and finalize the request without response
    _arbitrateDispute(_disputeId, IOracle.DisputeStatus.Won);

    // Assert Oracle::finalize
    assertEq(oracle.finalizedAt(_requestId), block.number);
    assertEq(oracle.finalizedResponseId(_requestId), 0);

    // Revert if the request has already been finalized
    vm.expectRevert(abi.encodeWithSelector(IOracle.Oracle_AlreadyFinalized.selector, _requestId));
    _finalizeRequest(_requestId, 0);
    vm.expectRevert(IOracle.Oracle_InvalidFinalizedResponse.selector);
    _finalizeRequest(_requestId, _responseId);
  }

  function test_FinalizeRequest_Arbitration_Lost() public {
    // Create the request
    bytes32 _requestId = _createRequest();
    // Propose the response
    bytes32 _responseId = _proposeResponse(_requestId);

    // Pass the response deadline
    vm.roll(block.number + responseDeadline);

    // Revert if the request is finalized without response when a response without dispute exists
    vm.expectRevert(abi.encodeWithSelector(IOracle.Oracle_FinalizableResponseExists.selector, _responseId));
    _finalizeRequest(_requestId, 0);

    // Pass the response dispute window
    vm.roll(block.number + responseDisputeWindow - responseDeadline);

    // Dispute the response
    bytes32 _disputeId = _disputeResponse(_requestId, _responseId);

    // TODO: Request can be finalized without response here
    // _finalizeRequest(_requestId, 0);

    // Revert if the request is finalized with response with unresolved dispute
    vm.expectRevert(IOracle.Oracle_InvalidFinalizedResponse.selector);
    _finalizeRequest(_requestId, _responseId);

    // Pledge for the dispute
    _pledgeForDispute(_requestId, _disputeId);
    // Pledge against the dispute
    _pledgeAgainstDispute(_requestId, _disputeId);

    // Pass the dispute deadline
    vm.warp(disputeDeadline + 1);

    // Escalate the dispute
    _escalateDispute(_requestId, _responseId, _disputeId);

    // Arbitrate and resolve the dispute, and finalize the request with response
    _arbitrateDispute(_disputeId, IOracle.DisputeStatus.Lost);

    // Assert Oracle::finalize
    assertEq(oracle.finalizedAt(_requestId), block.number);
    assertEq(oracle.finalizedResponseId(_requestId), _responseId);
    // Assert HorizonAccountingExtension::release
    assertEq(horizonAccountingExtension.bondedForRequest(_proposer, _requestId), 0);
    assertEq(horizonAccountingExtension.totalBonded(_proposer), 0);

    // Revert if the request has already been finalized
    vm.expectRevert(abi.encodeWithSelector(IOracle.Oracle_FinalizableResponseExists.selector, _responseId));
    _finalizeRequest(_requestId, 0);
    vm.expectRevert(abi.encodeWithSelector(IOracle.Oracle_AlreadyFinalized.selector, _requestId));
    _finalizeRequest(_requestId, _responseId);
  }

  function test_FinalizeRequest_Arbitration_NoResolution() public {
    // Create the request
    bytes32 _requestId = _createRequest();
    // Propose the response
    bytes32 _responseId = _proposeResponse(_requestId);

    // Pass the response deadline
    vm.roll(block.number + responseDeadline);

    // Revert if the request is finalized without response when a response without dispute exists
    vm.expectRevert(abi.encodeWithSelector(IOracle.Oracle_FinalizableResponseExists.selector, _responseId));
    _finalizeRequest(_requestId, 0);

    // Pass the response dispute window
    vm.roll(block.number + responseDisputeWindow - responseDeadline);

    // Dispute the response
    bytes32 _disputeId = _disputeResponse(_requestId, _responseId);

    // TODO: Request can be finalized without response here
    // _finalizeRequest(_requestId, 0);

    // Revert if the request is finalized with response with unresolved dispute
    vm.expectRevert(IOracle.Oracle_InvalidFinalizedResponse.selector);
    _finalizeRequest(_requestId, _responseId);

    // Pledge for the dispute
    _pledgeForDispute(_requestId, _disputeId);
    // Pledge against the dispute
    _pledgeAgainstDispute(_requestId, _disputeId);

    // Pass the dispute deadline
    vm.warp(disputeDeadline + 1);

    // Escalate the dispute
    _escalateDispute(_requestId, _responseId, _disputeId);

    // Arbitrate and resolve the dispute, and finalize the request without response
    _arbitrateDispute(_disputeId, IOracle.DisputeStatus.NoResolution);

    // Assert Oracle::finalize
    assertEq(oracle.finalizedAt(_requestId), block.number);
    assertEq(oracle.finalizedResponseId(_requestId), 0);

    // Revert if the request has already been finalized
    vm.expectRevert(abi.encodeWithSelector(IOracle.Oracle_AlreadyFinalized.selector, _requestId));
    _finalizeRequest(_requestId, 0);
    vm.expectRevert(IOracle.Oracle_InvalidFinalizedResponse.selector);
    _finalizeRequest(_requestId, _responseId);
  }

  function test_ReleaseUnutilizedResponse_BondEscalation_DisputerWon() public {
    // Create the request
    bytes32 _requestId = _createRequest();
    // Propose the response
    bytes32 _responseId = _proposeResponse(_requestId);

    // Revert if the request has not been finalized
    vm.expectRevert(IBondedResponseModule.BondedResponseModule_InvalidReleaseParameters.selector);
    _releaseUnfinalizableResponseBond(_requestId, _responseId);

    // Pass the response deadline
    vm.roll(block.number + responseDeadline);

    // Dispute the response
    bytes32 _disputeId = _disputeResponse(_requestId, _responseId);

    // TODO: What if the request is finalized without response, after a response has been disputed but before
    //       its bond escalation settlement or dispute arbitration?

    // Finalize the request without response
    _finalizeRequest(_requestId, 0);

    // Revert if the unfinalizable response has unresolved dispute
    vm.expectRevert(IBondedResponseModule.BondedResponseModule_InvalidReleaseParameters.selector);
    _releaseUnfinalizableResponseBond(_requestId, _responseId);

    // Pledge against the dispute
    _pledgeAgainstDispute(_requestId, _disputeId);

    // Pledge for the dispute, twice
    _pledgeForDispute(_requestId, _disputeId);
    _pledgeForDispute(_requestId, _disputeId);

    // Pass the dispute deadline and the tying buffer
    vm.warp(disputeDeadline + tyingBuffer + 1);

    // Settle the bond escalation
    _settleBondEscalation(_requestId, _responseId, _disputeId);

    vm.skip(true); // TODO: How does the proposer release the response bond?

    // Release the unfinalizable response bond
    _releaseUnfinalizableResponseBond(_requestId, _responseId);

    // Assert HorizonAccountingExtension::release
    assertEq(horizonAccountingExtension.bondedForRequest(_proposer, _requestId), 0);
    assertEq(horizonAccountingExtension.totalBonded(_proposer), 0);

    // TODO: What if the release does not revert because the proposer had bonded multiple times for the same request?
    // Revert if the unfinalizable response bond has already been released
    vm.expectRevert();
    _releaseUnfinalizableResponseBond(_requestId, _responseId);
  }

  function test_ReleaseUnutilizedResponse_BondEscalation_DisputerLost() public {
    // Create the request
    bytes32 _requestId = _createRequest();
    // Propose the response
    bytes32 _responseId = _proposeResponse(_requestId);

    // Revert if the request has not been finalized
    vm.expectRevert(IBondedResponseModule.BondedResponseModule_InvalidReleaseParameters.selector);
    _releaseUnfinalizableResponseBond(_requestId, _responseId);

    // Pass the response deadline
    vm.roll(block.number + responseDeadline);

    // Dispute the response
    bytes32 _disputeId = _disputeResponse(_requestId, _responseId);

    // TODO: What if the request is finalized without response, after a response has been disputed but before
    //       its bond escalation settlement or dispute arbitration?

    // Finalize the request without response
    _finalizeRequest(_requestId, 0);

    // Revert if the unfinalizable response has unresolved dispute
    vm.expectRevert(IBondedResponseModule.BondedResponseModule_InvalidReleaseParameters.selector);
    _releaseUnfinalizableResponseBond(_requestId, _responseId);

    // Pledge for the dispute
    _pledgeForDispute(_requestId, _disputeId);

    // Pledge against the dispute, twice
    _pledgeAgainstDispute(_requestId, _disputeId);
    _pledgeAgainstDispute(_requestId, _disputeId);

    // Pass the dispute deadline and the tying buffer
    vm.warp(disputeDeadline + tyingBuffer + 1);

    // Settle the bond escalation
    _settleBondEscalation(_requestId, _responseId, _disputeId);

    vm.skip(true); // TODO: How does the proposer release the response bond?

    // Release the unfinalizable response bond
    _releaseUnfinalizableResponseBond(_requestId, _responseId);

    // Assert HorizonAccountingExtension::release
    assertEq(horizonAccountingExtension.bondedForRequest(_proposer, _requestId), 0);
    assertEq(horizonAccountingExtension.totalBonded(_proposer), 0);

    // TODO: What if the release does not revert because the proposer had bonded multiple times for the same request?
    // Revert if the unfinalizable response bond has already been released
    vm.expectRevert();
    _releaseUnfinalizableResponseBond(_requestId, _responseId);
  }

  function test_ReleaseUnutilizedResponse_Arbitration_Won() public {
    // Create the request
    bytes32 _requestId = _createRequest();
    // Propose the response
    bytes32 _responseId = _proposeResponse(_requestId);

    // Revert if the request has not been finalized
    vm.expectRevert(IBondedResponseModule.BondedResponseModule_InvalidReleaseParameters.selector);
    _releaseUnfinalizableResponseBond(_requestId, _responseId);

    // Pass the response deadline
    vm.roll(block.number + responseDeadline);

    // Dispute the response
    bytes32 _disputeId = _disputeResponse(_requestId, _responseId);

    // TODO: What if the request is finalized without response, after a response has been disputed but before
    //       its bond escalation settlement or dispute arbitration?

    // Finalize the request without response
    _finalizeRequest(_requestId, 0);

    // Revert if the unfinalizable response has unresolved dispute
    vm.expectRevert(IBondedResponseModule.BondedResponseModule_InvalidReleaseParameters.selector);
    _releaseUnfinalizableResponseBond(_requestId, _responseId);

    // Pledge for the dispute
    _pledgeForDispute(_requestId, _disputeId);
    // Pledge against the dispute
    _pledgeAgainstDispute(_requestId, _disputeId);

    // Pass the dispute deadline
    vm.warp(disputeDeadline + 1);

    // Escalate the dispute
    _escalateDispute(_requestId, _responseId, _disputeId);

    // Arbitrate and resolve the dispute, and finalize the request without response
    _arbitrateDispute(_disputeId, IOracle.DisputeStatus.Won);

    vm.skip(true); // TODO: How does the proposer release the response bond?

    // Release the unfinalizable response bond
    _releaseUnfinalizableResponseBond(_requestId, _responseId);

    // Assert HorizonAccountingExtension::release
    assertEq(horizonAccountingExtension.bondedForRequest(_proposer, _requestId), 0);
    assertEq(horizonAccountingExtension.totalBonded(_proposer), 0);

    // TODO: What if the release does not revert because the proposer had bonded multiple times for the same request?
    // Revert if the unfinalizable response bond has already been released
    vm.expectRevert();
    _releaseUnfinalizableResponseBond(_requestId, _responseId);
  }

  function test_ReleaseUnutilizedResponse_Arbitration_Lost() public {
    // Create the request
    bytes32 _requestId = _createRequest();
    // Propose the response
    bytes32 _responseId = _proposeResponse(_requestId);

    // Revert if the request has not been finalized
    vm.expectRevert(IBondedResponseModule.BondedResponseModule_InvalidReleaseParameters.selector);
    _releaseUnfinalizableResponseBond(_requestId, _responseId);

    // Pass the response deadline
    vm.roll(block.number + responseDeadline);

    // Dispute the response
    bytes32 _disputeId = _disputeResponse(_requestId, _responseId);

    // TODO: What if the request is finalized without response, after a response has been disputed but before
    //       its bond escalation settlement or dispute arbitration?

    // Finalize the request without response
    _finalizeRequest(_requestId, 0);

    // Revert if the unfinalizable response has unresolved dispute
    vm.expectRevert(IBondedResponseModule.BondedResponseModule_InvalidReleaseParameters.selector);
    _releaseUnfinalizableResponseBond(_requestId, _responseId);

    // Pledge for the dispute
    _pledgeForDispute(_requestId, _disputeId);
    // Pledge against the dispute
    _pledgeAgainstDispute(_requestId, _disputeId);

    // Pass the dispute deadline
    vm.warp(disputeDeadline + 1);

    // Escalate the dispute
    _escalateDispute(_requestId, _responseId, _disputeId);

    // Arbitrate and resolve the dispute, and finalize the request with response
    _arbitrateDispute(_disputeId, IOracle.DisputeStatus.Lost);

    vm.skip(true); // TODO: How does the proposer release the response bond?

    // Release the unfinalizable response bond
    _releaseUnfinalizableResponseBond(_requestId, _responseId);

    // Assert HorizonAccountingExtension::release
    assertEq(horizonAccountingExtension.bondedForRequest(_proposer, _requestId), 0);
    assertEq(horizonAccountingExtension.totalBonded(_proposer), 0);

    // TODO: What if the release does not revert because the proposer had bonded multiple times for the same request?
    // Revert if the unfinalizable response bond has already been released
    vm.expectRevert();
    _releaseUnfinalizableResponseBond(_requestId, _responseId);
  }

  function test_ReleaseUnutilizedResponse_Arbitration_NoResolution() public {
    // Create the request
    bytes32 _requestId = _createRequest();
    // Propose the response
    bytes32 _responseId = _proposeResponse(_requestId);

    // Revert if the request has not been finalized
    vm.expectRevert(IBondedResponseModule.BondedResponseModule_InvalidReleaseParameters.selector);
    _releaseUnfinalizableResponseBond(_requestId, _responseId);

    // Pass the response deadline
    vm.roll(block.number + responseDeadline);

    // Dispute the response
    bytes32 _disputeId = _disputeResponse(_requestId, _responseId);

    // TODO: What if the request is finalized without response, after a response has been disputed but before
    //       its bond escalation settlement or dispute arbitration?

    // Finalize the request without response
    _finalizeRequest(_requestId, 0);

    // Revert if the unfinalizable response has unresolved dispute
    vm.expectRevert(IBondedResponseModule.BondedResponseModule_InvalidReleaseParameters.selector);
    _releaseUnfinalizableResponseBond(_requestId, _responseId);

    // Pledge for the dispute
    _pledgeForDispute(_requestId, _disputeId);
    // Pledge against the dispute
    _pledgeAgainstDispute(_requestId, _disputeId);

    // Pass the dispute deadline
    vm.warp(disputeDeadline + 1);

    // Escalate the dispute
    _escalateDispute(_requestId, _responseId, _disputeId);

    // Arbitrate and resolve the dispute, and finalize the request without response
    _arbitrateDispute(_disputeId, IOracle.DisputeStatus.NoResolution);

    vm.skip(true); // TODO: How does the proposer release the response bond?

    // Release the unfinalizable response bond
    _releaseUnfinalizableResponseBond(_requestId, _responseId);

    // Assert HorizonAccountingExtension::release
    assertEq(horizonAccountingExtension.bondedForRequest(_proposer, _requestId), 0);
    assertEq(horizonAccountingExtension.totalBonded(_proposer), 0);

    // TODO: What if the release does not revert because the proposer had bonded multiple times for the same request?
    // Revert if the unfinalizable response bond has already been released
    vm.expectRevert();
    _releaseUnfinalizableResponseBond(_requestId, _responseId);
  }
}
