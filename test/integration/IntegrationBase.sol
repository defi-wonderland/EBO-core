// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import {Test} from 'forge-std/Test.sol';
import {IERC20} from 'forge-std/interfaces/IERC20.sol';

import {Oracle} from '@defi-wonderland/prophet-core/solidity/contracts/Oracle.sol';
import {EBORequestCreator, IEBORequestCreator, IEpochManager, IOracle} from 'contracts/EBORequestCreator.sol';

contract IntegrationBase is Test {
  uint256 internal constant _FORK_BLOCK = 18_920_905;

  address internal _arbitrator = makeAddr('arbitrator');
  address internal _council = makeAddr('council');
  address internal _owner = makeAddr('owner');
  address internal _user = makeAddr('user');

  IEBORequestCreator internal _eboRequestCreator;
  IOracle internal _oracle;
  IEpochManager internal _epochManager;

  function setUp() public {
    vm.createSelectFork(vm.rpcUrl('mainnet'), _FORK_BLOCK);
    vm.startPrank(_owner);

    _oracle = new Oracle();

    // TODO: Replace with the implementation
    vm.mockCall(address(_epochManager), abi.encodeWithSelector(IEpochManager.currentEpoch.selector), abi.encode(0));
    _eboRequestCreator = new EBORequestCreator(_oracle, _epochManager, _arbitrator, _council);

    vm.stopPrank();
  }
}
