// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Script, console2} from "forge-std/Script.sol";
import {AccountManager} from "../src/AccountManager.sol";

/// @title  Deploy
/// @notice v0.1 deployment script. Currently ships only AccountManager since
///         it is the only fully-implemented contract in v0.1. The rest of the
///         system (OrderBook, SettlementEngine, USDCVault, MarketRegistry,
///         LiquidationKeeper) is scaffolded via interfaces + ADRs; their
///         deployment wiring will land alongside their implementations.
///
/// @dev    Wiring order at v1.0 is intended to be:
///         1. USDCVault (no deps)
///         2. AccountManager (no deps)
///         3. MarketRegistry (admin-curated markets bound to oracles)
///         4. OrderBook (consumes AccountManager + MarketRegistry)
///         5. SettlementEngine (consumes OrderBook + USDCVault + MarketRegistry)
///         6. LiquidationKeeper (consumes SettlementEngine + USDCVault + MarketRegistry)
///         7. USDCVault.bindSettlementEngine(settlement)
///         8. OrderBook.bindSettlementEngine(settlement)
///
///         The full Deploy contract will materialize the above as constants
///         and emit a deployment manifest (addresses + EIP-712 domainSeparator
///         + chainId) into the broadcast log for downstream consumers to pin.
contract Deploy is Script {
    function run() external {
        vm.startBroadcast();

        AccountManager accountManager = new AccountManager();
        console2.log("AccountManager:", address(accountManager));

        vm.stopBroadcast();
    }
}
