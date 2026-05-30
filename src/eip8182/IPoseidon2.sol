// SPDX-License-Identifier: MIT
pragma solidity >=0.8.8;

/// @title IPoseidon2 (EIP-8182 sponge)
/// @notice View interface for the EIP-8182-conformant Poseidon2-BN254-t4 sponge.
/// @dev    This is NOT the upstream zemse/poseidon2-evm IPoseidon2 (which
///         exposes hash_1/2/3 over uint256); the collision is of names only.
///
///         The interface is `view`, deliberately. OZ MerkleTree's custom-hasher
///         pointer signature is `function(bytes32,bytes32) view returns (bytes32)`;
///         a `pure` implementation satisfies `view`, but narrowing the interface
///         to `pure` breaks the pointer-type match. Do not narrow.
interface IPoseidon2 {
    /// @notice 2-input tree-node hash — the Merkle-tree compression.
    /// @dev    Untagged absorption with IV = 2<<64. NOT a domain-
    ///         separated hashN call; the IV-length-tag is what separates a
    ///         tree-node hash from any arity-≥3 application hash.
    function hash(bytes32 left, bytes32 right) external view returns (bytes32);

    /// @notice Fixed-arity, domain-separated absorption.
    /// @dev    inputs[0] MUST be the domain tag computed per EIP-8182 §3.1 as
    ///         fieldElement(keccak256("eip-8182.<name>")).
    ///         Reverts InvalidHashNArity(length) on inputs.length == 0 or 1
    ///         (a tag with no payload is a misuse).
    ///         Reverts InvalidFieldElement(value) on any inputs[i] >= PRIME.
    function hashN(bytes32[] calldata inputs) external view returns (bytes32);
}

/// @notice Thrown by hashN when inputs.length is 0 or 1 (no payload after tag).
error InvalidHashNArity(uint256 length);

/// @notice Thrown when an input element is >= BN254 scalar field PRIME.
///         Silent mod-p reduction is forbidden — it would allow (x, x+p) collisions.
error InvalidFieldElement(uint256 value);
