// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Test} from "forge-std/Test.sol";
import {AccountManager} from "../../src/AccountManager.sol";
import {USDCVault, IERC20} from "../../src/USDCVault.sol";
import {IAccountManager} from "../../src/interfaces/IAccountManager.sol";
import {MockUSDC} from "../USDCVault.t.sol";

/// @notice End-to-end v0.1 integration: register an account, deposit USDC,
///         withdraw USDC. Proves the two shipped primitives work together
///         as a usable system today, before OrderBook/SettlementEngine land.
///         An Arc builder forking v0.1 has a working USDC vault keyed on
///         permissionless account ids from day one.
contract DepositWithdrawRoundtripTest is Test {
    MockUSDC internal usdc;
    AccountManager internal accounts;
    USDCVault internal vault;

    address internal trader = address(0xCAFE);

    function setUp() public {
        usdc = new MockUSDC();
        accounts = new AccountManager();
        vault = new USDCVault(IERC20(address(usdc)), IAccountManager(address(accounts)));

        usdc.mint(trader, 500_000_000); // 500 USDC
    }

    function test_v01_endToEndRoundtrip() public {
        // 1. Permissionless account registration.
        vm.prank(trader);
        uint256 accountId = accounts.registerAccount();
        assertEq(accountId, 1, "first account id");
        assertEq(accounts.ownerOf(accountId), trader);
        assertEq(accounts.accountIdOf(trader), accountId);

        // 2. Approve + deposit USDC into the vault.
        vm.prank(trader);
        usdc.approve(address(vault), 250_000_000);
        vm.prank(trader);
        vault.deposit(accountId, 250_000_000);

        assertEq(vault.freeBalanceOf(accountId), 250_000_000, "free balance after deposit");
        assertEq(vault.lockedBalanceOf(accountId), 0, "no margin locked pre-settlement-engine");
        assertEq(vault.totalBalanceOf(accountId), 250_000_000);
        assertEq(usdc.balanceOf(trader), 250_000_000, "trader wallet debited");
        assertEq(usdc.balanceOf(address(vault)), 250_000_000, "vault holds the funds");

        // 3. Partial withdrawal back to wallet.
        vm.prank(trader);
        vault.withdraw(accountId, 100_000_000, trader);

        assertEq(vault.freeBalanceOf(accountId), 150_000_000, "free balance after partial withdraw");
        assertEq(usdc.balanceOf(trader), 350_000_000, "trader wallet refunded");
        assertEq(usdc.balanceOf(address(vault)), 150_000_000, "vault holds residual");

        // 4. Full withdrawal back to wallet.
        vm.prank(trader);
        vault.withdraw(accountId, 150_000_000, trader);

        assertEq(vault.freeBalanceOf(accountId), 0, "free balance drained");
        assertEq(vault.totalBalanceOf(accountId), 0);
        assertEq(usdc.balanceOf(trader), 500_000_000, "trader wallet fully restored");
        assertEq(usdc.balanceOf(address(vault)), 0, "vault drained");

        // 5. Account row persists post-withdrawal so the trader can
        //    re-deposit later without re-registering.
        assertEq(accounts.accountIdOf(trader), accountId, "account row persists");
    }

    function test_v01_marginHooksRevertUntilSettlementBound() public {
        vm.prank(trader);
        uint256 accountId = accounts.registerAccount();
        vm.prank(trader);
        usdc.approve(address(vault), 100_000_000);
        vm.prank(trader);
        vault.deposit(accountId, 100_000_000);

        // SettlementEngine not bound yet -> margin hooks revert.
        // Proves v0.1 is composable but doesn't pretend to support
        // settlement before v0.5 ships.
        vm.expectRevert(USDCVault.SettlementEngineNotBound.selector);
        vault.lockMargin(accountId, 10_000_000);

        vm.expectRevert(USDCVault.SettlementEngineNotBound.selector);
        vault.releaseMargin(accountId, 10_000_000);

        vm.expectRevert(USDCVault.SettlementEngineNotBound.selector);
        vault.applyPnL(accountId, 1_000_000);
    }
}
