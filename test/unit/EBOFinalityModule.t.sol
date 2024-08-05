// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {IModule} from '@defi-wonderland/prophet-core-contracts/solidity/interfaces/IModule.sol';
import {IOracle} from '@defi-wonderland/prophet-core-contracts/solidity/interfaces/IOracle.sol';

import {IEBOFinalityModule} from 'interfaces/IEBOFinalityModule.sol';

import {EBOFinalityModule} from 'contracts/EBOFinalityModule.sol';

import 'forge-std/Test.sol';

contract EBOFinalityModule_Unit_BaseTest is Test {
  EBOFinalityModule public eboFinalityModule;

  IOracle public oracle;
  address public eboRequestCreator;
  address public arbitrator;

  uint256 public constant FUZZED_ARRAY_LENGTH = 32;

  event RequestFinalized(bytes32 indexed _requestId, IOracle.Response _response, address _finalizer);
  event NewEpoch(uint256 _epoch, uint256 _chainId, uint256 _blockNumber);
  event AmendEpoch(uint256 _epoch, uint256 _chainId, uint256 _blockNumber);

  function setUp() public {
    oracle = IOracle(makeAddr('Oracle'));
    eboRequestCreator = makeAddr('EBORequestCreator');
    arbitrator = makeAddr('Arbitrator');

    eboFinalityModule = new EBOFinalityModule(oracle, eboRequestCreator, arbitrator);
  }

  function _getId(IOracle.Request memory _request) internal pure returns (bytes32 _id) {
    _id = keccak256(abi.encode(_request));
  }

  function _getDynamicArray(uint256[FUZZED_ARRAY_LENGTH] calldata _staticArray)
    internal
    pure
    returns (uint256[] memory _dynamicArray)
  {
    _dynamicArray = new uint256[](FUZZED_ARRAY_LENGTH);
    for (uint256 _i; _i < FUZZED_ARRAY_LENGTH; ++_i) {
      _dynamicArray[_i] = _staticArray[_i];
    }
  }
}

contract EBOFinalityModule_Unit_Constructor is EBOFinalityModule_Unit_BaseTest {
  function test_setOracle() public view {
    assertEq(address(eboFinalityModule.ORACLE()), address(oracle));
  }

  function test_setEBORequestCreator() public view {
    assertEq(eboFinalityModule.eboRequestCreator(), eboRequestCreator);
  }

  function test_setArbitrator() public view {
    assertEq(eboFinalityModule.arbitrator(), arbitrator);
  }
}

contract EBOFinalityModule_Unit_FinalizeRequest is EBOFinalityModule_Unit_BaseTest {
  modifier happyPath(IOracle.Request memory _request, IOracle.Response memory _response) {
    _request.requester = eboRequestCreator;
    _response.requestId = _getId(_request);

    vm.startPrank(address(oracle));
    _;
  }

  function test_revertOnlyOracle(
    IOracle.Request memory _request,
    IOracle.Response memory _response,
    address _finalizer
  ) public happyPath(_request, _response) {
    vm.stopPrank();
    vm.expectRevert(IModule.Module_OnlyOracle.selector);
    eboFinalityModule.finalizeRequest(_request, _response, _finalizer);
  }

  function test_revertInvalidRequester(
    IOracle.Request memory _request,
    IOracle.Response memory _response,
    address _finalizer,
    address _requester
  ) public happyPath(_request, _response) {
    vm.assume(_requester != eboRequestCreator);
    _request.requester = _requester;

    vm.expectRevert(IEBOFinalityModule.EBOFinalityModule_InvalidRequester.selector);
    eboFinalityModule.finalizeRequest(_request, _response, _finalizer);
  }

  function test_revertInvalidResponseBody(
    IOracle.Request memory _request,
    IOracle.Response memory _response,
    address _finalizer,
    bytes32 _requestId
  ) public happyPath(_request, _response) {
    vm.assume(_requestId != _getId(_request));
    _response.requestId = _requestId;

    vm.expectRevert(IModule.Module_InvalidResponseBody.selector);
    eboFinalityModule.finalizeRequest(_request, _response, _finalizer);
  }

  function test_emitNewEpoch(
    IOracle.Request memory _request,
    IOracle.Response memory _response,
    address _finalizer
  ) public happyPath(_request, _response) {
    vm.skip(true);
    // vm.expectEmit();
    // emit NewEpoch(_response.epoch, _response.chainId, _response.block);
    eboFinalityModule.finalizeRequest(_request, _response, _finalizer);
  }

  function test_emitRequestFinalized(
    IOracle.Request memory _request,
    IOracle.Response memory _response,
    address _finalizer
  ) public happyPath(_request, _response) {
    vm.expectEmit();
    emit RequestFinalized(_response.requestId, _response, _finalizer);
    eboFinalityModule.finalizeRequest(_request, _response, _finalizer);
  }
}

