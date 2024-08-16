// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.26;

import {_EPOCH_MANAGER} from '../Constants.sol';
import {Test} from 'forge-std/Test.sol';

import {Oracle} from '@defi-wonderland/prophet-core/solidity/contracts/Oracle.sol';
import {EBORequestCreator, IEBORequestCreator, IEpochManager, IOracle} from 'contracts/EBORequestCreator.sol';
import {EBORequestModule, IEBORequestModule} from 'contracts/EBORequestModule.sol';

contract IntegrationBase is Test {
  uint256 internal constant _FORK_BLOCK = 240_000_000;

  // Addresses
  address internal _arbitrator = makeAddr('arbitrator');
  address internal _council = makeAddr('council');
  address internal _owner = makeAddr('owner');
  address internal _user = makeAddr('user');

  // Data
  IOracle.Request _requestData;

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

    _requestData.nonce = 0;
    // Deploy EBORequestCreator
    _eboRequestCreator = new EBORequestCreator(_oracle, _epochManager, _arbitrator, _council, _requestData);

    // Deploy EBORequestModule
    _eboRequestModule = new EBORequestModule(_oracle, _eboRequestCreator, _arbitrator, _council);

    vm.stopPrank();

    vm.prank(_arbitrator);
    _eboRequestCreator.setRequestModuleData(address(_eboRequestModule), bytes(''));
  }
}
