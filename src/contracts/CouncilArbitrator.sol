// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.26;

import {IOracle} from '@defi-wonderland/prophet-core/solidity/interfaces/IOracle.sol';
import {ValidatorLib} from '@defi-wonderland/prophet-core/solidity/libraries/ValidatorLib.sol';
import {IArbitrator} from '@defi-wonderland/prophet-modules/solidity/interfaces/IArbitrator.sol';
import {IArbitratorModule} from
  '@defi-wonderland/prophet-modules/solidity/interfaces/modules/resolution/IArbitratorModule.sol';

import {IArbitrable, ICouncilArbitrator} from 'interfaces/ICouncilArbitrator.sol';

/**
 * @title CouncilArbitrator
 * @notice Resolves disputes by arbitration by The Graph
 */
contract CouncilArbitrator is ICouncilArbitrator {
  using ValidatorLib for IOracle.Dispute;

  /// @inheritdoc ICouncilArbitrator
  IOracle public immutable ORACLE;
  /// @inheritdoc ICouncilArbitrator
  IArbitratorModule public immutable ARBITRATOR_MODULE;
  /// @inheritdoc ICouncilArbitrator
  IArbitrable public immutable ARBITRABLE;

  /// @inheritdoc ICouncilArbitrator
  mapping(bytes32 _disputeId => ResolutionParameters _resolutionParams) public resolutions;
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
   * @param _arbitrable The address of the Arbitrable contract
   */
  constructor(IArbitratorModule _arbitratorModule, IArbitrable _arbitrable) {
    ORACLE = _arbitratorModule.ORACLE();
    ARBITRATOR_MODULE = _arbitratorModule;
    ARBITRABLE = _arbitrable;
  }

  /// @inheritdoc IArbitrator
  function resolve(
    IOracle.Request calldata _request,
    IOracle.Response calldata _response,
    IOracle.Dispute calldata _dispute
  ) external onlyArbitratorModule returns (bytes memory /* _data */ ) {
    bytes32 _disputeId = _dispute._getId();

    resolutions[_disputeId] = ResolutionParameters(_request, _response, _dispute);

    emit ResolutionStarted(_disputeId, _request, _response, _dispute);
  }

  /// @inheritdoc ICouncilArbitrator
  function resolveDispute(bytes32 _disputeId, IOracle.DisputeStatus _status) external {
    ARBITRABLE.validateArbitrator(msg.sender);

    ResolutionParameters memory _resolutionParams = resolutions[_disputeId];

    if (_resolutionParams.dispute.disputer == address(0)) revert CouncilArbitrator_InvalidResolution();
    if (_status <= IOracle.DisputeStatus.Escalated) revert CouncilArbitrator_InvalidResolutionStatus();
    if (getAnswer[_disputeId] != IOracle.DisputeStatus.None) revert CouncilArbitrator_DisputeAlreadyResolved();

    getAnswer[_disputeId] = _status;

    ORACLE.resolveDispute(_resolutionParams.request, _resolutionParams.response, _resolutionParams.dispute);
    ORACLE.finalize(_resolutionParams.request, _resolutionParams.response);

    emit DisputeResolved(_disputeId, _status);
  }

  /// @inheritdoc ICouncilArbitrator
  function getResolution(bytes32 _disputeId) external view returns (ResolutionParameters memory _resolutionParams) {
    _resolutionParams = resolutions[_disputeId];
  }
}
