// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {Test} from "forge-std/Test.sol";
import {LibPoseidon2Yul} from "../../src/bn254/yul/LibPoseidon2Yul.sol";
import {IPoseidon2} from "../../src/eip8182/IPoseidon2.sol";
import {LibPoseidon2Sponge} from "../../src/eip8182/LibPoseidon2Sponge.sol";
import {InvalidHashNArity} from "../../src/eip8182/IPoseidon2.sol";

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

contract HashNSinglePermutationTest is Test {
    /// @notice hashN with two inputs MUST equal upstream hash_2 of those inputs
    ///         (same IV = 2<<64, same single permutation, return state[0]).
    function test_hashN_arity2_matches_zemse_hash2() public view {
        bytes32[] memory inputs = new bytes32[](2);
        inputs[0] = bytes32(uint256(0x1762d324c2db6a912e607fd09664aaa02dfe45b90711c0dae9627d62a4207788));
        inputs[1] = bytes32(uint256(0x1047bd52da536f6bdd26dfe642d25d9092c458e64a78211298648e81414cbf35));
        bytes32 expected = bytes32(uint256(0x303cacb84a267e5f3f46914fd3262dcaa212930c27a2f9de22c080dd9857be35));
        assertEq(this._callHashN(inputs), expected, "hashN arity-2 mismatch");
    }

    function test_hashN_arity3_matches_zemse_hash3() public view {
        bytes32[] memory inputs = new bytes32[](3);
        inputs[0] = bytes32(uint256(0x300ced31bf248a1a2d4ea02b5e9f302a9e34df3c2109d5f1046ee9f59de6f6f1));
        inputs[1] = bytes32(uint256(0x2e6eb409ed7f41949cdb1925ac3ec68132b2443d873589a8afde4c027c3c0b68));
        inputs[2] = bytes32(uint256(0x2f08443953fc54fb351e41a46da99bbec1d290dae2907d2baf5174ed28eee9ea));
        bytes32 expected = bytes32(uint256(0x27e4cf07e4bf24219f6a2da9be19cea601313a95f8a1360cf8f15d474826bf49));
        assertEq(this._callHashN(inputs), expected, "hashN arity-3 mismatch");
    }

    function test_hashN_arity0_reverts() public {
        bytes32[] memory inputs = new bytes32[](0);
        vm.expectRevert(abi.encodeWithSelector(InvalidHashNArity.selector, uint256(0)));
        this._callHashN(inputs);
    }

    function test_hashN_arity1_reverts() public {
        bytes32[] memory inputs = new bytes32[](1);
        inputs[0] = bytes32(uint256(1));
        vm.expectRevert(abi.encodeWithSelector(InvalidHashNArity.selector, uint256(1)));
        this._callHashN(inputs);
    }

    function test_hashN_arity2_reverts_on_non_canonical() public {
        bytes32[] memory inputs = new bytes32[](2);
        inputs[0] = bytes32(LibPoseidon2Sponge.PRIME());
        inputs[1] = bytes32(uint256(1));
        vm.expectRevert();
        this._callHashN(inputs);
    }

    /// @notice hash(left, right) and hashN([left, right]) MUST produce the
    ///         same output — both are arity-2 with IV = 2<<64 and no auto-
    ///         tag prepending. (hashN doesn't auto-prepend; the caller is
    ///         expected to put the tag in inputs[0] when desired.)
    function test_hash_treenode_equals_hashN_two_inputs() public view {
        bytes32 l = bytes32(uint256(0x14ba77172ab2278bdf5a087ca0bd400e936bafe6dfc092c4e7a1b0950f1b6dbe));
        bytes32 r = bytes32(uint256(0x195c41f12d4fbac5e194c201536f3094541e73bf27d9f2413f09e731b3838733));
        bytes32 viaHash = LibPoseidon2Sponge.hash(l, r);

        bytes32[] memory inputs = new bytes32[](2);
        inputs[0] = l;
        inputs[1] = r;
        bytes32 viaHashN = this._callHashN(inputs);

        assertEq(viaHash, viaHashN, "hash and hashN must agree on bare 2-input absorption");
    }

    /// @notice External wrapper. hashN takes `calldata`, so calling via
    ///         `this._callHashN(inputs)` copies the memory array into calldata
    ///         at the ABI-encoding boundary.
    function _callHashN(bytes32[] calldata inputs) external pure returns (bytes32) {
        return LibPoseidon2Sponge.hashN(inputs);
    }
}

import {Field, LibPoseidon2} from "../../src/bn254/solidity/LibPoseidon2.sol";

