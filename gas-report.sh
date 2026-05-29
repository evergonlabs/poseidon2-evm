#!/bin/bash

# Run tests with traces and extract actual internal gas
# Only keep one entry per contract::function combination

# This approach produces same values from forge test --gas-report
# but it is difficult to have huff contracts included in gas report

# Huff is intentionally excluded from the snapshot: huffc is only installable
# as a floating `nightly` in CI (no pinnable release), so its gas drifts and
# would break this diff on unrelated changes. The Solidity/Yul numbers are
# deterministic (pinned solc + cancun) and are the meaningful regression guard.
OUTPUT=$(forge test --match-contract Poseidon2Test -vvvv 2>&1 | \
  grep -E "^[[:space:]]+├─ \[[0-9]+\] (Poseidon2_BN254|Poseidon2Yul_BN254)::(hash_1|hash_2|hash_3|fallback)" | \
  sed 's/.*├─ \[\([0-9]*\)\] \(.*\)::\([a-z_0-9]*\).*/\2:\3: \1 gas/' | \
  LC_ALL=C sort -u)

echo "$OUTPUT" | tee gas-report
