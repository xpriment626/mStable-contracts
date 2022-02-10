// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity 0.8.6;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/**
 * @title   Yield Generating Vault
 * @author  mStable
 * @notice  EIP-4626 Interface.
 *          This was written when the specification was still in Review status. For the latest version see https://eips.ethereum.org/EIPS/eip-4626.
 * @dev     VERSION: 1.0
 *          DATE:    2022-02-10
 */
interface IERC4626Vault {

    /// @notice The address of the underlying token used for the Vault uses for accounting, depositing, and withdrawing
    function asset() external view returns (IERC20 assetTokenAddress);

    /// @notice Total amount of the underlying asset that is “managed” by Vault
    function totalAssets() external view returns (uint256 totalManagedAssets);

    /// @notice The current exchange rate of shares to assets, quoted per unit share (share unit is 10 ** Vault.decimals()).
    function assetsPerShare() external view returns (uint256 assetsPerUnitShare);
    
    /**
     * @notice Total number of underlying assets that depositor’s shares represent.
     * @param depositor Owner of the shares.
     * @return assets The amount of underlying assets the depositor owns in the vault.
     */
    function assetsOf(address depositor) external view returns (uint256 assets);

    /**
     * @notice The maximum number of underlying assets that caller can deposit.
     * @param caller Account that the assets will be transferred from.
     * @return maxAssets The maximum amount of underlying assets the caller can deposit.
     */
    function maxDeposit(address caller) external view returns (uint256 maxAssets);

    /**
     * @notice Allows an on-chain or off-chain user to simulate the effects of their deposit at the current block, given current on-chain conditions.
     * @param assets The amount of underlying assets to be transferred.
     * @return shares The amount of vault shares that will be minted.
     */
    function previewDeposit(uint256 assets) external view returns (uint256 shares);

    /**
     * @notice Mint vault shares to receiver by transferring exact amount of underlying asset tokens from the caller.
     * @param assets The amount of underlying assets to be transferred to the vault.
     * @param receiver The account that the vault shares will be minted to.
     * @return shares The amount of vault shares that were minted.
     */
    function deposit(uint256 assets, address receiver) external returns (uint256 shares);

    /**
     * @notice The maximum number of vault shares that caller can mint.
     * @param caller Account that the underlying assets will be transferred from.
     * @return maxShares The maximum amount of vault shares the caller can mint.
     */
    function maxMint(address caller) external view returns (uint256 maxShares);

    /**
     * @notice Allows an on-chain or off-chain user to simulate the effects of their mint at the current block, given current on-chain conditions.
     * @param shares The amount of vault shares to be minted.
     * @return assets The amount of underlying assests that will be transferred from the caller.
     */
    function previewMint(uint256 shares) external view returns (uint256 assets);

    /**
     * @notice Mint exact amount of vault shares to the receiver by transferring enough underlying asset tokens from the caller.
     * @param shares The amount of vault shares to be minted.
     * @param receiver The account the vault shares will be minted to.
     * @return assets The amount of underlying assets that were transferred from the caller.
     */
    function mint(uint256 shares, address receiver) external returns (uint256 assets);

    /**
     * @notice The maximum number of underlying assets that owner can withdraw.
     * @param owner Account that owns the vault shares.
     * @return maxAssets The maximum amount of underlying assets the owner can withdraw.
     */
    function maxWithdraw(address owner) external view returns (uint256 maxAssets);

    /**
     * @notice Allows an on-chain or off-chain user to simulate the effects of their withdrawal at the current block, given current on-chain conditions.
     * @param assets The amount of underlying assets to be withdrawn.
     * @return shares The amount of vault shares that will be burnt.
     */
    function previewWithdraw(uint256 assets) external view returns (uint256 shares);

    /**
     * @notice Burns enough vault shares from owner and transfers the exact amount of underlying asset tokens to the receiver.
     * @param assets The amount of underlying assets to be withdrawn from the vault.
     * @param receiver The account that the underlying assets will be transferred to.
     * @param owner Account that owns the vault shares to be burnt.
     * @return shares The amount of vault shares that were burnt.
     */
    function withdraw(uint256 assets, address receiver, address owner) external returns (uint256 shares);

    /**
     * @notice The maximum number of underlying assets that owner can withdraw from redeeming vault shares.
     * @param owner Account that owns the vault shares.
     * @return maxAssets The maximum amount of underlying assets the owner can withdraw.
     */
    function maxRedeem(address owner) external view returns (uint256 maxAssets);


    /**
     * @notice Allows an on-chain or off-chain user to simulate the effects of their redeemption at the current block, given current on-chain conditions.
     * @param shares The amount of vault shares to be redeemed.
     * @return assets The amount of underlying assests that will transferred to the receiver.
     */
    function previewRedeem(uint256 shares) external view returns (uint256 assets);

    /**
     * @notice Burns exact amount of vault shares from owner and sends underlying asset tokens to the receiver.
     * @param shares The amount of vault shares to be burnt.
     * @param receiver The account the underlying assets will be transferred to.
     * @param owner The account that owns the vault shares to be burnt.
     * @return assets The amount of underlying assets that were transferred from the caller.
     */
    function redeem(uint256 shares, address receiver, address owner) external returns (uint256 assets);

}