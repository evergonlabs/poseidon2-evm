// SPDX-License-Identifier: MIT
pragma solidity >=0.8.8;

import {LibPoseidon2Yul} from "../bn254/yul/LibPoseidon2Yul.sol";

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
}
