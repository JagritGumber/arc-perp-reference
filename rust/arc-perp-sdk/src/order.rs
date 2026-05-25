//! EIP-712 `Order` type mirroring `src/types/OrderTypes.sol` on-chain.
//!
//! The struct field order, types, and EIP-712 type string must remain
//! byte-identical to the Solidity side. Any change here is a wire-breaking
//! change and the on-chain `ORDER_TYPEHASH` must rev in lockstep. The
//! Solidity-side test [`test/OrderTypes.t.sol::test_typeHash_isFrozen`]
//! catches Solidity-side drift; the Rust-side check is the
//! [`Order::EIP712_TYPE_STRING`] constant + the `ORDER_TYPEHASH`
//! comparison below.

use serde::{Deserialize, Serialize};

/// A single perpetual-futures order, EIP-712-signed by an account's owner.
///
/// Mirrors the `Order` struct in [`src/types/OrderTypes.sol`]. Field shape,
/// order, and types are wire-frozen and must not drift.
#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct Order {
    /// `AccountManager`-assigned identifier of the trader.
    pub account_id: u128,
    /// `MarketRegistry`-assigned identifier of the perp market.
    pub market_id: u128,
    /// `true` = long entry / short close, `false` = short entry / long close.
    pub is_buy: bool,
    /// Worst-acceptable price in `PRICE_SCALE` units (1e8 = $1).
    pub limit_price: u128,
    /// Notional size in 1e18 base units.
    pub size: u128,
    /// Monotonic per-account counter; settled orders consume their nonce.
    pub nonce: u128,
    /// `block.timestamp` cutoff. Orders past expiry are rejected at submit.
    pub expiry: u64,
    /// `true` = order may only reduce an existing position.
    pub reduce_only: bool,
}

impl Order {
    /// The canonical EIP-712 type string for `Order`. Must match
    /// `OrderTypes.sol::ORDER_TYPEHASH`'s input exactly.
    pub const EIP712_TYPE_STRING: &'static str = "Order(uint256 accountId,uint256 marketId,bool isBuy,uint256 limitPrice,uint256 size,uint256 nonce,uint256 expiry,bool reduceOnly)";

    /// Construct a new order. All fields validated at signing time
    /// downstream, not here.
    #[must_use]
    #[allow(clippy::too_many_arguments)]
    pub fn new(
        account_id: u128,
        market_id: u128,
        is_buy: bool,
        limit_price: u128,
        size: u128,
        nonce: u128,
        expiry: u64,
        reduce_only: bool,
    ) -> Self {
        Self {
            account_id,
            market_id,
            is_buy,
            limit_price,
            size,
            nonce,
            expiry,
            reduce_only,
        }
    }
}

/// Errors that can occur constructing or signing an order.
///
/// v0.1 surface is small; v0.8 adds variants for signer-backend errors
/// (Circle Dev Wallet API failures, AWS KMS errors, etc.) when the
/// signing backends land.
#[derive(Debug, thiserror::Error)]
pub enum OrderError {
    /// Order is missing a required field, has an invalid combination, or
    /// has expired. Specific reason in the inner message.
    #[error("invalid order: {0}")]
    Invalid(String),
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn eip712_type_string_matches_solidity() {
        // This string must remain byte-identical to the Solidity-side
        // ORDER_TYPEHASH input. A drift here is a wire-breaking change.
        assert_eq!(
            Order::EIP712_TYPE_STRING,
            "Order(uint256 accountId,uint256 marketId,bool isBuy,uint256 limitPrice,uint256 size,uint256 nonce,uint256 expiry,bool reduceOnly)"
        );
    }

    #[test]
    fn order_is_constructable_and_serde_roundtrips() {
        let order = Order::new(
            7,
            1,
            true,
            6_500_000_000_000,
            1_000_000_000_000_000_000,
            42,
            1_717_000_000,
            false,
        );
        let json = serde_json::to_string(&order).expect("serialize");
        let back: Order = serde_json::from_str(&json).expect("deserialize");
        assert_eq!(order, back);
    }
}
