// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.26;

import {IModule} from '@defi-wonderland/prophet-core/solidity/interfaces/IModule.sol';
import {IOracle} from '@defi-wonderland/prophet-core/solidity/interfaces/IOracle.sol';
import {ValidatorLib} from '@defi-wonderland/prophet-core/solidity/libraries/ValidatorLib.sol';
import {IAccountingExtension} from
  '@defi-wonderland/prophet-modules/solidity/interfaces/extensions/IAccountingExtension.sol';

import {EnumerableSet} from '@openzeppelin/contracts/utils/structs/EnumerableSet.sol';

import {IArbitrable} from 'interfaces/IArbitrable.sol';
import {IEBORequestCreator} from 'interfaces/IEBORequestCreator.sol';
import {IEBORequestModule} from 'interfaces/IEBORequestModule.sol';

import {EBORequestModule} from 'contracts/EBORequestModule.sol';

import 'forge-std/Test.sol';

contract EBORequestModuleForTest is EBORequestModule {
  using EnumerableSet for EnumerableSet.AddressSet;

  constructor(
    IOracle _oracle,
    IEBORequestCreator _eboRequestCreator,
    IArbitrable _arbitrable
  ) EBORequestModule(_oracle, _eboRequestCreator, _arbitrable) {}

  function addEBORequestCreatorForTest(IEBORequestCreator _eboRequestCreator) public {
    _eboRequestCreatorsAllowed.add(address(_eboRequestCreator));
  }
}

contract EBORequestModule_Unit_BaseTest is Test {
  EBORequestModuleForTest public eboRequestModule;

  IOracle public oracle;
  IEBORequestCreator public eboRequestCreator;
  IArbitrable public arbitrable;

  event AddEBORequestCreator(IEBORequestCreator indexed _eboRequestCreator);
  event RemoveEBORequestCreator(IEBORequestCreator indexed _eboRequestCreator);
  event RequestFinalized(bytes32 indexed _requestId, IOracle.Response _response, address _finalizer);

  function setUp() public {
    oracle = IOracle(makeAddr('Oracle'));
    eboRequestCreator = IEBORequestCreator(makeAddr('EBORequestCreator'));
    arbitrable = IArbitrable(makeAddr('Arbitrable'));

    eboRequestModule = new EBORequestModuleForTest(oracle, eboRequestCreator, arbitrable);
  }
}

contract EBORequestModule_Unit_Constructor is EBORequestModule_Unit_BaseTest {
  struct ConstructorParams {
    IOracle oracle;
    IEBORequestCreator eboRequestCreator;
    IArbitrable arbitrable;
  }

  function test_setOracle(ConstructorParams calldata _params) public {
    eboRequestModule = new EBORequestModuleForTest(_params.oracle, _params.eboRequestCreator, _params.arbitrable);

    assertEq(address(eboRequestModule.ORACLE()), address(_params.oracle));
  }

  function test_setArbitrable(ConstructorParams calldata _params) public {
    eboRequestModule = new EBORequestModuleForTest(_params.oracle, _params.eboRequestCreator, _params.arbitrable);

    assertEq(address(eboRequestModule.ARBITRABLE()), address(_params.arbitrable));
  }

  function test_addEBORequestCreator(ConstructorParams calldata _params) public {
    eboRequestModule = new EBORequestModuleForTest(_params.oracle, _params.eboRequestCreator, _params.arbitrable);

    assertEq(eboRequestModule.getAllowedEBORequestCreators()[0], address(_params.eboRequestCreator));
  }

  function test_emitAddEBORequestCreator(ConstructorParams calldata _params) public {
    vm.expectEmit();
    emit AddEBORequestCreator(_params.eboRequestCreator);
    new EBORequestModuleForTest(_params.oracle, _params.eboRequestCreator, _params.arbitrable);
  }
}

contract EBORequestModule_Unit_CreateRequest is EBORequestModule_Unit_BaseTest {
  struct CreateRequestParams {
    bytes32 requestId;
    IEBORequestModule.RequestParameters requestData;
    address requester;
  }

  modifier happyPath(CreateRequestParams memory _params) {
    _params.requester = address(eboRequestCreator);

    vm.startPrank(address(oracle));
    _;
  }

  function test_revertOnlyOracle(CreateRequestParams memory _params, address _caller) public happyPath(_params) {
    vm.assume(_caller != address(oracle));
    changePrank(_caller);

    bytes memory _encodedParams = abi.encode(_params.requestData);

    vm.expectRevert(IModule.Module_OnlyOracle.selector);
    eboRequestModule.createRequest(_params.requestId, _encodedParams, _params.requester);
  }

  function test_revertInvalidRequester(
    CreateRequestParams memory _params,
    address _requester
  ) public happyPath(_params) {
    vm.assume(_requester != address(eboRequestCreator));
    _params.requester = _requester;

    bytes memory _encodedParams = abi.encode(_params.requestData);

    vm.expectRevert(IEBORequestModule.EBORequestModule_InvalidRequester.selector);
    eboRequestModule.createRequest(_params.requestId, _encodedParams, _params.requester);
  }
}

