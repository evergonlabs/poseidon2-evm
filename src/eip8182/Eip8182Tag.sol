// SPDX-License-Identifier: MIT
pragma solidity >=0.8.8;

/// @title Eip8182Tag
/// @notice Derives domain tags as fieldElement(keccak256("eip-8182.<name>")).
///         This derivation — the "eip-8182." prefix and the `mod p` reduction —
///         is normative: EIP-8182 §3.1 requires every domain tag to be
///         `uint256(keccak256("eip-8182.<context_name>")) mod p` (a MUST).
/// @dev    A consumer picks its own `<name>` strings (one per logical hash
///         domain) and MUST keep the on-chain and in-circuit derivations on
///         identical strings. EIP-8182's own context names (§3.1 table, e.g.
///         "note_commitment", "nullifier") carry no version suffix.
library Eip8182Tag {
    uint256 internal constant PRIME = 0x30644e72e131a029b85045b68181585d2833e84879b9709143e1f593f0000001;
    bytes9 internal constant PREFIX = "eip-8182.";

    function derive(string memory name) internal pure returns (bytes32) {
        bytes32 h = keccak256(abi.encodePacked(PREFIX, bytes(name)));
        return bytes32(uint256(h) % PRIME);
    }
}
