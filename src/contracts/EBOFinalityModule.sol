// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Module} from '@defi-wonderland/prophet-core-contracts/solidity/contracts/Module.sol';

import {IModule} from '@defi-wonderland/prophet-core-contracts/solidity/interfaces/IModule.sol';
import {IOracle} from '@defi-wonderland/prophet-core-contracts/solidity/interfaces/IOracle.sol';

import {IEBOFinalityModule} from 'interfaces/IEBOFinalityModule.sol';

/**
 * @title EBOFinalityModule
 * @notice Module allowing users to index data into the subgraph
 * as a result of a request being finalized
 */
contract EBOFinalityModule is Module, IEBOFinalityModule {
  /// @inheritdoc IEBOFinalityModule
  address public immutable ARBITRATOR;

  /**
   * @notice Constructor
   * @param _oracle The address of the oracle
   * @param _arbitrator The address of The Graph's Arbitrator
   */
  constructor(IOracle _oracle, address _arbitrator) Module(_oracle) {
    ARBITRATOR = _arbitrator;
  }

  /**
   * @notice Checks that the caller is The Graph's Arbitrator
   */
  modifier onlyArbitrator() {
    if (msg.sender != ARBITRATOR) revert EBOFinalityModule_OnlyArbitrator();
    _;
  }

  /// @inheritdoc IModule
  function moduleName() public pure returns (string memory _moduleName) {
    _moduleName = 'EBOFinalityModule';
  }

  /// @inheritdoc IEBOFinalityModule
  function finalizeRequest(
    IOracle.Request calldata _request,
    IOracle.Response calldata _response,
    address _finalizer
  ) external override(Module, IEBOFinalityModule) onlyOracle {
    emit RequestFinalized(_response.requestId, _response, _finalizer);
    // emit NewEpoch(_response.epoch, _response.chainId, _response.block);
  }

  /// @inheritdoc IEBOFinalityModule
  function amendEpoch(
    uint256 _epoch,
    uint256[] calldata _chainIds,
    uint256[] calldata _blockNumbers
  ) external onlyArbitrator {
    uint256 _length = _chainIds.length;
    if (_length != _blockNumbers.length) revert EBOFinalityModule_LengthMismatch();

    for (uint256 i; i < _length; ++i) {
      emit AmendEpoch(_epoch, _chainIds[i], _blockNumbers[i]);
    }
  }
}
