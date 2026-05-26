// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {Test} from "forge-std/Test.sol";
import {Field, Poseidon2_BN254, LibPoseidon2} from "../../src/bn254/solidity/Poseidon2.sol";
import {Poseidon2Yul_BN254} from "../../src/bn254/yul/Poseidon2Yul.sol";
import {LibPoseidon2Yul} from "../../src/bn254/yul/LibPoseidon2Yul.sol";
import {IPoseidon2} from "../../src/IPoseidon2.sol";

/// @notice Spec §2 / roadmap step 4 — every Yul + pure-Solidity hash entry
///         point reverts on non-canonical inputs (>= PRIME). Silent mod-p
///         would allow constructing (x, x+p) collisions on note commitments
///         / nullifiers. Huff retains upstream silent-mod behavior (spec §4:
///         Huff is not extended in this fork) and is NOT exercised here.
contract Poseidon2RevertTest is Test {
    using Field for *;

    Poseidon2_BN254 private poseidon2;
    IPoseidon2 private poseidon2Yul;

    function setUp() public {
        poseidon2 = new Poseidon2_BN254();
        poseidon2Yul = IPoseidon2(address(new Poseidon2Yul_BN254()));
    }

    // ---- Yul contract / fallback ----

    function test_yul_hash_1_reverts_on_PRIME() public {
        vm.expectRevert();
        poseidon2Yul.hash_1(Field.PRIME);
    }

    function test_yul_hash_1_reverts_on_PRIME_plus_5() public {
        vm.expectRevert();
        poseidon2Yul.hash_1(Field.PRIME + 5);
    }

    function test_yul_hash_1_reverts_on_uint256_max() public {
        vm.expectRevert();
        poseidon2Yul.hash_1(type(uint256).max);
    }

    function test_yul_hash_2_reverts_on_non_canonical_left() public {
        vm.expectRevert();
        poseidon2Yul.hash_2(Field.PRIME, uint256(1));
    }

    function test_yul_hash_2_reverts_on_non_canonical_right() public {
        vm.expectRevert();
        poseidon2Yul.hash_2(uint256(1), Field.PRIME);
    }

    function test_yul_hash_3_reverts_on_non_canonical_third() public {
        vm.expectRevert();
        poseidon2Yul.hash_3(uint256(1), uint256(2), Field.PRIME + 7);
    }

    // ---- LibPoseidon2Yul (Yul library, inlined) ----
    // Internal library calls revert in the test frame itself, so we must
    // route them through an external call (this.xxx()) to satisfy
    // vm.expectRevert's depth requirement.

    function _callYulLibHash1(uint256 x) external pure returns (uint256) {
        return LibPoseidon2Yul.hash_1(x);
    }

    function _callYulLibPermute(uint256 s0, uint256 s1, uint256 s2, uint256 s3)
        external
        pure
        returns (uint256, uint256, uint256, uint256)
    {
        return LibPoseidon2Yul.poseidon2_permute(s0, s1, s2, s3);
    }

    function test_yulLib_hash_1_reverts_on_PRIME() public {
        vm.expectRevert();
        this._callYulLibHash1(Field.PRIME);
    }

    function test_yulLib_poseidon2_permute_reverts_on_non_canonical_s2() public {
        vm.expectRevert();
        this._callYulLibPermute(uint256(1), uint256(2), Field.PRIME + 1, 4 << 64);
    }

    // ---- Pure-Solidity reference (Field.checkField) ----
    // toField() is internal and reverts in the test frame, so we wrap the
    // Poseidon2_BN254 hash call in an external helper that accepts raw uint256.

    function _callSolidityHash1(uint256 raw) external view returns (uint256) {
        return poseidon2.hash_1(raw.toField()).toUint256();
    }

    function _callSolidityHash2(uint256 raw0, uint256 raw1) external view returns (uint256) {
        return poseidon2.hash_2(raw0.toField(), raw1.toField()).toUint256();
    }

    function test_solidity_hash_1_reverts_on_PRIME() public {
        vm.expectRevert(abi.encodeWithSelector(Field.InvalidFieldElement.selector, Field.PRIME));
        this._callSolidityHash1(Field.PRIME);
    }

    function test_solidity_hash_2_reverts_on_PRIME_plus_3() public {
        vm.expectRevert(abi.encodeWithSelector(Field.InvalidFieldElement.selector, Field.PRIME + 3));
        this._callSolidityHash2(Field.PRIME + 3, uint256(0));
    }

    // ---- Canonical inputs still work (sanity) ----

    function test_yul_canonical_inputs_still_hash() public view {
        // Sanity: zero is canonical and must NOT revert.
        uint256 result = poseidon2Yul.hash_1(0);
        assertTrue(result != 0, "hash_1(0) returned 0");
    }

    function test_solidity_canonical_inputs_still_hash() public view {
        uint256 result = poseidon2.hash_1(uint256(0).toField()).toUint256();
        assertTrue(result != 0, "Solidity hash_1(0) returned 0");
    }
}
