// SPDX-License-Identifier: MIT
pragma solidity >=0.8.8;

import {LibPoseidon2Yul} from "../bn254/yul/LibPoseidon2Yul.sol";
import {InvalidHashNArity, InvalidFieldElement} from "./IPoseidon2.sol";

/// @title LibPoseidon2Sponge
/// @notice EIP-8182-conformant sponge wrapper over the upstream Poseidon2-BN254-t4
///         permutation. Spec: Poseidon2-hasher-spec.md §2.
/// @dev    All entry points reject inputs >= PRIME (no silent mod). The
///         length-tagged-IV construction is `inputCount << 64`, per EIP-8182.
library LibPoseidon2Sponge {
    /// @notice BN254 scalar field PRIME, exposed for tests / external callers.
    function PRIME() internal pure returns (uint256) {
        return 0x30644e72e131a029b85045b68181585d2833e84879b9709143e1f593f0000001;
    }

    /// @notice 2-input tree-node hash. Untagged, IV = 2<<64. Spec §2.
    /// @dev    Canonical-input checks live inside LibPoseidon2Yul.poseidon2_core
    ///         (Task 3): it reverts on rate inputs >= PRIME. Passing `left`/
    ///         `right` through is safe.
    function hash(bytes32 left, bytes32 right) internal pure returns (bytes32) {
        uint256 l;
        uint256 r;
        assembly {
            l := left
            r := right
        }
        uint256 result = LibPoseidon2Yul.poseidon2_core(l, r, 0, 2 << 64);
        bytes32 out;
        assembly {
            out := result
        }
        return out;
    }

    /// @notice Fixed-arity domain-separated absorption.
    /// @dev    inputs[0] is the caller-supplied domain tag (derived per
    ///         EIP-8182 §10; not auto-prepended by this library). For arity
    ///         2-3 this is a single permutation; for
    ///         arity > 3 it absorbs in rate-3 blocks with additive duplex
    ///         (state[i] += block[i]) between permutations. Spec §2.
    ///         Reverts InvalidHashNArity on arity {0, 1}.
    ///         Reverts InvalidFieldElement on any inputs[i] >= PRIME.
    function hashN(bytes32[] calldata inputs) internal pure returns (bytes32) {
        uint256 n = inputs.length;
        if (n < 2) {
            revert InvalidHashNArity(n);
        }
        uint256 iv = n << 64;

        if (n <= 3) {
            // Single-permutation path (arity 2-3). Loads up to 3 rate lanes,
            // zero-pads the rest. poseidon2_core inherits the canonical-input
            // check on s0/s1/s2 (Task 3).
            uint256 s0_;
            uint256 s1_;
            uint256 s2_;
            assembly {
                s0_ := calldataload(inputs.offset)
                if gt(n, 1) { s1_ := calldataload(add(inputs.offset, 0x20)) }
                if gt(n, 2) { s2_ := calldataload(add(inputs.offset, 0x40)) }
            }
            return bytes32(LibPoseidon2Yul.poseidon2_core(s0_, s1_, s2_, iv));
        }

        // Multi-block additive-duplex absorb (arity > 3). Initial state =
        // (0, 0, 0, iv). For each rate-3 chunk: state[0..2] += chunk[0..2]
        // (mod PRIME); then permute. Last chunk is zero-padded if n is not
        // a multiple of 3. Spec §2 / EIP-8182 §10.
        uint256 PRIME_ = PRIME();
        uint256 st0 = 0;
        uint256 st1 = 0;
        uint256 st2 = 0;
        uint256 st3 = iv;

        uint256 i = 0;
        while (i < n) {
            // Load up to 3 inputs from the current chunk position.
            uint256 b0;
            uint256 b1;
            uint256 b2;
            assembly {
                b0 := calldataload(add(inputs.offset, mul(i, 0x20)))
            }
            // For b1/b2, only load if the index is within bounds; otherwise
            // they remain zero (zero-padded short tail).
            if (i + 1 < n) {
                assembly { b1 := calldataload(add(inputs.offset, mul(add(i, 1), 0x20))) }
            }
            if (i + 2 < n) {
                assembly { b2 := calldataload(add(inputs.offset, mul(add(i, 2), 0x20))) }
            }

            // Canonical-input checks. The rate lanes are SUMS after addmod,
            // so the inherited check in poseidon2_permute (which validates
            // its s0/s1/s2 arguments) cannot catch a non-canonical input.
            // Validate each loaded input ourselves BEFORE addmod.
            if (b0 >= PRIME_) revert InvalidFieldElement(b0);
            if (i + 1 < n && b1 >= PRIME_) revert InvalidFieldElement(b1);
            if (i + 2 < n && b2 >= PRIME_) revert InvalidFieldElement(b2);

            // Additive duplex: state[0..2] += block[0..2]. (b1/b2 are zero
            // when out of bounds, so this also correctly zero-pads the tail.)
            assembly {
                st0 := addmod(st0, b0, PRIME_)
                st1 := addmod(st1, b1, PRIME_)
                st2 := addmod(st2, b2, PRIME_)
            }

            // Permute. After addmod, st0..st2 are canonical, so the inherited
            // canonical check in poseidon2_permute is a no-op (a sanity guard).
            (st0, st1, st2, st3) = LibPoseidon2Yul.poseidon2_permute(st0, st1, st2, st3);

            i += 3;
        }

        return bytes32(st0);
    }
}
