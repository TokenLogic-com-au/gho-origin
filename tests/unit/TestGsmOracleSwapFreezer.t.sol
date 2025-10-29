// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import './TestOracleSwapFreezerBase.t.sol';
import {OracleSwapFreezer} from 'src/contracts/facilitators/gsm/swapFreezer/OracleSwapFreezer.sol';

contract TestGsmOracleSwapFreezer is TestOracleSwapFreezerBase {

  function _checkAndPerformAutomation(
    OracleSwapFreezer _swapFreezer
  ) internal override returns (bool) {
    (bool shouldRunKeeper, bytes memory performData) = _swapFreezer.checkUpkeep('');
    if (shouldRunKeeper) {
      _swapFreezer.performUpkeep(performData);
    }
    return shouldRunKeeper;
  }

  function _performAutomation(
    OracleSwapFreezer _swapFreezer,
    bytes memory performData
  ) internal override {
    _swapFreezer.performUpkeep(performData);
  }

  function _deployOracle(
    IGsm gsm,
    address underlyingAsset,
    IPoolAddressesProvider addressProvider,
    uint128 freezeLowerBound,
    uint128 freezeUpperBound,
    uint128 unfreezeLowerBound,
    uint128 unfreezeUpperBound,
    bool allowUnfreeze
  ) internal override returns (OracleSwapFreezer) {
    return
      new OracleSwapFreezer(
        gsm,
        underlyingAsset,
        addressProvider,
        freezeLowerBound,
        freezeUpperBound,
        unfreezeLowerBound,
        unfreezeUpperBound,
        allowUnfreeze
      );
  }
}
