# @evergonlabs/poseidon2-evm

EIP-8182-conformant [Poseidon2](https://eprint.iacr.org/2023/323.pdf) sponge hasher for the EVM (BN254, t=4).

A fork of [`zemse/poseidon2-evm`](https://github.com/zemse/poseidon2-evm) (MIT). Upstream provides a gas-optimized Poseidon2-BN254-t4 permutation in Yul + Huff. This fork adds an **EIP-8182-conformant sponge wrapper** over that permutation, exposing a small `view` interface a contract links against by `STATICCALL`. See [UPSTREAM](UPSTREAM) for the upstream pin and rebase recipe; upstreaming these changes is not a goal of this fork.

## What it provides

- **`IPoseidon2`** ([`src/eip8182/IPoseidon2.sol`](src/eip8182/IPoseidon2.sol)) — the interface:
  - `hash(bytes32 left, bytes32 right) view returns (bytes32)` — untagged 2-input tree-node compression (`IV = 2<<64`), shaped to match OpenZeppelin `MerkleTree`'s custom-hasher pointer `function(bytes32,bytes32) view returns (bytes32)`.
  - `hashN(bytes32[] calldata inputs) view returns (bytes32)` — fixed-arity, domain-separated absorption; the caller puts the domain tag in `inputs[0]`. Rate-3 multi-block absorb for arity > 3.
- **`Poseidon2_EIP8182`** ([`src/eip8182/Poseidon2_EIP8182.sol`](src/eip8182/Poseidon2_EIP8182.sol)) — the deployable, stateless singleton implementing `IPoseidon2`. Deploy once per chain and reach it by `STATICCALL`.
- **`Eip8182Tag`** ([`src/eip8182/Eip8182Tag.sol`](src/eip8182/Eip8182Tag.sol)) — domain-tag derivation `fieldElement(keccak256("eip-8182.<name>"))` per EIP-8182 §3.1.

Details and design notes: [`src/eip8182/README.md`](src/eip8182/README.md).

### Key properties

- **EIP-8182 conformant.** Length-tagged IV (`inputCount << 64`), domain tag as input element 0, untagged tree-node hash — verified against EIP-8182's published constants and normative vectors (pinned in [`assets/eip-8182/`](assets/eip-8182/)).
- **Rejects non-canonical inputs.** Every entry point reverts `InvalidFieldElement(uint256)` on inputs `>= p` instead of silently reducing mod `p` (silent reduction would let an attacker construct `(x, x+p)` collisions). This diverges from upstream's `hash_1/2/3`, which silently reduced.
- **Not deployed yet.** This fork ships source only; there are no production deployments. Deploy `Poseidon2_EIP8182` per chain and record the address.

## Installation

Consumed as a pinned git dependency (no registry publish required):

```bash
# npm / yarn (Hardhat, etc.)
npm install github:evergonlabs/poseidon2-evm#<tag-or-commit>

# Foundry
forge install evergonlabs/poseidon2-evm@<tag-or-commit>
```

Pin to an immutable tag or commit — this is a cryptographic primitive whose output must stay fixed. Imports resolve from the package's `src/` (zero transitive Solidity dependencies).

## Usage

Deploy the singleton once per chain, then link contracts against the interface.

```solidity
import {IPoseidon2} from "@evergonlabs/poseidon2-evm/src/eip8182/IPoseidon2.sol";
import {Poseidon2_EIP8182} from "@evergonlabs/poseidon2-evm/src/eip8182/Poseidon2_EIP8182.sol";

contract MyApp {
    IPoseidon2 public immutable poseidon2;

    constructor(IPoseidon2 hasher) {
        poseidon2 = hasher; // a chain-wide singleton; see deployment below
    }

    // Untagged Merkle tree-node compression.
    function node(bytes32 left, bytes32 right) external view returns (bytes32) {
        return poseidon2.hash(left, right);
    }

    // Domain-separated hash: tag in slot 0, payload after.
    function commitment(bytes32 tag, bytes32 a, bytes32 b) external view returns (bytes32) {
        bytes32[] memory inputs = new bytes32[](3);
        inputs[0] = tag; // e.g. fieldElement(keccak256("eip-8182.<name>"))
        inputs[1] = a;
        inputs[2] = b;
        return poseidon2.hashN(inputs);
    }
}

// Deploy once per chain and reuse the address:
//   Poseidon2_EIP8182 hasher = new Poseidon2_EIP8182();
```

The `poseidon2.hash` view function can be passed directly as the custom hasher to OpenZeppelin's `MerkleTree` library (its pointer type is exactly `function(bytes32,bytes32) view returns (bytes32)`).

> For callers that want the bare permutation rather than the sponge, the Yul library [`src/bn254/yul/LibPoseidon2Yul.sol`](src/bn254/yul/LibPoseidon2Yul.sol) exposes the upstream `hash_1/2/3` entry points (inlinable; no deployed contract needed).

## Gas

Measured under `STATICCALL` (warm), BN254 t=4, optimizer 1,000,000 runs, `cancun`:

| Call | Gas (approx) |
| ---- | ------------ |
| `hash` (tree node) | ≈ 20.4k |
| `hashN`, arity 17 (6 permutations) | ≈ 125k |
| 32× `hash` (depth-32 Merkle insert) | ≈ 653k |

The committed `gas-report` is a CI-checked snapshot of the underlying Yul/Solidity permutation entry points (Huff is excluded — it is not extended in this fork).

## Development

Foundry + Node toolchain, run from the repo root:

```bash
forge build                 # compile (solc 0.8.30, cancun, optimizer 1,000,000)
forge build --sizes         # also enforces the EIP-170 24KB runtime limit
forge test                  # full suite (correctness vectors, EIP-8182 vectors, fuzz)
forge fmt                   # format Solidity
./gas-report.sh             # regenerate the gas snapshot (requires huffc)
npm run verify:constants    # byte-check constants.ts against the pinned EIP-8182 JSON
npm run generate:yul        # regenerate the Yul from generate-yul.ts (then forge fmt)
```

Generated files (`src/bn254/yul/*`) are committed; edit the generator, not the output. CI pins the toolchain and gates on build, tests, formatting, generated-file sync, and the gas snapshot.

## Security

**Not audited — use at your own risk.**

Neither this fork nor the upstream `zemse/poseidon2-evm` it builds on has undergone a formal third-party security audit. This is a cryptographic primitive: a single wrong bit in a hash output is a protocol break, and a bug can compromise every commitment, nullifier, and Merkle root derived from it. Before any production use, review the code (or commission an audit), verify the pinned constants and test vectors reproduce your in-circuit Poseidon2 gadget's output exactly, and pin to an immutable tag/commit. See [SECURITY.md](SECURITY.md).

## License

MIT — retained from upstream `zemse/poseidon2-evm`. See [LICENSE](LICENSE).
