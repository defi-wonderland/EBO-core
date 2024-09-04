// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.26;

import {IOracle} from '@defi-wonderland/prophet-core/solidity/interfaces/IOracle.sol';
import {IValidator} from '@defi-wonderland/prophet-core/solidity/interfaces/IValidator.sol';
import {ValidatorLib} from '@defi-wonderland/prophet-core/solidity/libraries/ValidatorLib.sol';
import {IArbitrator} from '@defi-wonderland/prophet-modules/solidity/interfaces/IArbitrator.sol';
import {IArbitratorModule} from
  '@defi-wonderland/prophet-modules/solidity/interfaces/modules/resolution/IArbitratorModule.sol';

import {IArbitrable} from 'interfaces/IArbitrable.sol';
import {ICouncilArbitrator} from 'interfaces/ICouncilArbitrator.sol';

import {CouncilArbitrator} from 'contracts/CouncilArbitrator.sol';

import 'forge-std/Test.sol';

contract MockCouncilArbitrator is CouncilArbitrator {
  constructor(
    IArbitratorModule _arbitratorModule,
    address _arbitrator,
    address _council
  ) CouncilArbitrator(_arbitratorModule, _arbitrator, _council) {}

  // solhint-disable-next-line no-empty-blocks
  function mock_onlyArbitratorModule() external onlyArbitratorModule {}

  function mock_setResolutions(
    bytes32 _disputeId,
    ICouncilArbitrator.ResolutionParameters calldata _resolutionData
  ) external {
    resolutions[_disputeId] = _resolutionData;
  }
}

contract CouncilArbitrator_Unit_BaseTest is Test {
  using stdStorage for StdStorage;

  MockCouncilArbitrator public councilArbitrator;

  IOracle public oracle;
  IArbitratorModule public arbitratorModule;
  address public arbitrator;
  address public council;

  event ResolutionStarted(
    bytes32 indexed _disputeId, IOracle.Request _request, IOracle.Response _response, IOracle.Dispute _dispute
  );
  event DisputeResolved(bytes32 indexed _disputeId, IOracle.DisputeStatus _status);
  event SetArbitrator(address indexed _arbitrator);
  event SetCouncil(address indexed _council);

  function setUp() public {
    oracle = IOracle(makeAddr('Oracle'));
    vm.etch(address(oracle), '0x0');
    arbitratorModule = IArbitratorModule(makeAddr('ArbitratorModule'));
    arbitrator = makeAddr('Arbitrator');
    council = makeAddr('Council');

    vm.mockCall(address(arbitratorModule), abi.encodeCall(IValidator.ORACLE, ()), abi.encode(oracle));

    councilArbitrator = new MockCouncilArbitrator(arbitratorModule, arbitrator, council);
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
    address arbitrator;
    address council;
    IOracle oracle;
  }

  modifier happyPath(ConstructorParams calldata _params) {
    assumeNotForgeAddress(address(_params.arbitratorModule));
    vm.mockCall(address(_params.arbitratorModule), abi.encodeCall(IValidator.ORACLE, ()), abi.encode(_params.oracle));
    _;
  }

  function test_setArbitrator(ConstructorParams calldata _params) public happyPath(_params) {
    councilArbitrator = new MockCouncilArbitrator(_params.arbitratorModule, _params.arbitrator, _params.council);

    assertEq(councilArbitrator.arbitrator(), _params.arbitrator);
  }

  function test_emitSetArbitrator(ConstructorParams calldata _params) public happyPath(_params) {
    vm.expectEmit();
    emit SetArbitrator(_params.arbitrator);
    new MockCouncilArbitrator(_params.arbitratorModule, _params.arbitrator, _params.council);
  }

  function test_setCouncil(ConstructorParams calldata _params) public happyPath(_params) {
    councilArbitrator = new MockCouncilArbitrator(_params.arbitratorModule, _params.arbitrator, _params.council);

    assertEq(councilArbitrator.council(), _params.council);
  }

  function test_emitSetCouncil(ConstructorParams calldata _params) public happyPath(_params) {
    vm.expectEmit();
    emit SetCouncil(_params.council);
    new MockCouncilArbitrator(_params.arbitratorModule, _params.arbitrator, _params.council);
  }

  function test_setOracle(ConstructorParams calldata _params) public happyPath(_params) {
    councilArbitrator = new MockCouncilArbitrator(_params.arbitratorModule, _params.arbitrator, _params.council);

    assertEq(address(councilArbitrator.ORACLE()), address(_params.oracle));
  }

  function test_setArbitratorModule(ConstructorParams calldata _params) public happyPath(_params) {
    councilArbitrator = new MockCouncilArbitrator(_params.arbitratorModule, _params.arbitrator, _params.council);

    assertEq(address(councilArbitrator.ARBITRATOR_MODULE()), address(_params.arbitratorModule));
  }
}

