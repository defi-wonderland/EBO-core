// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.26;

import {ValidatorLib} from '@defi-wonderland/prophet-core/solidity/libraries/ValidatorLib.sol';
import {EnumerableSet} from '@openzeppelin/contracts/utils/structs/EnumerableSet.sol';

import {IAccountingExtension} from
  '@defi-wonderland/prophet-modules/solidity/interfaces/extensions/IAccountingExtension.sol';

import {
  EBOFinalityModule,
  IArbitrable,
  IEBOFinalityModule,
  IEBORequestCreator,
  IEBORequestModule,
  IModule,
  IOracle
} from 'contracts/EBOFinalityModule.sol';

import 'forge-std/Test.sol';

contract EBOFinalityModuleForTest is EBOFinalityModule {
  using EnumerableSet for EnumerableSet.AddressSet;

  constructor(
    IOracle _oracle,
    IEBORequestCreator _eboRequestCreator,
    IArbitrable _arbitrable
  ) EBOFinalityModule(_oracle, _eboRequestCreator, _arbitrable) {}

  function addEBORequestCreatorForTest(IEBORequestCreator _eboRequestCreator) public {
    _eboRequestCreatorsAllowed.add(address(_eboRequestCreator));
  }
}

contract EBOFinalityModule_Unit_BaseTest is Test {
  EBOFinalityModuleForTest public eboFinalityModule;

  IOracle public oracle;
  IEBORequestCreator public eboRequestCreator;
  IArbitrable public arbitrable;

  uint256 public constant FUZZED_ARRAY_LENGTH = 32;

  event NewEpoch(uint256 indexed _epoch, string indexed _chainId, uint256 _blockNumber);
  event AmendEpoch(uint256 indexed _epoch, string indexed _chainId, uint256 _blockNumber);
  event AddEBORequestCreator(IEBORequestCreator indexed _eboRequestCreator);
  event RemoveEBORequestCreator(IEBORequestCreator indexed _eboRequestCreator);
  event RequestFinalized(bytes32 indexed _requestId, IOracle.Response _response, address _finalizer);

  function setUp() public {
    oracle = IOracle(makeAddr('Oracle'));
    eboRequestCreator = IEBORequestCreator(makeAddr('EBORequestCreator'));
    arbitrable = IArbitrable(makeAddr('Arbitrable'));

    eboFinalityModule = new EBOFinalityModuleForTest(oracle, eboRequestCreator, arbitrable);
  }

  function _getDynamicArray(string[FUZZED_ARRAY_LENGTH] calldata _staticArray)
    internal
    pure
    returns (string[] memory _dynamicArray)
  {
    _dynamicArray = new string[](FUZZED_ARRAY_LENGTH);
    for (uint256 _i; _i < FUZZED_ARRAY_LENGTH; ++_i) {
      _dynamicArray[_i] = _staticArray[_i];
    }
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
  struct ConstructorParams {
    IOracle oracle;
    IEBORequestCreator eboRequestCreator;
    IArbitrable arbitrable;
  }

  function test_setOracle(ConstructorParams calldata _params) public {
    eboFinalityModule = new EBOFinalityModuleForTest(_params.oracle, _params.eboRequestCreator, _params.arbitrable);

    assertEq(address(eboFinalityModule.ORACLE()), address(_params.oracle));
  }

  function test_addEBORequestCreator(ConstructorParams calldata _params) public {
    eboFinalityModule = new EBOFinalityModuleForTest(_params.oracle, _params.eboRequestCreator, _params.arbitrable);

    assertEq(eboFinalityModule.getAllowedEBORequestCreators()[0], address(_params.eboRequestCreator));
  }

  function test_setArbitrable(ConstructorParams calldata _params) public {
    eboFinalityModule = new EBOFinalityModuleForTest(_params.oracle, _params.eboRequestCreator, _params.arbitrable);

    assertEq(address(eboFinalityModule.ARBITRABLE()), address(_params.arbitrable));
  }

  function test_emitAddEBORequestCreator(ConstructorParams calldata _params) public {
    vm.expectEmit();
    emit AddEBORequestCreator(_params.eboRequestCreator);
    new EBOFinalityModuleForTest(_params.oracle, _params.eboRequestCreator, _params.arbitrable);
  }
}

contract EBOFinalityModule_Unit_FinalizeRequest is EBOFinalityModule_Unit_BaseTest {
  using ValidatorLib for IOracle.Request;
  using ValidatorLib for IOracle.Response;

  struct FinalizeRequestParams {
    IOracle.Request request;
    IOracle.Response response;
    address finalizer;
    uint128 responseCreatedAt;
    bool finalizeWithResponse;
    IEBORequestModule.RequestParameters requestParams;
    IEBOFinalityModule.ResponseParameters responseParams;
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

      _params.response.response = abi.encode(_params.responseParams);
      _params.request.requestModuleData = abi.encode(_params.requestParams);
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
    eboFinalityModule.finalizeRequest(_params.request, _params.response, _params.finalizer);
  }

  function test_revertInvalidRequester(
    FinalizeRequestParams memory _params,
    address _requester
  ) public happyPath(_params) {
    vm.assume(_requester != address(eboRequestCreator));
    _params.request.requester = _requester;

    vm.expectRevert(IEBOFinalityModule.EBOFinalityModule_InvalidRequester.selector);
    eboFinalityModule.finalizeRequest(_params.request, _params.response, _params.finalizer);
  }

  function test_emitNewEpoch(FinalizeRequestParams memory _params) public happyPath(_params) {
    vm.assume(_params.finalizeWithResponse);
    IEBORequestModule.RequestParameters memory _requestParams =
      abi.decode(_params.request.requestModuleData, (IEBORequestModule.RequestParameters));

    IEBOFinalityModule.ResponseParameters memory _responseParams =
      abi.decode(_params.response.response, (IEBOFinalityModule.ResponseParameters));

    vm.expectEmit();
    emit NewEpoch(_requestParams.epoch, _requestParams.chainId, _responseParams.block);
    eboFinalityModule.finalizeRequest(_params.request, _params.response, _params.finalizer);
  }

  function test_emitRequestFinalizedWithResponse(FinalizeRequestParams memory _params) public happyPath(_params) {
    vm.assume(_params.finalizeWithResponse);

    vm.expectEmit();
    emit RequestFinalized(_params.response.requestId, _params.response, _params.finalizer);
    eboFinalityModule.finalizeRequest(_params.request, _params.response, _params.finalizer);
  }

  function test_emitRequestFinalizedWithNoResponse(FinalizeRequestParams memory _params) public happyPath(_params) {
    vm.assume(!_params.finalizeWithResponse);

    vm.expectEmit();
    emit RequestFinalized(_params.response.requestId, _params.response, _params.finalizer);
    eboFinalityModule.finalizeRequest(_params.request, _params.response, _params.finalizer);
  }
}

contract EBOFinalityModule_Unit_AmendEpoch is EBOFinalityModule_Unit_BaseTest {
  struct AmendEpochParams {
    uint256 epoch;
    string[FUZZED_ARRAY_LENGTH] chainIds;
    uint256[FUZZED_ARRAY_LENGTH] blockNumbers;
  }

  modifier happyPath(address _arbitrator) {
    vm.mockCall(
      address(arbitrable),
      abi.encodeWithSelector(IArbitrable.validateArbitrator.selector, _arbitrator),
      abi.encode(true)
    );
    vm.startPrank(_arbitrator);
    _;
  }

  function test_revertLengthMismatch(
    AmendEpochParams calldata _params,
    string[] calldata _chainIds,
    uint256[] calldata _blockNumbers,
    address _arbitrator
  ) public happyPath(_arbitrator) {
    vm.assume(_chainIds.length != _blockNumbers.length);

    vm.expectRevert(IEBOFinalityModule.EBOFinalityModule_LengthMismatch.selector);
    eboFinalityModule.amendEpoch(_params.epoch, _chainIds, _blockNumbers);
  }

  function test_emitAmendEpoch(AmendEpochParams calldata _params, address _arbitrator) public happyPath(_arbitrator) {
    string[] memory _chainIds = _getDynamicArray(_params.chainIds);
    uint256[] memory _blockNumbers = _getDynamicArray(_params.blockNumbers);

    for (uint256 _i; _i < _chainIds.length; ++_i) {
      vm.expectEmit();
      emit AmendEpoch(_params.epoch, _chainIds[_i], _blockNumbers[_i]);
    }
    eboFinalityModule.amendEpoch(_params.epoch, _chainIds, _blockNumbers);
  }
}

contract EBOFinalityModule_Unit_addEBORequestCreator is EBOFinalityModule_Unit_BaseTest {
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
    eboFinalityModule.addEBORequestCreator(_eboRequestCreator);

    address[] memory _allowedEBORequestCreators = eboFinalityModule.getAllowedEBORequestCreators();
    assertEq(_allowedEBORequestCreators[1], address(_eboRequestCreator));
    assertEq(_allowedEBORequestCreators.length, 2);
  }

  function test_emitAddEBORequestCreator(
    IEBORequestCreator _eboRequestCreator,
    address _arbitrator
  ) public happyPath(_eboRequestCreator, _arbitrator) {
    vm.expectEmit();
    emit AddEBORequestCreator(_eboRequestCreator);
    eboFinalityModule.addEBORequestCreator(_eboRequestCreator);
  }
}

