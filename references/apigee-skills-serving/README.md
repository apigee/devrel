# Apigee Skills Serving

Use Apigee API hub as the catalog and authority for **agent skills** —
versioned, signed, retrievable bundles of LLM agent instructions and
helper code that any agent runtime (OpenCode, Claude Code, Gemini CLI,
custom MCP hosts, etc.) can discover and install.

This reference implementation shows how to:

1. **Author** a skill (a `SKILL.md` + optional `scripts/`) and describe
   it with a `manifest.yaml` against a locked schema.
2. **Sign** the skill bundle with an Ed25519 key so consumers can verify
   integrity at install time.
3. **Upload** the signed `.skill` archive to a Google Cloud Storage
   bucket.
4. **Register** the skill (and its API hub attribute taxonomy) so it is
   discoverable through API hub's search and attribute filters.
5. **Install** a skill on the consumer side: search API hub, fetch the
   `gs://` URI, verify the Ed25519 signature, materialize the `SKILL.md`
   on disk for the agent runtime.

The whole loop runs on standard Apigee X / hybrid plus API hub — no
custom infrastructure.

Two ready-to-run agent skills wrap the reference implementation into
a one-line install for end users:

- **`skills/skill-finder/`** — consumer-side discovery client. Queries
  API hub for signed skills, verifies their Ed25519 signatures against
  locally-installed per-deployment trust roots, and installs matching
  skills into the agent runtime's skills directory.
- **`skills/skill-publisher/`** — author-side pipeline orchestrator.
  Wraps pack → sign → upload → register into a single skill an agent
  can invoke on a source skill directory.

Both are installed by `bin/install-skill-finder.sh` (which installs
both by default).

## Why Apigee API hub for skills?

Agent skills are, structurally, just metadata-tagged content addressed
by content-hash. API hub already provides:

- **A versioned catalog** with stable IDs, list and search endpoints.
- **A typed attribute taxonomy** for filtering (runtime compatibility,
  required IAM permissions, etc.).
- **Project-scoped IAM** so publish/consume permissions are governed
  through the same controls as the rest of your API surface.
- **A regional, replicated store** with audit logging.

Using API hub as the skill catalog avoids standing up a parallel registry
and lets organisations apply existing API governance to the agent surface.

## Repository layout

```text
references/apigee-skills-serving/
├── README.md                    you are here
├── LICENSE                      Apache 2.0
├── pipeline.sh                  devrel CI entry-point
├── env.sh.example               environment variable template
├── requirements.txt             Python runtime dependencies (4 packages)
├── pytest.ini                   test configuration
├── docs/
│   ├── architecture.md          design overview and trust model
│   ├── provisioning.md          customer-onboarding runbook (five-minute path)
│   ├── publish-and-install.md   detailed end-to-end walkthrough (under-the-hood)
│   └── policy-skill-catalog.md  about the apigee-policy-top10 example
├── bin/
│   ├── check-prerequisites.sh   pre-flight environment validator
│   ├── demo-setup.sh            env export + readiness print (legacy)
│   ├── demo-cleanup.sh          remove locally-installed skills
│   ├── install-skill-finder.sh  one-line installer for skill-finder + skill-publisher
│   ├── install-skill-publisher.sh  install skill-publisher only
│   └── provision.sh             one-line customer bootstrap (APIs, bucket,
│                                taxonomy, key gen, publish, trust root)
├── schema/
│   └── skill-manifest.schema.yaml  locked v1 manifest schema
├── scripts/                     publisher-side toolchain
│   ├── pack_skill.py            bundle a skill directory into a .skill zip
│   ├── sign_skill.py            Ed25519-sign a manifest
│   ├── upload_skill.py          push a signed .skill to GCS
│   ├── register_skill.py        register the manifest with API hub
│   ├── update_taxonomy.py       create/update API hub attribute taxonomy
│   └── common/                  shared libraries (retry, IAM, schema)
├── skills/                      shipped skills
│   ├── skill-finder/            consumer-side discovery + install client
│   ├── skill-publisher/         author-side pipeline orchestrator
│   ├── apigee-policy-top10/     example skill that reports top Apigee policies
│   ├── currency-converter/      minimal example
│   └── weather-lookup/          minimal example
├── examples/
│   └── apigee-proxy-skill/      full-fat showcase skill (Ed25519-signed
│                                example of a production manifest)
└── tests/                       hermetic unit + in-process integration tests
                                 (no live GCP needed; 220 tests, ~1.3s)
```

## Prerequisites

