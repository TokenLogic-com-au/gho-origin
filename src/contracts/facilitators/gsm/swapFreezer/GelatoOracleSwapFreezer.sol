// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

import {IPoolAddressesProvider} from 'aave-v3-origin/contracts/interfaces/IPoolAddressesProvider.sol';
import {OracleSwapFreezerBase} from 'src/contracts/facilitators/gsm/swapFreezer/OracleSwapFreezerBase.sol';
import {IGsm} from 'src/contracts/facilitators/gsm/interfaces/IGsm.sol';

/**
 * @title GelatoOracleSwapFreezer
 * @notice Gelato-compatible automated swap freezer for GSM.
 */
contract GelatoOracleSwapFreezer is OracleSwapFreezerBase {
  /**
   * @dev Constructor
   * @dev Freeze/unfreeze bounds are specified in USD with 8-decimal precision, like Aave v3 Price Oracles
   * @dev Unfreeze boundaries are "contained" in freeze boundaries, where freezeLowerBound < unfreezeLowerBound and unfreezeUpperBound < freezeUpperBound
   * @dev All bound ranges are inclusive
   * @param gsm The GSM that this contract will trigger freezes/unfreezes on
   * @param underlyingAsset The address of the collateral asset
   * @param addressProvider The Aave Addresses Provider for looking up the Price Oracle
   * @param freezeLowerBound The lower price bound for freeze operations
   * @param freezeUpperBound The upper price bound for freeze operations
   * @param unfreezeLowerBound The lower price bound for unfreeze operations, must be 0 if unfreezing not allowed
   * @param unfreezeUpperBound The upper price bound for unfreeze operations, must be 0 if unfreezing not allowed
   * @param allowUnfreeze True if bounds verification should factor in the unfreeze boundary, false otherwise
   */
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
    OracleSwapFreezerBase(
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
   * @notice Executes a given action on the GSM depending on the oracle value
   */
  function execute(bytes calldata) external {
    Action action = _getAction();
    if (action == Action.FREEZE) {
      GSM.setSwapFreeze(true);
    } else if (action == Action.UNFREEZE) {
      GSM.setSwapFreeze(false);
    }
  }

  /**
   * @notice Returns whether the action can be performed and the encoded call data for execution.
   * @return True if the action can be performed, false otherwise.
   * @return The encoded call data for the action to be executed.
   */

  function checkExecute(bytes calldata) external view returns (bool, bytes memory) {
    return (_getAction() == Action.NONE ? false : true, abi.encodeCall(this.execute, ''));
  }
}
