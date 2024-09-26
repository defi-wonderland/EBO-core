// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.26;

import {IModule, Module} from '@defi-wonderland/prophet-core/solidity/contracts/Module.sol';

import {EnumerableSet} from '@openzeppelin/contracts/utils/structs/EnumerableSet.sol';

import {
  IArbitrable,
  IEBOFinalityModule,
  IEBORequestCreator,
  IEBORequestModule,
  IOracle
} from 'interfaces/IEBOFinalityModule.sol';

/**
 * @title EBOFinalityModule
 * @notice Module allowing users to index data into the subgraph
 * as a result of a request being finalized
 */
contract EBOFinalityModule is Module, IEBOFinalityModule {
  using EnumerableSet for EnumerableSet.AddressSet;

  /// @inheritdoc IEBOFinalityModule
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

  /// @inheritdoc IEBOFinalityModule
  function finalizeRequest(
    IOracle.Request calldata _request,
    IOracle.Response calldata _response,
    address _finalizer
  ) external override(Module, IEBOFinalityModule) onlyOracle {
    if (!_eboRequestCreatorsAllowed.contains(address(_request.requester))) revert EBOFinalityModule_InvalidRequester();

    if (_response.requestId != 0) {
      IEBORequestModule.RequestParameters memory _requestParams = decodeRequestData(_request.requestModuleData);
      uint256 _block = decodeResponseData(_response.response);

      emit NewEpoch(_requestParams.epoch, _requestParams.chainId, _block);
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
  function addEBORequestCreator(IEBORequestCreator _eboRequestCreator) external {
    ARBITRABLE.validateArbitrator(msg.sender);
    _addEBORequestCreator(_eboRequestCreator);
  }

  /// @inheritdoc IEBOFinalityModule
  function removeEBORequestCreator(IEBORequestCreator _eboRequestCreator) external {
    ARBITRABLE.validateArbitrator(msg.sender);
    if (_eboRequestCreatorsAllowed.remove(address(_eboRequestCreator))) {
      emit RemoveEBORequestCreator(_eboRequestCreator);
    }
  }

  /// @inheritdoc IEBOFinalityModule
  function decodeRequestData(bytes calldata _data)
    public
    pure
    returns (IEBORequestModule.RequestParameters memory _params)
  {
    _params = abi.decode(_data, (IEBORequestModule.RequestParameters));
  }

  /// @inheritdoc IEBOFinalityModule
  function decodeResponseData(bytes calldata _data) public pure returns (uint256 _block) {
    _block = abi.decode(_data, (uint256));
  }

  /// @inheritdoc IEBOFinalityModule
  function getAllowedEBORequestCreators() external view returns (address[] memory _eboRequestCreators) {
    _eboRequestCreators = _eboRequestCreatorsAllowed.values();
  }

  /// @inheritdoc IModule
  function moduleName() external pure returns (string memory _moduleName) {
    _moduleName = 'EBOFinalityModule';
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
