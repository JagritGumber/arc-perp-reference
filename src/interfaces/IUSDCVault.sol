// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

/// @title  IUSDCVault
/// @notice Per-account USDC collateral vault. Standard ERC-20 vault with
///         transparent per-account accounting. No custodian binding (this is
///         the primitive that contrasts with Shapeshifter's Fireblocks-bound
///         USDCCollateralVault). Deposits credit an account's internal
///         balance; withdrawals debit it. Margin checks against this balance
///         happen at settle time.
interface IUSDCVault {
    event Deposited(uint256 indexed accountId, address indexed from, uint256 amount);
    event Withdrawn(uint256 indexed accountId, address indexed to, uint256 amount);
    event MarginLocked(uint256 indexed accountId, uint256 amount);
    event MarginReleased(uint256 indexed accountId, uint256 amount);
    event PnLApplied(uint256 indexed accountId, int256 pnl);

    /// @notice Deposit USDC into an account's collateral balance. Caller must
    ///         hold a registered account or be approved by one. ERC-20 transferFrom
    ///         pulls funds from msg.sender.
    function deposit(uint256 accountId, uint256 amount) external;

    /// @notice Withdraw USDC from an account's free (unlocked) balance.
    ///         Reverts if the account would fall below maintenance margin.
    ///         Only the account owner can withdraw.
    function withdraw(uint256 accountId, uint256 amount, address to) external;

    /// @notice Free (unlocked) balance available for withdrawal or new orders.
    function freeBalanceOf(uint256 accountId) external view returns (uint256);

    /// @notice Locked balance (initial margin against open positions).
    function lockedBalanceOf(uint256 accountId) external view returns (uint256);

    /// @notice Total balance = free + locked.
    function totalBalanceOf(uint256 accountId) external view returns (uint256);

    /// @notice Settlement-engine hook to lock initial margin on a new position.
    ///         Only callable by the bound SettlementEngine.
    function lockMargin(uint256 accountId, uint256 amount) external;

    /// @notice Settlement-engine hook to release margin on a closed position.
    ///         Only callable by the bound SettlementEngine.
    function releaseMargin(uint256 accountId, uint256 amount) external;

    /// @notice Settlement-engine hook to apply realized PnL on a closed position.
    ///         Only callable by the bound SettlementEngine. Negative PnL may
    ///         drive an account into liquidation.
    function applyPnL(uint256 accountId, int256 pnl) external;
}
