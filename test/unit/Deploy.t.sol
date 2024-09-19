// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.26;

import {IOracle, Oracle} from '@defi-wonderland/prophet-core/solidity/contracts/Oracle.sol';
import {BondEscalationAccounting} from
  '@defi-wonderland/prophet-modules/solidity/contracts/extensions/BondEscalationAccounting.sol';
import {
  BondEscalationModule,
  IBondEscalationModule
} from '@defi-wonderland/prophet-modules/solidity/contracts/modules/dispute/BondEscalationModule.sol';
import {
  ArbitratorModule,
  IArbitratorModule
} from '@defi-wonderland/prophet-modules/solidity/contracts/modules/resolution/ArbitratorModule.sol';
import {
  BondedResponseModule,
  IBondedResponseModule
} from '@defi-wonderland/prophet-modules/solidity/contracts/modules/response/BondedResponseModule.sol';
import {IEpochManager} from 'interfaces/external/IEpochManager.sol';

import {CouncilArbitrator} from 'contracts/CouncilArbitrator.sol';
import {EBOFinalityModule} from 'contracts/EBOFinalityModule.sol';
import {EBORequestCreator} from 'contracts/EBORequestCreator.sol';
import {EBORequestModule, IEBORequestModule} from 'contracts/EBORequestModule.sol';

import {Deploy} from 'script/Deploy.s.sol';

import {_ARBITRATOR, _COUNCIL, _EPOCH_MANAGER, _GRAPH_TOKEN} from 'script/Constants.sol';

import 'forge-std/Test.sol';

contract MockDeploy is Deploy {
  address internal _ghost_precomputedAddress;
  bool internal _ghost_mockPrecomputeCreateAddress;

  function mock_setPrecomputedAddress(address _precomputedAddress) external {
    _ghost_precomputedAddress = _precomputedAddress;
    _ghost_mockPrecomputeCreateAddress = true;
  }

  function _precomputeCreateAddress(uint256 _deploymentOffset) internal view override returns (address _targetAddress) {
    if (_ghost_mockPrecomputeCreateAddress) {
      _targetAddress = _ghost_precomputedAddress;
    } else {
      _targetAddress = super._precomputeCreateAddress(_deploymentOffset);
    }
  }
}

