// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import './TestOracleSwapFreezerBase.t.sol';
import {Address} from 'openzeppelin-contracts/contracts/utils/Address.sol';

contract TestGsmGelatoOracleSwapFreezer is TestOracleSwapFreezerBase {
  using Address for address;

  function testCheckUpkeepReturnsCorrectSelector() public view {
    (, bytes memory data) = swapFreezer.checkExecute('');
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

  function _checkAutomation(
    OracleSwapFreezerBase _swapFreezer
  ) internal view override returns (bool) {
    (bool shouldRunKeeper, ) = _swapFreezer.checkExecute('');
    return shouldRunKeeper;
  }

  function _checkAndPerformAutomation(
    OracleSwapFreezerBase _swapFreezer
  ) internal virtual override returns (bool) {
    (bool shouldRunKeeper, bytes memory encodedPerformData) = _swapFreezer.checkExecute('');
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
