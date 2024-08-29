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

import {CouncilArbitrator, ICouncilArbitrator} from 'contracts/CouncilArbitrator.sol';
import {EBOFinalityModule, IEBOFinalityModule} from 'contracts/EBOFinalityModule.sol';
import {EBORequestCreator, IEBORequestCreator, IEpochManager} from 'contracts/EBORequestCreator.sol';
import {EBORequestModule, IEBORequestModule} from 'contracts/EBORequestModule.sol';

import {_ARBITRATOR, _COUNCIL, _DEPLOYER, _EPOCH_MANAGER, _GRAPH_TOKEN} from './Constants.sol';

import 'forge-std/Script.sol';

contract Deploy is Script {
  // Oracle
  IOracle internal _oracle;

  // Modules
  IEBORequestModule internal _eboRequestModule;
  IBondedResponseModule internal _bondedResponseModule;
  IBondEscalationModule internal _bondEscalationModule;
  IArbitratorModule internal _arbitratorModule;
  IEBOFinalityModule internal _eboFinalityModule;

  // Extensions
  IBondEscalationAccounting internal _accountingExtension;

  // Periphery
  IEBORequestCreator internal _eboRequestCreator;
  ICouncilArbitrator internal _councilArbitrator;

  // The Graph
  IERC20 internal _graphToken;
  IEpochManager internal _epochManager;
  address internal _arbitrator;
  address internal _council;
  address internal _deployer;

  // Data
  IOracle.Request internal _requestData;
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

  function setUp() public virtual {
    // Define The Graph accounts
    _graphToken = IERC20(_GRAPH_TOKEN);
    _epochManager = IEpochManager(_EPOCH_MANAGER);
    _arbitrator = _ARBITRATOR;
    _council = _COUNCIL;
    _deployer = _DEPLOYER;

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

  function run() public virtual {
    vm.rememberKey(vm.envUint('ARBITRUM_DEPLOYER_PK'));
    vm.startBroadcast(_deployer);

    // Deploy Oracle
    _oracle = new Oracle();

    // Deploy BondedResponseModule
    _bondedResponseModule = new BondedResponseModule(_oracle);

    // Deploy BondEscalationModule
    _bondEscalationModule = new BondEscalationModule(_oracle);

    // Deploy ArbitratorModule
    _arbitratorModule = new ArbitratorModule(_oracle);

    // Deploy AccountingExtension
    _accountingExtension = new BondEscalationAccounting(_oracle);

    // Precompute the address of EBORequestCreator
    IEBORequestCreator _precomputedEBORequestCreator = IEBORequestCreator(_precomputeCreateAddress(2));

    // Deploy EBORequestModule
    _eboRequestModule = new EBORequestModule(_oracle, _precomputedEBORequestCreator, _arbitrator, _council);

    // Deploy EBOFinalityModule
    _eboFinalityModule = new EBOFinalityModule(_oracle, _precomputedEBORequestCreator, _arbitrator, _council);

    // Deploy EBORequestCreator
    _setRequestData();
    _eboRequestCreator = new EBORequestCreator(_oracle, _epochManager, _arbitrator, _council, _requestData);

    // Assert that EBORequestCreator was deployed at the precomputed address
    assert(_eboRequestCreator == _precomputedEBORequestCreator);

    vm.stopBroadcast();
  }

  function _setRequestData() internal {
    // Set placeholder nonce
    _requestData.nonce = 0;

    // Set modules
    _requestData.requestModule = address(_eboRequestModule);
    _requestData.responseModule = address(_bondedResponseModule);
    _requestData.disputeModule = address(_bondEscalationModule);
    _requestData.resolutionModule = address(_arbitratorModule);
    _requestData.finalityModule = address(_eboFinalityModule);

    // Set request module data
    _requestParams.accountingExtension = _accountingExtension;
    _requestParams.paymentAmount = _paymentAmount;
    _requestData.requestModuleData = abi.encode(_requestParams);

    // Set response module data
    _responseParams.accountingExtension = _accountingExtension;
    _responseParams.bondToken = _graphToken;
    _responseParams.bondSize = _responseBondSize;
    _responseParams.deadline = _responseDeadline;
    _responseParams.disputeWindow = _responseDisputeWindow;
    _requestData.responseModuleData = abi.encode(_responseParams);

    // Set dispute module data
    _disputeParams.accountingExtension = _accountingExtension;
    _disputeParams.bondToken = _graphToken;
    _disputeParams.bondSize = _disputeBondSize;
    _disputeParams.maxNumberOfEscalations = _maxNumberOfEscalations;
    _disputeParams.bondEscalationDeadline = _disputeDeadline;
    _disputeParams.tyingBuffer = _tyingBuffer;
    _disputeParams.disputeWindow = _disputeDisputeWindow;
    _requestData.disputeModuleData = abi.encode(_disputeParams);

    // Set resolution module data
    _resolutionParams.arbitrator = address(_councilArbitrator);
    _requestData.resolutionModuleData = abi.encode(_resolutionParams);

    // TODO: Set finality module data?
    // _requestData.finalityModuleData = abi.encode(_finalityParams);
  }

  function _precomputeCreateAddress(uint256 _deploymentCount) internal view returns (address _targetAddress) {
    // Get nonce for the target deployment
    uint256 _targetNonce = vm.getNonce(_deployer) + _deploymentCount;
    // Precompute the address of the target deployment
    _targetAddress = vm.computeCreateAddress(_deployer, _targetNonce);
  }
}
