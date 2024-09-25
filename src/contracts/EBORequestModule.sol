// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.26;

import {IModule, Module} from '@defi-wonderland/prophet-core/solidity/contracts/Module.sol';

import {EnumerableSet} from '@openzeppelin/contracts/utils/structs/EnumerableSet.sol';

import {IArbitrable, IEBORequestCreator, IEBORequestModule, IOracle} from 'interfaces/IEBORequestModule.sol';

/**
 * @title EBORequestModule
 * @notice Module allowing users to create a request for RPC data for a specific epoch
 */
contract EBORequestModule is Module, IEBORequestModule {
  using EnumerableSet for EnumerableSet.AddressSet;

  /// @inheritdoc IEBORequestModule
  IArbitrable public immutable ARBITRABLE;

  /**
   * @notice The set of EBORequestCreators allowed
   */
  EnumerableSet.AddressSet internal _eboRequestCreatorsAllowed;

  /**
   * @notice Constructor
   * @param _oracle The address of the Oracle
   * @param _eboRequestCreator The address of the EBORequestCreator
   * @param _arbitrable The address of the Arbitrable contract
   */
  constructor(IOracle _oracle, IEBORequestCreator _eboRequestCreator, IArbitrable _arbitrable) Module(_oracle) {
    _addEBORequestCreator(_eboRequestCreator);
    ARBITRABLE = _arbitrable;
  }

  /// @inheritdoc IEBORequestModule
  function createRequest(bytes32 _requestId, bytes calldata _data, address _requester) external onlyOracle {
    if (!_eboRequestCreatorsAllowed.contains(_requester)) revert EBORequestModule_InvalidRequester();

    RequestParameters memory _params = decodeRequestData(_data);

    // TODO: Bond for the rewards
  }

  /// @inheritdoc IEBORequestModule
  function finalizeRequest(
    IOracle.Request calldata _request,
    IOracle.Response calldata _response,
    address _finalizer
  ) external override(Module, IEBORequestModule) onlyOracle {
    if (!_eboRequestCreatorsAllowed.contains(_request.requester)) revert EBORequestModule_InvalidRequester();

    // TODO: Redeclare the `Request` struct
    // RequestParameters memory _params = decodeRequestData(_request.requestModuleData);

    if (_response.requestId != 0) {
      // TODO: Bond for the rewards
    }

    emit RequestFinalized(_response.requestId, _response, _finalizer);
  }

  /// @inheritdoc IEBORequestModule
  function addEBORequestCreator(IEBORequestCreator _eboRequestCreator) external {
    ARBITRABLE.validateArbitrator(msg.sender);
    _addEBORequestCreator(_eboRequestCreator);
  }

  /// @inheritdoc IEBORequestModule
  function removeEBORequestCreator(IEBORequestCreator _eboRequestCreator) external {
    ARBITRABLE.validateArbitrator(msg.sender);
    if (_eboRequestCreatorsAllowed.remove(address(_eboRequestCreator))) {
      emit RemoveEBORequestCreator(_eboRequestCreator);
    }
  }

  /// @inheritdoc IEBORequestModule
  function getAllowedEBORequestCreators() external view returns (address[] memory _eboRequestCreators) {
    _eboRequestCreators = _eboRequestCreatorsAllowed.values();
  }

  /// @inheritdoc IEBORequestModule
  function decodeRequestData(bytes calldata _data) public pure returns (RequestParameters memory _params) {
    _params = abi.decode(_data, (RequestParameters));
  }

  /// @inheritdoc IModule
  function validateParameters(bytes calldata _encodedParameters)
    external
    pure
    override(IModule, Module)
    returns (bool _valid)
  {
    RequestParameters memory _params = decodeRequestData(_encodedParameters);
    _valid =
      _params.epoch != 0 && bytes(_params.chainId).length != 0 && address(_params.accountingExtension) != address(0);
  }

  /// @inheritdoc IModule
  function moduleName() external pure returns (string memory _moduleName) {
    _moduleName = 'EBORequestModule';
  }

  /**
   * @notice Adds the address of the EBORequestCreator
   * @param _eboRequestCreator The address of the EBORequestCreator
   */
  function _addEBORequestCreator(IEBORequestCreator _eboRequestCreator) private {
    if (_eboRequestCreatorsAllowed.add(address(_eboRequestCreator))) {
      emit AddEBORequestCreator(_eboRequestCreator);
    }
  }
}
