import { round_constant, internal_matrix_diagonal } from "../constants";
import { readFileSync } from "fs";
import { fileURLToPath } from "url";
import { dirname, resolve } from "path";

const __dirname = dirname(fileURLToPath(import.meta.url));
const JSON_PATH = resolve(__dirname, "../assets/eip-8182/poseidon2_bn254_t4_rf8_rp56.json");
const eip = JSON.parse(readFileSync(JSON_PATH, "utf8"));

function normalize(x: string | bigint): bigint {
  if (typeof x === "bigint") return x;
  const trimmed = x.trim();
  if (!trimmed.startsWith("0x")) {
    throw new Error(`Expected 0x-prefixed hex string, got: ${trimmed}`);
  }
  return BigInt(trimmed);
}

const errors: string[] = [];

// --- Internal diagonal ---
// JSON field: eip.internalDiagonal (string[], length 4)
// constants.ts: internal_matrix_diagonal (string[], length 4)
if (!Array.isArray(eip.internalDiagonal)) {
  throw new Error("EIP-8182 JSON missing or malformed 'internalDiagonal' (expected string[])");
}
const eipDiag: string[] = eip.internalDiagonal;

if (eipDiag.length !== internal_matrix_diagonal.length) {
  errors.push(
    `internalDiagonal length: local=${internal_matrix_diagonal.length} eip=${eipDiag.length}`
  );
}
for (let i = 0; i < Math.min(eipDiag.length, internal_matrix_diagonal.length); i++) {
  const lhs = normalize(internal_matrix_diagonal[i]);
  const rhs = normalize(eipDiag[i]);
  if (lhs !== rhs) {
    errors.push(
      `internalDiagonal[${i}] mismatch: local=${lhs.toString(16)} eip=${rhs.toString(16)}`
    );
  }
}

// --- Round constants ---
// JSON field: eip.roundConstants — a FLAT array of 88 values.
//   Layout: 4 full-external-rounds-in × 4 elements = 16
//           56 partial-rounds × 1 element              = 56
//           4 full-external-rounds-out × 4 elements  = 16
//   Total = 88
//
// constants.ts: round_constant — a 2-D array of 64 rows × 4 elements.
//   Rows  0-3  : first 4 full external rounds (all 4 slots populated)
//   Rows  4-59 : 56 partial rounds           (only slot [0] non-zero; [1..3] = 0)
//   Rows 60-63 : last 4 full external rounds  (all 4 slots populated)
//
// We reconstruct the EIP flat order from constants.ts:
//   - rows 0-3 fully (16 values)
//   - rows 4-59, slot [0] only (56 values)
//   - rows 60-63 fully (16 values)

if (!Array.isArray(eip.roundConstants)) {
  throw new Error("EIP-8182 JSON missing or malformed 'roundConstants' (expected string[])");
}
const eipFlat: string[] = eip.roundConstants;

function buildLocalFlat(): bigint[] {
  const flat: bigint[] = [];
  // First 4 full rounds
  for (let r = 0; r < 4; r++) {
    for (let i = 0; i < 4; i++) {
      flat.push(normalize(round_constant[r][i]));
    }
  }
  // 56 partial rounds — only first element per row.
  // Slots [1], [2], [3] are 0 by construction: the Yul generator's
  // internal_m_multiplication only reads round_constant[r][0] for partial
  // rounds; the other slots are never addressed, so 0 is a deliberate
  // semantic choice, not merely padding to fill a fixed-width matrix.
  for (let r = 4; r < 60; r++) {
    flat.push(normalize(round_constant[r][0]));
    // Verify the padding zeros are actually zero
    for (let i = 1; i < 4; i++) {
      const v = normalize(round_constant[r][i]);
      if (v !== 0n) {
        errors.push(
          `round_constant[${r}][${i}]: expected zero padding in partial round, got ${v.toString(16)}`
        );
      }
    }
  }
  // Last 4 full rounds
  for (let r = 60; r < 64; r++) {
    for (let i = 0; i < 4; i++) {
      flat.push(normalize(round_constant[r][i]));
    }
  }
  return flat;
}

const localFlat = buildLocalFlat();

if (eipFlat.length !== localFlat.length) {
  errors.push(
    `roundConstants length: local(flat)=${localFlat.length} eip=${eipFlat.length}`
  );
}
for (let idx = 0; idx < Math.min(eipFlat.length, localFlat.length); idx++) {
  const lhs = localFlat[idx];
  const rhs = normalize(eipFlat[idx]);
  if (lhs !== rhs) {
    errors.push(
      `roundConstants[${idx}] mismatch: local=${lhs.toString(16)} eip=${rhs.toString(16)}`
    );
  }
}

if (errors.length === 0) {
  console.log(
    "constants.ts matches EIP-8182 (commit pin: see assets/eip-8182/EIP-8182-COMMIT)"
  );
  process.exit(0);
} else {
  for (const e of errors) console.error(e);
  process.exit(1);
}
