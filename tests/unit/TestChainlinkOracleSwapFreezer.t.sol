// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import './TestOracleSwapFreezerBase.t.sol';

contract TestChainlinkOracleSwapFreezer is TestOracleSwapFreezerBase {
  function _deployOracleSwapFreezer(
    IGsm gsm,
    address underlyingAsset,
    IPoolAddressesProvider addressProvider,
    uint128 freezeLowerBound,
    uint128 freezeUpperBound,
    uint128 unfreezeLowerBound,
    uint128 unfreezeUpperBound,
    bool allowUnfreeze
  ) internal override returns (OracleSwapFreezerBase) {
    return
      new ChainlinkOracleSwapFreezer(
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

  function _checkAutomation(
    OracleSwapFreezerBase _swapFreezer
  ) internal view override returns (bool) {
    (bool shouldRunKeeper, ) = _swapFreezer.checkUpkeep('');
    return shouldRunKeeper;
  }

  function _checkAndPerformAutomation(
    OracleSwapFreezerBase _swapFreezer
  ) internal override returns (bool) {
    (bool shouldRunKeeper, bytes memory performData) = _swapFreezer.checkUpkeep('');
    if (shouldRunKeeper) {
      _swapFreezer.performUpkeep(performData);
    }
    return shouldRunKeeper;
  }

  function _performAutomation(
    OracleSwapFreezerBase _swapFreezer,
    bytes memory performData
  ) internal override {
    _swapFreezer.performUpkeep(performData);
  }
}