contract EBOFinalityModule_Unit_AmendEpoch is EBOFinalityModule_Unit_BaseTest {
  function test_revertOnlyArbitrator(
    uint256 _epoch,
    uint256[] calldata _chainIds,
    uint256[] calldata _blockNumbers
  ) public {
    vm.expectRevert(IEBOFinalityModule.EBOFinalityModule_OnlyArbitrator.selector);
    eboFinalityModule.amendEpoch(_epoch, _chainIds, _blockNumbers);
  }

  function test_revertLengthMismatch(
    uint256 _epoch,
    uint256[] calldata _chainIds,
    uint256[] calldata _blockNumbers
  ) public {
    vm.assume(_chainIds.length != _blockNumbers.length);

    vm.prank(arbitrator);
    vm.expectRevert(IEBOFinalityModule.EBOFinalityModule_LengthMismatch.selector);
    eboFinalityModule.amendEpoch(_epoch, _chainIds, _blockNumbers);
  }

  function test_emitAmendEpoch(
    uint256 _epoch,
    uint256[FUZZED_ARRAY_LENGTH] calldata _chainIds,
    uint256[FUZZED_ARRAY_LENGTH] calldata _blockNumbers
  ) public {
    uint256[] memory _chainIds = _getDynamicArray(_chainIds);
    uint256[] memory _blockNumbers = _getDynamicArray(_blockNumbers);

    vm.prank(arbitrator);
    for (uint256 _i; _i < _chainIds.length; ++_i) {
      vm.expectEmit();
      emit AmendEpoch(_epoch, _chainIds[_i], _blockNumbers[_i]);
    }
    eboFinalityModule.amendEpoch(_epoch, _chainIds, _blockNumbers);
  }
}

contract EBOFinalityModule_Unit_SetEBORequestCreator is EBOFinalityModule_Unit_BaseTest {
  function test_revertOnlyArbitrator(address _eboRequestCreator) public {
    vm.expectRevert(IEBOFinalityModule.EBOFinalityModule_OnlyArbitrator.selector);
    eboFinalityModule.setEBORequestCreator(_eboRequestCreator);
  }

  function test_setEBORequestCreator(address _eboRequestCreator) public {
    vm.prank(arbitrator);
    eboFinalityModule.setEBORequestCreator(_eboRequestCreator);

    assertEq(eboFinalityModule.eboRequestCreator(), _eboRequestCreator);
  }
}

contract EBOFinalityModule_Unit_SetArbitrator is EBOFinalityModule_Unit_BaseTest {
  function test_revertOnlyArbitrator(address _arbitrator) public {
    vm.expectRevert(IEBOFinalityModule.EBOFinalityModule_OnlyArbitrator.selector);
    eboFinalityModule.setArbitrator(_arbitrator);
  }

  function test_setArbitrator(address _arbitrator) public {
    vm.prank(arbitrator);
    eboFinalityModule.setArbitrator(_arbitrator);

    assertEq(eboFinalityModule.arbitrator(), _arbitrator);
  }
}

contract EBOFinalityModule_Unit_ModuleName is EBOFinalityModule_Unit_BaseTest {
  function test_returnModuleName() public view {
    assertEq(eboFinalityModule.moduleName(), 'EBOFinalityModule');
  }
}
