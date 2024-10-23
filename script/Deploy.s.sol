// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.26;

import {IOracle, Oracle} from '@defi-wonderland/prophet-core/solidity/contracts/Oracle.sol';
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
import {
  IAccountingExtension,
  IBondEscalationAccounting
} from '@defi-wonderland/prophet-modules/solidity/interfaces/extensions/IBondEscalationAccounting.sol';
import {IERC20} from '@openzeppelin/contracts/interfaces/IERC20.sol';
import {IEpochManager} from 'interfaces/external/IEpochManager.sol';
import {IHorizonStaking} from 'interfaces/external/IHorizonStaking.sol';

import {Arbitrable, IArbitrable} from 'contracts/Arbitrable.sol';
import {CouncilArbitrator, ICouncilArbitrator} from 'contracts/CouncilArbitrator.sol';
import {EBOFinalityModule, IEBOFinalityModule} from 'contracts/EBOFinalityModule.sol';
import {EBORequestCreator, IEBORequestCreator} from 'contracts/EBORequestCreator.sol';
import {EBORequestModule, IEBORequestModule} from 'contracts/EBORequestModule.sol';
import {HorizonAccountingExtension, IHorizonAccountingExtension} from 'contracts/HorizonAccountingExtension.sol';

import {
  _ARBITRUM_SEPOLIA_ARBITRATOR,
  _ARBITRUM_SEPOLIA_COUNCIL,
  _ARBITRUM_SEPOLIA_EPOCH_MANAGER,
  _ARBITRUM_SEPOLIA_GRAPH_TOKEN,
  _ARBITRUM_SEPOLIA_HORIZON_STAKING,
  _MAX_USERS_TO_CHECK,
  _MIN_THAWING_PERIOD
} from 'script/Constants.sol';

import 'forge-std/Script.sol';

