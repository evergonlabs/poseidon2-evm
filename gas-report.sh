#!/bin/bash

# Run tests with traces and extract actual internal gas
# Only keep one entry per contract::function combination

# This approach produces same values from forge test --gas-report
# but it is difficult to have huff contracts included in gas report

# Huff is intentionally excluded from the snapshot: huffc is only installable
# as a floating `nightly` in CI (no pinnable release), so its gas drifts and
# would break this diff on unrelated changes. The Solidity/Yul numbers are
# deterministic (pinned solc + cancun) and are the meaningful regression guard.
# Note: Poseidon2Test deploys the Huff contract in setUp via HuffDeployer, so
# huffc must be installed for this to run at all (CI installs it; a local run
# without huffc produces no traces). We snapshot only the Yul/Solidity lines.
OUTPUT=$(forge test --match-contract Poseidon2Test -vvvv 2>&1 | \
  grep -E "^[[:space:]]+├─ \[[0-9]+\] (Poseidon2_BN254|Poseidon2Yul_BN254)::(hash_1|hash_2|hash_3|fallback)" | \
  sed 's/.*├─ \[\([0-9]*\)\] \(.*\)::\([a-z_0-9]*\).*/\2:\3: \1 gas/' | \
  LC_ALL=C sort -u)

# Refuse to overwrite the baseline with empty/partial data (4 expected lines:
# Yul fallback + Solidity hash_1/2/3). Guards against silently blanking
# gas-report when the test run produced no traces (e.g. huffc missing, so
# Poseidon2Test.setUp reverted).
if [ "$(printf '%s\n' "$OUTPUT" | grep -c ' gas$')" -lt 4 ]; then
  echo "gas-report.sh: extracted fewer than 4 gas entries — refusing to overwrite gas-report." >&2
  echo "Is huffc installed? Poseidon2Test.setUp deploys the Huff contract." >&2
  exit 1
fi

echo "$OUTPUT" | tee gas-report
