# EIP-8182 sponge wrapper

EIP-8182-conformant Poseidon2-BN254-t4 sponge over the upstream
[`zemse/poseidon2-evm`](https://github.com/zemse/poseidon2-evm) permutation.

## Entry points

- `IPoseidon2.hash(bytes32 left, bytes32 right) view returns (bytes32)` —
  untagged 2-input tree-node compression. `IV = 2<<64`. No domain tag.
- `IPoseidon2.hashN(bytes32[] calldata inputs) view returns (bytes32)` —
  fixed-arity, domain-separated absorption. `inputs[0]` is the caller-
  provided domain tag (derived as `fieldElement(keccak256("eip-8182.<name>"))`).
  Reverts `InvalidHashNArity(length)` on `inputs.length == 0` or `1`.
  Reverts `InvalidFieldElement(value)` on any `inputs[i] >= PRIME`.

## Divergences from upstream `zemse/poseidon2-evm`

- **Non-canonical inputs revert.** The upstream `hash_1/2/3` silently
  reduced `x` to `x mod p`. This fork rejects any input `>= p` across
  every Yul / Solidity entry point. Silent mod-p would let an attacker
  construct `(x, x+p)` collisions. Huff is unchanged in this fork (not
  extended; see UPSTREAM).
- **New view interface** `src/eip8182/IPoseidon2.sol` distinct from upstream
  `src/IPoseidon2.sol`. The interface is `view` (matches OZ `MerkleTree`'s
  custom-hasher pointer signature); the upstream interface exposes
  `hash_1/2/3` and is unaffected.
- **Multi-block sponge** via `LibPoseidon2Sponge.hashN` for arity > 3, using
  the additive duplex absorb already present in `src/bn254/solidity/LibPoseidon2.sol`
  but without the trailing-1 variable-length pad (length lives in the IV instead).

## Files

- `IPoseidon2.sol` — the view interface.
- `LibPoseidon2Sponge.sol` — the sponge library (Yul-backed via `LibPoseidon2Yul`).
- `Poseidon2_EIP8182.sol` — the deployable singleton.
- `Eip8182Tag.sol` — domain-tag derivation helper.

## Test coverage

- Constants byte-equivalence against the pinned EIP-8182 JSON (`test/eip8182/ConstantsByteCheck.t.sol`).
- EIP-8182 normative test vectors (`test/eip8182/Eip8182Vectors.t.sol`).
- Per-arity sponge vectors (`test/eip8182/Eip8182TagVectors.t.sol`) — arity 2 untagged, arity 2 tagged, arity 4, arity 10, arity 17.
- Tagged vs untagged 2-input collision regression.
- Gas measurement under `STATICCALL` (warm `hash`, depth-32 walk, worst-case `hashN`).

## Pinning for production use

For production deployment the artifacts in this directory should be pinned to
a specific EIP-8182 commit and bound to the in-circuit Poseidon2 gadget against
the test-vector set. A consuming protocol's binding ceremony should pin the
EIP-8182 commit, audit the artifact unchanged, and verify the on-chain constants
match the JSON byte-for-byte. See the off-repo spec §6 / §4 for the obligations.
