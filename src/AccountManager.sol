// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {IAccountManager} from "./interfaces/IAccountManager.sol";

/// @title  AccountManager
/// @notice Permissionless account registration for Tangent. Any EOA can
///         call registerAccount() and immediately receive a tradeable
///         accountId; no off-chain custody-binding step. Contrasts with
///         Shapeshifter's Fireblocks-bound pattern where getAccountOwner is
///         set externally.
///
///         v0.1 ships only the single-account-per-EOA shape. Sub-accounts
///         (per-strategy isolated margin) are scheduled for v1.1; the
///         IAccountManager interface and event signatures already cover them
///         so downstream consumers can target the v1.1 surface today.
///
/// @dev    Account ids are monotonic starting at 1 (0 is reserved as the
///         "unregistered" sentinel). This lets accountIdOf(unknownEOA)
///         return 0 unambiguously.
contract AccountManager is IAccountManager {
    /// @notice Total number of registered master accounts. Also the next
    ///         accountId to be assigned (after pre-increment).
    uint256 public override totalAccounts;

    /// @notice accountId -> owning EOA.
    mapping(uint256 => address) private _owners;

    /// @notice owning EOA -> accountId. Zero = unregistered.
    mapping(address => uint256) private _accountIds;

    error AlreadyRegistered(address owner, uint256 existingAccountId);
    error UnknownAccount(uint256 accountId);

    /// @inheritdoc IAccountManager
    function registerAccount() external override returns (uint256 accountId) {
        uint256 existing = _accountIds[msg.sender];
        if (existing != 0) revert AlreadyRegistered(msg.sender, existing);

        unchecked {
            // Pre-increment so first accountId is 1, not 0.
            accountId = ++totalAccounts;
        }

        _owners[accountId] = msg.sender;
        _accountIds[msg.sender] = accountId;

        emit AccountRegistered(accountId, msg.sender, uint64(block.timestamp));
    }

    /// @inheritdoc IAccountManager
    function ownerOf(uint256 accountId) external view override returns (address owner) {
        owner = _owners[accountId];
        if (owner == address(0)) revert UnknownAccount(accountId);
    }

    /// @inheritdoc IAccountManager
    function accountIdOf(address owner) external view override returns (uint256) {
        return _accountIds[owner];
    }
}
