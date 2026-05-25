//! EIP-712 domain-separator helper inputs.
//!
//! The actual `keccak256` hashing of the domain separator is deferred to
//! v0.8 when the signing backends land (those crates bring their own
//! `keccak256` via alloy / sha3). This module ships the typed inputs so
//! callers can construct a `DomainSeparatorInput` at SDK boundary today.

use serde::{Deserialize, Serialize};

/// Typed inputs to the EIP-712 domain separator. Concrete `to_bytes32()`
/// implementation lands at v0.8 alongside the alloy-based signing client.
///
/// On the Solidity side this is computed in
/// `OrderTypes.sol::domainSeparator(chainId, verifyingContract)` with
/// name `"ArcPerpRef"` and version `"v1"`. Any change to those constants
/// is a wire-breaking change and the [`DomainSeparatorInput::NAME`] /
/// [`DomainSeparatorInput::VERSION`] constants here must rev in lockstep.
#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct DomainSeparatorInput {
    /// The chain id the OrderBook is deployed on. Bound at deploy time
    /// in `Deploy.s.sol`; readers pin against the deployment manifest at
    /// `docs/deployments/arc-testnet.json` (v0.7 target).
    pub chain_id: u64,
    /// The OrderBook contract address. Bound at deploy time.
    pub verifying_contract: [u8; 20],
}

impl DomainSeparatorInput {
    /// EIP-712 domain name. MUST match the Solidity-side
    /// `keccak256(bytes("ArcPerpRef"))` argument.
    pub const NAME: &'static str = "ArcPerpRef";

    /// EIP-712 domain version. MUST match the Solidity-side
    /// `keccak256(bytes("v1"))` argument.
    pub const VERSION: &'static str = "v1";

    /// Construct from typed inputs.
    #[must_use]
    pub fn new(chain_id: u64, verifying_contract: [u8; 20]) -> Self {
        Self {
            chain_id,
            verifying_contract,
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn domain_name_and_version_match_solidity() {
        assert_eq!(DomainSeparatorInput::NAME, "ArcPerpRef");
        assert_eq!(DomainSeparatorInput::VERSION, "v1");
    }

    #[test]
    fn domain_separator_input_serde_roundtrips() {
        let input = DomainSeparatorInput::new(11111, [0u8; 20]);
        let json = serde_json::to_string(&input).expect("serialize");
        let back: DomainSeparatorInput = serde_json::from_str(&json).expect("deserialize");
        assert_eq!(input, back);
    }
}
