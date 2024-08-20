// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.26;

import {IHorizonAccountingExtension, IHorizonStaking} from 'interfaces/IHorizonAccountingExtension.sol';

contract HorizonAccountingExtension is IHorizonAccountingExtension {
  /// @inheritdoc IHorizonAccountingExtension
  uint256 public immutable MIN_THAWING_PERIOD = 30 days;

  /// @inheritdoc IHorizonAccountingExtension
  IHorizonStaking public horizonStaking;

  /// @inheritdoc IHorizonAccountingExtension
  address public prophet;

  /// @inheritdoc IHorizonAccountingExtension
  mapping(address _user => uint256 _bonded) public totalBonded;

  constructor(IHorizonStaking _horizonStaking, address _prophet) {
    horizonStaking = _horizonStaking;
    prophet = _prophet;
  }

  /// @inheritdoc IHorizonAccountingExtension
  function bondedAction(uint256 _bondAmount) external {
    IHorizonStaking.Provision memory _provisionData = horizonStaking.getProvision(msg.sender, prophet);

    if (_provisionData.thawingPeriod != MIN_THAWING_PERIOD) revert HorizonAccountingExtension_InvalidThawingPeriod();
    if (_bondAmount > _provisionData.tokens) revert HorizonAccountingExtension_InsufficientTokens();

    totalBonded[msg.sender] += _bondAmount;

    if (totalBonded[msg.sender] > _provisionData.tokens + _provisionData.tokensThawing) {
      revert HorizonAccountingExtension_InsufficientBondedTokens();
    }

    emit Bonded(msg.sender, _bondAmount);
  }

  /// @inheritdoc IHorizonAccountingExtension
  function finalize(uint256 _bondAmount) external {
    if (_bondAmount > totalBonded[msg.sender]) revert HorizonAccountingExtension_InsufficientBondedTokens();
    totalBonded[msg.sender] -= _bondAmount;

    emit Finalized(msg.sender, _bondAmount);
  }
}