1. Apigee X or hybrid organization
   ([provision an eval org](https://cloud.google.com/apigee/docs/api-platform/get-started/provisioning-intro)
   if needed).
2. Apigee API hub instance
   ([enable API hub](https://cloud.google.com/apigee/docs/apihub/provision)
   in your GCP project).
3. A Google Cloud Storage bucket you can write to (for hosting `.skill`
   archives).
4. Local tools:
   - Python 3.11+ with `pip`
   - [`gcloud` SDK](https://cloud.google.com/sdk/docs/install)
   - `jq`, `curl`, `unzip`
5. Application Default Credentials (`gcloud auth application-default
   login`).
6. The roles `roles/apihub.editor` and `roles/storage.objectCreator` on
   the target project.

## Quickstart (five minutes)

The fast path uses two shell scripts:

```bash
# 1. Install skill-finder + skill-publisher on your machine.
curl -fsSL https://raw.githubusercontent.com/apigee/devrel/main/\
references/apigee-skills-serving/bin/install-skill-finder.sh \
  | bash -s -- --runtime gemini      # or --runtime opencode / antigravity

# 2. Clone the reference and provision your GCP project.
git clone https://github.com/apigee/devrel.git
cd devrel/references/apigee-skills-serving
bash bin/provision.sh --project MY_PROJECT --yes
```

`provision.sh` enables the required GCP APIs, creates a GCS
bucket, sets up the API hub attribute taxonomy, generates a
fresh Ed25519 signing keypair on your machine (private key
stays there), and publishes the three example skills. Every
step is idempotent — re-run any time to reconcile drift.

Full runbook (including troubleshooting and key rotation):
[`docs/provisioning.md`](docs/provisioning.md).

### Under the hood

The scripts above chain the five underlying operations that
this reference exists to demonstrate:

```bash
# For each skill:
python3 -m scripts.pack_skill    --src skills/<name> --out /tmp/<name>.skill
python3 -m scripts.upload_skill  --zip /tmp/<name>.skill --bucket "$GCS_BUCKET"
python3 -m scripts.sign_skill    --manifest <patched-manifest> \
                                 --zip /tmp/<name>.skill \
                                 --priv-key <signing.raw> \
                                 --out <signed-manifest>
python3 -m scripts.register_skill --manifest <signed-manifest> \
                                 --project "$APIHUB_PROJECT" \
                                 --location "$APIHUB_LOCATION"
```

Full walkthrough:
[`docs/publish-and-install.md`](docs/publish-and-install.md).

Design rationale and trust model:
[`docs/architecture.md`](docs/architecture.md).

## Running the tests

The bundled test suite is hermetic — all HTTP calls, ADC lookups, and
GCP services are mocked. It runs in any environment with Python 3.11+
and the four packages in `requirements.txt`:

```bash
pip install -r requirements.txt
pytest -q
```

`pipeline.sh` runs the same suite and is what apigee/devrel CI invokes
nightly.

## Shipped skills

| Skill                         | Purpose                                                                                                                                                       |
| ----------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `skill-finder`                | Consumer-side. Discovers, verifies, and installs signed skills from the customer's API hub. Multi-key trust root; per-deployment provisioning.                |
| `skill-publisher`             | Author-side. Wraps pack → sign → upload → register into a single skill an agent can invoke on a source skill directory.                                       |
| `currency-converter`          | Minimal example. A `SKILL.md` plus a `manifest.yaml`. Useful as a copy-and-edit starting point.                                                               |
| `weather-lookup`              | Minimal example demonstrating a skill with API-key-based external HTTP calls.                                                                                 |
| `apigee-policy-top10`         | A skill that documents the ten most useful Apigee policy patterns, with a script that enumerates the policies present in your org. See [`docs/policy-skill-catalog.md`](docs/policy-skill-catalog.md). |
| `examples/apigee-proxy-skill` | A complete, production-shaped skill: 18 MCP tools, 25 Jinja2 policy templates, full manifest.                                                                 |

## Limitations and non-goals

- The skill registry uses API hub's standard search; ranking is
  keyword overlap, not semantic. For semantic ranking, integrate
  a vector search component separately.
- The trust root is **per-deployment**, not shared. Each customer
  who runs `provision.sh` generates their own Ed25519 keypair on
  their machine. The `apigee/devrel` repo intentionally contains
  no signing key material and no signed release bundles;
  skill-finder itself is trusted by provenance (TLS + `apigee`
  GitHub org). See
  [`docs/architecture.md#trust-model`](docs/architecture.md#trust-model)
  for the full rationale.
- Key rotation is a supported operator workflow (multi-key
  trust root; add-then-remove pattern with no install-time gap),
  but is not automated. See
  [`docs/provisioning.md#key-rotation-with-zero-downtime`](docs/provisioning.md#key-rotation-with-zero-downtime).
- The GCS bucket for signed bundles must be public-read because
  skill-finder downloads via anonymous HTTPS. This is a demo
  choice; production would use signed URLs or an authenticated
  consumer.
- Skills are sandboxed by the consumer runtime (OpenCode, Gemini
  CLI, Antigravity, custom MCP hosts). This reference does not
  introduce additional sandboxing on top.

## License

[Apache 2.0](LICENSE). See the [LICENSE](LICENSE) file for details.

## Disclaimer

This is not an officially supported Google product.
