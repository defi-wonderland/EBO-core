// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Module} from '@defi-wonderland/prophet-core/solidity/contracts/Module.sol';
import {IModule} from '@defi-wonderland/prophet-core/solidity/interfaces/IModule.sol';
import {IOracle} from '@defi-wonderland/prophet-core/solidity/interfaces/IOracle.sol';

import {Arbitrable} from 'contracts/Arbitrable.sol';
import {IEBOFinalityModule} from 'interfaces/IEBOFinalityModule.sol';

/**
 * @title EBOFinalityModule
 * @notice Module allowing users to index data into the subgraph
 * as a result of a request being finalized
 */
contract EBOFinalityModule is Module, Arbitrable, IEBOFinalityModule {
  /// @inheritdoc IEBOFinalityModule
  address public eboRequestCreator;

  /**
   * @notice Constructor
   * @param _oracle The address of the Oracle
   * @param _eboRequestCreator The address of the EBORequestCreator
   * @param _arbitrator The address of The Graph's Arbitrator
   * @param _council The address of The Graph's Council
   */
  constructor(
    IOracle _oracle,
    address _eboRequestCreator,
    address _arbitrator,
    address _council
  ) Module(_oracle) Arbitrable(_arbitrator, _council) {
    _setEBORequestCreator(_eboRequestCreator);
  }

  /// @inheritdoc IEBOFinalityModule
  function finalizeRequest(
    IOracle.Request calldata _request,
    IOracle.Response calldata _response,
    address _finalizer
  ) external override(Module, IEBOFinalityModule) onlyOracle {
    if (_request.requester != eboRequestCreator) revert EBOFinalityModule_InvalidRequester();

    if (_response.requestId != 0) {
      // TODO: Redeclare the `Response` struct
      // emit NewEpoch(_response.epoch, _response.chainId, _response.block);
    }

    emit RequestFinalized(_response.requestId, _response, _finalizer);
  }

  /// @inheritdoc IEBOFinalityModule
  function amendEpoch(
    uint256 _epoch,
    string[] calldata _chainIds,
    uint256[] calldata _blockNumbers
  ) external onlyArbitrator {
    uint256 _length = _chainIds.length;
    if (_length != _blockNumbers.length) revert EBOFinalityModule_LengthMismatch();

    for (uint256 _i; _i < _length; ++_i) {
      emit AmendEpoch(_epoch, _chainIds[_i], _blockNumbers[_i]);
    }
  }

  /// @inheritdoc IEBOFinalityModule
  function setEBORequestCreator(address _eboRequestCreator) external onlyArbitrator {
    _setEBORequestCreator(_eboRequestCreator);
  }

  /// @inheritdoc IModule
  function moduleName() external pure returns (string memory _moduleName) {
    _moduleName = 'EBOFinalityModule';
  }

  /**
   * @notice Sets the address of the EBORequestCreator
   * @param _eboRequestCreator The address of the EBORequestCreator
   */
  function _setEBORequestCreator(address _eboRequestCreator) private {
    eboRequestCreator = _eboRequestCreator;
    emit SetEBORequestCreator(_eboRequestCreator);
  }
}
