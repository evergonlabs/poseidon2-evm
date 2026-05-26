// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {Test} from "forge-std/Test.sol";
import {LibPoseidon2Sponge} from "../../src/eip8182/LibPoseidon2Sponge.sol";

/// @title Eip8182VectorsTest
/// @notice Walks every supported vector in assets/eip-8182/poseidon2_vectors.json
///         and asserts the sponge wrapper reproduces each one byte-for-byte.
///         Spec §1. UPSTREAM roadmap step 5.
///
/// @dev    The JSON is pinned to a specific EIP-8182 commit recorded in
///         assets/eip-8182/EIP-8182-COMMIT. If the EIP-8182 draft is amended
///         post-pin, this test continues to assert the pinned version.
///
///         Schema observed:
///           {
///             "fieldModulus": "0x...",
///             "poseidonVectors": [
///               { "inputs": ["0x...", ...], "output": "0x..." },
///               ...
///             ]
///           }
///         9 vectors total; arities: 0, 1, 2, 3, 4, 5, 6, 17, 116.
///         Arities 0 and 1 are excluded — per spec (Tasks 6–7), hashN reverts
///         on InvalidHashNArity for n < 2, matching EIP-8182 §3 which defines
///         the hash only for n >= 2.
contract Eip8182VectorsTest is Test {
    /// @notice External wrapper: routes a memory array through an external
    ///         call to satisfy hashN's `calldata` parameter requirement.
    function _callHashN(bytes32[] calldata inputs) external pure returns (bytes32) {
        return LibPoseidon2Sponge.hashN(inputs);
    }

    function test_eip8182_normative_vectors() public {
        string memory raw = vm.readFile("assets/eip-8182/poseidon2_vectors.json");

        // Parse the poseidonVectors array from the JSON.
        // Each entry has an `inputs` sub-array and an `output` scalar — all
        // values are 0x-prefixed 32-byte hex strings (auto-decoded as bytes32).
        bytes memory inputsEncoded = vm.parseJson(raw, ".poseidonVectors[*].inputs");
        bytes memory outputsEncoded = vm.parseJson(raw, ".poseidonVectors[*].output");

        bytes32[][] memory allInputs = abi.decode(inputsEncoded, (bytes32[][]));
        bytes32[] memory allOutputs = abi.decode(outputsEncoded, (bytes32[]));

        assertEq(allInputs.length, allOutputs.length, "vector count mismatch");
        assertGt(allInputs.length, 0, "no vectors loaded - schema mismatch?");

        uint256 exercised = 0;
        for (uint256 i = 0; i < allInputs.length; i++) {
            bytes32[] memory inputs = allInputs[i];
            uint256 arity = inputs.length;

            // Arities 0 and 1 are intentionally unsupported by this library:
            // hashN reverts with InvalidHashNArity for n < 2. The EIP includes
            // these vectors to describe the raw permutation, but our sponge
            // wrapper starts at arity 2. Skip and continue.
            if (arity < 2) {
                continue;
            }

            bytes32 actual;
            if (arity == 2) {
                // Route arity-2 through hash() — the tree-node compression
                // path. It is identical to hashN([a, b]) (same IV = 2<<64,
                // same single permutation, same output lane). Using hash()
                // here additionally exercises the tree-node code path.
                actual = LibPoseidon2Sponge.hash(inputs[0], inputs[1]);
            } else {
                // Arity >= 3: route through hashN via external call so the
                // memory array gets ABI-encoded into calldata at the boundary.
                actual = this._callHashN(inputs);
            }

            assertEq(
                actual,
                allOutputs[i],
                string.concat(
                    "vector #",
                    vm.toString(i),
                    " mismatch (arity ",
                    vm.toString(arity),
                    ")"
                )
            );
            exercised++;
        }

        // Guarantee we actually ran vectors (guards against future schema
        // changes silently skipping everything).
        assertGt(exercised, 0, "no vectors exercised - all were skipped?");
        emit log_named_uint("EIP-8182 normative vectors exercised", exercised);
    }
}
