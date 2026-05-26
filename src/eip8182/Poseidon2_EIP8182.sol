// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {IPoseidon2} from "./IPoseidon2.sol";
import {LibPoseidon2Sponge} from "./LibPoseidon2Sponge.sol";

/// @title Poseidon2_EIP8182
/// @notice EIP-8182-conformant Poseidon2-BN254-t4 sponge hasher.
/// @dev    Deployable singleton — the ConfidentialOmnibusVault references one
///         instance via `address public immutable poseidon2` and reaches it
///         through STATICCALL. Spec: Poseidon2-hasher-spec.md §0, §3, §7.
///
///         Holds no storage. STATICCALL sandboxes it from caller storage.
///         The implementation functions are `pure`; the interface is `view`
///         (so the function-pointer type matches OpenZeppelin MerkleTree's
///         custom-hasher signature). A `pure` impl satisfies a `view`
///         interface — see spec §3.
contract Poseidon2_EIP8182 is IPoseidon2 {
    /// @inheritdoc IPoseidon2
    function hash(bytes32 left, bytes32 right) external pure override returns (bytes32) {
        return LibPoseidon2Sponge.hash(left, right);
    }

    /// @inheritdoc IPoseidon2
    function hashN(bytes32[] calldata inputs) external pure override returns (bytes32) {
        return LibPoseidon2Sponge.hashN(inputs);
    }
}
