# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Engineering quality bar (read first, applies to everything)

This codebase ships a **cryptographic primitive** consumed by a financial-grade protocol (the `ConfidentialOmnibusVault` of the iso20022-gateway). Every change must clear an industry quality bar, not a "good enough for a demo" bar. A bit-level deviation in a hash function is a protocol-break: a wrong constant, a missed `mod p`, a wrong length tag, and the on-chain hasher silently produces a different value than the in-circuit gadget — every nullifier, note commitment, and Merkle root downstream is then invalid.

### Non-negotiable principles

1. **No shortcuts, no hacks, no cheating.** If a fix feels like a workaround, it is a workaround — stop and find the proper solution. Examples of disallowed shortcuts: silently reducing inputs `mod p` instead of reverting on non-canonical input; `unchecked { … }` blocks added "to save gas" without proving the arithmetic stays in range; commenting out a failing test vector; `--force` on a constants byte-check that should be reproducible; commented-out code left behind.
2. **Find the root cause.** When a hash output diverges from a reference vector, the cause is one specific deviation (a constant, a matrix entry, an ordering, an IV, a domain-tag placement). Bisect until you find it. Do not "tune" coefficients until tests pass.
3. **Industry-standard patterns over clever ones.** When a problem has a well-established solution (EIP-8182's length-tagged-IV sponge, the `STATICCALL` view interface, the OZ `MerkleTree` custom-hasher pointer signature), use the standard. Cleverness in load-bearing crypto code is debt. Deliberate divergences are documented in the spec set (off-repo) and called out in code comments to the relevant spec section.
4. **Every layer must be production-grade.** Yul / Huff generators → byte-deterministic output that round-trips through `forge fmt`. Tests → fuzz + EIP-8182 normative vectors + protocol-specific test vectors per arity. Gas → measured under `STATICCALL`, not estimated. Interface → matches the OZ `MerkleTree` pointer signature exactly (`function(bytes32,bytes32) view returns (bytes32)`).
5. **Verify before declaring done.** `forge test` passes, gas report produced, byte-equivalence of constants against EIP-8182 JSON confirmed. Not "the code looks right" — running the suite and reading the output.

### Decision-making bar

When weighing alternatives:
1. Is it correct? (Does it match EIP-8182's normative spec + every pinned test vector + the in-circuit Poseidon2 gadget byte-for-byte?)
2. Is it the established standard? (EIP-8182 §10 for domain tags, length-tagged IV for sponge, etc. — or a deliberate, documented divergence?)
3. Is it maintainable? Can a cryptography reviewer audit it without a meeting?
4. Is it observable? Custom errors (e.g. `InvalidHashNArity`) over `revert` strings; gas-reportable.
5. Is it secure? Reverts on non-canonical input; no silent `mod`; no path that returns a value when the contract should have reverted.

A solution that fails any of these is not "highest standard" — it is technical debt being staged. Stop and pick the better path.

### When in doubt

Ask. A two-minute clarification is cheaper than a half-day on the wrong path. Particularly for: anything that changes the hash output (constants, matrices, IV, ordering, domain-tag placement), the `IPoseidon2` interface shape (the OZ pointer signature is load-bearing), or the boundary between sponge-wrapper logic and the underlying permutation.

## Project Overview

A fork of [`zemse/poseidon2-evm`](https://github.com/zemse/poseidon2-evm) (MIT). Upstream provides a gas-optimized Poseidon2-BN254-t4 permutation in Yul + Huff with packaged `hash_1/2/3` entry points.

This fork (`eip8182-sponge` branch) adds an **EIP-8182-conformant sponge wrapper** over the same permutation, exposing the vault-side `IPoseidon2` interface (`hash(bytes32,bytes32)` for tree nodes, `hashN(bytes32[])` for domain-tagged variable-arity hashes). The motivating consumer is the iso20022-gateway `ConfidentialOmnibusVault`, but the fork itself ships only generic primitives — no vault-specific code lives here, and the changes are intended to be upstream-compatible.

See [UPSTREAM](UPSTREAM) for the upstream pin, rebase recipe, and atomic-commit roadmap.

## Authoritative spec

The implementation spec for this hasher is `Poseidon2-hasher-spec.md`, kept **off-repo** in the iso20022-gateway spec set (currently under `C:\Work\projects\ethereum\allianceblock\_other\2026-05-18_iso20022-omnibus-redesign\`). It is the source of truth for:

- Parameter set (BN254, t=4, R_F=8, R_P=56, x⁵ S-box, rate 3 / capacity 1).
- Sponge construction: length-tagged IV `inputCount << 64`, domain tag as **input element 0** (per EIP-8182 §10), tree-node hashes are **untagged** with `IV = 2<<64`.
- Domain-tag derivation (`<TAG>_V1 = fieldElement(keccak256("eip-8182.<name>"))`) and the full 12-tag set.
- The `IPoseidon2` interface shape (and why it is `view`, not `pure` — OZ `MerkleTree`'s custom-hasher pointer requires `view`).
- Reject non-canonical inputs (`>= p`) — do NOT silently reduce.
- The `EXIT_V1` length-2 regression vector and per-arity test surface.
- The Phase 4 ceremony binding obligations.

**Do not duplicate the spec into the repo.** Reference it by section (`spec §2`, `spec §3`) in commit messages and PR descriptions. Code comments may reference durable artifacts (EIP-8182, the upstream `zemse/poseidon2-evm` repo, the test-vector JSON files once pinned in-repo), but should not point to off-repo spec paths.

## Locked decisions (do not relitigate without a spec update)

These come directly from `Poseidon2-hasher-spec.md`:

- **t = 4, single instance.** One sponge serves every protocol hash (tree node, note / nullifier / account commitments, `intentHash`). `hash` and `hashN` are two entry points into the same sponge, not two instances.
- **Domain tags are input element 0, not a capacity initializer.** Matches V4 §6.2 notation `poseidon2(NOTE_COMMITMENT_V1, …)`.
- **Tree-node hash is untagged.** `hash(left, right)` absorbs exactly two elements with `IV = 2<<64` and no domain tag. The length-tag in the IV is what separates a tree-node hash from any arity-≥3 application hash.
- **Use the length-tagged-IV (standard) sponge construction.** Do **not** use `zemse`'s variable-length / trailing-`1`-padding branch — it diverges from EIP-8182 and from the in-circuit gadget.
- **Revert on non-canonical input (`>= p`).** Silent `mod` would let an attacker construct a collision (`x` and `x + p` hashing to the same value).
- **`IPoseidon2` interface is `view`, not `pure`.** OZ `MerkleTree`'s custom-hasher pointer type is `function(bytes32,bytes32) view returns (bytes32)`. The implementation may be `pure`; a `pure` impl satisfies a `view` interface. Narrowing the interface to `pure` breaks the OZ pointer type match.
- **Constants come from EIP-8182's `poseidon2_bn254_t4_rf8_rp56.json`**, pinned to a fixed commit. The `zemse` constants are byte-verified against this JSON; they are not regenerated.
- **The Yul generator is the canonical path.** Huff is not extended here — its absorb wrapper is hand-managed-stack and "experimental".
- **The permutation primitive must surface the full 4-element post-permutation state.** Upstream `poseidon2_core` returns only `state0`, discarding `state1/2/3`; this fork adds `poseidon2_permute` alongside it (purely additive — `hash_1/2/3` continue to call `poseidon2_core`). Multi-block sponge absorbs (`hashN` arity > 3) need the full state.
- **Specs and plans live off-repo.** Do not write spec or plan markdown into this repo.

## Commands

Foundry + Node toolchain. Run from the repo root.

```bash
forge build                       # compile (solc 0.8.30, cancun, optimizer 1,000,000)
forge test                        # full test suite
forge test --match-test <name>    # single test
forge test -vvv                   # verbose traces
forge fmt                         # format Solidity
./gas-report.sh                   # produce gas report (writes ./gas-report)

npm run generate:yul              # regenerate src/bn254/yul/* from generate-yul.ts (then forge fmt)
npm run generate:huff             # regenerate src/bn254/huff/* from generate-huff.ts
npm run generate:gas-report       # alias for ./gas-report.sh
npm run fmt                       # prettier on ts/js/json/md + forge fmt
npm test                          # alias for forge test
```

Notes:
- `ffi = true` in `foundry.toml` — some tests shell out to a reference implementation. Don't disable it.
- `solc_version = "0.8.30"`, `evm_version = "cancun"`, `optimizer_runs = 1000000`. Do not change these without spec-level approval — they affect deployed bytecode and the audit surface.
- Fuzz: `runs = 10000`, `max_test_rejects = 0`. Don't silence failing fuzz cases with `vm.assume` unless the constraint is genuinely required by the function's domain.

## Architecture

### Source layout

```
src/
  IPoseidon2.sol                  # upstream (zemse) hash_1/2/3 interface — kept for compat
  bn254/
    Poseidon2.sol                 # helper library exposing hash_2 etc. via STATICCALL
    solidity/                     # pure-Solidity reference impl (264k gas; correctness reference)
    yul/                          # Yul implementation (Poseidon2Yul, LibPoseidon2Yul)
    huff/                         # Huff implementation (experimental; not extended in this fork)
generate-yul.ts                   # Yul codegen template emitter (~7 KB)
generate-huff.ts                  # Huff codegen
test/
  Poseidon2.t.sol                 # correctness + fuzz + overflow safety
```

The fork's new artifacts (sponge wrapper, `hash` / `hashN` entry points, the new `IPoseidon2` view interface for the vault) will be added incrementally per the UPSTREAM roadmap. **Do not collide with the upstream `IPoseidon2` name** — the vault-side interface in this fork is named `IPoseidon2` by convention; the collision with the upstream's `hash_1/2/3` interface is intentional but the two are distinct files / different consumers. When introducing the new interface, decide explicitly where it lives and document the choice in a comment.

### Toolchain layering

1. **Generators** (`generate-yul.ts`, `generate-huff.ts`) emit `.sol` / `.huff` from the EIP-8182 parameters. Generated files are committed (so reviewers can read what is actually deployed), but the generator is the source of truth — never hand-edit a generated file, edit the generator and regenerate.
2. **Permutation primitive** — the Yul `poseidon2_core` is the 64-round permutation that returns only `state0` (upstream behavior). This fork adds `poseidon2_permute` alongside it (purely additive — `hash_1/2/3` continue to call `poseidon2_core` for byte-identical behavior). `poseidon2_permute` exposes the full 4-element post-permutation state required for multi-block sponge absorbs (`hashN` arity > 3). **No protocol logic lives here.**
3. **Sponge wrapper** — absorbs inputs in rate-3 blocks with the length-tagged IV, calls `poseidon2_permute` between blocks, prepends the domain tag for `hashN`. **No permutation logic lives here.**
4. **Interface** (`IPoseidon2` view) — the contract surface the vault links against via `STATICCALL`.

Keep this separation. A change to the permutation should not require touching the sponge wrapper, and vice versa.

## Code style

- Solidity 0.8.30, optimizer runs 1,000,000, EVM `cancun`.
- `forge fmt` is the formatter — run it before committing.
- Prettier 3.8.x for `ts/js/json/md` — `npm run fmt`.
- Custom errors over `require` strings (`InvalidHashNArity(uint256)` is the spec example).
- Comments at decision points only — point to the spec section or the EIP-8182 clause. Don't narrate "what the code does"; well-named identifiers and the spec do that.
- No emoji in source files unless explicitly requested.

## Testing

The test surface from spec §7:

- Byte-equivalence of `zemse`-imported constants against `poseidon2_bn254_t4_rf8_rp56.json` (pinned EIP-8182 commit).
- EIP-8182 normative test vectors (`poseidon2_vectors.json`).
- Per-arity protocol vectors: arity 2 untagged (tree-node), arity 2 tagged with `EXIT_V1`, arity 4 with `NOTE_COMMITMENT_V1`, and up to arity ~17 for the worst-case `intentHash` (⌈17 / 3⌉ = 6 permutations).
- **`EXIT_V1` length-2 collision regression** — `hashN([EXIT_V1, address(0x02)])` MUST NOT equal `hash(bytes32(0x01), bytes32(0x02))`. Both calls use `IV = 2<<64`, but the tag in slot 0 makes the absorbed sequences differ.
- Rejection of non-canonical inputs (`>= p`).
- Rejection of arity-`{0, 1}` for `hashN` (`InvalidHashNArity`).
- Gas measurement of `hash` and the worst-case `hashN` under `STATICCALL` (the vault calls cross-contract, not inline).
- Differential test of the OZ `_zeros` ladder against an independent Python / Rust reference Poseidon2 zero-walk.

Test vectors that are pinned (EIP-8182 JSONs, protocol-specific arity vectors) are checked into the repo so the test run is hermetic. The protocol-specific vector set will be frozen at the Phase 4 ceremony — until then, treat it as draft and call out any change in the PR description.

## Git workflow

- Branch: `eip8182-sponge`. Atomic-commit roadmap is in [UPSTREAM](UPSTREAM) — try to keep commits scoped to one step (constants byte-check, then state expansion, then sponge wrapper, etc.) so the PR review can follow the spec sections in order.
- Conventional commits where natural — `feat: …`, `fix: …`, `test: …`, `chore: …`.
- Do not amend or force-push once a commit is shared; create a new commit. (Standard project rule — see the iso20022-gateway CLAUDE.md for the rationale.)
- Generated files are committed; if you regenerate, the generator change and the generated diff go in the **same** commit so reviewers see them together.

## Working with the spec

When the user asks for a feature, the workflow is:

1. **Open `Poseidon2-hasher-spec.md`** — find the section that covers the feature (the spec is organized §0 Role, §1 Parameters, §2 Sponge & domain separation, §3 Interface, §4 Implementation plan, §5 Why, §6 Cryptography-lead status, §7 Vault integration).
2. **Check the UPSTREAM roadmap** — does the feature land in one of the seven planned commits, or is it net-new scope?
3. **Implement against the spec, not the user's paraphrase.** The user is the spec owner but the spec text is canonical; if they conflict, surface the conflict before implementing.
4. **Cite the spec section** in the PR / commit (`per spec §2`, `per spec §7 EXIT_V1 vector`).

If the spec is wrong or incomplete, say so — the spec is a working document and the cryptography lead can amend it. Don't paper over an under-specified case with a silent default.
