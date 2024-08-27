// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.26;

import './IntegrationBase.sol';

contract Integration_ProposeResponse is IntegrationBase {
  function setUp() public override {
    super.setUp();

    // Create data
    _setRequestModuleData();
    _setResponseModuleData();

    // Approve modules and chain IDs
    _approveModules(_user);
    _addChains();

    // Create the requests
    _createRequest();
  }

  function test_proposeResponse() public {
    _proposeResponse();

    assertEq(_oracle.responseCreatedAt(_responseId), block.number);
    assertEq(_accountingExtension.bondedAmountOf(_user, _graphToken, _requestId), _bondSize);
  }
}
