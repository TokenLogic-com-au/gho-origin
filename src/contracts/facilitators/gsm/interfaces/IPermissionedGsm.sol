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
   * @notice Returns whether `originator` can currently buy or sell through the GSM
   * @dev The result covers the frozen and seized state, the buy or sell open flag, and the role of
   * the originator. It does not check amounts, exposure, reserve limit, liquidity, balances,
   * allowances or signatures, so a swap can still revert for those reasons.
   * @param originator The address of the caller, or of the signer for signature swaps
   * @param isBuy True to check `buyAsset`, false to check `sellAsset`
   * @return True if the GSM is not frozen or seized and the originator is allowed to swap, false
   * otherwise
   */
  function canSwap(address originator, bool isBuy) external view returns (bool);

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
}
