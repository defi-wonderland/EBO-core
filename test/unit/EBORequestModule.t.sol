// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {IModule} from '@defi-wonderland/prophet-core/solidity/interfaces/IModule.sol';
import {IOracle} from '@defi-wonderland/prophet-core/solidity/interfaces/IOracle.sol';

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

  uint256 public constant FUZZED_ARRAY_LENGTH = 32;

  event RequestCreated(bytes32 _requestId, bytes _data, address _requester);
  event SetEBORequestCreator(address _eboRequestCreator);
  // TODO: event RequestFinalized(bytes32 indexed _requestId, IOracle.Response _response, address _finalizer);
  event SetArbitrator(address _arbitrator);
  event SetCouncil(address _council);

  function setUp() public {
    oracle = IOracle(makeAddr('Oracle'));
    eboRequestCreator = makeAddr('EBORequestCreator');
    arbitrator = makeAddr('Arbitrator');
    council = makeAddr('Council');

    eboRequestModule = new EBORequestModule(oracle, eboRequestCreator, arbitrator, council);
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

  function test_emitRequestCreated(CreateRequestParams memory _params) public happyPath(_params) {
    bytes memory _encodedParams = abi.encode(_params.requestData);

    vm.expectEmit();
    emit RequestCreated(_params.requestId, _encodedParams, _params.requester);
    eboRequestModule.createRequest(_params.requestId, _encodedParams, _params.requester);
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
  function test_returnInvalidParams(IEBORequestModule.RequestParameters memory _params) public view {
    bytes memory _encodedParams = abi.encode(_params);

    assertFalse(eboRequestModule.validateParameters(_encodedParams));
  }

  function test_returnValidParams(IEBORequestModule.RequestParameters memory _params) public view {
    bytes memory _encodedParams = abi.encode(_params);

    // TODO: assertTrue(eboRequestModule.validateParameters(_encodedParams));
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
