// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.26;

import {Module} from '@defi-wonderland/prophet-core/solidity/contracts/Module.sol';
import {IModule} from '@defi-wonderland/prophet-core/solidity/interfaces/IModule.sol';
import {IOracle} from '@defi-wonderland/prophet-core/solidity/interfaces/IOracle.sol';

import {IArbitrable, IEBOFinalityModule} from 'interfaces/IEBOFinalityModule.sol';
import {IEBORequestCreator} from 'interfaces/IEBORequestCreator.sol';

/**
 * @title EBOFinalityModule
 * @notice Module allowing users to index data into the subgraph
 * as a result of a request being finalized
 */
contract EBOFinalityModule is Module, IEBOFinalityModule {
  /// @inheritdoc IEBOFinalityModule
  IArbitrable public immutable ARBITRABLE;

  /// @inheritdoc IEBOFinalityModule
  mapping(IEBORequestCreator _eboRequestCreator => bool _enabled) public enabledEBORequestCreators;

  /**
   * @notice Constructor
   * @param _oracle The address of the Oracle
   * @param _eboRequestCreator The address of the EBORequestCreator
   * @param _arbitrable The address of the Arbitrable contract
   */
  constructor(IOracle _oracle, IEBORequestCreator _eboRequestCreator, IArbitrable _arbitrable) Module(_oracle) {
    _setEBORequestCreator(_eboRequestCreator);
    ARBITRABLE = _arbitrable;
  }

  /// @inheritdoc IEBOFinalityModule
  function finalizeRequest(
    IOracle.Request calldata _request,
    IOracle.Response calldata _response,
    address _finalizer
  ) external override(Module, IEBOFinalityModule) onlyOracle {
    if (!enabledEBORequestCreators[IEBORequestCreator(_request.requester)]) revert EBOFinalityModule_InvalidRequester();

    if (_response.requestId != 0) {
      ResponseParameters memory _params = decodeResponseData(_response.response);
      emit NewEpoch(_params.epoch, _params.chainId, _params.block);
    }

    emit RequestFinalized(_response.requestId, _response, _finalizer);
  }

  /// @inheritdoc IEBOFinalityModule
  function amendEpoch(uint256 _epoch, string[] calldata _chainIds, uint256[] calldata _blockNumbers) external {
    ARBITRABLE.validateArbitrator(msg.sender);

    uint256 _length = _chainIds.length;
    if (_length != _blockNumbers.length) revert EBOFinalityModule_LengthMismatch();

    for (uint256 _i; _i < _length; ++_i) {
      emit AmendEpoch(_epoch, _chainIds[_i], _blockNumbers[_i]);
    }
  }

  /// @inheritdoc IEBOFinalityModule
  function setEBORequestCreator(IEBORequestCreator _eboRequestCreator) external {
    ARBITRABLE.validateArbitrator(msg.sender);
    _setEBORequestCreator(_eboRequestCreator);
  }

  function removeEBORequestCreator(IEBORequestCreator _eboRequestCreator) external {
    ARBITRABLE.validateArbitrator(msg.sender);
    delete enabledEBORequestCreators[_eboRequestCreator];
    emit RemoveEBORequestCreator(_eboRequestCreator);
  }

  /// @inheritdoc IModule
  function moduleName() external pure returns (string memory _moduleName) {
    _moduleName = 'EBOFinalityModule';
  }

  /// @inheritdoc IEBOFinalityModule
  function decodeResponseData(bytes calldata _data) public pure returns (ResponseParameters memory _params) {
    _params = abi.decode(_data, (ResponseParameters));
  }

  /**
   * @notice Sets the address of the EBORequestCreator
   * @param _eboRequestCreator The address of the EBORequestCreator
   */
  function _setEBORequestCreator(IEBORequestCreator _eboRequestCreator) private {
    enabledEBORequestCreators[_eboRequestCreator] = true;
    emit SetEBORequestCreator(_eboRequestCreator);
  }
}
