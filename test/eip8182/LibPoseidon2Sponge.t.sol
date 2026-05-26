// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {Test} from "forge-std/Test.sol";
import {LibPoseidon2Yul} from "../../src/bn254/yul/LibPoseidon2Yul.sol";
import {IPoseidon2} from "../../src/eip8182/IPoseidon2.sol";
import {LibPoseidon2Sponge} from "../../src/eip8182/LibPoseidon2Sponge.sol";

contract LibPoseidon2SpongeTest is Test {
    /// @notice poseidon2_permute MUST return the full 4-element post-permutation state.
    ///         state0 must match what poseidon2_core (the single-output upstream) returns,
    ///         and state1/2/3 must be non-zero AND distinct from state0 for non-trivial inputs.
    function test_poseidon2_permute_returns_full_state() public pure {
        _assertFourLaneOutput(1, 2, 3, 2 << 64);
        _assertFourLaneOutput(
            // Realistic field-element inputs (e.g. note-commitment-shaped values).
            0x1762d324c2db6a912e607fd09664aaa02dfe45b90711c0dae9627d62a4207788,
            0x1047bd52da536f6bdd26dfe642d25d9092c458e64a78211298648e81414cbf35,
            0x0a529bb6bbbf25ed33a47a4637dc70eb469a29893047482866748ae7f3a5afe1,
            4 << 64
        );
    }

    function _assertFourLaneOutput(uint256 s0, uint256 s1, uint256 s2, uint256 iv) internal pure {
        uint256 single = LibPoseidon2Yul.poseidon2_core(s0, s1, s2, iv);
        (uint256 r0, uint256 r1, uint256 r2, uint256 r3) = LibPoseidon2Yul.poseidon2_permute(s0, s1, s2, iv);

        // r0 must equal poseidon2_core's single-output return (the rate-0 lane).
        assertEq(r0, single, "r0 != poseidon2_core(s0,s1,s2,iv)");

        // r1/r2/r3 must be non-zero AND distinct from r0. A buggy
        // implementation that emitted `rN := state0` for all four would pass
        // a !=0 check alone, since state0 is non-zero for these inputs.
        assertTrue(r1 != 0 && r1 != r0, "r1 missing or duplicates r0");
        assertTrue(r2 != 0 && r2 != r0, "r2 missing or duplicates r0");
        assertTrue(r3 != 0 && r3 != r0, "r3 missing or duplicates r0");

        // Mutual distinctness — a permutation maps distinct lanes to distinct
        // outputs with overwhelming probability. Probability of any collision
        // here is ~2^-254 for random-looking inputs (BN254 scalar field).
        assertTrue(r1 != r2 && r1 != r3 && r2 != r3, "rate-1/2/3 lanes collide");
    }
}

contract InterfaceShapeTest is Test {
    /// @notice Compile-time type assertion: the IPoseidon2.hash method MUST
    ///         have the exact signature OpenZeppelin MerkleTree's custom-hasher
    ///         pointer expects — `function(bytes32, bytes32) view returns (bytes32)`.
    ///         If the interface ever drifts (e.g. narrowed to `pure`, or
    ///         renamed, or arg types changed), this stops compiling.
    function test_interface_pointer_shape_compiles() public pure {
        // Cannot bind to an interface method without a deployed address, so
        // we use a typed reference to a hypothetical instance. The cast itself
        // is the assertion: if IPoseidon2.hash isn't `function(bytes32,bytes32) external view returns (bytes32)`,
        // this assignment fails to compile.
        IPoseidon2 hasher = IPoseidon2(address(0));
        function(bytes32, bytes32) external view returns (bytes32) ptr = hasher.hash;
        ptr; // silence unused warning
    }
}

contract HashTreeNodeTest is Test {
    function test_hash_treenode_matches_zemse_hash2_vectors() public pure {
        // Same vectors as test/Poseidon2.t.sol::test_hash_2_vectors.
        // Tree-node hash is bare 2-input absorption with IV = 2<<64 — identical
        // to upstream hash_2. Spec §2: "Per EIP-8182, Merkle tree-node hashes
        // are bare 2-input absorptions with IV = 2<<64 and no domain tag."
        bytes32 l = bytes32(uint256(0x1762d324c2db6a912e607fd09664aaa02dfe45b90711c0dae9627d62a4207788));
        bytes32 r = bytes32(uint256(0x1047bd52da536f6bdd26dfe642d25d9092c458e64a78211298648e81414cbf35));
        bytes32 expected = bytes32(uint256(0x303cacb84a267e5f3f46914fd3262dcaa212930c27a2f9de22c080dd9857be35));
        assertEq(LibPoseidon2Sponge.hash(l, r), expected, "tree-node hash mismatch");
    }

    function test_hash_treenode_zero_left_zero_right() public pure {
        bytes32 expected = bytes32(uint256(0x0b63a53787021a4a962a452c2921b3663aff1ffd8d5510540f8e659e782956f1));
        assertEq(LibPoseidon2Sponge.hash(bytes32(0), bytes32(0)), expected, "tree-node hash(0,0) mismatch");
    }

    function test_hash_treenode_reverts_on_non_canonical_left() public {
        bytes32 nonCanonical = bytes32(LibPoseidon2Sponge.PRIME());
        vm.expectRevert();
        this._callHash(nonCanonical, bytes32(uint256(1)));
    }

    function test_hash_treenode_reverts_on_non_canonical_right() public {
        bytes32 nonCanonical = bytes32(LibPoseidon2Sponge.PRIME());
        vm.expectRevert();
        this._callHash(bytes32(uint256(1)), nonCanonical);
    }

    function _callHash(bytes32 left, bytes32 right) external pure returns (bytes32) {
        return LibPoseidon2Sponge.hash(left, right);
    }
}
