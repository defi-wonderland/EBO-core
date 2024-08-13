// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {IModule} from '@defi-wonderland/prophet-core/solidity/interfaces/IModule.sol';
import {IOracle} from '@defi-wonderland/prophet-core/solidity/interfaces/IOracle.sol';
import {IValidator} from '@defi-wonderland/prophet-core/solidity/interfaces/IValidator.sol';
import {ValidatorLib} from '@defi-wonderland/prophet-core/solidity/libraries/ValidatorLib.sol';
import {IAccountingExtension} from
  '@defi-wonderland/prophet-modules/solidity/interfaces/extensions/IAccountingExtension.sol';

import {IArbitrable} from 'interfaces/IArbitrable.sol';
import {IEBORequestModule} from 'interfaces/IEBORequestModule.sol';

import {EBORequestModule} from 'contracts/EBORequestModule.sol';

import 'forge-std/Test.sol';

contract EBORequestModule_Unit_BaseTest is Test {
  EBORequestModule public eboRequestModule;

  IOracle public oracle;
  address public eboRequestCreator;
  address public arbitrator;
  address public council;

  event SetEBORequestCreator(address _eboRequestCreator);
  event RequestFinalized(bytes32 indexed _requestId, IOracle.Response _response, address _finalizer);
  event SetArbitrator(address _arbitrator);
  event SetCouncil(address _council);

  function setUp() public {
    oracle = IOracle(makeAddr('Oracle'));
    eboRequestCreator = makeAddr('EBORequestCreator');
    arbitrator = makeAddr('Arbitrator');
    council = makeAddr('Council');

    eboRequestModule = new EBORequestModule(oracle, eboRequestCreator, arbitrator, council);
  }

  function _getId(IOracle.Request memory _request) internal pure returns (bytes32 _id) {
    _id = keccak256(abi.encode(_request));
  }

  function _getId(IOracle.Response memory _response) internal pure returns (bytes32 _id) {
    _id = keccak256(abi.encode(_response));
  }
}

contract EBORequestModule_Unit_Constructor is EBORequestModule_Unit_BaseTest {
  struct ConstructorParams {
    IOracle oracle;
    address eboRequestCreator;
    address arbitrator;
    address council;
  }

  function test_setOracle(ConstructorParams calldata _params) public {
    eboRequestModule =
      new EBORequestModule(_params.oracle, _params.eboRequestCreator, _params.arbitrator, _params.council);

    assertEq(address(eboRequestModule.ORACLE()), address(_params.oracle));
  }

  function test_setArbitrator(ConstructorParams calldata _params) public {
    eboRequestModule =
      new EBORequestModule(_params.oracle, _params.eboRequestCreator, _params.arbitrator, _params.council);

    assertEq(eboRequestModule.arbitrator(), _params.arbitrator);
  }

  function test_emitSetArbitrator(ConstructorParams calldata _params) public {
    vm.expectEmit();
    emit SetArbitrator(_params.arbitrator);
    new EBORequestModule(_params.oracle, _params.eboRequestCreator, _params.arbitrator, _params.council);
  }

  function test_setCouncil(ConstructorParams calldata _params) public {
    eboRequestModule =
      new EBORequestModule(_params.oracle, _params.eboRequestCreator, _params.arbitrator, _params.council);

    assertEq(eboRequestModule.council(), _params.council);
  }

  function test_emitSetCouncil(ConstructorParams calldata _params) public {
    vm.expectEmit();
    emit SetCouncil(_params.council);
    new EBORequestModule(_params.oracle, _params.eboRequestCreator, _params.arbitrator, _params.council);
  }

  function test_setEBORequestCreator(ConstructorParams calldata _params) public {
    eboRequestModule =
      new EBORequestModule(_params.oracle, _params.eboRequestCreator, _params.arbitrator, _params.council);

    assertEq(eboRequestModule.eboRequestCreator(), _params.eboRequestCreator);
  }

  function test_emitSetEBORequestCreator(ConstructorParams calldata _params) public {
    vm.expectEmit();
    emit SetEBORequestCreator(_params.eboRequestCreator);
    new EBORequestModule(_params.oracle, _params.eboRequestCreator, _params.arbitrator, _params.council);
  }
}

contract EBORequestModule_Unit_CreateRequest is EBORequestModule_Unit_BaseTest {
  struct CreateRequestParams {
    bytes32 requestId;
    IEBORequestModule.RequestParameters requestData;
    address requester;
  }

  modifier happyPath(CreateRequestParams memory _params) {
    _params.requester = eboRequestCreator;

    vm.startPrank(address(oracle));
    _;
  }

  function test_revertOnlyOracle(CreateRequestParams memory _params) public happyPath(_params) {
    vm.stopPrank();

    bytes memory _encodedParams = abi.encode(_params.requestData);

    vm.expectRevert(IModule.Module_OnlyOracle.selector);
    eboRequestModule.createRequest(_params.requestId, _encodedParams, _params.requester);
  }

  function test_revertInvalidRequester(
    CreateRequestParams memory _params,
    address _requester
  ) public happyPath(_params) {
    vm.assume(_requester != eboRequestCreator);
    _params.requester = _requester;

    bytes memory _encodedParams = abi.encode(_params.requestData);

    vm.expectRevert(IEBORequestModule.EBORequestModule_InvalidRequester.selector);
    eboRequestModule.createRequest(_params.requestId, _encodedParams, _params.requester);
  }
}