contract UnitDeploy is Test {
  MockDeploy public deploy;

  uint256 internal _currentEpoch;

  function setUp() public {
    deploy = new MockDeploy();

    _currentEpoch = 100;
  }

  function test_SetUpShouldDefineTheGraphAccounts() public {
    deploy.setUp();

    // it should define The Graph accounts
    assertEq(address(deploy.graphToken()).code, _GRAPH_TOKEN.code);
    assertEq(address(deploy.epochManager()).code, _EPOCH_MANAGER.code);
    assertEq(address(deploy.arbitrator()), _ARBITRATOR);
    assertEq(address(deploy.council()), _COUNCIL);
  }

  function test_RunRevertWhen_TheGraphAccountsAreNotSetUp() public {
    // it should revert
    vm.expectRevert();
    deploy.run();
  }

  modifier givenTheGraphAccountsAreSetUp() {
    vm.mockCall(_EPOCH_MANAGER, abi.encodeCall(IEpochManager.currentEpoch, ()), abi.encode(_currentEpoch));

    deploy.setUp();
    _;
  }

  function test_RunRevertWhen_PrecomputedAddressIsIncorrect(address _precomputedAddress)
    public
    givenTheGraphAccountsAreSetUp
  {
    uint256 _nonceEBORequestCreator = vm.getNonce(tx.origin) + deploy.OFFSET_EBO_REQUEST_CREATOR();
    address _precomputedEBORequestCreator = vm.computeCreateAddress(tx.origin, _nonceEBORequestCreator);
    vm.assume(_precomputedEBORequestCreator != _precomputedAddress);

    deploy.mock_setPrecomputedAddress(_precomputedAddress);

    // it should revert
    vm.expectRevert(Deploy.Deploy_InvalidPrecomputedAddress.selector);
    deploy.run();
  }

  function test_RunWhenPrecomputedAddressIsCorrect() public givenTheGraphAccountsAreSetUp {
    uint256 _nonceBefore = vm.getNonce(tx.origin);
    deploy.run();
    uint256 _nonceAfter = vm.getNonce(tx.origin);

    // it should deploy all contracts using a single EOA
    assertEq(deploy.DEPLOYMENT_COUNT(), _nonceAfter - _nonceBefore);

    // it should deploy `Oracle`
    assertEq(address(deploy.oracle()).code, type(Oracle).runtimeCode);

    // it should deploy `EBORequestModule` with correct args
    EBORequestModule _eboRequestModule =
      new EBORequestModule(deploy.oracle(), deploy.eboRequestCreator(), deploy.arbitrable());
    assertEq(address(deploy.eboRequestModule()).code, address(_eboRequestModule).code);
    assertEq(address(deploy.eboRequestModule().ORACLE()), address(deploy.oracle()));
    assertEq(address(deploy.eboRequestModule().eboRequestCreator()), address(deploy.eboRequestCreator()));
    assertEq(address(deploy.eboRequestModule().ARBITRABLE()), address(deploy.arbitrable()));

    // it should deploy `BondedResponseModule` with correct args
    BondedResponseModule _bondedResponseModule = new BondedResponseModule(deploy.oracle());
    assertEq(address(deploy.bondedResponseModule()).code, address(_bondedResponseModule).code);
    assertEq(address(deploy.bondedResponseModule().ORACLE()), address(deploy.oracle()));

    // it should deploy `BondEscalationModule` with correct args
    BondEscalationModule _bondEscalationModule = new BondEscalationModule(deploy.oracle());
    assertEq(address(deploy.bondEscalationModule()).code, address(_bondEscalationModule).code);
    assertEq(address(deploy.bondEscalationModule().ORACLE()), address(deploy.oracle()));

    // it should deploy `ArbitratorModule` with correct args
    ArbitratorModule _arbitratorModule = new ArbitratorModule(deploy.oracle());
    assertEq(address(deploy.arbitratorModule()).code, address(_arbitratorModule).code);
    assertEq(address(deploy.arbitratorModule().ORACLE()), address(deploy.oracle()));

    // it should deploy `EBOFinalityModule` with correct args
    EBOFinalityModule _eboFinalityModule =
      new EBOFinalityModule(deploy.oracle(), deploy.eboRequestCreator(), deploy.arbitrable());
    assertEq(address(deploy.eboFinalityModule()).code, address(_eboFinalityModule).code);
    assertEq(address(deploy.eboFinalityModule().ORACLE()), address(deploy.oracle()));
    assertEq(deploy.eboFinalityModule().enabledEBORequestCreators(deploy.eboRequestCreator()), true);
    assertEq(address(deploy.eboFinalityModule().ARBITRABLE()), address(deploy.arbitrable()));

    // it should deploy `BondEscalationAccounting` with correct args
    BondEscalationAccounting _bondEscalationAccounting = new BondEscalationAccounting(deploy.oracle());
    assertEq(address(deploy.bondEscalationAccounting()).code, address(_bondEscalationAccounting).code);
    assertEq(address(deploy.bondEscalationAccounting().ORACLE()), address(deploy.oracle()));

    // it should deploy `EBORequestCreator` with correct args
    IOracle.Request memory _requestData = _instantiateRequestData();
    EBORequestCreator _eboRequestCreator =
      new EBORequestCreator(deploy.oracle(), deploy.epochManager(), deploy.arbitrable(), _requestData);
    assertEq(address(deploy.eboRequestCreator()).code, address(_eboRequestCreator).code);
    assertEq(address(deploy.eboRequestCreator().ORACLE()), address(deploy.oracle()));
    assertEq(address(deploy.eboRequestCreator().epochManager()), address(deploy.epochManager()));
    assertEq(address(deploy.eboRequestCreator().ARBITRABLE()), address(deploy.arbitrable()));
    assertEq(abi.encode(deploy.eboRequestCreator().getRequestData()), abi.encode(_requestData));

    // it should deploy `CouncilArbitrator` with correct args
    CouncilArbitrator _councilArbitrator = new CouncilArbitrator(deploy.arbitratorModule(), deploy.arbitrable());
    assertEq(address(deploy.councilArbitrator()).code, address(_councilArbitrator).code);
    assertEq(address(deploy.councilArbitrator().ARBITRATOR_MODULE()), address(deploy.arbitratorModule()));
    assertEq(address(deploy.councilArbitrator().ARBITRABLE()), address(deploy.arbitrable()));
  }

  function _instantiateRequestData() internal view returns (IOracle.Request memory _requestData) {
    _requestData.nonce = 0;

    _requestData.requester = address(deploy.eboRequestCreator());
    _requestData.requestModule = address(deploy.eboRequestModule());
    _requestData.responseModule = address(deploy.bondedResponseModule());
    _requestData.disputeModule = address(deploy.bondEscalationModule());
    _requestData.resolutionModule = address(deploy.arbitratorModule());
    _requestData.finalityModule = address(deploy.eboFinalityModule());

    IEBORequestModule.RequestParameters memory _requestParams = _instantiateRequestParams();
    IBondedResponseModule.RequestParameters memory _responseParams = _instantiateResponseParams();
    IBondEscalationModule.RequestParameters memory _disputeParams = _instantiateDisputeParams();
    IArbitratorModule.RequestParameters memory _resolutionParams = _instantiateResolutionParams();
    _requestData.requestModuleData = abi.encode(_requestParams);
    _requestData.responseModuleData = abi.encode(_responseParams);
    _requestData.disputeModuleData = abi.encode(_disputeParams);
    _requestData.resolutionModuleData = abi.encode(_resolutionParams);
  }

  function _instantiateRequestParams()
    internal
    view
    returns (IEBORequestModule.RequestParameters memory _requestParams)
  {
    _requestParams.accountingExtension = deploy.bondEscalationAccounting();
    _requestParams.paymentAmount = deploy.paymentAmount();
  }

  function _instantiateResponseParams()
    internal
    view
    returns (IBondedResponseModule.RequestParameters memory _responseParams)
  {
    _responseParams.accountingExtension = deploy.bondEscalationAccounting();
    _responseParams.bondToken = deploy.graphToken();
    _responseParams.bondSize = deploy.responseBondSize();
    _responseParams.deadline = deploy.responseDeadline();
    _responseParams.disputeWindow = deploy.responseDisputeWindow();
  }

  function _instantiateDisputeParams()
    internal
    view
    returns (IBondEscalationModule.RequestParameters memory _disputeParams)
  {
    _disputeParams.accountingExtension = deploy.bondEscalationAccounting();
    _disputeParams.bondToken = deploy.graphToken();
    _disputeParams.bondSize = deploy.disputeBondSize();
    _disputeParams.maxNumberOfEscalations = deploy.maxNumberOfEscalations();
    _disputeParams.bondEscalationDeadline = deploy.disputeDeadline();
    _disputeParams.tyingBuffer = deploy.tyingBuffer();
    _disputeParams.disputeWindow = deploy.disputeDisputeWindow();
  }

  function _instantiateResolutionParams()
    internal
    view
    returns (IArbitratorModule.RequestParameters memory _resolutionParams)
  {
    _resolutionParams.arbitrator = address(deploy.councilArbitrator());
  }
}
