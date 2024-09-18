// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.26;

import {IOracle} from '@defi-wonderland/prophet-core/solidity/interfaces/IOracle.sol';
import {IValidator} from '@defi-wonderland/prophet-core/solidity/interfaces/IValidator.sol';
import {ValidatorLib} from '@defi-wonderland/prophet-core/solidity/libraries/ValidatorLib.sol';
import {IArbitrator} from '@defi-wonderland/prophet-modules/solidity/interfaces/IArbitrator.sol';
import {IArbitratorModule} from
  '@defi-wonderland/prophet-modules/solidity/interfaces/modules/resolution/IArbitratorModule.sol';

import {Helpers} from 'test/utils/Helpers.sol';

import {IArbitrable} from 'interfaces/IArbitrable.sol';
import {ICouncilArbitrator} from 'interfaces/ICouncilArbitrator.sol';

import {CouncilArbitrator} from 'contracts/CouncilArbitrator.sol';

import 'forge-std/Test.sol';

contract MockCouncilArbitrator is CouncilArbitrator {
  constructor(
    IArbitratorModule _arbitratorModule,
    IArbitrable _arbitrable
  ) CouncilArbitrator(_arbitratorModule, _arbitrable) {}

  // solhint-disable-next-line no-empty-blocks
  function mock_onlyArbitratorModule() external onlyArbitratorModule {}

  function mock_setResolutions(
    bytes32 _disputeId,
    ICouncilArbitrator.ResolutionParameters calldata _resolutionParams
  ) external {
    resolutions[_disputeId] = _resolutionParams;
  }
}

contract CouncilArbitrator_Unit_BaseTest is Test, Helpers {
  using stdStorage for StdStorage;

  MockCouncilArbitrator public councilArbitrator;

  IOracle public oracle;
  IArbitratorModule public arbitratorModule;
  IArbitrable public arbitrable;

  event ResolutionStarted(
    bytes32 indexed _disputeId, IOracle.Request _request, IOracle.Response _response, IOracle.Dispute _dispute
  );
  event DisputeArbitrated(bytes32 indexed _disputeId, IOracle.DisputeStatus _award);

  function setUp() public {
    oracle = IOracle(makeAddr('Oracle'));
    vm.etch(address(oracle), '0x0');
    arbitrable = IArbitrable(makeAddr('Arbitrable'));
    vm.etch(address(arbitrable), '0x0');
    arbitratorModule = IArbitratorModule(makeAddr('ArbitratorModule'));

    vm.mockCall(address(arbitratorModule), abi.encodeCall(IValidator.ORACLE, ()), abi.encode(oracle));

    councilArbitrator = new MockCouncilArbitrator(arbitratorModule, arbitrable);
  }

  function _mockGetAnswer(bytes32 _disputeId, IOracle.DisputeStatus _status) internal {
    stdstore.target(address(councilArbitrator)).sig(IArbitrator.getAnswer.selector).with_key(_disputeId).checked_write(
      uint8(_status)
    );
  }
}

contract CouncilArbitrator_Unit_Constructor is CouncilArbitrator_Unit_BaseTest {
  struct ConstructorParams {
    IArbitratorModule arbitratorModule;
    IArbitrable arbitrable;
    IOracle oracle;
  }

  modifier happyPath(ConstructorParams calldata _params) {
    assumeNotForgeAddress(address(_params.arbitratorModule));
    vm.mockCall(address(_params.arbitratorModule), abi.encodeCall(IValidator.ORACLE, ()), abi.encode(_params.oracle));
    _;
  }

  function test_setOracle(ConstructorParams calldata _params) public happyPath(_params) {
    councilArbitrator = new MockCouncilArbitrator(_params.arbitratorModule, _params.arbitrable);

    assertEq(address(councilArbitrator.ORACLE()), address(_params.oracle));
  }

  function test_setArbitratorModule(ConstructorParams calldata _params) public happyPath(_params) {
    councilArbitrator = new MockCouncilArbitrator(_params.arbitratorModule, _params.arbitrable);

    assertEq(address(councilArbitrator.ARBITRATOR_MODULE()), address(_params.arbitratorModule));
  }

  function test_setArbitrable(ConstructorParams calldata _params) public happyPath(_params) {
    councilArbitrator = new MockCouncilArbitrator(_params.arbitratorModule, _params.arbitrable);

    assertEq(address(councilArbitrator.ARBITRABLE()), address(_params.arbitrable));
  }
}

contract CouncilArbitrator_Unit_Resolve is CouncilArbitrator_Unit_BaseTest {
  using ValidatorLib for IOracle.Dispute;

  modifier happyPath() {
    vm.startPrank(address(arbitratorModule));
    _;
  }

  function test_revertOnlyArbitratorModule(
    ICouncilArbitrator.ResolutionParameters calldata _params,
    address _caller
  ) public happyPath {
    vm.assume(_caller != address(arbitratorModule));
    changePrank(_caller);

    vm.expectRevert(ICouncilArbitrator.CouncilArbitrator_OnlyArbitratorModule.selector);
    councilArbitrator.resolve(_params.request, _params.response, _params.dispute);
  }

  function test_setResolutions(ICouncilArbitrator.ResolutionParameters calldata _params) public happyPath {
    councilArbitrator.resolve(_params.request, _params.response, _params.dispute);

    bytes32 _disputeId = _params.dispute._getId();
    (IOracle.Request memory _request, IOracle.Response memory _response, IOracle.Dispute memory _dispute) =
      councilArbitrator.resolutions(_disputeId);

    assertEq(abi.encode(_request), abi.encode(_params.request));
    assertEq(abi.encode(_response), abi.encode(_params.response));
    assertEq(abi.encode(_dispute), abi.encode(_params.dispute));
  }

  function test_emitResolutionStarted(ICouncilArbitrator.ResolutionParameters calldata _params) public happyPath {
    bytes32 _disputeId = _params.dispute._getId();

    vm.expectEmit();
    emit ResolutionStarted(_disputeId, _params.request, _params.response, _params.dispute);
    councilArbitrator.resolve(_params.request, _params.response, _params.dispute);
  }
}

