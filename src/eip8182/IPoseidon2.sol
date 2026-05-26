// SPDX-License-Identifier: MIT
pragma solidity >=0.8.8;

/// @title IPoseidon2 (EIP-8182 sponge, vault-side)
/// @notice The view interface ConfidentialOmnibusVault links Poseidon2 through.
/// @dev    This is NOT the upstream zemse/poseidon2-evm IPoseidon2 (which
///         exposes hash_1/2/3 over uint256); the collision is of names only.
///         See src/IPoseidon2.sol for the upstream interface.
///
///         The interface is `view`, deliberately. OZ MerkleTree's custom-hasher
///         pointer signature is `function(bytes32,bytes32) view returns (bytes32)`;
///         a `pure` implementation satisfies `view`, but narrowing the interface
///         to `pure` breaks the pointer-type match. Do not narrow.
///
///         Spec: Poseidon2-hasher-spec.md §3.
interface IPoseidon2 {
    /// @notice 2-input tree-node hash — the Merkle-tree compression.
    /// @dev    Untagged absorption with IV = 2<<64 (spec §2). NOT a domain-
    ///         separated hashN call; the IV-length-tag is what separates a
    ///         tree-node hash from any arity-≥3 application hash.
    function hash(bytes32 left, bytes32 right) external view returns (bytes32);

    /// @notice Fixed-arity, domain-separated absorption.
    /// @dev    inputs[0] MUST be the *_V1 domain tag computed per EIP-8182 §10
    ///         as fieldElement(keccak256("eip-8182.<tag_name>")) (spec §2).
    ///         Reverts InvalidHashNArity(length) on inputs.length == 0 or 1
    ///         (a tag with no payload is a misuse).
    ///         Reverts InvalidFieldElement(value) on any inputs[i] >= PRIME.
    function hashN(bytes32[] calldata inputs) external view returns (bytes32);
}

/// @notice Thrown by hashN when inputs.length is 0 or 1 (no payload after tag).
error InvalidHashNArity(uint256 length);

/// @notice Thrown when an input element is >= BN254 scalar field PRIME.
///         Silent mod-p reduction is explicitly forbidden by the spec (§2).
error InvalidFieldElement(uint256 value);
