// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {Test} from "forge-std/Test.sol";
import {LibPoseidon2Yul} from "../../src/bn254/yul/LibPoseidon2Yul.sol";

contract LibPoseidon2SpongeTest is Test {
    /// @notice poseidon2_permute MUST return the full 4-element post-permutation state.
    ///         state0 must match what poseidon2_core (the single-output upstream) returns,
    ///         and state1/2/3 must be non-zero for non-trivial inputs.
    function test_poseidon2_permute_returns_full_state() public pure {
        uint256 s0 = 1;
        uint256 s1 = 2;
        uint256 s2 = 3;
        uint256 iv = 2 << 64;

        uint256 single = LibPoseidon2Yul.poseidon2_core(s0, s1, s2, iv);
        (uint256 r0, uint256 r1, uint256 r2, uint256 r3) = LibPoseidon2Yul.poseidon2_permute(s0, s1, s2, iv);

        assertEq(r0, single, "state0 must equal poseidon2_core output");
        assertTrue(r1 != 0, "state1 should be non-zero post-permutation");
        assertTrue(r2 != 0, "state2 should be non-zero post-permutation");
        assertTrue(r3 != 0, "state3 should be non-zero post-permutation");
    }
}
