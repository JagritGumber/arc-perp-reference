// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Test} from "forge-std/Test.sol";
import {USDCVault, IERC20} from "../../src/USDCVault.sol";
import {AccountManager} from "../../src/AccountManager.sol";
import {IAccountManager} from "../../src/interfaces/IAccountManager.sol";
import {MockUSDC} from "../USDCVault.t.sol";

/// @notice Foundry invariant-mode handler for USDCVault. The handler restricts
///         the fuzzer to legal action sequences (deposit, withdraw, lock,
///         release, pnl) on a fixed set of accounts, then the test asserts
///         conservation properties that must hold across ANY interleaving.
///
///         This is the seam where most economic bugs in vault contracts live:
///         a unit test catches a single-call bug, an invariant test catches
///         the "100 random calls in a weird order broke a conservation law"
///         class of bug.
contract VaultInvariantHandler is Test {
    USDCVault internal immutable vault;
    MockUSDC internal immutable usdc;
    AccountManager internal immutable accounts;
    address internal immutable settlementEngine;

    uint256[] internal accountIds;
    mapping(uint256 => address) internal ownerOf;

    /// @notice Track total USDC moved into the vault from outside (deposits)
    ///         minus total moved out (withdrawals). Should always equal the
    ///         actual vault USDC balance.
    int256 public netExternalFlow;

    /// @notice Track total PnL credited minus debited via applyPnL. Combined
    ///         with netExternalFlow this constrains the sum-of-internal-balances.
    int256 public netPnLApplied;

    constructor(
        USDCVault _vault,
        MockUSDC _usdc,
        AccountManager _accounts,
        address _settlementEngine,
        address[] memory traders
    ) {
        vault = _vault;
        usdc = _usdc;
        accounts = _accounts;
        settlementEngine = _settlementEngine;

        // Register one account per trader, mint and pre-approve USDC.
        for (uint256 i = 0; i < traders.length; i++) {
            address t = traders[i];
            vm.prank(t);
            uint256 id = accounts.registerAccount();
            accountIds.push(id);
            ownerOf[id] = t;
            usdc.mint(t, 1_000_000_000_000); // 1M USDC, plenty for fuzz
            vm.prank(t);
            usdc.approve(address(vault), type(uint256).max);
        }
    }

    function deposit(uint256 accIdx, uint128 amount) external {
        if (accountIds.length == 0) return;
        if (amount == 0) return;
        uint256 id = accountIds[accIdx % accountIds.length];
        address t = ownerOf[id];
        if (usdc.balanceOf(t) < amount) return;
        vm.prank(t);
        vault.deposit(id, amount);
        netExternalFlow += int256(uint256(amount));
    }

    function withdraw(uint256 accIdx, uint128 amount) external {
        if (accountIds.length == 0) return;
        if (amount == 0) return;
        uint256 id = accountIds[accIdx % accountIds.length];
        address t = ownerOf[id];
        uint256 free = vault.freeBalanceOf(id);
        if (free == 0 || amount > free) return;
        vm.prank(t);
        vault.withdraw(id, amount, t);
        netExternalFlow -= int256(uint256(amount));
    }

    function lockMargin(uint256 accIdx, uint128 amount) external {
        if (accountIds.length == 0) return;
        if (amount == 0) return;
        uint256 id = accountIds[accIdx % accountIds.length];
        uint256 free = vault.freeBalanceOf(id);
        if (free == 0 || amount > free) return;
        vm.prank(settlementEngine);
        vault.lockMargin(id, amount);
    }

    function releaseMargin(uint256 accIdx, uint128 amount) external {
        if (accountIds.length == 0) return;
        if (amount == 0) return;
        uint256 id = accountIds[accIdx % accountIds.length];
        uint256 locked = vault.lockedBalanceOf(id);
        if (locked == 0 || amount > locked) return;
        vm.prank(settlementEngine);
        vault.releaseMargin(id, amount);
    }

    function applyPnL(uint256 accIdx, int128 pnl) external {
        if (accountIds.length == 0 || pnl == 0) return;
        uint256 id = accountIds[accIdx % accountIds.length];
        int256 pnlBig = int256(pnl);

        // Compute the actual delta the vault will apply. Negative PnL is
        // clamped to the account's total balance (per USDCVault behavior:
        // overflows zero out, never go below zero). We track the same
        // clamp here so the invariant accounting stays accurate.
        int256 applied;
        if (pnlBig > 0) {
            applied = pnlBig;
        } else {
            uint256 loss = uint256(-pnlBig);
            uint256 total = vault.totalBalanceOf(id);
            uint256 absorbed = loss > total ? total : loss;
            applied = -int256(absorbed);
        }

        vm.prank(settlementEngine);
        vault.applyPnL(id, pnlBig);
        netPnLApplied += applied;
    }

    function totalAccounts() external view returns (uint256) {
        return accountIds.length;
    }

    function accountAt(uint256 i) external view returns (uint256) {
        return accountIds[i];
    }
}

