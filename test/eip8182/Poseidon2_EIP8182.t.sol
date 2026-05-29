// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {Test} from "forge-std/Test.sol";
import {IPoseidon2, InvalidHashNArity, InvalidFieldElement} from "../../src/eip8182/IPoseidon2.sol";
import {Poseidon2_EIP8182} from "../../src/eip8182/Poseidon2_EIP8182.sol";

contract Poseidon2EIP8182Test is Test {
    IPoseidon2 private hasher;

    function setUp() public {
        hasher = IPoseidon2(address(new Poseidon2_EIP8182()));
    }

    function test_hash_treenode_via_staticcall() public view {
        bytes32 l = bytes32(uint256(0x1762d324c2db6a912e607fd09664aaa02dfe45b90711c0dae9627d62a4207788));
        bytes32 r = bytes32(uint256(0x1047bd52da536f6bdd26dfe642d25d9092c458e64a78211298648e81414cbf35));
        bytes32 expected = bytes32(uint256(0x303cacb84a267e5f3f46914fd3262dcaa212930c27a2f9de22c080dd9857be35));
        assertEq(hasher.hash(l, r), expected);
    }

    function test_hashN_arity4_via_staticcall() public view {
        bytes32[] memory inputs = new bytes32[](4);
        inputs[0] = bytes32(uint256(1));
        inputs[1] = bytes32(uint256(2));
        inputs[2] = bytes32(uint256(3));
        inputs[3] = bytes32(uint256(4));
        bytes32 first = hasher.hashN(inputs);
        // Idempotent under STATICCALL — repeat must equal.
        assertEq(first, hasher.hashN(inputs), "hashN not deterministic via STATICCALL");
    }

    function test_hashN_arity0_reverts_via_staticcall() public {
        bytes32[] memory inputs = new bytes32[](0);
        vm.expectRevert(abi.encodeWithSelector(InvalidHashNArity.selector, uint256(0)));
        hasher.hashN(inputs);
    }

    function test_hash_non_canonical_reverts_via_staticcall() public {
        // PRIME itself is non-canonical.
        uint256 prime = 0x30644e72e131a029b85045b68181585d2833e84879b9709143e1f593f0000001;
        bytes32 nonCanon = bytes32(prime);
        vm.expectRevert(abi.encodeWithSelector(InvalidFieldElement.selector, prime));
        hasher.hash(nonCanon, bytes32(uint256(1)));
    }

    /// @notice OZ MerkleTree's custom-hasher pointer signature is
    ///         `function(bytes32,bytes32) view returns (bytes32)`. This test
    ///         binds an external function pointer of that exact signature to
    ///         our hasher.hash; it compiles iff the interface is `view`.
    function test_oz_merkle_pointer_signature_compiles() public view {
        function(bytes32, bytes32) external view returns (bytes32) ptr = hasher.hash;
        ptr; // silence unused
    }

    /// @notice STATICCALL truly sandboxes the hasher from caller storage.
    ///         The hasher holds no storage, so the STATICCALL must succeed
    ///         and never write — confirmed by the `view` qualifier on the
    ///         interface + the `pure` impl, but a runtime check that low-
    ///         level staticcall returns the same bytes is a useful sanity.
    function test_low_level_staticcall_matches_high_level() public view {
        bytes32 l = bytes32(uint256(5));
        bytes32 r = bytes32(uint256(7));
        bytes32 highLevel = hasher.hash(l, r);

        (bool ok, bytes memory ret) = address(hasher).staticcall(abi.encodeWithSelector(IPoseidon2.hash.selector, l, r));
        assertTrue(ok, "low-level staticcall failed");
        assertEq(ret.length, 32, "unexpected return size");
        bytes32 lowLevel = abi.decode(ret, (bytes32));
        assertEq(highLevel, lowLevel, "high-level and low-level disagree");
    }
}

contract Poseidon2EIP8182GasTest is Test {
    IPoseidon2 private hasher;

    function setUp() public {
        hasher = IPoseidon2(address(new Poseidon2_EIP8182()));
    }

    function test_gas_hash_treenode_staticcall() public {
        // Warm the contract first to measure steady-state (non-cold) cost.
        hasher.hash(bytes32(uint256(1)), bytes32(uint256(2)));

        uint256 g0 = gasleft();
        bytes32 result = hasher.hash(bytes32(uint256(3)), bytes32(uint256(4)));
        uint256 spent = g0 - gasleft();
        emit log_named_uint("hash(treenode) STATICCALL gas (warm)", spent);
        assertTrue(result != bytes32(0), "sanity");
    }

    function test_gas_hashN_arity17_staticcall() public {
        bytes32[] memory inputs = new bytes32[](17);
        for (uint256 i = 0; i < 17; i++) {
            inputs[i] = bytes32(uint256(0xa70 + i));
        }

        // Warm
        hasher.hashN(inputs);

        uint256 g0 = gasleft();
        bytes32 result = hasher.hashN(inputs);
        uint256 spent = g0 - gasleft();
        emit log_named_uint("hashN(arity=17) STATICCALL gas (warm, 6 permutations)", spent);
        assertTrue(result != bytes32(0), "sanity");
    }

    function test_gas_depth32_merkle_walk_estimate() public {
        // depth-32 _insertLeaf does up to 32 hash() calls.
        // Measure 32 sequential hash() calls to estimate the worst-case
        // insert-path cost.
        bytes32 acc = bytes32(uint256(1));
        bytes32 sibling = bytes32(uint256(2));

        // Warm
        hasher.hash(acc, sibling);

        uint256 g0 = gasleft();
        for (uint256 d = 0; d < 32; d++) {
            acc = hasher.hash(acc, sibling);
        }
        uint256 spent = g0 - gasleft();
        emit log_named_uint("hash(treenode) STATICCALL x32 gas (depth-32 insertLeaf)", spent);
        emit log_named_uint("per-hash average", spent / 32);
        assertTrue(acc != bytes32(0), "sanity");
    }
}
