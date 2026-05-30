// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {Test} from "forge-std/Test.sol";
import {LibPoseidon2Sponge} from "../../src/eip8182/LibPoseidon2Sponge.sol";
import {Eip8182Tag} from "../../src/eip8182/Eip8182Tag.sol";
import {Field, LibPoseidon2} from "../../src/bn254/solidity/LibPoseidon2.sol";

/// @title Eip8182TagVectorsTest
/// @notice Per-arity coverage. These are internal-consistency
///         and structural-distinctness checks for the EIP-8182 sponge and the
///         Eip8182Tag derivation primitive.
contract Eip8182TagVectorsTest is Test {
    using Field for *;

    function _reference(bytes32[] memory inputs) internal pure returns (bytes32) {
        Field.Type[] memory casted = new Field.Type[](inputs.length);
        for (uint256 i = 0; i < inputs.length; i++) {
            casted[i] = uint256(inputs[i]).toField();
        }
        return bytes32(LibPoseidon2.hash(casted, inputs.length, false).toUint256());
    }

    function _callHashN(bytes32[] calldata inputs) external pure returns (bytes32) {
        return LibPoseidon2Sponge.hashN(inputs);
    }

    // ---- Arity 2 untagged: tree node ----
    function test_protocol_arity2_untagged_treenode() public pure {
        bytes32 l = bytes32(uint256(0xabcdef));
        bytes32 r = bytes32(uint256(0x123456));
        bytes32[] memory pair = new bytes32[](2);
        pair[0] = l;
        pair[1] = r;
        assertEq(LibPoseidon2Sponge.hash(l, r), _reference(pair), "tree-node hash matches reference");
    }

    // ---- Arity 2 tagged: example tag in slot 0 ----
    function test_protocol_arity2_with_example_tag() public view {
        bytes32[] memory inputs = new bytes32[](2);
        inputs[0] = Eip8182Tag.derive("test_nullifier");
        inputs[1] = bytes32(uint256(uint160(0x000000000000000000000000000000000000C0FFEE)));
        assertEq(this._callHashN(inputs), _reference(inputs), "tagged arity-2 matches reference");
    }

    // ---- Arity 4 tagged with example commitment tag ----
    function test_protocol_arity4_with_example_commitment_tag() public view {
        bytes32[] memory inputs = new bytes32[](4);
        inputs[0] = Eip8182Tag.derive("test_commitment");
        inputs[1] = bytes32(uint256(0xfeed01)); // field A
        inputs[2] = bytes32(uint256(7)); // counter
        inputs[3] = bytes32(uint256(0xfeed02)); // salt
        assertEq(this._callHashN(inputs), _reference(inputs), "tagged arity-4 matches reference");
    }

    // ---- Arity 10 — longer payload + tag ----
    function test_protocol_arity10_with_tag() public view {
        bytes32[] memory inputs = new bytes32[](10);
        inputs[0] = Eip8182Tag.derive("test_commitment");
        for (uint256 i = 1; i < 10; i++) {
            inputs[i] = bytes32(uint256(0xb0d0 + i));
        }
        assertEq(this._callHashN(inputs), _reference(inputs), "tagged arity-10 matches reference");
    }

    // ---- Arity 17 — multi-block worst-case (⌈17/3⌉ = 6 permutations) ----
    function test_protocol_arity17_multiblock() public view {
        bytes32[] memory inputs = new bytes32[](17);
        inputs[0] = Eip8182Tag.derive("test_tag");
        for (uint256 i = 1; i < 17; i++) {
            inputs[i] = bytes32(uint256(0x1a7700 + i));
        }
        assertEq(this._callHashN(inputs), _reference(inputs), "arity-17 multi-block matches reference");
    }

    // ---- Tag uniqueness: 12 freshly-derived tags must be pairwise distinct ----
    function test_fresh_derivation_tags_are_distinct() public pure {
        bytes32[12] memory tags;
        for (uint256 k = 0; k < 12; k++) {
            tags[k] = Eip8182Tag.derive(string.concat("test_tag_", vm.toString(k)));
        }
        for (uint256 i = 0; i < 12; i++) {
            for (uint256 j = i + 1; j < 12; j++) {
                assertTrue(
                    tags[i] != tags[j], string.concat("tags ", vm.toString(i), " and ", vm.toString(j), " collide")
                );
            }
        }
    }

    // ---- Cross-tag distinctness: same payload, different tag → different hash ----
    function test_same_payload_different_tag_different_hash() public view {
        bytes32[] memory a = new bytes32[](3);
        a[0] = Eip8182Tag.derive("test_nullifier");
        a[1] = bytes32(uint256(0xdead));
        a[2] = bytes32(uint256(0xbeef));

        bytes32[] memory b = new bytes32[](3);
        b[0] = Eip8182Tag.derive("test_commitment");
        b[1] = a[1];
        b[2] = a[2];

        assertTrue(this._callHashN(a) != this._callHashN(b), "different tag must produce different hash");
    }

    /// @notice Tagged vs untagged 2-input collision regression.
    ///
    ///         hash(bytes32(0x01), bytes32(0x02)) is the bare 2-input tree-node
    ///         hash. hashN([tag, bytes32(0x02)]) is a 2-input absorption where
    ///         slot 0 is a domain tag. BOTH use IV = 2<<64. The ONLY structural
    ///         difference is the slot-0 value — these MUST NOT collide. If they
    ///         ever do, the inputCount=2 collision argument has broken (likely
    ///         the hashN path stopped treating slot 0 as a regular input, or
    ///         the IV computation diverged).
    function test_tagged_vs_untagged_2input_no_collision() public view {
        bytes32 viaHash = LibPoseidon2Sponge.hash(bytes32(uint256(0x01)), bytes32(uint256(0x02)));

        bytes32[] memory inputs = new bytes32[](2);
        inputs[0] = Eip8182Tag.derive("test_nullifier");
        inputs[1] = bytes32(uint256(0x02));
        bytes32 viaHashN = this._callHashN(inputs);

        assertTrue(viaHash != viaHashN, "tagged length-2 collision: structural lock broken");
    }

    // ---- Print a few derived tags (derivation demo) ----
    function test_print_tags() public {
        emit log_named_bytes32("derive(note_commitment)", Eip8182Tag.derive("note_commitment"));
        emit log_named_bytes32("derive(nullifier)", Eip8182Tag.derive("nullifier"));
        emit log_named_bytes32("derive(custom_name_v1)", Eip8182Tag.derive("custom_name_v1"));
    }
}
