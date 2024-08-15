// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.26;

interface IEpochManager {
  /*///////////////////////////////////////////////////////////////
                              FUNCTIONS
  //////////////////////////////////////////////////////////////*/

  function currentEpoch() external view returns (uint256 _currentEpoch);
}
