// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.26;

import {Module} from '@defi-wonderland/prophet-core/solidity/contracts/Module.sol';
import {IModule} from '@defi-wonderland/prophet-core/solidity/interfaces/IModule.sol';
import {IOracle} from '@defi-wonderland/prophet-core/solidity/interfaces/IOracle.sol';

import {Arbitrable} from 'contracts/Arbitrable.sol';
import {IEBORequestCreator} from 'interfaces/IEBORequestCreator.sol';
import {IEBORequestModule} from 'interfaces/IEBORequestModule.sol';

/**
 * @title EBORequestModule
 * @notice Module allowing users to create a request for RPC data for a specific epoch
 */
contract EBORequestModule is Module, Arbitrable, IEBORequestModule {
  /// @inheritdoc IEBORequestModule
  IEBORequestCreator public eboRequestCreator;

  /**
   * @notice Constructor
   * @param _oracle The address of the Oracle
   * @param _eboRequestCreator The address of the EBORequestCreator
   * @param _arbitrator The address of The Graph's Arbitrator
   * @param _council The address of The Graph's Council
   */
  constructor(
    IOracle _oracle,
    IEBORequestCreator _eboRequestCreator,
    address _arbitrator,
    address _council
  ) Module(_oracle) Arbitrable(_arbitrator, _council) {
    _setEBORequestCreator(_eboRequestCreator);
  }

  /// @inheritdoc IEBORequestModule
  function createRequest(bytes32 _requestId, bytes calldata _data, address _requester) external onlyOracle {
    if (_requester != address(eboRequestCreator)) revert EBORequestModule_InvalidRequester();

    RequestParameters memory _params = decodeRequestData(_data);

    // TODO: Bond for the rewards
  }

  /// @inheritdoc IEBORequestModule
  function finalizeRequest(
    IOracle.Request calldata _request,
    IOracle.Response calldata _response,
    address _finalizer
  ) external override(Module, IEBORequestModule) onlyOracle {
    if (_request.requester != address(eboRequestCreator)) revert EBORequestModule_InvalidRequester();

    // TODO: Redeclare the `Request` struct
    // RequestParameters memory _params = decodeRequestData(_request.requestModuleData);

    if (_response.requestId != 0) {
      // TODO: Bond for the rewards
    }

    emit RequestFinalized(_response.requestId, _response, _finalizer);
  }

  /// @inheritdoc IEBORequestModule
  function setEBORequestCreator(IEBORequestCreator _eboRequestCreator) external onlyArbitrator {
    _setEBORequestCreator(_eboRequestCreator);
  }

  /// @inheritdoc IModule
  function validateParameters(
    bytes calldata _encodedParameters
  ) external pure override(IModule, Module) returns (bool _valid) {
    RequestParameters memory _params = decodeRequestData(_encodedParameters);
    _valid =
      _params.epoch != 0 && bytes(_params.chainId).length != 0 && address(_params.accountingExtension) != address(0);
  }

  /// @inheritdoc IModule
  function moduleName() external pure returns (string memory _moduleName) {
    _moduleName = 'EBORequestModule';
  }

  /// @inheritdoc IEBORequestModule
  function decodeRequestData(bytes calldata _data) public pure returns (RequestParameters memory _params) {
    _params = abi.decode(_data, (RequestParameters));
  }

  /**
   * @notice Sets the address of the EBORequestCreator
   * @param _eboRequestCreator The address of the EBORequestCreator
   */
  function _setEBORequestCreator(IEBORequestCreator _eboRequestCreator) private {
    eboRequestCreator = _eboRequestCreator;
    emit SetEBORequestCreator(_eboRequestCreator);
  }
}
