// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Module} from '@defi-wonderland/prophet-core/solidity/contracts/Module.sol';
import {IModule} from '@defi-wonderland/prophet-core/solidity/interfaces/IModule.sol';
import {IOracle} from '@defi-wonderland/prophet-core/solidity/interfaces/IOracle.sol';

import {Arbitrable} from 'contracts/Arbitrable.sol';
import {IEBORequestModule} from 'interfaces/IEBORequestModule.sol';

/**
 * @title EBORequestModule
 * @notice Module allowing users to fetch epoch block data from the oracle
 * as a result of a request being created
 */
contract EBORequestModule is Module, Arbitrable, IEBORequestModule {
  /// @inheritdoc IEBORequestModule
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

  /// @inheritdoc IEBORequestModule
  function createRequest(bytes32 _requestId, bytes calldata _data, address _requester) external onlyOracle {
    if (_requester != eboRequestCreator) revert EBORequestModule_InvalidRequester();

    RequestParameters memory _params = decodeRequestData(_data);

    // TODO: Bond for the rewards
  }

  /// @inheritdoc IEBORequestModule
  function finalizeRequest(
    IOracle.Request calldata _request,
    IOracle.Response calldata _response,
    address _finalizer
  ) external override(Module, IEBORequestModule) onlyOracle {
    if (_request.requester != eboRequestCreator) revert EBORequestModule_InvalidRequester();

    // TODO: Redeclare the `Request` struct
    // RequestParameters memory _params = decodeRequestData(_request.requestModuleData);

    if (_response.requestId != 0) {
      _validateResponse(_request, _response);

      // TODO: Bond for the rewards
    }

    emit RequestFinalized(_response.requestId, _response, _finalizer);
  }
  // TODO: string chainId

  /// @inheritdoc IEBORequestModule
  function setEBORequestCreator(address _eboRequestCreator) external onlyArbitrator {
    _setEBORequestCreator(_eboRequestCreator);
  }

  /// @inheritdoc IModule
  function validateParameters(
    bytes calldata _encodedParameters
  ) external pure override(IModule, Module) returns (bool _valid) {
    RequestParameters memory _params = decodeRequestData(_encodedParameters);
    _valid = _params.epoch != 0 && _params.chainId != 0 && address(_params.accountingExtension) != address(0);
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
  function _setEBORequestCreator(address _eboRequestCreator) private {
    eboRequestCreator = _eboRequestCreator;
    emit SetEBORequestCreator(_eboRequestCreator);
  }
}
