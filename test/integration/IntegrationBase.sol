// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import {Test} from 'forge-std/Test.sol';
import {IERC20} from 'forge-std/interfaces/IERC20.sol';

import {Oracle} from '@defi-wonderland/prophet-core/solidity/contracts/Oracle.sol';
import {EBORequestCreator, IEBORequestCreator, IOracle} from 'contracts/EBORequestCreator.sol';

contract IntegrationBase is Test {
  uint256 internal constant _FORK_BLOCK = 18_920_905;

  address internal _arbitrator = makeAddr('arbitrator');
  address internal _council = makeAddr('council');
  address internal _owner = makeAddr('owner');
  address internal _user = makeAddr('user');

  IOracle.Request _requestData;

  IEBORequestCreator internal _eboRequestCreator;
  IOracle internal _oracle;

  function setUp() public {
    vm.createSelectFork(vm.rpcUrl('mainnet'), _FORK_BLOCK);
    vm.startPrank(_owner);

    _oracle = new Oracle();

    _requestData.nonce = 0;
    // TODO: Replace with the implementation
    _eboRequestCreator = new EBORequestCreator(_oracle, _arbitrator, _council, _requestData);

    vm.stopPrank();
  }
}