contract EBORequestModule_Unit_FinalizeRequest is EBORequestModule_Unit_BaseTest {
  struct FinalizeRequestParams {
    IOracle.Request request;
    IOracle.Response response;
    address finalizer;
    uint128 responseCreatedAt;
    bool finalizeWithResponse;
  }

  modifier happyPath(FinalizeRequestParams memory _params) {
    _params.request.requester = eboRequestCreator;

    if (_params.finalizeWithResponse) {
      _params.response.requestId = _getId(_params.request);

      vm.assume(_params.responseCreatedAt != 0);
      vm.mockCall(
        address(oracle),
        abi.encodeCall(IOracle.responseCreatedAt, (_getId(_params.response))),
        abi.encode(_params.responseCreatedAt)
      );
    } else {
      _params.response.requestId = 0;
    }

    vm.startPrank(address(oracle));
    _;
  }

  function test_revertOnlyOracle(FinalizeRequestParams memory _params) public happyPath(_params) {
    vm.stopPrank();
    vm.expectRevert(IModule.Module_OnlyOracle.selector);
    eboRequestModule.finalizeRequest(_params.request, _params.response, _params.finalizer);
  }

  function test_revertInvalidRequester(
    FinalizeRequestParams memory _params,
    address _requester
  ) public happyPath(_params) {
    vm.assume(_requester != eboRequestCreator);
    _params.request.requester = _requester;

    vm.expectRevert(IEBORequestModule.EBORequestModule_InvalidRequester.selector);
    eboRequestModule.finalizeRequest(_params.request, _params.response, _params.finalizer);
  }

  function test_revertInvalidResponseBody(
    FinalizeRequestParams memory _params,
    bytes32 _requestId
  ) public happyPath(_params) {
    vm.assume(_params.finalizeWithResponse);
    vm.assume(_requestId != 0);
    vm.assume(_requestId != _getId(_params.request));
    _params.response.requestId = _requestId;

    vm.expectRevert(ValidatorLib.ValidatorLib_InvalidResponseBody.selector);
    eboRequestModule.finalizeRequest(_params.request, _params.response, _params.finalizer);
  }

  function test_revertInvalidResponse(FinalizeRequestParams memory _params) public happyPath(_params) {
    vm.assume(_params.finalizeWithResponse);
    vm.mockCall(address(oracle), abi.encodeCall(IOracle.responseCreatedAt, (_getId(_params.response))), abi.encode(0));

    vm.expectRevert(IValidator.Validator_InvalidResponse.selector);
    eboRequestModule.finalizeRequest(_params.request, _params.response, _params.finalizer);
  }

  function test_emitRequestFinalized(FinalizeRequestParams memory _params) public happyPath(_params) {
    vm.expectEmit();
    emit RequestFinalized(_params.response.requestId, _params.response, _params.finalizer);
    eboRequestModule.finalizeRequest(_params.request, _params.response, _params.finalizer);
  }
}

contract EBORequestModule_Unit_SetEBORequestCreator is EBORequestModule_Unit_BaseTest {
  modifier happyPath() {
    vm.startPrank(arbitrator);
    _;
  }

  function test_revertOnlyArbitrator(address _eboRequestCreator) public happyPath {
    vm.stopPrank();
    vm.expectRevert(IArbitrable.Arbitrable_OnlyArbitrator.selector);
    eboRequestModule.setEBORequestCreator(_eboRequestCreator);
  }

  function test_setEBORequestCreator(address _eboRequestCreator) public happyPath {
    eboRequestModule.setEBORequestCreator(_eboRequestCreator);

    assertEq(eboRequestModule.eboRequestCreator(), _eboRequestCreator);
  }

  function test_emitSetEBORequestCreator(address _eboRequestCreator) public happyPath {
    vm.expectEmit();
    emit SetEBORequestCreator(_eboRequestCreator);
    eboRequestModule.setEBORequestCreator(_eboRequestCreator);
  }
}

contract EBORequestModule_Unit_ValidateParameters is EBORequestModule_Unit_BaseTest {
  function test_returnInvalidEpochParam(IEBORequestModule.RequestParameters memory _params) public view {
    _params.epoch = 0;

    bytes memory _encodedParams = abi.encode(_params);

    assertFalse(eboRequestModule.validateParameters(_encodedParams));
  }

  function test_returnInvalidChainIdParam(IEBORequestModule.RequestParameters memory _params) public view {
    vm.assume(_params.epoch != 0);
    _params.chainId = 0;

    bytes memory _encodedParams = abi.encode(_params);

    assertFalse(eboRequestModule.validateParameters(_encodedParams));
  }

  function test_returnInvalidAccountingExtensionParam(IEBORequestModule.RequestParameters memory _params) public view {
    vm.assume(_params.epoch != 0);
    vm.assume(_params.chainId != 0);
    _params.accountingExtension = IAccountingExtension(address(0));

    bytes memory _encodedParams = abi.encode(_params);

    assertFalse(eboRequestModule.validateParameters(_encodedParams));
  }

  function test_returnValidParams(IEBORequestModule.RequestParameters memory _params) public view {
    vm.assume(_params.epoch != 0);
    vm.assume(_params.chainId != 0);
    vm.assume(address(_params.accountingExtension) != address(0));

    bytes memory _encodedParams = abi.encode(_params);

    assertTrue(eboRequestModule.validateParameters(_encodedParams));
  }
}

contract EBORequestModule_Unit_ModuleName is EBORequestModule_Unit_BaseTest {
  function test_returnModuleName() public view {
    assertEq(eboRequestModule.moduleName(), 'EBORequestModule');
  }
}

contract EBORequestModule_Unit_DecodeRequestData is EBORequestModule_Unit_BaseTest {
  function test_returnDecodedParams(IEBORequestModule.RequestParameters calldata _params) public view {
    bytes memory _encodedParams = abi.encode(_params);
    IEBORequestModule.RequestParameters memory _decodedParams = eboRequestModule.decodeRequestData(_encodedParams);

    assertEq(abi.encode(_decodedParams), abi.encode(_params));
  }
}
