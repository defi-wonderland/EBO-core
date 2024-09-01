// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.26;

import {Oracle} from '@defi-wonderland/prophet-core/solidity/contracts/Oracle.sol';
import {BondEscalationAccounting} from
  '@defi-wonderland/prophet-modules/solidity/contracts/extensions/BondEscalationAccounting.sol';
import {BondEscalationModule} from
  '@defi-wonderland/prophet-modules/solidity/contracts/modules/dispute/BondEscalationModule.sol';
import {ArbitratorModule} from
  '@defi-wonderland/prophet-modules/solidity/contracts/modules/resolution/ArbitratorModule.sol';
import {BondedResponseModule} from
  '@defi-wonderland/prophet-modules/solidity/contracts/modules/response/BondedResponseModule.sol';
import {IEpochManager} from 'interfaces/external/IEpochManager.sol';

import {CouncilArbitrator} from 'contracts/CouncilArbitrator.sol';
import {EBOFinalityModule} from 'contracts/EBOFinalityModule.sol';
import {EBORequestCreator} from 'contracts/EBORequestCreator.sol';
import {EBORequestModule} from 'contracts/EBORequestModule.sol';

import {Deploy} from 'script/Deploy.s.sol';

import {_ARBITRATOR, _COUNCIL, _DEPLOYER, _EPOCH_MANAGER, _GRAPH_TOKEN} from 'script/Constants.sol';

import 'forge-std/Test.sol';

contract UnitDeploy is Test {
  Deploy public deploy;

  function setUp() public {
    deploy = new Deploy();
  }

  function test_SetUpShouldDefineTheGraphAccounts() public {
    deploy.setUp();

    // it should define The Graph accounts
    assertEq(address(deploy.graphToken()).code, _GRAPH_TOKEN.code);
    assertEq(address(deploy.epochManager()).code, _EPOCH_MANAGER.code);
    assertEq(address(deploy.arbitrator()), _ARBITRATOR);
    assertEq(address(deploy.council()), _COUNCIL);
    assertEq(address(deploy.deployer()), _DEPLOYER);
  }

  function test_RunRevertGiven_TheGraphAccountsAreNotSetUp() public {
    // it should revert
    vm.expectRevert();
    deploy.run();
  }

  function test_RunGivenTheGraphAccountsAreSetUp(uint256 _currentEpoch) public {
    vm.mockCall(_EPOCH_MANAGER, abi.encodeCall(IEpochManager.currentEpoch, ()), abi.encode(_currentEpoch));

    deploy.setUp();
    deploy.run();

    // it should deploy Oracle
    assertEq(address(deploy.oracle()).code, type(Oracle).runtimeCode);

    // it should deploy EBORequestModule with correct args
    // BUG: Error (9274): "runtimeCode" is not available for contracts containing immutable variables.
    // assertEq(address(deploy.eboRequestModule()).code, type(EBORequestModule).runtimeCode);
    assertEq(address(deploy.eboRequestModule().ORACLE()), address(deploy.oracle()));
    assertEq(address(deploy.eboRequestModule().eboRequestCreator()), address(deploy.eboRequestCreator()));
    assertEq(address(deploy.eboRequestModule().arbitrator()), address(deploy.arbitrator()));
    assertEq(address(deploy.eboRequestModule().council()), address(deploy.council()));

    // it should deploy BondedResponseModule with correct args
    // BUG: Error (9274): "runtimeCode" is not available for contracts containing immutable variables.
    // assertEq(address(deploy.bondedResponseModule()).code, type(BondedResponseModule).runtimeCode);
    assertEq(address(deploy.bondedResponseModule().ORACLE()), address(deploy.oracle()));

    // it should deploy BondEscalationModule with correct args
    // BUG: Error (9274): "runtimeCode" is not available for contracts containing immutable variables.
    // assertEq(address(deploy.bondEscalationModule()).code, type(BondEscalationModule).runtimeCode);
    assertEq(address(deploy.bondEscalationModule().ORACLE()), address(deploy.oracle()));

    // it should deploy ArbitratorModule with correct args
    // BUG: Error (9274): "runtimeCode" is not available for contracts containing immutable variables.
    // assertEq(address(deploy.arbitratorModule()).code, type(ArbitratorModule).runtimeCode);
    assertEq(address(deploy.arbitratorModule().ORACLE()), address(deploy.oracle()));

    // it should deploy EBOFinalityModule with correct args
    // BUG: Error (9274): "runtimeCode" is not available for contracts containing immutable variables.
    // assertEq(address(deploy.eboFinalityModule()).code, type(EBOFinalityModule).runtimeCode);
    assertEq(address(deploy.eboFinalityModule().ORACLE()), address(deploy.oracle()));
    assertEq(address(deploy.eboFinalityModule().eboRequestCreator()), address(deploy.eboRequestCreator()));
    assertEq(address(deploy.eboFinalityModule().arbitrator()), address(deploy.arbitrator()));
    assertEq(address(deploy.eboFinalityModule().council()), address(deploy.council()));

    // it should deploy BondEscalationAccounting with correct args
    // BUG: Error (9274): "runtimeCode" is not available for contracts containing immutable variables.
    // assertEq(address(deploy.bondEscalationAccounting()).code, type(BondEscalationAccounting).runtimeCode);
    assertEq(address(deploy.bondEscalationAccounting().ORACLE()), address(deploy.oracle()));

    // it should deploy EBORequestCreator with correct args
    // BUG: Error (9274): "runtimeCode" is not available for contracts containing immutable variables.
    // assertEq(address(deploy.eboRequestCreator()).code, type(EBORequestCreator).runtimeCode);
    assertEq(address(deploy.eboRequestCreator().ORACLE()), address(deploy.oracle()));
    assertEq(address(deploy.eboRequestCreator().epochManager()), address(deploy.epochManager()));
    assertEq(address(deploy.eboRequestCreator().arbitrator()), address(deploy.arbitrator()));
    assertEq(address(deploy.eboRequestCreator().council()), address(deploy.council()));
    assertEq(abi.encode(deploy.eboRequestCreator().getRequestData()), abi.encode(deploy.getRequestData()));

    // it should deploy CouncilArbitrator with correct args
    // BUG: Error (9274): "runtimeCode" is not available for contracts containing immutable variables.
    // assertEq(address(deploy.councilArbitrator()).code, type(CouncilArbitrator).runtimeCode);
    assertEq(address(deploy.councilArbitrator().ARBITRATOR_MODULE()), address(deploy.arbitratorModule()));
    assertEq(address(deploy.councilArbitrator().arbitrator()), address(deploy.arbitrator()));
    assertEq(address(deploy.councilArbitrator().council()), address(deploy.council()));
  }
}
