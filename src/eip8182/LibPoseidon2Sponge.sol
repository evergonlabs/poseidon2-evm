// SPDX-License-Identifier: MIT
pragma solidity >=0.8.8;

import {LibPoseidon2Yul} from "../bn254/yul/LibPoseidon2Yul.sol";
import {InvalidHashNArity} from "./IPoseidon2.sol";

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
    /// @dev    inputs[0] is the *_V1 domain tag (caller-provided; not auto-
    ///         prepended). For arity 2-3 this is a single permutation; for
    ///         arity > 3 it absorbs in rate-3 blocks (Task 7). Spec §2 / §3.
    ///         Reverts InvalidHashNArity on arity {0, 1}.
    ///         Reverts InvalidFieldElement on any inputs[i] >= PRIME (the
    ///         inherited check in poseidon2_core covers the rate inputs).
    function hashN(bytes32[] calldata inputs) internal pure returns (bytes32) {
        uint256 n = inputs.length;
        if (n < 2) {
            // arity 0 / 1 is a misuse — a domain tag with no payload.
            revert InvalidHashNArity(n);
        }
        uint256 iv = n << 64;

        if (n <= 3) {
            // Single-permutation path: load up to 3 rate lanes, zero-pad the rest.
            uint256 s0;
            uint256 s1;
            uint256 s2;
            assembly {
                s0 := calldataload(inputs.offset)
                if gt(n, 1) { s1 := calldataload(add(inputs.offset, 0x20)) }
                if gt(n, 2) { s2 := calldataload(add(inputs.offset, 0x40)) }
            }
            uint256 result = LibPoseidon2Yul.poseidon2_core(s0, s1, s2, iv);
            return bytes32(result);
        }

        // arity > 3 path lands in Task 7. Until then, stub-revert.
        revert("LibPoseidon2Sponge: arity > 3 not yet implemented");
    }
}
