// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

/// @title  IAccountManager
/// @notice Permissionless account registration. The primitive that breaks the
///         Fireblocks-custody binding pattern Shapeshifter's CMDT ClearingHouse
///         requires. Any EOA can call registerAccount() and immediately become
///         tradeable; no off-chain provisioning step. Optional sub-account
///         factory in v1.1 for traders who want isolated margin per strategy.
interface IAccountManager {
    /// @notice Emitted when a new master account is registered.
    event AccountRegistered(uint256 indexed accountId, address indexed owner, uint64 registeredAt);

    /// @notice Emitted when a sub-account is derived under an existing master.
    /// @dev    Deferred to v1.1; v0.1 ships only single-account-per-EOA.
    event SubAccountRegistered(uint256 indexed parentAccountId, uint256 indexed subAccountId, uint64 registeredAt);

    /// @notice Register a new permissionless master account bound to msg.sender.
    ///         Reverts if msg.sender already owns a master account.
    /// @return accountId Newly assigned account identifier (monotonic).
    function registerAccount() external returns (uint256 accountId);

    /// @notice Lookup the owner of an account. Used by OrderBook + SettlementEngine
    ///         when recovering signatures against accountId.
    function ownerOf(uint256 accountId) external view returns (address);

    /// @notice Lookup the master accountId owned by an EOA. Returns 0 if unregistered.
    function accountIdOf(address owner) external view returns (uint256);

    /// @notice Total number of registered master accounts. Useful for sub-account
    ///         id derivation and indexers.
    function totalAccounts() external view returns (uint256);
}
