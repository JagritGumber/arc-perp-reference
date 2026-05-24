# ADR 0002 — Permissionless account onboarding

Status: accepted, v0.1
Date: 2026-05-25

## Context

Shapeshifter's CMDT ClearingHouse — the perp DEX most builders find when they go looking on Arc Testnet — uses a Fireblocks-bound account model. The on-chain `ClearingHouse` checks `getAccountOwner(accountId)` to validate signers, and that binding is provisioned off-chain via Shapeshifter's Fireblocks integration. New traders cannot onboard themselves; they must go through Shapeshifter's custody workflow.

For human-mediated institutional trading this pattern is reasonable — Fireblocks handles compliance, key management, and counterparty vetting. For autonomous AI agent builders it is a hard blocker. The agent has no human in the loop to complete a Fireblocks-style onboarding flow. An agent that needs to construct, sign, and submit orders every few minutes cannot wait for a custodian to provision a binding.

Both teams that hit this wall during the Agora hackathon (Selbo and Baus's CapitalArc) ended up redesigning execution against Hyperliquid testnet, where account onboarding is permissionless via standard EOA signing. The Arc-native venue that would have been the natural target was structurally unreachable for autonomous flows.

## Decision

`arc-perp-reference` ships permissionless account onboarding. Specifically:

- `AccountManager.registerAccount()` is callable by any EOA with no preconditions. The function assigns the caller a fresh monotonic `accountId` and records the mapping `accountId -> msg.sender` directly in contract state. No off-chain step, no allowlist, no custodian binding.
- All downstream contracts (`OrderBook`, `SettlementEngine`, `USDCVault`) consume `AccountManager.ownerOf(accountId)` as the canonical signer source. Order signature recovery checks the signed digest against the EOA returned by `ownerOf`.
- Each EOA can register exactly one master account in v0.1. The `AlreadyRegistered` revert prevents accidental duplicates and keeps the `accountIdOf(owner)` mapping injective.
- Sub-accounts (per-strategy isolated margin) are scoped for v1.1. The `IAccountManager` interface already declares the `SubAccountRegistered` event so downstream consumers can target the v1.1 surface today, but the implementation reserves the sub-account namespace and returns "not implemented" for now.

The `accountId = 0` value is reserved as the unregistered sentinel. This lets `accountIdOf(unknownEOA)` return `0` unambiguously without an `Option<uint256>` type or a separate exists-check.

## Consequences

**Positive:**
- Any builder can integrate immediately. No allowlist, no email, no custodian provisioning.
- Autonomous AI agents can self-onboard. The Circle Developer-Controlled Wallet pattern that Selbo and similar agents use plays cleanly with this model: the wallet calls `registerAccount()` once and immediately becomes tradeable.
- The trust surface for accounts is minimal — just the `AccountManager` contract itself. No off-chain binding to verify, no Fireblocks vault to trust, no custodian to sue if something goes wrong.
- The model is forkable. Any application on Arc that needs permissionless account registration without custodian binding can reuse `AccountManager` directly.

**Negative:**
- No KYC, no compliance, no jurisdiction filtering. Production deployments targeting regulated venues would need to layer those on top (likely via an allowlist of pre-cleared addresses sitting in front of `registerAccount`). For an open-source reference this is intentional.
- The one-account-per-EOA limit in v0.1 forces traders who want isolated risk per strategy to use multiple EOAs. Sub-accounts in v1.1 fix this.
- A spam EOA can register an account for free (modulo gas). Mitigation: account registration costs only ~50k gas and the account is useless until funded via `USDCVault.deposit`, so the spam cost is bounded.

**Neutral:**
- Account ownership is non-transferable in v0.1. The owner mapping is set at registration and not exposed for update. A future v1.1 might add an `transferOwnership(accountId, newOwner)` flow with a timelock, but it is not required for v0.1.

## Alternatives considered

- **Fireblocks-bound accounts (rejected).** This is Shapeshifter's existing pattern. Rejected because it blocks autonomous agent onboarding, which is the use case this reference exists to unblock.
- **ERC-4337 Smart Contract Account model (deferred to v1.1).** Strong long-term fit for gasless onboarding and richer signing semantics. Deferred because it adds bundler infrastructure that v0.1 does not need. The current EOA-registration model can coexist with an SCA-registration path added later.
- **Self-sovereign DID / ENS / SIWE binding (rejected for v0.1).** Adds external identity dependencies for marginal benefit. The simpler `EOA -> accountId` mapping is sufficient and easy to reason about.
- **Allowlist-gated registration (rejected).** Defeats the explicit goal of the primitive. Production forks can add an allowlist layer if their use case demands it.

## References

- Shapeshifter CMDT ClearingHouse contract: `0x70a069462195E57A4f2E9aCb626Cf1d7E6aF9892` on Arc Testnet (the `getAccountOwner(accountId)` shape this primitive contrasts with)
- Circle Developer-Controlled Wallets entity-secret pattern: https://developers.circle.com/w3s/programmable-wallets
- ERC-4337 Account Abstraction (for v1.1 path): https://eips.ethereum.org/EIPS/eip-4337
- Hyperliquid sub-accounts pattern (for v1.1 sub-account inspiration): https://hyperliquid.gitbook.io/hyperliquid-docs/for-developers/api/sub-accounts
