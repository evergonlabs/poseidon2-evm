// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {Test} from "forge-std/Test.sol";
import {LibPoseidon2Sponge} from "../../src/eip8182/LibPoseidon2Sponge.sol";
import {Eip8182Tag} from "../../src/eip8182/Eip8182Tag.sol";
import {Field, LibPoseidon2} from "../../src/bn254/solidity/LibPoseidon2.sol";

/// @title ProtocolVectorsTest
/// @notice Per-arity protocol coverage from spec §7. These are internal-
///         consistency + structural-distinctness checks until the Phase 4
///         ceremony freezes golden vectors in docs/design_decisions.md
///         (gateway side). Spec §2 / §7 / roadmap step 6.
contract ProtocolVectorsTest is Test {
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
    function test_protocol_arity2_untagged_treenode() public view {
        bytes32 l = bytes32(uint256(0xabcdef));
        bytes32 r = bytes32(uint256(0x123456));
        bytes32[] memory pair = new bytes32[](2);
        pair[0] = l;
        pair[1] = r;
        assertEq(LibPoseidon2Sponge.hash(l, r), _reference(pair), "tree-node hash matches reference");
    }

    // ---- Arity 2 tagged with EXIT_V1: exitRecipientHash / relayerAddressHash ----
    function test_protocol_arity2_EXIT_V1() public view {
        bytes32[] memory inputs = new bytes32[](2);
        inputs[0] = Eip8182Tag.EXIT_V1();
        inputs[1] = bytes32(uint256(uint160(0x000000000000000000000000000000000000C0FFEE)));
        assertEq(this._callHashN(inputs), _reference(inputs), "EXIT_V1(arity2) matches reference");
    }

    // ---- Arity 4 tagged with NOTE_COMMITMENT_V1 ----
    function test_protocol_arity4_NOTE_COMMITMENT_V1() public view {
        bytes32[] memory inputs = new bytes32[](4);
        inputs[0] = Eip8182Tag.NOTE_COMMITMENT_V1();
        inputs[1] = bytes32(uint256(0xfeed01)); // noteBodyCommitment
        inputs[2] = bytes32(uint256(7)); // leafIndex
        inputs[3] = bytes32(uint256(0xfeed02)); // ingestField
        assertEq(this._callHashN(inputs), _reference(inputs), "NOTE_COMMITMENT_V1(arity4) matches reference");
    }

    // ---- Arity 10 — V4 §7.1 noteBodyCommitment absorption shape ----
    function test_protocol_arity10_NOTE_BODY_V1() public view {
        bytes32[] memory inputs = new bytes32[](10);
        inputs[0] = Eip8182Tag.NOTE_BODY_V1();
        for (uint256 i = 1; i < 10; i++) {
            inputs[i] = bytes32(uint256(0xb0d0 + i));
        }
        assertEq(this._callHashN(inputs), _reference(inputs), "NOTE_BODY_V1(arity10) matches reference");
    }

    // ---- Arity 17 — worst-case intentHash (⌈17/3⌉ = 6 permutations) ----
    function test_protocol_arity17_INTENT_V1() public view {
        bytes32[] memory inputs = new bytes32[](17);
        inputs[0] = Eip8182Tag.INTENT_V1();
        for (uint256 i = 1; i < 17; i++) {
            inputs[i] = bytes32(uint256(0x1a7700 + i));
        }
        assertEq(this._callHashN(inputs), _reference(inputs), "INTENT_V1(arity17) matches reference");
    }

    // ---- Tag uniqueness: all 12 tags must be distinct ----
    function test_all_protocol_tags_are_distinct() public pure {
        bytes32[12] memory tags = [
            Eip8182Tag.NOTE_COMMITMENT_V1(),
            Eip8182Tag.NOTE_BODY_V1(),
            Eip8182Tag.NULLIFIER_V1(),
            Eip8182Tag.ACCOUNT_V1(),
            Eip8182Tag.OWNER_V1(),
            Eip8182Tag.AMOUNT_V1(),
            Eip8182Tag.INTENT_V1(),
            Eip8182Tag.SPEND_V1(),
            Eip8182Tag.TAG_V1(),
            Eip8182Tag.EXIT_V1(),
            Eip8182Tag.INGEST_V1(),
            Eip8182Tag.POLICY_V1()
        ];
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
        a[0] = Eip8182Tag.NULLIFIER_V1();
        a[1] = bytes32(uint256(0xdead));
        a[2] = bytes32(uint256(0xbeef));

        bytes32[] memory b = new bytes32[](3);
        b[0] = Eip8182Tag.ACCOUNT_V1();
        b[1] = a[1];
        b[2] = a[2];

        assertTrue(this._callHashN(a) != this._callHashN(b), "different tag must produce different hash");
    }

    // ---- Print all 12 derived tag hex values (for gateway-side pinning) ----
    function test_print_tags() public {
        emit log_named_bytes32("NOTE_COMMITMENT_V1", Eip8182Tag.NOTE_COMMITMENT_V1());
        emit log_named_bytes32("NOTE_BODY_V1", Eip8182Tag.NOTE_BODY_V1());
        emit log_named_bytes32("NULLIFIER_V1", Eip8182Tag.NULLIFIER_V1());
        emit log_named_bytes32("ACCOUNT_V1", Eip8182Tag.ACCOUNT_V1());
        emit log_named_bytes32("OWNER_V1", Eip8182Tag.OWNER_V1());
        emit log_named_bytes32("AMOUNT_V1", Eip8182Tag.AMOUNT_V1());
        emit log_named_bytes32("INTENT_V1", Eip8182Tag.INTENT_V1());
        emit log_named_bytes32("SPEND_V1", Eip8182Tag.SPEND_V1());
        emit log_named_bytes32("TAG_V1", Eip8182Tag.TAG_V1());
        emit log_named_bytes32("EXIT_V1", Eip8182Tag.EXIT_V1());
        emit log_named_bytes32("INGEST_V1", Eip8182Tag.INGEST_V1());
        emit log_named_bytes32("POLICY_V1", Eip8182Tag.POLICY_V1());
    }
}
