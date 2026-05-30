// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {Test} from "forge-std/Test.sol";

contract ConstantsByteCheckTest is Test {
    /// @notice Runs `npm run verify:constants` via FFI. Fails the test suite if
    ///         constants.ts diverges from the pinned EIP-8182 JSON.
    ///
    ///         Detect Windows via the OS env var (set to "Windows_NT" on Windows;
    ///         unset elsewhere). On Windows, forge's FFI uses CreateProcess directly
    ///         and cannot resolve `npm.cmd` by bare name, so we route through
    ///         `cmd /c`. On Linux/macOS we use `sh -c`.
    function test_constants_match_eip8182() public {
        bool isWindows = bytes(vm.envOr("OS", string(""))).length > 0;
        string[] memory cmd = new string[](3);
        if (isWindows) {
            cmd[0] = "cmd";
            cmd[1] = "/c";
            cmd[2] = "npm run verify:constants";
        } else {
            cmd[0] = "sh";
            cmd[1] = "-c";
            cmd[2] = "npm run verify:constants";
        }
        bytes memory out = vm.ffi(cmd);

        // Assert the success string is present in the output. We use a substring
        // check rather than exact equality because `npm run` prepends a banner line
        // ("> poseidon2-evm@... verify:constants\n> npx tsx ...\n\n") whose presence
        // and exact whitespace is npm-version-dependent and platform-variable.
        bytes memory expected = bytes("constants.ts matches EIP-8182 (commit pin: see assets/eip-8182/EIP-8182-COMMIT)");
        assertTrue(_contains(out, expected), "verify:constants did not print success message");
    }

    /// @dev Returns true if `haystack` contains `needle` as a contiguous subsequence.
    function _contains(bytes memory haystack, bytes memory needle) internal pure returns (bool) {
        if (needle.length == 0) return true;
        if (needle.length > haystack.length) return false;
        uint256 limit = haystack.length - needle.length;
        for (uint256 i = 0; i <= limit; i++) {
            bool found = true;
            for (uint256 j = 0; j < needle.length; j++) {
                if (haystack[i + j] != needle[j]) {
                    found = false;
                    break;
                }
            }
            if (found) return true;
        }
        return false;
    }
}
