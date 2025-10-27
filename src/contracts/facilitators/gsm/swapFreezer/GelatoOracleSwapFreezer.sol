// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

import {IPoolAddressesProvider} from 'aave-v3-origin/contracts/interfaces/IPoolAddressesProvider.sol';
import {OracleSwapFreezer} from 'src/contracts/facilitators/gsm/swapFreezer/OracleSwapFreezer.sol';
import {IGsm} from 'src/contracts/facilitators/gsm/interfaces/IGsm.sol';

contract GelatoOracleSwapFreezer is OracleSwapFreezer {
  constructor(
    IGsm gsm,
    address underlyingAsset,
    IPoolAddressesProvider addressProvider,
    uint128 freezeLowerBound,
    uint128 freezeUpperBound,
    uint128 unfreezeLowerBound,
    uint128 unfreezeUpperBound,
    bool allowUnfreeze
  )
    OracleSwapFreezer(
      gsm,
      underlyingAsset,
      addressProvider,
      freezeLowerBound,
      freezeUpperBound,
      unfreezeLowerBound,
      unfreezeUpperBound,
      allowUnfreeze
    )
  {}

  /**
   * @inheritdoc OracleSwapFreezer
   * @dev the returned bytes is specific to gelato and is encoded with the function selector.
   */
  function checkUpkeep(bytes calldata data) public view override returns (bool, bytes memory) {
    (bool upkeepNeeded, bytes memory encodedActionDataToExecute) = super.checkUpkeep(data);
    return (upkeepNeeded, abi.encodeCall(this.performUpkeep, encodedActionDataToExecute));
  }
}