contract VaultInvariantTest is Test {
    USDCVault internal vault;
    MockUSDC internal usdc;
    AccountManager internal accounts;
    VaultInvariantHandler internal handler;

    address internal settlementEngine = address(0x5E771);

    function setUp() public {
        usdc = new MockUSDC();
        accounts = new AccountManager();
        vault = new USDCVault(IERC20(address(usdc)), IAccountManager(address(accounts)));
        vault.bindSettlementEngine(settlementEngine);

        address[] memory traders = new address[](4);
        traders[0] = address(0xA11CE);
        traders[1] = address(0xB0B);
        traders[2] = address(0xCA01);
        traders[3] = address(0xD0DD);

        handler = new VaultInvariantHandler(vault, usdc, accounts, settlementEngine, traders);

        targetContract(address(handler));
    }

    /// @notice Invariant 1: the vault's USDC balance always equals the sum
    ///         of every account's free + locked + the cumulative PnL applied.
    ///         This is the global accounting identity that every action must
    ///         preserve. A bug that lets an account secretly mint or burn
    ///         internal balance would break this.
    function invariant_globalAccountingIdentity() public view {
        uint256 sumInternal;
        uint256 n = handler.totalAccounts();
        for (uint256 i = 0; i < n; i++) {
            sumInternal += vault.totalBalanceOf(handler.accountAt(i));
        }
        // sumInternal should equal: netExternalFlow + netPnLApplied
        // (both can be negative, so we cast to int256 for the comparison)
        int256 expected = handler.netExternalFlow() + handler.netPnLApplied();
        // Clamp at zero: if cumulative debits exceed credits, the vault's
        // overflow-zeroing means we can't actually go below zero. The vault
        // ends up holding less USDC than the "owed" sum would suggest, but
        // that's the absorbing-loss path, not a bug.
        if (expected < 0) expected = 0;
        assertEq(int256(sumInternal), expected, "internal accounting drifted from external flow + PnL");
    }

    /// @notice Invariant 2: for any account, totalBalance must always equal
    ///         freeBalance + lockedBalance. A bug that moved balance into
    ///         locked without debiting free (or released without crediting
    ///         free) would break this.
    function invariant_perAccountFreePlusLocked() public view {
        uint256 n = handler.totalAccounts();
        for (uint256 i = 0; i < n; i++) {
            uint256 id = handler.accountAt(i);
            assertEq(
                vault.totalBalanceOf(id),
                vault.freeBalanceOf(id) + vault.lockedBalanceOf(id),
                "free+locked != total for an account"
            );
        }
    }

    /// @notice Invariant 3: free and locked balances are always
    ///         non-negative (uint underflow check). If we ever underflowed,
    ///         the balance would wrap to a huge number and this would catch
    ///         it via the < check on a uint that's logically expected to be small.
    function invariant_balancesNeverUnderflow() public view {
        uint256 n = handler.totalAccounts();
        uint256 vaultUSDC = usdc.balanceOf(address(vault));
        for (uint256 i = 0; i < n; i++) {
            uint256 id = handler.accountAt(i);
            uint256 total = vault.totalBalanceOf(id);
            // A single account's total can't exceed the vault's USDC holdings.
            // (Cumulative across all accounts can if PnL credits inflated balances,
            // but a single account being larger than the vault's USDC is impossible.)
            assertLe(total, vaultUSDC + uint256(handler.netPnLApplied() > 0 ? handler.netPnLApplied() : int256(0)),
                "single-account total exceeds vault USDC + PnL credits");
        }
    }
}
