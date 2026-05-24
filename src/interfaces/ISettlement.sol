// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

/// @title  ISettlement
/// @notice Permissionless settlement of matched orders. The primitive that
///         breaks the SETTLEMENT_ROLE gate Shapeshifter's CMDT ClearingHouse
///         enforces. Anyone can call settleBatch with a valid match set;
///         margin, liquidation, and signature checks are enforced on-chain.
interface ISettlement {
    /// @notice A single matched fill between two opposing orders.
    /// @param  buyOrderHash    Hash of the buy-side order (long entry or short close).
    /// @param  sellOrderHash   Hash of the sell-side order (short entry or long close).
    /// @param  buyAccountId    Account opening/adjusting the long side of the fill.
    /// @param  sellAccountId   Account opening/adjusting the short side of the fill.
    /// @param  marketId        Market the fill executed in.
    /// @param  size            Fill size in 1e18 base units.
    /// @param  price           Fill price in PRICE_SCALE units (1e8 = $1).
    struct Match {
        bytes32 buyOrderHash;
        bytes32 sellOrderHash;
        uint256 buyAccountId;
        uint256 sellAccountId;
        uint256 marketId;
        uint256 size;
        uint256 price;
    }

    /// @notice Emitted per match successfully settled.
    event Settled(
        bytes32 indexed buyOrderHash,
        bytes32 indexed sellOrderHash,
        uint256 indexed marketId,
        uint256 size,
        uint256 price
    );

    /// @notice Settle a batch of matches. Permissionless. Validates that:
    ///         - both order hashes were emitted by the bound OrderBook in the
    ///           current block (or last N blocks per settlement window)
    ///         - both accounts pass margin checks at the new positions
    ///         - neither account is in liquidation
    ///         Reverts the whole batch on any failure.
    function settleBatch(Match[] calldata matches) external;
}
