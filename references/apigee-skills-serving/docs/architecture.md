# Architecture

## Concept

An **agent skill** is a small bundle of LLM agent instructions and
helper code. It has:

- A `SKILL.md` — the instruction file the agent reads. Frontmatter
  declares the skill's name and one-line description; the body tells
  the agent when to use the skill and how.
- An optional `scripts/` directory with executables the agent can
  invoke (Python, shell, etc.).
- A `manifest.yaml` — metadata describing the skill: version,
  description, GCS location, signing material, declared IAM
  permissions, etc.

A **skill catalog** maps from natural-language queries ("help me set up
JWT validation in Apigee") to a ranked list of skills, with enough
metadata for the consumer to fetch and verify each one.

This reference uses **Apigee API hub** as the catalog. API hub provides
the storage, the search interface, the attribute taxonomy for filtering,
and the IAM boundary. The publisher (this repository's `scripts/`)
writes skills into API hub; the consumer (an agent runtime running on a
developer's machine) reads from API hub and installs skills locally.

## Component overview

```text
                ┌──────────────────────┐
                │   Author's machine   │
                │  ───────────────     │
                │  edit SKILL.md       │
                │  edit manifest.yaml  │
                └──────────┬───────────┘
                           │
                           │ pack_skill.py
                           ▼
                ┌──────────────────────┐         ┌────────────────┐
                │  Publisher           │         │                │
                │  ──────────          │         │   Cloud        │
                │  sign_skill.py       │────────▶│   Storage      │
                │  upload_skill.py     │  .skill │   bucket       │
                │  register_skill.py   │         │                │
                └──────────┬───────────┘         └────────┬───────┘
                           │ manifest                     │
                           ▼                              │ gs://
                ┌──────────────────────┐                  │
                │   Apigee API hub     │                  │
                │   ──────────────     │                  │
                │   APIs + attributes  │                  │
                │   typed taxonomy     │                  │
                │   search endpoint    │                  │
                └──────────┬───────────┘                  │
                           │                              │
                           │ list, get,                   │
                           │ filter by attribute          │
                           ▼                              │
                ┌──────────────────────┐                  │
                │  Consumer (agent     │                  │
                │  runtime, e.g.       │◀─────────────────┘
                │  OpenCode, Claude    │
                │  Code, Gemini CLI)   │
                │  ────────────────    │
                │  search API hub      │
                │  fetch .skill        │
                │  verify Ed25519      │
                │  materialize SKILL.md│
                └──────────────────────┘
```

## Trust model

The signing and verification flow uses Ed25519 detached signatures
over a **canonical serialization** of the manifest.

### What is signed

The publisher canonicalises the manifest (sorted keys, normalized
unicode, deterministic whitespace), excluding the `signature` and
`signing_key_id` fields themselves, then signs the canonical bytes
with the publisher's private key. The signature and the SHA-256
fingerprint of the corresponding public key are written back into the
manifest.

The `.skill` zip archive's SHA-256 (the `zip_sha256` field) is also
recorded in the manifest and signed transitively. This binds the
manifest to its zip contents so the consumer cannot be tricked into
verifying one manifest but installing a different bundle.

### What the consumer verifies

At install time, the consumer:

1. Fetches the manifest from API hub.
2. Looks up the publisher's public key by the `signing_key_id`
   fingerprint (typically out-of-band; the consumer is configured with
   a list of trusted publisher keys).
3. Re-canonicalises the manifest (excluding signature fields).
4. Verifies the Ed25519 signature.
5. Downloads the `.skill` zip from `gs_uri`.
6. Computes SHA-256 of the downloaded zip and compares it against the
   manifest's `zip_sha256`.
7. Only after both checks pass does the consumer extract the `.skill`
   contents to the local skills directory.

### Threat model

| Attack                                       | Mitigation                                                                 |
| -------------------------------------------- | -------------------------------------------------------------------------- |
| Compromised GCS bucket serves a wrong zip    | `zip_sha256` mismatch is detected before extraction.                       |
| Modified manifest in API hub                 | Ed25519 signature mismatch is detected.                                    |
| Replay of an old (vulnerable) skill version  | Consumer is responsible for tracking versions; manifest carries `version`. |
| Compromised publisher signing key            | Out of scope; operator must rotate the trust root.                         |
| Malicious skill body (legitimate signature)  | Out of scope; agent runtime sandboxing is the boundary.                    |

The reference does **not** introduce a new sandbox. The agent runtime
that loads the skill (OpenCode, Claude Code, etc.) is responsible for
limiting what skill code can do once it runs.

## Canonical serialization

The canonical form is JSON-encoded YAML with:

- Keys recursively sorted in code-point order.
- Unicode normalized to NFC.
- Strings UTF-8 encoded.
- Numbers in their shortest unambiguous decimal form.
- No trailing whitespace, single trailing newline.

This is implemented in `scripts/common/canonical.py`. The canonical
form is RFC-locked; consumers and publishers MUST produce byte-identical
output for the same logical manifest, or signatures will not verify.

## API hub attribute taxonomy

API hub's typed attributes let consumers filter the catalog. This
reference declares four user-defined attributes via
`scripts/update_taxonomy.py`:

| Attribute               | Type   | Purpose                                                     |
| ----------------------- | ------ | ----------------------------------------------------------- |
| `skill-compatible`      | bool   | True for entries consumable as agent skills.                |
| `skill-runtime-iam`     | string | Comma-separated list of IAM permissions the skill declares. |
| `skill-signing-key-id`  | string | SHA-256 fingerprint of the publisher's signing key.         |
| `skill-bundle-gs-uri`   | string | GCS URI of the signed `.skill` archive.                     |

These attributes are immutable once created (API hub does not support
attribute schema migration). The `update_taxonomy.py` script is
idempotent: it creates any missing attributes and leaves existing
ones untouched.

## Failure modes

The publisher scripts each have a documented exit-code contract:

| Exit | Meaning                                                              |
| ---- | -------------------------------------------------------------------- |
| `0`  | Success.                                                             |
| `1`  | User error (bad arguments, missing input file, malformed manifest).  |
| `2`  | Transient failure (5xx, network, retry exhausted).                   |
| `3`  | Permission denied (403, missing IAM role).                           |
| `4`  | Signature verification or canonicalisation failure.                  |

Operator-facing log lines are prefixed with `[apigee-skills]` to make
them easy to filter from agent runtime output. The contract is asserted
in the test suite (`tests/test_iam_preflight.py`,
`tests/test_check_demo_prerequisites.py`).

## Why API hub, not a custom registry

| Concern                  | API hub                                              | Custom registry                                 |
| ------------------------ | ---------------------------------------------------- | ----------------------------------------------- |
| Storage + replication    | Built in, regional.                                  | Build it.                                       |
| Search + ranking         | Built in, keyword overlap.                           | Build it.                                       |
| Attribute taxonomy       | Built in, typed.                                     | Build it.                                       |
| IAM                      | GCP IAM, integrated with the rest of your platform. | Build it, or bolt on an external IdP.           |
| Audit logging            | Cloud Audit Logs.                                    | Build it.                                       |
| Cost                     | Per-API hub pricing.                                 | VM + DB + load balancer + ops.                  |

The trade-off is that you must accept API hub's data model (APIs and
their attributes). Skills are not first-class entities — they ride
on top of the `Api` resource type. For the reference scope, this is a
clean fit; for very high skill volumes or specialised query patterns,
a custom registry may be warranted.
