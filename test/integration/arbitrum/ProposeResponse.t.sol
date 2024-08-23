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
    _approveModules();
    _addChains();

    // Create the requests
    _createRequests();
  }

  function test_proposeResponse() public {
    _proposeResponse();
  }
}