contract CouncilArbitrator_Unit_Resolve is CouncilArbitrator_Unit_BaseTest {
  using ValidatorLib for IOracle.Dispute;

  modifier happyPath() {
    vm.startPrank(address(arbitratorModule));
    _;
  }

  function test_revertOnlyArbitratorModule(ICouncilArbitrator.ResolutionParameters calldata _params) public happyPath {
    vm.stopPrank();

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

contract CouncilArbitrator_Unit_ResolveDispute is CouncilArbitrator_Unit_BaseTest {
  struct ResolveDisputeParams {
    bytes32 disputeId;
    uint8 status;
    ICouncilArbitrator.ResolutionParameters resolutionData;
    uint8 answer;
  }

  modifier happyPath(ResolveDisputeParams memory _params) {
    vm.assume(_params.resolutionData.dispute.disputer != address(0));
    vm.assume(
      _params.status > uint8(IOracle.DisputeStatus.Escalated)
        && _params.status <= uint8(IOracle.DisputeStatus.NoResolution)
    );

    _params.answer = uint8(IOracle.DisputeStatus.None);

    councilArbitrator.mock_setResolutions(_params.disputeId, _params.resolutionData);

    vm.startPrank(arbitrator);
    _;
  }

  function test_revertOnlyArbitrator(ResolveDisputeParams memory _params) public happyPath(_params) {
    vm.stopPrank();

    vm.expectRevert(IArbitrable.Arbitrable_OnlyArbitrator.selector);
    councilArbitrator.resolveDispute(_params.disputeId, IOracle.DisputeStatus(_params.status));
  }

  function test_revertInvalidResolution(ResolveDisputeParams memory _params) public happyPath(_params) {
    _params.resolutionData.dispute.disputer = address(0);
    councilArbitrator.mock_setResolutions(_params.disputeId, _params.resolutionData);

    vm.expectRevert(ICouncilArbitrator.CouncilArbitrator_InvalidResolution.selector);
    councilArbitrator.resolveDispute(_params.disputeId, IOracle.DisputeStatus(_params.status));
  }

  function test_revertInvalidResolutionStatus(
    ResolveDisputeParams memory _params,
    uint8 _status
  ) public happyPath(_params) {
    vm.assume(_status <= uint8(IOracle.DisputeStatus.Escalated));

    vm.expectRevert(ICouncilArbitrator.CouncilArbitrator_InvalidResolutionStatus.selector);
    councilArbitrator.resolveDispute(_params.disputeId, IOracle.DisputeStatus(_status));
  }

  function test_revertDisputeAlreadyResolved(
    ResolveDisputeParams memory _params,
    uint8 _answer
  ) public happyPath(_params) {
    vm.assume(_answer > uint8(IOracle.DisputeStatus.None) && _answer <= uint8(IOracle.DisputeStatus.NoResolution));
    _mockGetAnswer(_params.disputeId, IOracle.DisputeStatus(_answer));

    vm.expectRevert(ICouncilArbitrator.CouncilArbitrator_DisputeAlreadyResolved.selector);
    councilArbitrator.resolveDispute(_params.disputeId, IOracle.DisputeStatus(_params.status));
  }

  function test_setGetAnswer(ResolveDisputeParams memory _params) public happyPath(_params) {
    councilArbitrator.resolveDispute(_params.disputeId, IOracle.DisputeStatus(_params.status));

    assertEq(uint8(councilArbitrator.getAnswer(_params.disputeId)), _params.status);
  }

  function test_callOracleResolveDispute(ResolveDisputeParams memory _params) public happyPath(_params) {
    vm.expectCall(
      address(oracle),
      abi.encodeCall(
        IOracle.resolveDispute,
        (_params.resolutionData.request, _params.resolutionData.response, _params.resolutionData.dispute)
      )
    );
    councilArbitrator.resolveDispute(_params.disputeId, IOracle.DisputeStatus(_params.status));
  }

  function test_callOracleFinalize(ResolveDisputeParams memory _params) public happyPath(_params) {
    vm.expectCall(
      address(oracle),
      abi.encodeCall(IOracle.finalize, (_params.resolutionData.request, _params.resolutionData.response))
    );
    councilArbitrator.resolveDispute(_params.disputeId, IOracle.DisputeStatus(_params.status));
  }

  function test_emitDisputeResolved(ResolveDisputeParams memory _params) public happyPath(_params) {
    vm.expectEmit();
    emit DisputeResolved(_params.disputeId, IOracle.DisputeStatus(_params.status));
    councilArbitrator.resolveDispute(_params.disputeId, IOracle.DisputeStatus(_params.status));
  }
}

contract CouncilArbitrator_Unit_OnlyArbitratorModule is CouncilArbitrator_Unit_BaseTest {
  modifier happyPath() {
    vm.startPrank(address(arbitratorModule));
    _;
  }

  function test_revertOnlyArbitratorModule() public happyPath {
    vm.stopPrank();

    vm.expectRevert(ICouncilArbitrator.CouncilArbitrator_OnlyArbitratorModule.selector);
    councilArbitrator.mock_onlyArbitratorModule();
  }

  function test_onlyArbitratorModule() public happyPath {
    councilArbitrator.mock_onlyArbitratorModule();
  }
}
