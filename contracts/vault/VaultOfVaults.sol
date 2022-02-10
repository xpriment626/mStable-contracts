// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity 0.8.6;

import { Initializable } from "@openzeppelin/contracts/proxy/utils/Initializable.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import { ImmutableModule } from "../shared/ImmutableModule.sol";
import { InitializableToken, IERC20 } from "../shared/InitializableToken.sol";
import { StableMath } from "../shared/StableMath.sol";
import { IERC4626Vault } from "./IERC4626Vault.sol";

/**
 * @title   Vault of Yield Bearing Vaultss
 * @author  mStable
 * @notice  
 * @dev     VERSION: 1.0
 *          DATE:    2022-02-10
 */
contract VaultOfVaults is Initializable, ImmutableModule, InitializableToken, IERC4626Vault {
    using SafeERC20 for IERC20;
    using StableMath for uint256;

    uint256 public constant UNDERLYING_VAULT_COUNT = 3;

    /// @notice The address of the underlying token used for the Vault uses for accounting, depositing, and withdrawing
    IERC20 public override immutable asset;

    /// @notice The current exchange rate of shares to assets, quoted per unit share (share unit is 10 ** Vault.decimals()).
    uint256 public override assetsPerShare;

    // TODO A array of 16 weights of size 16 bits.
    // uint256 weights = ;

    // TODO move into an immutable byte array
    IERC4626Vault[UNDERLYING_VAULT_COUNT] public underlyingVaults;

    event Deposit(address caller, address receiver, uint256 assets, uint256 shares);
    event Withdraw(address owner, address receiver, uint256 assets, uint256 shares);
    event AssetsPerShareUpdated(uint256 assetsPerShare);
    
    constructor(
        address _nexus,
        address _asset,
        address[] memory _underlyingVaults
    ) ImmutableModule(_nexus) {
        require(_asset != address(0), "Asset is zero");
        asset = IERC20(_asset);

        for (uint256 i = 0; i < UNDERLYING_VAULT_COUNT; i++) {
            require(_underlyingVaults[i] != address(0), "Underlying is zero");
            underlyingVaults[i] = IERC4626Vault(_underlyingVaults[i]);
        }
    }

    function initialize() external initializer {
        // For each underlying vault
        for (uint256 i = 0; i < UNDERLYING_VAULT_COUNT; i++) {
            // Approce the underlying vaults to transfer assets from this vault of vaults.
            asset.approve(address(underlyingVaults[i]), type(uint256).max);
        }
    }

    /// @notice Total amount of the underlying asset that is “managed” by Vault
    /// @dev This will sum the latest amount of assset in each of the underlying vaults.
    function totalAssets() public override view returns (uint256 totalManagedAssets) {
        // For each underlying vault
        for (uint256 i = 0; i < UNDERLYING_VAULT_COUNT; i++) {
            // Add the amount of underlying assets this vault has in the underlying vault
            totalManagedAssets += underlyingVaults[i].assetsOf(address(this));
        }
    }

    /**
     * @notice Total number of underlying assets that depositor’s shares represent.
     * @param depositor Owner of the shares.
     * @return assets The amount of underlying assets the depositor owns in the vault.
     */
    function assetsOf(address depositor) external override view returns (uint256 assets) {
        assets = balanceOf(depositor) * assetsPerShare;
    }

    /**
     * @notice The maximum number of underlying assets that caller can deposit.
     * @param caller Account that the assets will be transferred from.
     * @return maxAssets The maximum amount of underlying assets the caller can deposit.
     */
    function maxDeposit(address caller) external override pure returns (uint256 maxAssets) {
        maxAssets = type(uint256).max;
    }

    /**
     * @notice Allows an on-chain or off-chain user to simulate the effects of their deposit at the current block, given current on-chain conditions.
     * @param assets The amount of underlying assets to be transferred.
     * @return shares The amount of vault shares that will be minted.
     */
    function previewDeposit(uint256 assets) external override view returns (uint256 shares) {
        // TODO what if the underlying vault charges a deposit fee? The number of assets in won't equal the number of assets redeemable.

        // Get the current asset totals from the underlying vaults
        uint256 newTotalAssets = totalAssets();
        uint256 totalShares = totalSupply();

        // shares per asset = total shares / total assets
        // new shares = total shares / total assets * new assets
        shares = assets * newTotalAssets / totalShares;
    }

    /**
     * @notice Mint vault shares to receiver by transferring exact amount of underlying asset tokens from the caller.
     * @param assets The amount of underlying assets to be transferred to the vault.
     * @param receiver The account that the vault shares will be minted to.
     * @return shares The amount of vault shares that were minted.
     */
    function deposit(uint256 assets, address receiver) external override returns (uint256 shares) {
        require(receiver != address(0), "Receiver is zero");

        // Get the asset totals before new deposits
        (, uint256 totalAssetsBefore, uint256 totalSharesBefore) = _updateAssetsPerShares();

        // shares per asset = total shares / total assets
        // new shares = total shares / total assets * new assets
        shares = assets * totalSharesBefore / totalAssetsBefore;

        _transferDepositMint(assets, shares, receiver);
    }

    /**
     * @notice The maximum number of vault shares that caller can mint.
     * @param caller Account that the underlying assets will be transferred from.
     * @return maxShares The maximum amount of vault shares the caller can mint.
     */
    function maxMint(address caller) external override pure returns (uint256 maxShares) {
        maxShares = type(uint256).max;
    }

    /**
     * @notice Allows an on-chain or off-chain user to simulate the effects of their mint at the current block, given current on-chain conditions.
     * @param shares The amount of vault shares to be minted.
     * @return assets The amount of underlying assests that will be transferred from the caller.
     */
    function previewMint(uint256 shares) external override view returns (uint256 assets) {
        assets = _calcAssetsFromShares(shares);
    }

    /**
     * @notice Mint exact amount of vault shares to the receiver by transferring enough underlying asset tokens from the caller.
     * @param shares The amount of vault shares to be minted.
     * @param receiver The account the vault shares will be minted to.
     * @return assets The amount of underlying assets that were transferred from the caller.
     */
    function mint(uint256 shares, address receiver) external override returns (uint256 assets) {
        require(receiver != address(0), "Receiver is zero");

        // Get the new assets per share ration
        (uint256 newAssetsPerShare, , ) = _updateAssetsPerShares();

        assets = shares.mulTruncate(newAssetsPerShare);

        _transferDepositMint(assets, shares, receiver);
    }

    /**
     * @notice The maximum number of underlying assets that owner can withdraw.
     * @param owner Account that owns the vault shares.
     * @return maxAssets The maximum amount of underlying assets the owner can withdraw.
     */
    function maxWithdraw(address owner) external override view returns (uint256 maxAssets) {
    }

    /**
     * @notice Allows an on-chain or off-chain user to simulate the effects of their withdrawal at the current block, given current on-chain conditions.
     * @param assets The amount of underlying assets to be withdrawn.
     * @return shares The amount of vault shares that will be burnt.
     */
    function previewWithdraw(uint256 assets) external override view returns (uint256 shares) {
    }

    /**
     * @notice Burns enough vault shares from owner and transfers the exact amount of underlying asset tokens to the receiver.
     * @param assets The amount of underlying assets to be withdrawn from the vault.
     * @param receiver The account that the underlying assets will be transferred to.
     * @return shares The amount of vault shares that were burnt.
     */
    function withdraw(uint256 assets, address receiver, address owner) external override returns (uint256 shares) {
        require(receiver != address(0), "Receiver is zero");

        // Get the asset totals before new withdraw
        (, uint256 totalAssetsBefore, uint256 totalSharesBefore) = _updateAssetsPerShares();

        // shares per asset = total shares / total assets
        // burnt shares = withdrawn assets * total shares / total assets
        shares = assets * totalSharesBefore / totalAssetsBefore;

        _withdrawBurnTransfer(assets, shares, owner, receiver);
    }

    /**
     * @notice The maximum number of underlying assets that owner can withdraw from redeeming vault shares.
     * @param owner Account that owns the vault shares.
     * @return maxAssets The maximum amount of underlying assets the owner can withdraw.
     */
    function maxRedeem(address owner) external override view returns (uint256 maxAssets) {
    }

    /**
     * @notice Allows an on-chain or off-chain user to simulate the effects of their redeemption at the current block, given current on-chain conditions.
     * @param shares The amount of vault shares to be redeemed.
     * @return assets The amount of underlying assests that will transferred to the receiver.
     */
    function previewRedeem(uint256 shares) external override view returns (uint256 assets) {
        assets = _calcAssetsFromShares(shares);
    }

    /**
     * @notice Burns exact amount of vault shares from owner and sends underlying asset tokens to the receiver.
     * @param shares The amount of vault shares to be burnt.
     * @param receiver The account the underlying assets will be transferred to.
     * @param owner The account that owns the vault shares to be burnt.
     * @return assets The amount of underlying assets that were transferred from the caller.
     */
    function redeem(uint256 shares, address receiver, address owner) external override returns (uint256 assets) {

        // Get the new assets per share ration
        (uint256 newAssetsPerShare, , ) = _updateAssetsPerShares();

        assets = shares.mulTruncate(newAssetsPerShare);

        _withdrawBurnTransfer(assets, shares, owner, receiver);
    }

    function _transferDepositMint(uint256 assets, uint256 shares, address receiver) internal {
        // Transfer in the assets to this vault from the sender
        asset.safeTransferFrom(msg.sender, address(this), assets);

        // Deposit new assets into underlying vaults evenly
        // TODO change so the allocation is configurable
        uint256 allocation = assets / UNDERLYING_VAULT_COUNT;
        for (uint256 i = 0; i < UNDERLYING_VAULT_COUNT; i++) {
            underlyingVaults[i].deposit(allocation, address(this));
        }

        emit Deposit(msg.sender, receiver, assets, shares);

        // Mint new shares to the receiver
        _mint(receiver, shares);
    }

    function _withdrawBurnTransfer(uint256 assets, uint256 shares, address owner, address receiver) internal {

        // Get the proportions of assets across the underlying vaults before the withdraw
        uint256 totalAssetsBefore;
        uint256[] memory vaultsAssets = new uint256[](UNDERLYING_VAULT_COUNT);
        for (uint256 i = 0; i < UNDERLYING_VAULT_COUNT; i++) {
            uint256 vaultAssets = underlyingVaults[i].assetsOf(address(this));
            vaultsAssets[i] = vaultAssets;
            totalAssetsBefore += vaultAssets;
        }

        // Withdraw assets from underlying vaults propotionally directly to the receiver
        for (uint256 i = 0; i < UNDERLYING_VAULT_COUNT; i++) {
            uint256 allocation = assets * vaultsAssets[i] / totalAssetsBefore;
            underlyingVaults[i].withdraw(allocation, receiver, address(this));
        }

        emit Withdraw(owner, receiver, assets, shares);

        // Burn shares from the owner
        _burn(owner, shares);
    }

    function _calcAssetsFromShares(uint256 shares) internal view returns (uint256 assets) {
        uint256 newTotalAssets = totalAssets();
        uint256 totalShares = totalSupply();

        uint256 newAssetsPerShare = _calculateAssetsPerShare(newTotalAssets, totalShares);
        assets = shares.mulTruncate(newAssetsPerShare);
    }

    function _updateAssetsPerShares() internal returns (
        uint256 newAssetsPerShare,
        uint256 newTotalAssets,
        uint256 totalShares
    ) {
        newTotalAssets = totalAssets();
        totalShares = totalSupply();

        newAssetsPerShare = _calculateAssetsPerShare(newTotalAssets, totalShares);

        // TODO should we only update if the new value is different to the old value?
        // Store new assertsPerShare in contract storage
        assetsPerShare = newAssetsPerShare;

        emit AssetsPerShareUpdated(newAssetsPerShare);
    }

    /**
     * @dev Calculates new assets per share ratio, given the total amount of assets and total shares
     *      assetsPerShare = assets / (shares - 1)
     */
    function _calculateAssetsPerShare(uint256 _totalAssets, uint256 _totalShares)
        internal
        pure
        returns (uint256 _assetsPerShare)
    {
        _assetsPerShare = _totalAssets.divPrecisely(_totalShares - 1);
    }

}