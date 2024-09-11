// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.26;

import {IModule} from '@defi-wonderland/prophet-core/solidity/interfaces/IModule.sol';
import {IOracle} from '@defi-wonderland/prophet-core/solidity/interfaces/IOracle.sol';
import {ValidatorLib} from '@defi-wonderland/prophet-core/solidity/libraries/ValidatorLib.sol';

import {IArbitrable} from 'interfaces/IArbitrable.sol';
import {IEBOFinalityModule} from 'interfaces/IEBOFinalityModule.sol';
import {IEBORequestCreator} from 'interfaces/IEBORequestCreator.sol';

import {EBOFinalityModule} from 'contracts/EBOFinalityModule.sol';

import 'forge-std/Test.sol';

contract EBOFinalityModule_Unit_BaseTest is Test {
  EBOFinalityModule public eboFinalityModule;

  IOracle public oracle;
  IEBORequestCreator public eboRequestCreator;
  address public arbitrator;
  address public council;

  uint256 public constant FUZZED_ARRAY_LENGTH = 32;

  event NewEpoch(uint256 indexed _epoch, string indexed _chainId, uint256 _blockNumber);
  event AmendEpoch(uint256 indexed _epoch, string indexed _chainId, uint256 _blockNumber);
  event SetEBORequestCreator(IEBORequestCreator indexed _eboRequestCreator);
  event RequestFinalized(bytes32 indexed _requestId, IOracle.Response _response, address _finalizer);
  event SetArbitrator(address indexed _arbitrator);
  event SetCouncil(address indexed _council);

  function setUp() public {
    oracle = IOracle(makeAddr('Oracle'));
    eboRequestCreator = IEBORequestCreator(makeAddr('EBORequestCreator'));
    arbitrator = makeAddr('Arbitrator');
    council = makeAddr('Council');

    eboFinalityModule = new EBOFinalityModule(oracle, eboRequestCreator, arbitrator, council);
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
    address arbitrator;
    address council;
  }

  function test_setOracle(ConstructorParams calldata _params) public {
    eboFinalityModule =
      new EBOFinalityModule(_params.oracle, _params.eboRequestCreator, _params.arbitrator, _params.council);

    assertEq(address(eboFinalityModule.ORACLE()), address(_params.oracle));
  }

  function test_setArbitrator(ConstructorParams calldata _params) public {
    eboFinalityModule =
      new EBOFinalityModule(_params.oracle, _params.eboRequestCreator, _params.arbitrator, _params.council);

    assertEq(eboFinalityModule.arbitrator(), _params.arbitrator);
  }

  function test_emitSetArbitrator(ConstructorParams calldata _params) public {
    vm.expectEmit();
    emit SetArbitrator(_params.arbitrator);
    new EBOFinalityModule(_params.oracle, _params.eboRequestCreator, _params.arbitrator, _params.council);
  }

  function test_setCouncil(ConstructorParams calldata _params) public {
    eboFinalityModule =
      new EBOFinalityModule(_params.oracle, _params.eboRequestCreator, _params.arbitrator, _params.council);

    assertEq(eboFinalityModule.council(), _params.council);
  }

  function test_emitSetCouncil(ConstructorParams calldata _params) public {
    vm.expectEmit();
    emit SetCouncil(_params.council);
    new EBOFinalityModule(_params.oracle, _params.eboRequestCreator, _params.arbitrator, _params.council);
  }

  function test_setEBORequestCreator(ConstructorParams calldata _params) public {
    eboFinalityModule =
      new EBOFinalityModule(_params.oracle, _params.eboRequestCreator, _params.arbitrator, _params.council);

    assertEq(address(eboFinalityModule.eboRequestCreator()), address(_params.eboRequestCreator));
  }

  function test_emitSetEBORequestCreator(ConstructorParams calldata _params) public {
    vm.expectEmit();
    emit SetEBORequestCreator(_params.eboRequestCreator);
    new EBOFinalityModule(_params.oracle, _params.eboRequestCreator, _params.arbitrator, _params.council);
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

    vm.skip(true);
    // vm.expectEmit();
    // emit NewEpoch(_params.response.epoch, _params.response.chainId, _params.response.block);
    eboFinalityModule.finalizeRequest(_params.request, _params.response, _params.finalizer);
  }

  function test_emitRequestFinalized(FinalizeRequestParams memory _params) public happyPath(_params) {
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

  modifier happyPath() {
    vm.startPrank(arbitrator);
    _;
  }

  function test_revertOnlyArbitrator(AmendEpochParams calldata _params, address _caller) public happyPath {
    vm.assume(_caller != arbitrator);
    changePrank(_caller);

    string[] memory _chainIds = _getDynamicArray(_params.chainIds);
    uint256[] memory _blockNumbers = _getDynamicArray(_params.blockNumbers);

    vm.expectRevert(IArbitrable.Arbitrable_OnlyArbitrator.selector);
    eboFinalityModule.amendEpoch(_params.epoch, _chainIds, _blockNumbers);
  }

  function test_revertLengthMismatch(
    AmendEpochParams calldata _params,
    string[] calldata _chainIds,
    uint256[] calldata _blockNumbers
  ) public happyPath {
    vm.assume(_chainIds.length != _blockNumbers.length);

    vm.expectRevert(IEBOFinalityModule.EBOFinalityModule_LengthMismatch.selector);
    eboFinalityModule.amendEpoch(_params.epoch, _chainIds, _blockNumbers);
  }

  function test_emitAmendEpoch(AmendEpochParams calldata _params) public happyPath {
    string[] memory _chainIds = _getDynamicArray(_params.chainIds);
    uint256[] memory _blockNumbers = _getDynamicArray(_params.blockNumbers);

    for (uint256 _i; _i < _chainIds.length; ++_i) {
      vm.expectEmit();
      emit AmendEpoch(_params.epoch, _chainIds[_i], _blockNumbers[_i]);
    }
    eboFinalityModule.amendEpoch(_params.epoch, _chainIds, _blockNumbers);
  }
}

contract EBOFinalityModule_Unit_SetEBORequestCreator is EBOFinalityModule_Unit_BaseTest {
  modifier happyPath() {
    vm.startPrank(arbitrator);
    _;
  }

  function test_revertOnlyArbitrator(IEBORequestCreator _eboRequestCreator, address _caller) public happyPath {
    vm.assume(_caller != arbitrator);
    changePrank(_caller);

    vm.expectRevert(IArbitrable.Arbitrable_OnlyArbitrator.selector);
    eboFinalityModule.setEBORequestCreator(_eboRequestCreator);
  }

  function test_setEBORequestCreator(IEBORequestCreator _eboRequestCreator) public happyPath {
    eboFinalityModule.setEBORequestCreator(_eboRequestCreator);

    assertEq(address(eboFinalityModule.eboRequestCreator()), address(_eboRequestCreator));
  }

  function test_emitSetEBORequestCreator(IEBORequestCreator _eboRequestCreator) public happyPath {
    vm.expectEmit();
    emit SetEBORequestCreator(_eboRequestCreator);
    eboFinalityModule.setEBORequestCreator(_eboRequestCreator);
  }
}

contract EBOFinalityModule_Unit_ModuleName is EBOFinalityModule_Unit_BaseTest {
  function test_returnModuleName() public view {
    assertEq(eboFinalityModule.moduleName(), 'EBOFinalityModule');
  }
}
