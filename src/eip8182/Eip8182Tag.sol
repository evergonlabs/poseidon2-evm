// SPDX-License-Identifier: MIT
pragma solidity >=0.8.8;

/// @title Eip8182Tag
/// @notice Derives EIP-8182 §10 domain tags as
///         fieldElement(keccak256("eip-8182.<name>")).
/// @dev    The reduction `% PRIME` ensures the tag is a canonical field
///         element (keccak256 output can exceed PRIME, though it almost never
///         does in practice; we reduce defensively).
///
///         A consumer protocol typically picks its own set of `<name>` strings
///         (one per logical hash domain — e.g., one for leaf-commitment hashes,
///         one for nullifier hashes, etc.) and pins the derived hex values in
///         its own design notes. This library only ships the derivation
///         primitive plus a couple of illustrative examples below.
library Eip8182Tag {
    uint256 internal constant PRIME = 0x30644e72e131a029b85045b68181585d2833e84879b9709143e1f593f0000001;
    bytes9 internal constant PREFIX = "eip-8182.";

    function derive(string memory name) internal pure returns (bytes32) {
        bytes32 h = keccak256(abi.encodePacked(PREFIX, bytes(name)));
        return bytes32(uint256(h) % PRIME);
    }

    // ----------------------------------------------------------------
    // Illustrative examples. Not part of EIP-8182 — pick your own
    // <name> strings in the consuming protocol.
    // ----------------------------------------------------------------

    /// @notice Example: a tag for a generic 4-input commitment hash.
    function EXAMPLE_COMMITMENT_V1() internal pure returns (bytes32) {
        return derive("example_commitment_v1");
    }

    /// @notice Example: a tag for a generic single-input nullifier-style hash.
    function EXAMPLE_NULLIFIER_V1() internal pure returns (bytes32) {
        return derive("example_nullifier_v1");
    }
}
