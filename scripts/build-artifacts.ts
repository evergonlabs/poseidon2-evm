// Extracts a clean, deploy-ready artifact from the Foundry build output for
// consumers that deploy the precompiled contract rather than recompiling the
// Solidity (which would otherwise need compiler-setting overrides to reproduce
// the canonical bytecode). Run via `npm run build:artifacts` (which runs
// `forge build` first), then publish. Output is gitignored and produced at
// publish time — not committed (a committed + CI-gated artifact is the
// production-time upgrade).
import { readFileSync, writeFileSync, mkdirSync } from "fs";
import { dirname, resolve } from "path";
import { fileURLToPath } from "url";

const root = resolve(dirname(fileURLToPath(import.meta.url)), "..");

// Contracts to publish a deploy artifact for (deployable, with bytecode).
const CONTRACTS = ["Poseidon2_EIP8182"];

const outDir = resolve(root, "artifacts");
mkdirSync(outDir, { recursive: true });

for (const name of CONTRACTS) {
  const foundryPath = resolve(root, `out/${name}.sol/${name}.json`);
  const built = JSON.parse(readFileSync(foundryPath, "utf8"));

  const bytecode: string | undefined = built.bytecode?.object;
  const deployedBytecode: string | undefined = built.deployedBytecode?.object;
  if (!Array.isArray(built.abi) || !bytecode || !deployedBytecode) {
    throw new Error(
      `Incomplete Foundry artifact for ${name} at ${foundryPath} — run \`forge build\` first.`,
    );
  }

  // Flatten Foundry's nested {object} into viem/ethers-friendly hex strings.
  const artifact = {
    contractName: name,
    abi: built.abi,
    bytecode,
    deployedBytecode,
  };

  const dest = resolve(outDir, `${name}.json`);
  writeFileSync(dest, JSON.stringify(artifact, null, 2) + "\n");
  console.log(
    `wrote artifacts/${name}.json (runtime ${(deployedBytecode.length - 2) / 2} bytes)`,
  );
}
