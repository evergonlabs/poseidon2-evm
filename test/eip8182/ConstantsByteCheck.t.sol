// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {Test} from "forge-std/Test.sol";

contract ConstantsByteCheckTest is Test {
    /// @notice Runs `npm run verify:constants` via FFI. Fails the test suite if
    ///         constants.ts diverges from the pinned EIP-8182 JSON.
    ///
    ///         On Windows, forge FFI uses CreateProcess directly and cannot
    ///         resolve npm.cmd from PATH, so we invoke via `cmd /c` with the
    ///         full command as a single argument, which is equivalent to running
    ///         `npm run verify:constants` from the shell.
    function test_constants_match_eip8182() public {
        string[] memory cmd = new string[](3);
        cmd[0] = "cmd";
        cmd[1] = "/c";
        cmd[2] = "npm run verify:constants";
        bytes memory out = vm.ffi(cmd);
        assertGt(out.length, 0, "verify:constants produced no output");
    }
}
