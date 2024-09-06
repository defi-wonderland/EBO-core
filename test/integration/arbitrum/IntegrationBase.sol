// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.26;

import {IOracle, Oracle} from '@defi-wonderland/prophet-core/solidity/contracts/Oracle.sol';
import {ValidatorLib} from '@defi-wonderland/prophet-core/solidity/libraries/ValidatorLib.sol';
import {
  BondEscalationAccounting,
  IBondEscalationAccounting
} from '@defi-wonderland/prophet-modules/solidity/contracts/extensions/BondEscalationAccounting.sol';

import {
  BondEscalationModule,
  IBondEscalationModule
} from '@defi-wonderland/prophet-modules/solidity/contracts/modules/dispute/BondEscalationModule.sol';
import {
  BondedResponseModule,
  IBondedResponseModule
} from '@defi-wonderland/prophet-modules/solidity/contracts/modules/response/BondedResponseModule.sol';
import {IERC20} from '@openzeppelin/contracts/interfaces/IERC20.sol';

import {CouncilArbitrator, ICouncilArbitrator} from 'contracts/CouncilArbitrator.sol';
import {EBORequestCreator, IEBORequestCreator, IEpochManager} from 'contracts/EBORequestCreator.sol';
import {EBORequestModule, IEBORequestModule} from 'contracts/EBORequestModule.sol';

import {_EPOCH_MANAGER, _GRAPH_TOKEN} from 'script/Constants.sol';

import 'forge-std/Test.sol';

contract IntegrationBase is Test {
  using ValidatorLib for IOracle.Request;
  using ValidatorLib for IOracle.Response;
  using ValidatorLib for IOracle.Dispute;

  uint256 internal constant _FORK_BLOCK = 240_000_000;

  // Oracle
  IOracle internal _oracle;

  // Modules
  IEBORequestModule internal _eboRequestModule;
  IBondedResponseModule internal _bondedResponseModule;
  IBondEscalationModule internal _bondEscalationModule;

  // Extensions
  IBondEscalationAccounting internal _accountingExtension;

  // Periphery
  IEBORequestCreator internal _eboRequestCreator;
  ICouncilArbitrator internal _councilArbitrator;

  // The Graph
  IERC20 internal _graphToken;
  IEpochManager internal _epochManager;
  address internal _arbitrator = makeAddr('arbitrator');
  address internal _council = makeAddr('council');
  address internal _deployer = makeAddr('deployer');

  // Others
  address internal _user = makeAddr('user');

  // Data
  IOracle.Request internal _requestData;
  IOracle.Response internal _responseData;
  IOracle.Dispute internal _disputeData;
  IEBORequestModule.RequestParameters internal _requestParams;
  IBondedResponseModule.RequestParameters internal _responseParams;
  IBondEscalationModule.RequestParameters internal _disputeParams;
  bytes32 internal _requestId;
  bytes32 internal _responseId;
  bytes32 internal _disputeId;
  uint256 internal _paymentAmount;
  uint256 internal _bondSize;
  uint256 internal _currentEpoch;
  string internal _chainId = 'chainId1';

  function setUp() public virtual {
    vm.createSelectFork(vm.rpcUrl('arbitrum'), _FORK_BLOCK);
    vm.startPrank(_deployer);

    // Fetch GraphToken
    _graphToken = IERC20(_GRAPH_TOKEN);
    // Fetch EpochManager
    _epochManager = IEpochManager(_EPOCH_MANAGER);
    // Fetch the current epoch
    _currentEpoch = _epochManager.currentEpoch();

    // Deploy Oracle
    _oracle = new Oracle();

    // Deploy EBORequestCreator
    _eboRequestCreator = new EBORequestCreator(_oracle, _epochManager, _arbitrator, _council, _requestData);

    // Deploy EBORequestModule
    _eboRequestModule = new EBORequestModule(_oracle, _eboRequestCreator, _arbitrator, _council);

    // Deploy BondedResponseModule
    _bondedResponseModule = new BondedResponseModule(_oracle);

    // Deploy BondEscalationModule
    _bondEscalationModule = new BondEscalationModule(_oracle);

    // Deploy AccountingExtension
    _accountingExtension = new BondEscalationAccounting(_oracle);

    vm.stopPrank();
  }

  function _createRequest() internal {
    _requestParams.epoch = _currentEpoch;
    _requestParams.chainId = _chainId;
    _requestData.requestModuleData = abi.encode(_requestParams);

    _requestId = _requestData._getId();

    vm.prank(_user);
    _eboRequestCreator.createRequest(_currentEpoch, _chainId);
  }

  function _proposeResponse() internal {
    _responseData.proposer = _user;
    _responseData.requestId = _requestId;
    _responseData.response = abi.encode(''); // TODO: Populate response

    _responseId = _responseData._getId();

    vm.prank(_user);
    _oracle.proposeResponse(_requestData, _responseData);
  }

  function _disputeResponse() internal {
    _disputeData.disputer = _user;
    _disputeData.proposer = _user;
    _disputeData.responseId = _responseId;
    _disputeData.requestId = _requestId;

    _disputeId = _disputeData._getId();

    vm.prank(_user);
    _oracle.disputeResponse(_requestData, _responseData, _disputeData);
  }

  function _setRequestModuleData() internal {
    _requestData.nonce = 0;
    _requestData.requester = address(_eboRequestCreator);
    _requestData.requestModule = address(_eboRequestModule);

    _requestParams.accountingExtension = _accountingExtension;
    _requestParams.paymentAmount = _paymentAmount;
    _requestData.requestModuleData = abi.encode(_requestParams);

    vm.prank(_arbitrator);
    _eboRequestCreator.setRequestModuleData(address(_eboRequestModule), _requestParams);
  }

  function _setResponseModuleData() internal {
    _requestData.responseModule = address(_bondedResponseModule);

    _responseParams.accountingExtension = _accountingExtension;
    _responseParams.bondToken = _graphToken;
    _responseParams.bondSize = _bondSize;
    _responseParams.deadline = block.timestamp + 1 days;
    _responseParams.disputeWindow = block.number + 1 days;
    _requestData.responseModuleData = abi.encode(_responseParams);

    vm.prank(_arbitrator);
    _eboRequestCreator.setResponseModuleData(address(_bondedResponseModule), _responseParams);
  }

  function _setDisputeModuleData() internal {
    _requestData.disputeModule = address(_bondEscalationModule);

    _disputeParams.accountingExtension = _accountingExtension;
    _disputeParams.bondToken = _graphToken;
    _disputeParams.bondSize = _bondSize;
    _disputeParams.maxNumberOfEscalations = 1;
    _disputeParams.bondEscalationDeadline = block.timestamp + 1 days;
    _disputeParams.tyingBuffer = block.timestamp + 1 days;
    _disputeParams.disputeWindow = block.number + 1 days;
    _requestData.disputeModuleData = abi.encode(_disputeParams);

    vm.prank(_arbitrator);
    _eboRequestCreator.setDisputeModuleData(address(_bondEscalationModule), _disputeParams);
  }

  function _approveModules(address _sender) internal {
    vm.startPrank(_sender);
    _accountingExtension.approveModule(address(_eboRequestModule));
    _accountingExtension.approveModule(address(_bondedResponseModule));
    _accountingExtension.approveModule(address(_bondEscalationModule));
    vm.stopPrank();
  }

  function _addChains() internal {
    vm.startPrank(_arbitrator);
    _eboRequestCreator.addChain(_chainId);
    vm.stopPrank();
  }
}
