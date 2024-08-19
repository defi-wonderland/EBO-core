// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.26;

import {IOracle} from '@defi-wonderland/prophet-core/solidity/interfaces/IOracle.sol';
import {IArbitrator} from '@defi-wonderland/prophet-modules/solidity/interfaces/IArbitrator.sol';
import {IArbitratorModule} from
  '@defi-wonderland/prophet-modules/solidity/interfaces/modules/resolution/IArbitratorModule.sol';

import {Arbitrable} from 'contracts/Arbitrable.sol';
import {ICouncilArbitrator} from 'interfaces/ICouncilArbitrator.sol';

/**
 * @title CouncilArbitrator
 * @notice Resolves disputes by arbitration by The Graph
 */
contract CouncilArbitrator is Arbitrable, ICouncilArbitrator {
  /// @inheritdoc ICouncilArbitrator
  IOracle public immutable ORACLE;
  /// @inheritdoc ICouncilArbitrator
  IArbitratorModule public immutable ARBITRATOR_MODULE;

  /// @inheritdoc IArbitrator
  mapping(bytes32 _disputeId => IOracle.DisputeStatus _status) public getAnswer;

  /**
   * @notice Checks that the caller is the Arbitrator Module
   */
  modifier onlyArbitratorModule() {
    if (msg.sender != address(ARBITRATOR_MODULE)) revert CouncilArbitrator_OnlyArbitratorModule();
    _;
  }

  /**
   * @notice Constructor
   * @param _arbitratorModule The address of the Arbitrator Module
   * @param _arbitrator The address of The Graph's Arbitrator
   * @param _council The address of The Graph's Council
   */
  constructor(
    IArbitratorModule _arbitratorModule,
    address _arbitrator,
    address _council
  ) Arbitrable(_arbitrator, _council) {
    ORACLE = _arbitratorModule.ORACLE();
    ARBITRATOR_MODULE = _arbitratorModule;
  }

  /// @inheritdoc IArbitrator
  function resolve(
    IOracle.Request memory _request,
    IOracle.Response memory _response,
    IOracle.Dispute memory _dispute
  ) external onlyArbitratorModule returns (bytes memory /* _data */ ) {
    // TODO: Emit event with params? Save params locally?
  }

  /// @inheritdoc ICouncilArbitrator
  function resolveDispute(bytes32 _disputeId, IOracle.DisputeStatus _status) external onlyArbitrator {
    // TODO: Checks?

    getAnswer[_disputeId] = _status;

    // TODO: Provide or fetch params?
    // ORACLE.resolveDispute(_request, _response, _dispute);
    // ORACLE.finalize(_request, _response);

    emit DisputeResolved(_disputeId, _status);
  }
}
