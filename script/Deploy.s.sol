// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.26;

import {IOracle, Oracle} from '@defi-wonderland/prophet-core/solidity/contracts/Oracle.sol';
import {
  BondEscalationAccounting,
  IBondEscalationAccounting
} from '@defi-wonderland/prophet-modules/solidity/contracts/extensions/BondEscalationAccounting.sol';
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
import {IERC20} from '@openzeppelin/contracts/interfaces/IERC20.sol';
import {IEpochManager} from 'interfaces/external/IEpochManager.sol';

import {CouncilArbitrator, ICouncilArbitrator} from 'contracts/CouncilArbitrator.sol';
import {EBOFinalityModule, IEBOFinalityModule} from 'contracts/EBOFinalityModule.sol';
import {EBORequestCreator, IEBORequestCreator} from 'contracts/EBORequestCreator.sol';
import {EBORequestModule, IEBORequestModule} from 'contracts/EBORequestModule.sol';

import {_ARBITRATOR, _COUNCIL, _DEPLOYER, _EPOCH_MANAGER, _GRAPH_TOKEN} from './Constants.sol';

import 'forge-std/Script.sol';

contract Deploy is Script {
  uint256 public constant DEPLOYMENT_COUNT = 9;
  uint256 public constant OFFSET_EBO_REQUEST_CREATOR = DEPLOYMENT_COUNT - 1;

  // Oracle
  IOracle public oracle;

  // Modules
  IEBORequestModule public eboRequestModule;
  IBondedResponseModule public bondedResponseModule;
  IBondEscalationModule public bondEscalationModule;
  IArbitratorModule public arbitratorModule;
  IEBOFinalityModule public eboFinalityModule;

  // Extensions
  IBondEscalationAccounting public bondEscalationAccounting;

  // Periphery
  IEBORequestCreator public eboRequestCreator;
  ICouncilArbitrator public councilArbitrator;

  // The Graph
  IERC20 public graphToken;
  IEpochManager public epochManager;
  address public arbitrator;
  address public council;
  address public deployer;

  // Data
  IOracle.Request public requestData;
  IEBORequestModule.RequestParameters internal _requestParams;
  IBondedResponseModule.RequestParameters internal _responseParams;
  IBondEscalationModule.RequestParameters internal _disputeParams;
  IArbitratorModule.RequestParameters internal _resolutionParams;
  uint256 internal _paymentAmount;
  uint256 internal _responseBondSize;
  uint256 internal _responseDeadline;
  uint256 internal _responseDisputeWindow;
  uint256 internal _disputeBondSize;
  uint256 internal _maxNumberOfEscalations;
  uint256 internal _disputeDeadline;
  uint256 internal _tyingBuffer;
  uint256 internal _disputeDisputeWindow;

  error Deploy_InvalidPrecomputedAddress();

  function getRequestData() external view returns (IOracle.Request memory _requestData) {
    _requestData = requestData;
  }

  function setUp() public {
    // Define The Graph accounts
    graphToken = IERC20(_GRAPH_TOKEN);
    epochManager = IEpochManager(_EPOCH_MANAGER);
    arbitrator = _ARBITRATOR;
    council = _COUNCIL;
    deployer = _DEPLOYER;

    // TODO: Define request module params
    _paymentAmount = 0;

    // TODO: Define response module params
    _responseBondSize = 0;
    _responseDeadline = 0;
    _responseDisputeWindow = 0;

    // TODO: Define dispute module params
    _disputeBondSize = 0;
    _maxNumberOfEscalations = 0;
    _disputeDeadline = 0;
    _tyingBuffer = 0;
    _disputeDisputeWindow = 0;
  }

  function run() public {
    vm.rememberKey(vm.envUint('ARBITRUM_DEPLOYER_PK'));
    vm.startBroadcast(deployer);

    // Precompute address of `EBORequestCreator`
    IEBORequestCreator _precomputedEBORequestCreator =
      IEBORequestCreator(_precomputeCreateAddress(OFFSET_EBO_REQUEST_CREATOR));

    // Deploy `Oracle`
    oracle = new Oracle();

    // Deploy `EBORequestModule`
    eboRequestModule = new EBORequestModule(oracle, _precomputedEBORequestCreator, arbitrator, council);

    // Deploy `BondedResponseModule`
    bondedResponseModule = new BondedResponseModule(oracle);

    // Deploy `BondEscalationModule`
    bondEscalationModule = new BondEscalationModule(oracle);

    // Deploy `ArbitratorModule`
    arbitratorModule = new ArbitratorModule(oracle);

    // Deploy `EBOFinalityModule`
    eboFinalityModule = new EBOFinalityModule(oracle, _precomputedEBORequestCreator, arbitrator, council);

    // Deploy `BondEscalationAccounting`
    bondEscalationAccounting = new BondEscalationAccounting(oracle);

    // Deploy `CouncilArbitrator`
    councilArbitrator = new CouncilArbitrator(arbitratorModule, arbitrator, council);

    // Deploy `EBORequestCreator`
    _setRequestData(_precomputedEBORequestCreator);
    eboRequestCreator = new EBORequestCreator(oracle, epochManager, arbitrator, council, requestData);

    // Assert that `EBORequestCreator` was deployed at the precomputed address
    if (eboRequestCreator != _precomputedEBORequestCreator) revert Deploy_InvalidPrecomputedAddress();

    vm.stopBroadcast();
  }

  function _setRequestData(IEBORequestCreator _precomputedEBORequestCreator) internal {
    // Set placeholder nonce
    requestData.nonce = 0;

    // Set requester
    requestData.requester = address(_precomputedEBORequestCreator);

    // Set modules
    requestData.requestModule = address(eboRequestModule);
    requestData.responseModule = address(bondedResponseModule);
    requestData.disputeModule = address(bondEscalationModule);
    requestData.resolutionModule = address(arbitratorModule);
    requestData.finalityModule = address(eboFinalityModule);

    // Set request module data
    _requestParams.accountingExtension = bondEscalationAccounting;
    _requestParams.paymentAmount = _paymentAmount;
    requestData.requestModuleData = abi.encode(_requestParams);

    // Set response module data
    _responseParams.accountingExtension = bondEscalationAccounting;
    _responseParams.bondToken = graphToken;
    _responseParams.bondSize = _responseBondSize;
    _responseParams.deadline = _responseDeadline;
    _responseParams.disputeWindow = _responseDisputeWindow;
    requestData.responseModuleData = abi.encode(_responseParams);

    // Set dispute module data
    _disputeParams.accountingExtension = bondEscalationAccounting;
    _disputeParams.bondToken = graphToken;
    _disputeParams.bondSize = _disputeBondSize;
    _disputeParams.maxNumberOfEscalations = _maxNumberOfEscalations;
    _disputeParams.bondEscalationDeadline = _disputeDeadline;
    _disputeParams.tyingBuffer = _tyingBuffer;
    _disputeParams.disputeWindow = _disputeDisputeWindow;
    requestData.disputeModuleData = abi.encode(_disputeParams);

    // Set resolution module data
    _resolutionParams.arbitrator = address(councilArbitrator);
    requestData.resolutionModuleData = abi.encode(_resolutionParams);

    // TODO: Set finality module data?
    // requestData.finalityModuleData = abi.encode(_finalityParams);
  }

  function _precomputeCreateAddress(uint256 _deploymentOffset) internal view virtual returns (address _targetAddress) {
    // Get nonce for the target deployment
    uint256 _targetNonce = vm.getNonce(deployer) + _deploymentOffset;
    // Precompute address of the target deployment
    _targetAddress = vm.computeCreateAddress(deployer, _targetNonce);
  }
}
