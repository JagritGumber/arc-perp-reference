// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Script, console2} from "forge-std/Script.sol";
import {AccountManager} from "../src/AccountManager.sol";
import {USDCVault, IERC20} from "../src/USDCVault.sol";
import {IAccountManager} from "../src/interfaces/IAccountManager.sol";

/// @title  Deploy
/// @notice v0.1 deployment script. Deploys the two primitives that ship in
///         v0.1 and wires USDCVault against AccountManager. SettlementEngine
///         binding intentionally NOT performed here - that happens in the
///         v0.7 wired-deploy script once SettlementEngine.sol exists.
///
/// @dev    Required env vars:
///         - ARC_USDC: address of the USDC ERC-20 on Arc Testnet
///                     (the canonical contract that will hold collateral).
///         Optional env vars:
///         - PRIVATE_KEY: vm.startBroadcast key. Foundry's --account flag
///                        works too if you prefer keystore-managed keys.
///
///         Run:
///           forge script script/Deploy.s.sol \
///             --rpc-url $ARC_RPC --broadcast --verify
contract Deploy is Script {
    function run() external {
        address usdc = vm.envAddress("ARC_USDC");
        vm.startBroadcast();

        AccountManager accountManager = new AccountManager();
        USDCVault vault = new USDCVault(IERC20(usdc), IAccountManager(address(accountManager)));

        console2.log("--- arc-perp-reference v0.1 deployment ---");
        console2.log("AccountManager:", address(accountManager));
        console2.log("USDCVault:     ", address(vault));
        console2.log("USDC (Arc):    ", usdc);
        console2.log("ChainId:       ", block.chainid);

        vm.stopBroadcast();
    }
}