contract HashNMultiBlockTest is Test {
    using Field for *;

    /// @notice Reference helper: pure-Solidity LibPoseidon2 with EIP-8182-style
    ///         absorb (is_variable_length=false). This IS the EIP-8182 §10
    ///         construction — additive duplex, zero-padded short tail, length
    ///         in the IV. The only difference from the optimized Yul path is
    ///         speed (and that this reference reverts via Field.toField on
    ///         non-canonical inputs, which is the same behavior we want).
    function _reference(bytes32[] memory inputs) internal pure returns (bytes32) {
        Field.Type[] memory casted = new Field.Type[](inputs.length);
        for (uint256 i = 0; i < inputs.length; i++) {
            casted[i] = uint256(inputs[i]).toField(); // reverts if >= PRIME
        }
        return bytes32(LibPoseidon2.hash(casted, inputs.length, false).toUint256());
    }

    function test_hashN_arity4_matches_reference() public view {
        bytes32[] memory inputs = new bytes32[](4);
        inputs[0] = bytes32(uint256(0x0891e9efa2b82224dccfee5171614168f84c4c99443c7e6e2753433a978f5955));
        inputs[1] = bytes32(uint256(0x01c81114d1f4eb857dfe3a8479760fd0c8e33d9ed6f42f8ee3eef974b85ef937));
        inputs[2] = bytes32(uint256(0x03a2238b91de1214a385af17ade25f2e71b6364b4d54dfb6e7ec96fd12be5a65));
        inputs[3] = bytes32(uint256(0x24cc93df58f07c156dd648edac3318420325db58ff1cccbc3d9a3cdb529f8469));

        bytes32 expected = _reference(inputs);
        assertEq(this._callHashN(inputs), expected, "hashN arity-4 mismatch");
    }

    function test_hashN_arity5_matches_reference() public view {
        bytes32[] memory inputs = new bytes32[](5);
        for (uint256 i = 0; i < 5; i++) {
            inputs[i] = bytes32(uint256(0xaa00 + i));
        }
        bytes32 expected = _reference(inputs);
        assertEq(this._callHashN(inputs), expected, "hashN arity-5 mismatch");
    }

    function test_hashN_arity6_matches_reference() public view {
        // Boundary: exactly two blocks, no zero-padding in the last block.
        bytes32[] memory inputs = new bytes32[](6);
        for (uint256 i = 0; i < 6; i++) {
            inputs[i] = bytes32(uint256(0xbb00 + i));
        }
        bytes32 expected = _reference(inputs);
        assertEq(this._callHashN(inputs), expected, "hashN arity-6 mismatch");
    }

    function test_hashN_arity10_matches_reference() public view {
        bytes32[] memory inputs = new bytes32[](10);
        for (uint256 i = 0; i < 10; i++) {
            inputs[i] = bytes32(uint256(i + 1));
        }
        bytes32 expected = _reference(inputs);
        assertEq(this._callHashN(inputs), expected, "hashN arity-10 mismatch");
    }

    function test_hashN_arity17_matches_reference() public view {
        // Worst-case intentHash arity per spec §7. ⌈17/3⌉ = 6 permutations.
        bytes32[] memory inputs = new bytes32[](17);
        for (uint256 i = 0; i < 17; i++) {
            inputs[i] = bytes32(uint256(0xdead00 + i));
        }
        bytes32 expected = _reference(inputs);
        assertEq(this._callHashN(inputs), expected, "hashN arity-17 mismatch");
    }

    function test_hashN_arity4_reverts_on_non_canonical_middle_input() public {
        bytes32[] memory inputs = new bytes32[](4);
        inputs[0] = bytes32(uint256(1));
        inputs[1] = bytes32(LibPoseidon2Sponge.PRIME() + 7);
        inputs[2] = bytes32(uint256(3));
        inputs[3] = bytes32(uint256(4));
        vm.expectRevert();
        this._callHashN(inputs);
    }

    function test_hashN_arity4_reverts_on_non_canonical_last_input() public {
        bytes32[] memory inputs = new bytes32[](4);
        inputs[0] = bytes32(uint256(1));
        inputs[1] = bytes32(uint256(2));
        inputs[2] = bytes32(uint256(3));
        inputs[3] = bytes32(LibPoseidon2Sponge.PRIME());
        vm.expectRevert();
        this._callHashN(inputs);
    }

    /// @notice Fuzz: arity in [4, 32], all canonical inputs, must match the
    ///         pure-Solidity reference for every shape and value.
    function testFuzz_hashN_matches_reference(uint256[] memory raw) public view {
        uint256 n = raw.length;
        vm.assume(n >= 4 && n <= 32);
        bytes32[] memory inputs = new bytes32[](n);
        for (uint256 i = 0; i < n; i++) {
            inputs[i] = bytes32(raw[i] % LibPoseidon2Sponge.PRIME());
        }
        bytes32 expected = _reference(inputs);
        assertEq(this._callHashN(inputs), expected, "hashN != reference");
    }

    function _callHashN(bytes32[] calldata inputs) external pure returns (bytes32) {
        return LibPoseidon2Sponge.hashN(inputs);
    }
}
