//! Minimal example: construct an `Order` and print it.
//!
//! v0.8 will expand this into a full `place_order.rs` that signs via a
//! Circle Dev Wallet and submits through the on-chain `OrderBook`.
//!
//! Run with:
//!   cargo run --example construct_order -p arc-perp-sdk

use arc_perp_sdk::{domain::DomainSeparatorInput, order::Order};

fn main() {
    // A long BTC order: 1 BTC notional at $65k limit price.
    let order = Order::new(
        7,                       // accountId (from AccountManager.registerAccount)
        1,                       // marketId (BTC perp, from MarketRegistry.registerMarket)
        true,                    // isBuy = long entry
        6_500_000_000_000,       // limitPrice = $65,000 in PRICE_SCALE (1e8) units
        1_000_000_000_000_000_000, // size = 1 BTC in 1e18 base units
        1,                       // nonce
        1_717_000_000,           // expiry (unix timestamp)
        false,                   // not reduce-only
    );

    let domain = DomainSeparatorInput::new(11111, [0u8; 20]);

    println!("=== arc-perp-sdk example: constructed order ===");
    println!("EIP-712 domain:");
    println!("  name             : {}", DomainSeparatorInput::NAME);
    println!("  version          : {}", DomainSeparatorInput::VERSION);
    println!("  chainId          : {}", domain.chain_id);
    println!("  verifyingContract: 0x{}", hex::encode(domain.verifying_contract));
    println!();
    println!("Order:");
    println!("  accountId   : {}", order.account_id);
    println!("  marketId    : {}", order.market_id);
    println!("  isBuy       : {}", order.is_buy);
    println!("  limitPrice  : {} (= ${:.2})", order.limit_price, (order.limit_price as f64) / 1e8);
    println!("  size        : {} (= {} units)", order.size, (order.size as f64) / 1e18);
    println!("  nonce       : {}", order.nonce);
    println!("  expiry      : {}", order.expiry);
    println!("  reduceOnly  : {}", order.reduce_only);
    println!();
    println!("EIP-712 type string:");
    println!("  {}", Order::EIP712_TYPE_STRING);
    println!();
    println!("(v0.8 will add signing + RPC submission; this example only constructs the typed payload.)");
}