contract CouncilArbitrator_Unit_ArbitrateDispute is CouncilArbitrator_Unit_BaseTest {
  struct ArbitrateDisputeParams {
    bytes32 disputeId;
    uint8 award;
    address arbitrator;
    ICouncilArbitrator.ResolutionParameters resolutionParams;
  }

  modifier happyPath(ArbitrateDisputeParams memory _params) {
    vm.assume(_params.resolutionParams.dispute.disputer != address(0));
    vm.assume(
      _params.award > uint8(IOracle.DisputeStatus.Escalated)
        && _params.award <= uint8(IOracle.DisputeStatus.NoResolution)
    );

    councilArbitrator.mock_setResolutions(_params.disputeId, _params.resolutionParams);

    _mockAndExpect(
      address(arbitrable), abi.encodeCall(IArbitrable.validateArbitrator, (_params.arbitrator)), abi.encode(true)
    );
    vm.startPrank(_params.arbitrator);
    _;
  }

  function test_revertInvalidDispute(ArbitrateDisputeParams memory _params) public happyPath(_params) {
    _params.resolutionParams.dispute.disputer = address(0);
    councilArbitrator.mock_setResolutions(_params.disputeId, _params.resolutionParams);

    vm.expectRevert(ICouncilArbitrator.CouncilArbitrator_InvalidDispute.selector);
    councilArbitrator.arbitrateDispute(_params.disputeId, IOracle.DisputeStatus(_params.award));
  }

  function test_revertInvalidAward(ArbitrateDisputeParams memory _params, uint8 _award) public happyPath(_params) {
    vm.assume(_award <= uint8(IOracle.DisputeStatus.Escalated));

    vm.expectRevert(ICouncilArbitrator.CouncilArbitrator_InvalidAward.selector);
    councilArbitrator.arbitrateDispute(_params.disputeId, IOracle.DisputeStatus(_award));
  }

  function test_revertDisputeAlreadyArbitrated(
    ArbitrateDisputeParams memory _params,
    uint8 _answer
  ) public happyPath(_params) {
    vm.assume(_answer > uint8(IOracle.DisputeStatus.None) && _answer <= uint8(IOracle.DisputeStatus.NoResolution));
    _mockGetAnswer(_params.disputeId, IOracle.DisputeStatus(_answer));

    vm.expectRevert(ICouncilArbitrator.CouncilArbitrator_DisputeAlreadyArbitrated.selector);
    councilArbitrator.arbitrateDispute(_params.disputeId, IOracle.DisputeStatus(_params.award));
  }

  function test_setGetAnswer(ArbitrateDisputeParams memory _params) public happyPath(_params) {
    councilArbitrator.arbitrateDispute(_params.disputeId, IOracle.DisputeStatus(_params.award));

    assertEq(uint8(councilArbitrator.getAnswer(_params.disputeId)), _params.award);
  }

  function test_callOracleResolveDispute(ArbitrateDisputeParams memory _params) public happyPath(_params) {
    vm.expectCall(
      address(oracle),
      abi.encodeCall(
        IOracle.resolveDispute,
        (_params.resolutionParams.request, _params.resolutionParams.response, _params.resolutionParams.dispute)
      )
    );
    councilArbitrator.arbitrateDispute(_params.disputeId, IOracle.DisputeStatus(_params.award));
  }

  function test_callOracleFinalizeWithResponse(ArbitrateDisputeParams memory _params) public happyPath(_params) {
    _params.award = uint8(IOracle.DisputeStatus.Lost);

    vm.expectCall(
      address(oracle),
      abi.encodeCall(IOracle.finalize, (_params.resolutionParams.request, _params.resolutionParams.response))
    );
    councilArbitrator.arbitrateDispute(_params.disputeId, IOracle.DisputeStatus(_params.award));
  }

  function test_callOracleFinalizeWithoutResponse(ArbitrateDisputeParams memory _params) public happyPath(_params) {
    vm.assume(_params.award != uint8(IOracle.DisputeStatus.Lost));
    _params.resolutionParams.response.requestId = 0;

    vm.expectCall(
      address(oracle),
      abi.encodeCall(IOracle.finalize, (_params.resolutionParams.request, _params.resolutionParams.response))
    );
    councilArbitrator.arbitrateDispute(_params.disputeId, IOracle.DisputeStatus(_params.award));
  }

  function test_emitDisputeArbitrated(ArbitrateDisputeParams memory _params) public happyPath(_params) {
    vm.expectEmit();
    emit DisputeArbitrated(_params.disputeId, IOracle.DisputeStatus(_params.award));
    councilArbitrator.arbitrateDispute(_params.disputeId, IOracle.DisputeStatus(_params.award));
  }
}

contract CouncilArbitrator_Unit_OnlyArbitratorModule is CouncilArbitrator_Unit_BaseTest {
  modifier happyPath() {
    vm.startPrank(address(arbitratorModule));
    _;
  }

  function test_revertOnlyArbitratorModule(address _caller) public happyPath {
    vm.assume(_caller != address(arbitratorModule));
    changePrank(_caller);

    vm.expectRevert(ICouncilArbitrator.CouncilArbitrator_OnlyArbitratorModule.selector);
    councilArbitrator.mock_onlyArbitratorModule();
  }

  function test_onlyArbitratorModule() public happyPath {
    councilArbitrator.mock_onlyArbitratorModule();
  }
}