contract EBOFinalityModule_Unit_RemoveEBORequestCreator is EBOFinalityModule_Unit_BaseTest {
  modifier happyPath(IEBORequestCreator _eboRequestCreator, address _arbitrator) {
    vm.assume(address(_eboRequestCreator) != address(eboRequestCreator));
    vm.mockCall(
      address(arbitrable),
      abi.encodeWithSelector(IArbitrable.validateArbitrator.selector, _arbitrator),
      abi.encode(true)
    );

    eboFinalityModule.addEBORequestCreatorForTest(_eboRequestCreator);
    vm.startPrank(_arbitrator);
    _;
  }

  function test_removeEBORequestCreator(
    IEBORequestCreator _eboRequestCreator,
    address _arbitrator
  ) public happyPath(_eboRequestCreator, _arbitrator) {
    eboFinalityModule.removeEBORequestCreator(_eboRequestCreator);

    address[] memory _allowedEBORequestCreators = eboFinalityModule.getAllowedEBORequestCreators();

    assertEq(_allowedEBORequestCreators.length, 1);

    for (uint256 _i; _i < _allowedEBORequestCreators.length; ++_i) {
      assertNotEq(_allowedEBORequestCreators[_i], address(_eboRequestCreator));
    }
  }

  function test_emitRemoveEBORequestCreator(
    IEBORequestCreator _eboRequestCreator,
    address _arbitrator
  ) public happyPath(_eboRequestCreator, _arbitrator) {
    vm.expectEmit();
    emit RemoveEBORequestCreator(_eboRequestCreator);
    eboFinalityModule.removeEBORequestCreator(_eboRequestCreator);
  }
}

contract EBOFinalityModule_Unit_ModuleName is EBOFinalityModule_Unit_BaseTest {
  function test_returnModuleName() public view {
    assertEq(eboFinalityModule.moduleName(), 'EBOFinalityModule');
  }
}

contract EBOFinalityModule_Unit_DecodeRequestData is EBOFinalityModule_Unit_BaseTest {
  function test_decodeRequestData(uint256 _epoch, string memory _chainId) public view {
    bytes memory _data =
      abi.encode(IEBORequestModule.RequestParameters(_epoch, _chainId, IAccountingExtension(address(0)), 0));

    IEBORequestModule.RequestParameters memory _params = eboFinalityModule.decodeRequestData(_data);

    assertEq(_params.epoch, _epoch);
    assertEq(_params.chainId, _chainId);
  }
}

contract EBOFinalityModule_Unit_DecodeResponseData is EBOFinalityModule_Unit_BaseTest {
  function test_decodeResponseData(uint256 _block) public view {
    bytes memory _data = abi.encode(IEBOFinalityModule.ResponseParameters(_block));

    IEBOFinalityModule.ResponseParameters memory _params = eboFinalityModule.decodeResponseData(_data);

    assertEq(_params.block, _block);
  }
}
