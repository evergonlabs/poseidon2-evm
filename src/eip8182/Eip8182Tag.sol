// SPDX-License-Identifier: MIT
pragma solidity >=0.8.8;

/// @title Eip8182Tag
/// @notice Derives EIP-8182 §10 domain tags as
///         fieldElement(keccak256("eip-8182.<name>")). Spec §2.
/// @dev    The reduction `% PRIME` ensures the tag is a canonical field
///         element (keccak256 output can exceed PRIME, though it almost never
///         does in practice; we reduce defensively).
///
///         CAVEAT: the exact `<name>` string convention (lowercase/snake_case
///         in this file) needs confirmation from the cryptography lead against
///         the gateway-side docs/design_decisions.md before the Phase 4
///         ceremony binds the tag IDs. The hex values printed by
///         test_print_tags in ProtocolVectors.t.sol must match what's pinned
///         in the gateway's design-decisions doc.

// Derived tag values (must match docs/design_decisions.md on the gateway side):
//   NOTE_COMMITMENT_V1 = 0x09aacdfda9b185730424cfd6c1059297134a4a64e1ca7411afc4f1b0b2deefe9
//   NOTE_BODY_V1       = 0x15bac6cd51646ec69ebfc6bab54b7488642ebed951d9ba526ebef9feb4b6ce21
//   NULLIFIER_V1       = 0x24d6034432c3b1717b680aba5f47021c6616889bd6b576470d3ef02cba4f8f5f
//   ACCOUNT_V1         = 0x1ad417510087003092701a032f81806279472fe742542bdcd867b3a5aa061302
//   OWNER_V1           = 0x134e9a1ca5b2b9e1c0710a307644bbdfadd2a59e476301177e95b663e06d0b52
//   AMOUNT_V1          = 0x2afd6a8cc1fe51404ea32914186c0a1813da321eed8df841f3e958323117391e
//   INTENT_V1          = 0x1a39ef8be5817f3c18aff8fbf4b2fc3cca3a70767178101da0fc6fb952ba6175
//   SPEND_V1           = 0x1b0a3cd60cc0bbe2bc265906036c5267ae138981bc806c2331a16db891497676
//   TAG_V1             = 0x1e19fd8a731d8f125298e5ead07775657a1f1247ffff490dd9ece905f877c297
//   EXIT_V1            = 0x2c123a96588690a648ac7dc6f7e5ebfc7843d47edbd716b0b53026e57661d2a4
//   INGEST_V1          = 0x17ac7ba90c26b483c87cd8f751a22a8ca6da582599d8875161924bb92f759de6
//   POLICY_V1          = 0x1582ec40895a9ad51f9cd5be516003275f845fb503b10beabf89737f05143026
library Eip8182Tag {
    uint256 internal constant PRIME = 0x30644e72e131a029b85045b68181585d2833e84879b9709143e1f593f0000001;
    bytes9 internal constant PREFIX = "eip-8182.";

    function derive(string memory name) internal pure returns (bytes32) {
        bytes32 h = keccak256(abi.encodePacked(PREFIX, bytes(name)));
        return bytes32(uint256(h) % PRIME);
    }

    // Convenience: the 12-tag protocol set from spec §2 / V4 §3.
    function NOTE_COMMITMENT_V1() internal pure returns (bytes32) {
        return derive("note_commitment_v1");
    }

    function NOTE_BODY_V1() internal pure returns (bytes32) {
        return derive("note_body_v1");
    }

    function NULLIFIER_V1() internal pure returns (bytes32) {
        return derive("nullifier_v1");
    }

    function ACCOUNT_V1() internal pure returns (bytes32) {
        return derive("account_v1");
    }

    function OWNER_V1() internal pure returns (bytes32) {
        return derive("owner_v1");
    }

    function AMOUNT_V1() internal pure returns (bytes32) {
        return derive("amount_v1");
    }

    function INTENT_V1() internal pure returns (bytes32) {
        return derive("intent_v1");
    }

    function SPEND_V1() internal pure returns (bytes32) {
        return derive("spend_v1");
    }

    function TAG_V1() internal pure returns (bytes32) {
        return derive("tag_v1");
    }

    function EXIT_V1() internal pure returns (bytes32) {
        return derive("exit_v1");
    }

    function INGEST_V1() internal pure returns (bytes32) {
        return derive("ingest_v1");
    }

    function POLICY_V1() internal pure returns (bytes32) {
        return derive("policy_v1");
    }
}
