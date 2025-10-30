// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import './TestOracleSwapFreezerBase.t.sol';
import {Address} from 'openzeppelin-contracts/contracts/utils/Address.sol';
import {IGsm} from 'src/contracts/facilitators/gsm/interfaces/IGsm.sol';
import {IPoolAddressesProvider} from 'aave-v3-origin/contracts/interfaces/IPoolAddressesProvider.sol';
import {GelatoOracleSwapFreezer} from 'src/contracts/facilitators/gsm/swapFreezer/GelatoOracleSwapFreezer.sol';
import {OracleSwapFreezerBase} from 'src/contracts/facilitators/gsm/swapFreezer/OracleSwapFreezerBase.sol';

contract TestGsmGelatoOracleSwapFreezer is TestOracleSwapFreezerBase {
  using Address for address;

  function testCheckUpkeepReturnsCorrectSelector() public view {
    (, bytes memory data) = swapFreezer.checkUpkeep('');
    bytes4 selector;
    assembly {
      selector := mload(add(data, 32))
    }
    assertEq(selector, OracleSwapFreezerBase.performUpkeep.selector);
  }

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
      new GelatoOracleSwapFreezer(
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

  function _checkAndPerformAutomation(
    OracleSwapFreezerBase _swapFreezer
  ) internal virtual override returns (bool) {
    (bool shouldRunKeeper, bytes memory encodedPerformData) = _swapFreezer.checkUpkeep('');
    if (shouldRunKeeper) {
      address(_swapFreezer).functionCall(encodedPerformData);
    }
    return shouldRunKeeper;
  }

  function _performAutomation(
    OracleSwapFreezerBase _swapFreezer,
    bytes memory encodedCalldata
  ) internal override {
    address(_swapFreezer).functionCall(encodedCalldata);
  }
}
