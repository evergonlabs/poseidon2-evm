# Security Policy

## Audit status

**Not audited. Use at your own risk.**

The implementations in this repository have **not** undergone a formal
third-party security audit, and neither has the upstream
[`zemse/poseidon2-evm`](https://github.com/zemse/poseidon2-evm) project this
fork builds on. They are provided "as is", without warranty of any kind (see
[LICENSE](LICENSE)).

This is a cryptographic primitive: a single wrong bit in a hash output is a
protocol break, and a bug can compromise every commitment, nullifier, and
Merkle root derived from it. Before any production use:

- Review the code, or commission an independent audit.
- Verify that the pinned constants and normative test vectors reproduce the
  exact output of your in-circuit Poseidon2 gadget.
- Pin to an immutable tag or commit, and re-verify after any update.

## Reporting a vulnerability

Please report security vulnerabilities **privately** — do not open a public
issue.

- Use GitHub's private vulnerability reporting on this repository: the
  **Security** tab → **Report a vulnerability**.

We will acknowledge receipt and work on a fix as soon as possible.

## Scope

This policy covers the Poseidon2 implementations and the EIP-8182 sponge
wrapper in this repository (`src/`). For issues in the upstream
[`zemse/poseidon2-evm`](https://github.com/zemse/poseidon2-evm) project,
report them there.