contract Deploy is Script {
  uint256 public constant DEPLOYMENT_COUNT = 10;
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
  IHorizonAccountingExtension public horizonAccountingExtension;

  // Periphery
  IEBORequestCreator public eboRequestCreator;
  ICouncilArbitrator public councilArbitrator;
  IArbitrable public arbitrable;

  // The Graph
  IERC20 public graphToken;
  IHorizonStaking public horizonStaking;
  IEpochManager public epochManager;
  address public arbitrator;
  address public council;

  // Data
  uint256 public paymentAmount;
  uint256 public responseBondSize;
  uint256 public responseDeadline;
  uint256 public responseDisputeWindow;
  uint256 public disputeBondSize;
  uint256 public maxNumberOfEscalations;
  uint256 public disputeDeadline;
  uint256 public tyingBuffer;
  uint256 public disputeDisputeWindow;

  error Deploy_InvalidPrecomputedAddress();

  function setUp() public virtual {
    // Define The Graph accounts
    graphToken = IERC20(_ARBITRUM_SEPOLIA_GRAPH_TOKEN);
    horizonStaking = IHorizonStaking(_ARBITRUM_SEPOLIA_HORIZON_STAKING);
    epochManager = IEpochManager(_ARBITRUM_SEPOLIA_EPOCH_MANAGER);
    arbitrator = _ARBITRUM_SEPOLIA_ARBITRATOR;
    council = _ARBITRUM_SEPOLIA_COUNCIL;

    // Set request module params
    paymentAmount = 0 ether;

    // Set response module params
    // TODO: Review production params (responseBondSize == disputeBondSize)
    responseBondSize = 0.5 ether;
    responseDeadline = 5 days;
    responseDisputeWindow = 1 weeks;

    // Set dispute module params
    // TODO: Review production params (disputeBondSize == responseBondSize)
    disputeBondSize = 0.3 ether;
    maxNumberOfEscalations = 2;
    disputeDeadline = 10 days;
    tyingBuffer = 3 days;
    disputeDisputeWindow = 2 weeks;
  }

  function run() public {
    vm.startBroadcast();

    // Precompute address of `EBORequestCreator`
    IEBORequestCreator _precomputedEBORequestCreator =
      IEBORequestCreator(_precomputeCreateAddress(OFFSET_EBO_REQUEST_CREATOR));

    // Deploy `Oracle`
    oracle = new Oracle();
    console.log('`Oracle` deployed at:', address(oracle));

    // Deploy `Arbitrable`
    arbitrable = new Arbitrable(arbitrator, council);
    console.log('`Arbitrable` deployed at:', address(arbitrable));

    // Deploy `EBORequestModule`
    eboRequestModule = new EBORequestModule(oracle, _precomputedEBORequestCreator, arbitrable);
    console.log('`EBORequestModule` deployed at:', address(eboRequestModule));

    // Deploy `BondedResponseModule`
    bondedResponseModule = new BondedResponseModule(oracle);
    console.log('`BondedResponseModule` deployed at:', address(bondedResponseModule));

    // Deploy `BondEscalationModule`
    bondEscalationModule = new BondEscalationModule(oracle);
    console.log('`BondEscalationModule` deployed at:', address(bondEscalationModule));

    // Deploy `ArbitratorModule`
    arbitratorModule = new ArbitratorModule(oracle);
    console.log('`ArbitratorModule` deployed at:', address(arbitratorModule));

    // Deploy `EBOFinalityModule`
    eboFinalityModule = new EBOFinalityModule(oracle, _precomputedEBORequestCreator, arbitrable);
    console.log('`EBOFinalityModule` deployed at:', address(eboFinalityModule));

    // Deploy `HorizonAccountingExtension`
    address[] memory _authorizedCallers = _instantiateAuthorizedCallers();
    horizonAccountingExtension = new HorizonAccountingExtension(
      horizonStaking, oracle, graphToken, arbitrable, _MIN_THAWING_PERIOD, _MAX_USERS_TO_CHECK, _authorizedCallers
    );
    console.log('`HorizonAccountingExtension` deployed at:', address(horizonAccountingExtension));

    // Deploy `CouncilArbitrator`
    councilArbitrator = new CouncilArbitrator(arbitratorModule, arbitrable);
    console.log('`CouncilArbitrator` deployed at:', address(councilArbitrator));

    // Deploy `EBORequestCreator`
    IOracle.Request memory _requestData = _instantiateRequestData();
    eboRequestCreator = new EBORequestCreator(oracle, epochManager, arbitrable, _requestData);
    console.log('`EBORequestCreator` deployed at:', address(eboRequestCreator));

    // Assert that `EBORequestCreator` was deployed at the precomputed address
    if (eboRequestCreator != _precomputedEBORequestCreator) revert Deploy_InvalidPrecomputedAddress();

    vm.stopBroadcast();
  }

  function _instantiateRequestData() internal view returns (IOracle.Request memory _requestData) {
    // Set placeholder nonce
    _requestData.nonce = 0;

    // Set requester and modules
    _requestData.requester = address(eboRequestCreator);
    _requestData.requestModule = address(eboRequestModule);
    _requestData.responseModule = address(bondedResponseModule);
    _requestData.disputeModule = address(bondEscalationModule);
    _requestData.resolutionModule = address(arbitratorModule);
    _requestData.finalityModule = address(eboFinalityModule);

    // Set modules data
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
    _requestParams.accountingExtension = IAccountingExtension(address(horizonAccountingExtension));
    _requestParams.paymentAmount = paymentAmount;
  }

  function _instantiateResponseParams()
    internal
    view
    returns (IBondedResponseModule.RequestParameters memory _responseParams)
  {
    _responseParams.accountingExtension = IAccountingExtension(address(horizonAccountingExtension));
    _responseParams.bondToken = graphToken;
    _responseParams.bondSize = responseBondSize;
    _responseParams.deadline = responseDeadline;
    _responseParams.disputeWindow = responseDisputeWindow;
  }

  function _instantiateDisputeParams()
    internal
    view
    returns (IBondEscalationModule.RequestParameters memory _disputeParams)
  {
    _disputeParams.accountingExtension = IBondEscalationAccounting(address(horizonAccountingExtension));
    _disputeParams.bondToken = graphToken;
    _disputeParams.bondSize = disputeBondSize;
    _disputeParams.maxNumberOfEscalations = maxNumberOfEscalations;
    _disputeParams.bondEscalationDeadline = disputeDeadline;
    _disputeParams.tyingBuffer = tyingBuffer;
    _disputeParams.disputeWindow = disputeDisputeWindow;
  }

  function _instantiateResolutionParams()
    internal
    view
    returns (IArbitratorModule.RequestParameters memory _resolutionParams)
  {
    _resolutionParams.arbitrator = address(councilArbitrator);
  }

  function _instantiateAuthorizedCallers() internal view returns (address[] memory _authorizedCallers) {
    _authorizedCallers = new address[](1);
    _authorizedCallers[0] = address(bondEscalationModule);
  }

  function _precomputeCreateAddress(uint256 _deploymentOffset) internal view virtual returns (address _targetAddress) {
    // Get nonce for the target deployment
    uint256 _targetNonce = vm.getNonce(tx.origin) + _deploymentOffset;
    // Precompute address of the target deployment
    _targetAddress = vm.computeCreateAddress(tx.origin, _targetNonce);
  }
}
