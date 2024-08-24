// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.26;

import {IOracle, Oracle} from '@defi-wonderland/prophet-core/solidity/contracts/Oracle.sol';
import {ValidatorLib} from '@defi-wonderland/prophet-core/solidity/libraries/ValidatorLib.sol';
import {
  BondEscalationAccounting,
  IBondEscalationAccounting
} from '@defi-wonderland/prophet-modules/solidity/contracts/extensions/BondEscalationAccounting.sol';
import {
  BondedResponseModule,
  IBondedResponseModule
} from '@defi-wonderland/prophet-modules/solidity/contracts/modules/response/BondedResponseModule.sol';
import {IERC20} from '@openzeppelin/contracts/interfaces/IERC20.sol';

import {CouncilArbitrator, ICouncilArbitrator} from 'contracts/CouncilArbitrator.sol';
import {EBORequestCreator, IEBORequestCreator, IEpochManager} from 'contracts/EBORequestCreator.sol';
import {EBORequestModule, IEBORequestModule} from 'contracts/EBORequestModule.sol';

import {_EPOCH_MANAGER, _GRAPH_TOKEN} from '../Constants.sol';

import 'forge-std/Test.sol';

contract IntegrationBase is Test {
  using ValidatorLib for IOracle.Request;
  using ValidatorLib for IOracle.Response;

  uint256 internal constant _FORK_BLOCK = 240_000_000;

  // Oracle
  IOracle internal _oracle;

  // Modules
  IEBORequestModule internal _eboRequestModule;
  IBondedResponseModule internal _bondedResponseModule;

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

  // EOAs
  address internal _deployer = makeAddr('deployer');
  address internal _user = makeAddr('user');

  // Data
  IOracle.Request internal _requestData;
  IOracle.Response internal _responseData;
  IEBORequestModule.RequestParameters internal _requestParams;
  IBondedResponseModule.RequestParameters internal _responseParams;
  bytes32 internal _requestId;
  bytes32 internal _responseId;
  uint256 internal _bondSize;
  uint256 internal _currentEpoch;
  string internal _chainId = 'chainId1';

  function setUp() public virtual {
    vm.createSelectFork(vm.rpcUrl('arbitrum'), _FORK_BLOCK);
    vm.startPrank(_deployer);

    // Deploy GraphToken
    _graphToken = IERC20(_GRAPH_TOKEN);
    // Deploy EpochManager
    _epochManager = IEpochManager(_EPOCH_MANAGER);
    // Get the current epoch
    _currentEpoch = _epochManager.currentEpoch();

    // Deploy Oracle
    _oracle = new Oracle();

    // Get nonce of the deployment EBORequestModule
    uint256 _nonce = vm.getNonce(_deployer) + 1;
    address _preComputedEboRequestModule = vm.computeCreateAddress(_deployer, _nonce);
    // TODO: Why precompute?

    // Deploy EBORequestCreator
    _eboRequestCreator = new EBORequestCreator(_oracle, _epochManager, _arbitrator, _council, _requestData);

    // Deploy EBORequestModule
    _eboRequestModule = new EBORequestModule(_oracle, _eboRequestCreator, _arbitrator, _council);

    // Deploy BondedResponseModule
    _bondedResponseModule = new BondedResponseModule(_oracle);

    // Deploy AccountingExtension
    _accountingExtension = new BondEscalationAccounting(_oracle);

    vm.stopPrank();
  }

  function _createRequest() internal {
    string[] memory _chainIds = _getChainIds();

    _requestParams.epoch = _currentEpoch;
    _requestParams.chainId = _chainId;
    _requestData.requestModuleData = abi.encode(_requestParams);

    _requestId = _requestData._getId();

    vm.prank(_user);
    _eboRequestCreator.createRequests(_currentEpoch, _chainIds);
  }

  function _proposeResponse() internal {
    _responseData.proposer = _user;
    _responseData.requestId = _requestId;
    _responseData.response = abi.encode(''); // TODO: Populate response

    _responseId = _responseData._getId();

    vm.prank(_user);
    _oracle.proposeResponse(_requestData, _responseData);
  }

  function _setRequestModuleData() internal {
    _requestData.nonce = 0;
    _requestData.requester = address(_eboRequestCreator);
    _requestData.requestModule = address(_eboRequestModule);

    _requestParams.accountingExtension = _accountingExtension;
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

  function _approveModules() internal {
    vm.startPrank(_user);
    _accountingExtension.approveModule(address(_eboRequestModule));
    _accountingExtension.approveModule(address(_bondedResponseModule));
    vm.stopPrank();
  }

  function _addChains() internal {
    string[] memory _chainIds = _getChainIds();

    vm.startPrank(_arbitrator);
    for (uint256 _i; _i < _chainIds.length; ++_i) {
      _eboRequestCreator.addChain(_chainIds[_i]);
    }
    vm.stopPrank();
  }

  function _getChainIds() internal view returns (string[] memory _chainIds) {
    _chainIds = new string[](1);
    _chainIds[0] = _chainId;
  }
}
