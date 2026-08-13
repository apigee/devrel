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

The reference consumer implementation is the `skill-finder` skill
(installed via `bin/install-skill-finder.sh`). At install time,
`find_install.py` performs a locked 16-step contract:

1. Fetches the manifest from API hub.
2. Looks up the publisher's public key by the `signing_key_id`
   fingerprint against **the trust roots installed on this
   machine** (see "Per-deployment trust roots" below).
3. Re-canonicalises the manifest (excluding signature fields).
4. Verifies the Ed25519 signature.
5. Downloads the `.skill` zip from `gs_uri`.
6. Computes SHA-256 of the downloaded zip and compares it against
   the manifest's `zip_sha256`.
7. Only after both checks pass does the consumer extract the
   `.skill` contents to the local skills directory.

### Per-deployment trust roots

The trust root is **not** a shared, repo-baked public key. It is a
per-deployment secret: each customer who runs `bin/provision.sh`
generates a fresh Ed25519 keypair on their own machine, signs
their catalog with it, and drops the corresponding public PEM into
their local skill-finder install's `keys/` directory. The private
key never leaves the customer's machine and is never committed to
any repo (including `apigee/devrel`).

Consequences:

- **skill-finder itself is trusted by provenance**, not by
  signature. The operator fetched skill-finder from a known-good
  URL (`raw.githubusercontent.com/apigee/devrel/main/…`) over TLS
  from the `apigee` GitHub organisation. There is no signature to
  verify because the code that would verify it *is* skill-finder.

- **Payload skills** (currency-converter, weather-lookup,
  apigee-policy-top10, and anything a customer publishes on top)
  ARE cryptographically verified against the per-deployment trust
  root.

### Multi-key trust roots

skill-finder loads **every** `.pem` file under
`~/.<runtime>/skills/skill-finder/keys/` as an accepted trust
root. A downloaded manifest is accepted if its `signing_key_id`
matches **any** installed key. This supports three operator
workflows:

- **Multi-publisher orgs**: Alice's team's key and Bob's team's
  key can both be trusted simultaneously. Any skill signed by
  either team installs cleanly.
- **Zero-downtime key rotation**: add the new key alongside the
  old one; publish new skills signed with the new key; wait for
  callers to stop using the old key; remove the old key. No
  install-time gap.
- **Bootstrap onboarding**: `bin/provision.sh` drops a
  `<fingerprint>.pem` into `keys/` after the initial key
  generation, giving skill-finder its first trust root without a
  separate configuration step.

If `keys/` is empty at verify time, skill-finder emits
`trust root: FAILED — no valid keys loaded from …` and refuses
to install anything.

### Threat model

| Attack                                       | Mitigation                                                                 |
| -------------------------------------------- | -------------------------------------------------------------------------- |
| Compromised GCS bucket serves a wrong zip    | `zip_sha256` mismatch is detected before extraction.                       |
| Modified manifest in API hub                 | Ed25519 signature mismatch is detected.                                    |
| Replay of an old (vulnerable) skill version  | Consumer is responsible for tracking versions; manifest carries `version`. |
| Compromised publisher signing key            | Operator rotates by adding a new key to `keys/`, re-publishing all skills, then removing the old key. Multi-key support means no install-time gap. |
| Malicious skill body (legitimate signature)  | Out of scope; agent runtime sandboxing is the boundary.                    |
| Compromised skill-finder installer over TLS  | Out of scope for v1 (relies on TLS + apigee org provenance). Operators can pin `--ref <commit-sha>` in the installer invocation to reduce exposure. |

The reference does **not** introduce a new sandbox. The agent
runtime that loads the skill (OpenCode, Gemini CLI, Antigravity,
Claude Code, custom MCP hosts) is responsible for limiting what
skill code can do once it runs.

### Trust-root discovery in v2 (not implemented)

A future iteration could store the trust root in API hub itself
as a well-known attribute on a placeholder API resource. This
would let skill-finder discover the trust root from the same
catalog it queries for skills, eliminating the
`bin/provision.sh`-drops-a-PEM step. The first fetch would be
trust-on-first-use (TOFU) against a URL the operator provides;
subsequent fetches would verify against the cached pubkey. This
is a v2 design and is intentionally out of scope for v1: it
requires new attribute conventions, taxonomy changes, and a
bootstrap mode that would add several more moving parts.

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
`scripts/update_taxonomy.py`, plus one system-defined enum value
patched in from `bin/provision.sh`:

| Attribute          | Kind         | Type    | Purpose                                                                  |
| ------------------ | ------------ | ------- | ------------------------------------------------------------------------ |
| `agentic_skill`    | user-defined | bool    | True for entries consumable by the agent runtime.                        |
| `keywords`         | user-defined | strings | Discovery keywords mirrored from the manifest (cardinality: up to 20).   |
| `gs_uri`           | user-defined | string  | GCS URI of the signed `.skill` archive.                                  |
| `signing_key_id`   | user-defined | string  | `sha256:<hex>` fingerprint of the publisher's signing public key.        |
| `skill-spec`       | system enum  | —       | Value patched into the built-in `system-spec-type` enum (see note below).|

The four user-defined attributes are immutable once created (API hub
does not support attribute schema migration). The `update_taxonomy.py`
script is idempotent: it creates any missing attributes and leaves
existing ones untouched.

The `skill-spec` value on the built-in `system-spec-type` enum is
added by a direct API hub `PATCH` from `bin/provision.sh` because
`update_taxonomy.py` only manages user-defined attributes. Migrating
that patch into `update_taxonomy.py` is a documented follow-up
(see `docs/provisioning.md#step-4-api-hub-attribute-taxonomy`).

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
