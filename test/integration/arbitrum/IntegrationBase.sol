// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.26;

import {_EPOCH_MANAGER} from '../Constants.sol';
import {Test} from 'forge-std/Test.sol';

import {Oracle} from '@defi-wonderland/prophet-core/solidity/contracts/Oracle.sol';
import {IAccountingExtension} from
  '@defi-wonderland/prophet-modules/solidity/interfaces/extensions/IAccountingExtension.sol';
import {EBORequestCreator, IEBORequestCreator, IEpochManager, IOracle} from 'contracts/EBORequestCreator.sol';
import {EBORequestModule, IEBORequestModule} from 'contracts/EBORequestModule.sol';

contract IntegrationBase is Test {
  uint256 internal constant _FORK_BLOCK = 240_000_000;

  // Addresses
  address internal _arbitrator = makeAddr('arbitrator');
  address internal _council = makeAddr('council');
  address internal _owner = makeAddr('owner');
  address internal _user = makeAddr('user');
  IAccountingExtension internal _accountingExtension = IAccountingExtension(makeAddr('accountingExtension'));

  // Data
  IOracle.Request internal _requestData;
  IEBORequestModule.RequestParameters internal _requestParams;

  // Contracts
  IEBORequestCreator internal _eboRequestCreator;
  IEBORequestModule internal _eboRequestModule;
  IOracle internal _oracle;
  IEpochManager internal _epochManager;

  function setUp() public {
    vm.createSelectFork(vm.rpcUrl('arbitrum'), _FORK_BLOCK);
    vm.startPrank(_owner);

    // Deploy Oracle
    _oracle = new Oracle();

    // Deploy EpochManager
    _epochManager = IEpochManager(_EPOCH_MANAGER);

    // Get nonce of the deployment EBORequestModule
    uint256 _nonce = vm.getNonce(_owner) + 1;

    address _preComputedEboRequestModule = vm.computeCreateAddress(_owner, _nonce);

    // Create data
    _requestParams.accountingExtension = _accountingExtension;

    _requestData.nonce = 0;
    _requestData.requestModule = _preComputedEboRequestModule;
    _requestData.requestModuleData = abi.encode(_requestParams);

    // Deploy EBORequestCreator
    _eboRequestCreator = new EBORequestCreator(_oracle, _epochManager, _arbitrator, _council, _requestData);

    // Deploy EBORequestModule
    _eboRequestModule = new EBORequestModule(_oracle, _eboRequestCreator, _arbitrator, _council);

    vm.stopPrank();
  }
}
