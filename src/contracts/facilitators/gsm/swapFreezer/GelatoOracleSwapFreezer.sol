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
   * @dev The returned bytes is specific to gelato and is encoded with the function selector.
   * @notice Method that is simulated by the keepers to see if any work actually
   * needs to be performed. This method does does not actually need to be
   * executable, and since it is only ever simulated it can consume lots of gas.
   * @dev To ensure that it is never called, you may want to add the
   * cannotExecute modifier from KeeperBase to your implementation of this
   * method.
   * @param data Specified in the upkeep registration so it is always the
   * same for a registered upkeep. This can easily be broken down into specific
   * arguments using `abi.decode`, so multiple upkeeps can be registered on the
   * same contract and easily differentiated by the contract.
   * @return upkeepNeeded boolean to indicate whether the keeper should call
   * performUpkeep or not.
   * @return performData bytes that the keeper should call performUpkeep with, if
   * upkeep is needed. If you would like to encode data to decode later, try
   * `abi.encode`.
   */
  function checkUpkeep(bytes calldata data) public view override returns (bool, bytes memory) {
    (bool upkeepNeeded, bytes memory encodedActionDataToExecute) = super.checkUpkeep(data);
    return (upkeepNeeded, abi.encodeCall(this.performUpkeep, encodedActionDataToExecute));
  }
}