contract EBORequestModule_Unit_FinalizeRequest is EBORequestModule_Unit_BaseTest {
  using ValidatorLib for IOracle.Request;
  using ValidatorLib for IOracle.Response;

  struct FinalizeRequestParams {
    IOracle.Request request;
    IOracle.Response response;
    address finalizer;
    uint128 responseCreatedAt;
    bool finalizeWithResponse;
  }

  modifier happyPath(FinalizeRequestParams memory _params) {
    _params.request.requester = address(eboRequestCreator);

    if (_params.finalizeWithResponse) {
      bytes32 _requestId = _params.request._getId();
      bytes32 _responseId = _params.response._getId();

      _params.response.requestId = _requestId;

      vm.assume(_params.responseCreatedAt != 0);
      vm.mockCall(
        address(oracle), abi.encodeCall(IOracle.responseCreatedAt, (_responseId)), abi.encode(_params.responseCreatedAt)
      );
    } else {
      _params.response.requestId = 0;
    }

    vm.startPrank(address(oracle));
    _;
  }

  function test_revertOnlyOracle(FinalizeRequestParams memory _params, address _caller) public happyPath(_params) {
    vm.assume(_caller != address(oracle));
    changePrank(_caller);

    vm.expectRevert(IModule.Module_OnlyOracle.selector);
    eboRequestModule.finalizeRequest(_params.request, _params.response, _params.finalizer);
  }

  function test_revertInvalidRequester(
    FinalizeRequestParams memory _params,
    address _requester
  ) public happyPath(_params) {
    vm.assume(_requester != address(eboRequestCreator));
    _params.request.requester = _requester;

    vm.expectRevert(IEBORequestModule.EBORequestModule_InvalidRequester.selector);
    eboRequestModule.finalizeRequest(_params.request, _params.response, _params.finalizer);
  }

  function test_emitRequestFinalized(FinalizeRequestParams memory _params) public happyPath(_params) {
    vm.expectEmit();
    emit RequestFinalized(_params.response.requestId, _params.response, _params.finalizer);
    eboRequestModule.finalizeRequest(_params.request, _params.response, _params.finalizer);
  }
}

contract EBORequestModule_Unit_SetEBORequestCreator is EBORequestModule_Unit_BaseTest {
  modifier happyPath(IEBORequestCreator _eboRequestCreator, address _arbitrator) {
    vm.assume(address(_eboRequestCreator) != address(eboRequestCreator));
    vm.mockCall(
      address(arbitrable),
      abi.encodeWithSelector(IArbitrable.validateArbitrator.selector, _arbitrator),
      abi.encode(true)
    );
    vm.startPrank(_arbitrator);
    _;
  }

  function test_addEBORequestCreator(
    IEBORequestCreator _eboRequestCreator,
    address _arbitrator
  ) public happyPath(_eboRequestCreator, _arbitrator) {
    eboRequestModule.addEBORequestCreator(_eboRequestCreator);

    assertEq(eboRequestModule.getAllowedEBORequestCreators()[1], address(_eboRequestCreator));
  }

  function test_emitAddEBORequestCreator(
    IEBORequestCreator _eboRequestCreator,
    address _arbitrator
  ) public happyPath(_eboRequestCreator, _arbitrator) {
    vm.expectEmit();
    emit AddEBORequestCreator(_eboRequestCreator);
    eboRequestModule.addEBORequestCreator(_eboRequestCreator);
  }
}

contract EBORequestModule_Unit_RemoveEBORequestCreator is EBORequestModule_Unit_BaseTest {
  modifier happyPath(IEBORequestCreator _eboRequestCreator, address _arbitrator) {
    vm.assume(address(_eboRequestCreator) != address(eboRequestCreator));

    eboRequestModule.addEBORequestCreatorForTest(_eboRequestCreator);
    vm.mockCall(
      address(arbitrable),
      abi.encodeWithSelector(IArbitrable.validateArbitrator.selector, _arbitrator),
      abi.encode(true)
    );
    vm.startPrank(_arbitrator);
    _;
  }

  function test_removeEBORequestCreator(
    IEBORequestCreator _eboRequestCreator,
    address _arbitrator
  ) public happyPath(_eboRequestCreator, _arbitrator) {
    eboRequestModule.removeEBORequestCreator(_eboRequestCreator);

    address[] memory _allowedEBORequestCreators = eboRequestModule.getAllowedEBORequestCreators();

    assertEq(_allowedEBORequestCreators.length, 1);
    assertEq(_allowedEBORequestCreators[0], address(eboRequestCreator));
    assertNotEq(_allowedEBORequestCreators[0], address(_eboRequestCreator));
  }

  function test_emitRemoveEBORequestCreator(
    IEBORequestCreator _eboRequestCreator,
    address _arbitrator
  ) public happyPath(_eboRequestCreator, _arbitrator) {
    vm.expectEmit();
    emit RemoveEBORequestCreator(_eboRequestCreator);
    eboRequestModule.removeEBORequestCreator(_eboRequestCreator);
  }
}

contract EBORequestModule_Unit_GetAllowedEBORequestCreators is EBORequestModule_Unit_BaseTest {
  function test_returnAllowedEBORequestCreators() public {
    assertEq(eboRequestModule.getAllowedEBORequestCreators()[0], address(eboRequestCreator));
    assertEq(eboRequestModule.getAllowedEBORequestCreators().length, 1);
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
    _params.chainId = '';

    bytes memory _encodedParams = abi.encode(_params);

    assertFalse(eboRequestModule.validateParameters(_encodedParams));
  }

  function test_returnInvalidAccountingExtensionParam(IEBORequestModule.RequestParameters memory _params) public view {
    vm.assume(_params.epoch != 0);
    vm.assume(bytes(_params.chainId).length != 0);
    _params.accountingExtension = IAccountingExtension(address(0));

    bytes memory _encodedParams = abi.encode(_params);

    assertFalse(eboRequestModule.validateParameters(_encodedParams));
  }

  function test_returnValidParams(IEBORequestModule.RequestParameters memory _params) public view {
    vm.assume(_params.epoch != 0);
    vm.assume(bytes(_params.chainId).length != 0);
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
