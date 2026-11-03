// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/**
 * @title IPermissionedGsm
 * @author Aave
 * @notice Defines the access restriction behaviour of the GHO Stability Module
 */
interface IPermissionedGsm {
  /**
   * @dev Emitted when the Configurator lifts or restores the buy restriction
   * @param configurator The address of the Configurator
   * @param open True if `buyAsset` is open to any address, False otherwise
   */
  event BuyAccessOpenUpdated(address indexed configurator, bool open);

  /**
   * @dev Emitted when the Configurator lifts or restores the sell restriction
   * @param configurator The address of the Configurator
   * @param open True if `sellAsset` is open to any address, False otherwise
   */
  event SellAccessOpenUpdated(address indexed configurator, bool open);

  /**
   * @notice Lift or restore the `BUY_ASSET_ROLE` restriction on buys
   * @param open True to open `buyAsset` to any address, false otherwise
   */
  function setBuyAccessOpen(bool open) external;

  /**
   * @notice Lift or restore the `SELL_ASSET_ROLE` restriction on sells
   * @param open True to open `sellAsset` to any address, false otherwise
   */
  function setSellAccessOpen(bool open) external;

  /**
   * @notice Revokes the `BUY_ASSET_ROLE` and `SELL_ASSET_ROLE` from `swapper` immediately
   * @dev Only callable by the `SWAP_GUARDIAN_ROLE`. Does nothing for a role `swapper` does not hold
   * @param swapper The address to remove from the swappers
   */
  function revokeSwapRoles(address swapper) external;

  /**
   * @notice Restores the `BUY_ASSET_ROLE` and `SELL_ASSET_ROLE` restrictions on buys and sells
   * @dev Only callable by the `SWAP_GUARDIAN_ROLE`. Does nothing for a side that is not open.
   * Emits `BuyAccessOpenUpdated` and `SellAccessOpenUpdated` for each side that was open
   */
  function closeSwapAccess() external;

  /**
   * @notice Returns whether buys are open to any address
   * @return True if `buyAsset` is open to any address, false if it is role restricted
   */
  function getIsBuyAccessOpen() external view returns (bool);

  /**
   * @notice Returns whether sells are open to any address
   * @return True if `sellAsset` is open to any address, false if it is role restricted
   */
  function getIsSellAccessOpen() external view returns (bool);

  /**
   * @notice Returns the identifier of the `BUY_ASSET_ROLE`
   * @return The bytes32 id hash of the `BUY_ASSET_ROLE`
   */
  function BUY_ASSET_ROLE() external pure returns (bytes32);

  /**
   * @notice Returns the identifier of the `SELL_ASSET_ROLE`
   * @return The bytes32 id hash of the `SELL_ASSET_ROLE`
   */
  function SELL_ASSET_ROLE() external pure returns (bytes32);

  /**
   * @notice Returns the identifier of the `SWAP_GUARDIAN_ROLE`, which can only remove swappers and
   * close the GSM, never grant swap access or open the GSM
   * @return The bytes32 id hash of the `SWAP_GUARDIAN_ROLE`
   */
  function SWAP_GUARDIAN_ROLE() external pure returns (bytes32);
}
