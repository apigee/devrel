# Apigee Skills Serving

Use Apigee API hub as the catalog and authority for **agent skills** —
versioned, signed, retrievable bundles of LLM agent instructions and
helper code that any agent runtime (OpenCode, Claude Code, Gemini CLI,
custom MCP hosts, etc.) can discover and install.

This reference implementation shows how to:

1. **Author** a skill (a `SKILL.md` + optional `scripts/`) and describe it
   with a `manifest.yaml` against a locked schema.
2. **Sign** the skill bundle with an Ed25519 key so consumers can verify
   integrity at install time.
3. **Upload** the signed `.skill` archive to a Google Cloud Storage bucket.
4. **Register** the skill (and its API hub attribute taxonomy) so it is
   discoverable through API hub's search and attribute filters.
5. **Install** a skill on the consumer side: search API hub, fetch the
   `gs://` URI, verify the Ed25519 signature, materialize the `SKILL.md`
   on disk for the agent runtime.

The whole loop runs on standard Apigee X / hybrid plus API hub — no
custom infrastructure.

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
│   ├── publish-and-install.md   end-to-end walkthrough
│   └── policy-skill-catalog.md  about the apigee-policy-top10 example
├── bin/
│   ├── check-prerequisites.sh   pre-flight environment validator
│   ├── demo-setup.sh            env export + readiness print
│   └── demo-cleanup.sh          remove demo artifacts
├── schema/
│   └── skill-manifest.schema.yaml  locked v1 manifest schema
├── scripts/                     publisher-side toolchain
│   ├── pack_skill.py            bundle a skill directory into a .skill zip
│   ├── sign_skill.py            Ed25519-sign a manifest
│   ├── upload_skill.py          push a signed .skill to GCS
│   ├── register_skill.py        register the manifest with API hub
│   ├── update_taxonomy.py       create/update API hub attribute taxonomy
│   └── common/                  shared libraries (retry, IAM, schema)
├── skills/                      example skills
│   ├── apigee-policy-top10/     skill that documents Apigee policy patterns
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

## Quickstart

```bash
# 1. Clone and enter the reference
git clone https://github.com/apigee/devrel.git
cd devrel/references/apigee-skills-serving

# 2. Install Python dependencies into a virtualenv
python3 -m venv .venv
. .venv/bin/activate
pip install -r requirements.txt

# 3. Set up environment variables (edit values to match your project)
cp env.sh.example env.sh
$EDITOR env.sh
. ./env.sh

# 4. Verify prerequisites
./bin/check-prerequisites.sh

# 5. (One-time) Create the API hub attribute taxonomy
python3 scripts/update_taxonomy.py \
  --project "$APIHUB_PROJECT" \
  --location "$APIHUB_LOCATION"

# 6. Pack, sign, upload, register a skill
python3 scripts/pack_skill.py    skills/currency-converter   /tmp/cc.skill
python3 scripts/sign_skill.py    /tmp/cc.skill   --key-file ./signing.key
python3 scripts/upload_skill.py  /tmp/cc.skill   --bucket "$GCS_BUCKET"
python3 scripts/register_skill.py \
  --project "$APIHUB_PROJECT" --location "$APIHUB_LOCATION" \
  --manifest /tmp/cc.skill
```

Full walkthrough: [`docs/publish-and-install.md`](docs/publish-and-install.md).
Design rationale and trust model: [`docs/architecture.md`](docs/architecture.md).

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

## Example skills

| Skill                  | Purpose                                                                                             |
| ---------------------- | --------------------------------------------------------------------------------------------------- |
| `currency-converter`   | Minimal example. A `SKILL.md` plus a `manifest.yaml`. Useful as a copy-and-edit starting point.     |
| `weather-lookup`       | Minimal example demonstrating a skill with API-key-based external HTTP calls.                       |
| `apigee-policy-top10`  | A skill that documents the ten most useful Apigee policy patterns, with a script that enumerates    |
|                        | the policies present in your org. See [`docs/policy-skill-catalog.md`](docs/policy-skill-catalog.md). |
| `examples/apigee-proxy-skill` | A complete, production-shaped skill: 18 MCP tools, 25 Jinja2 policy templates, full manifest. |

## Limitations and non-goals

- The skill registry uses API hub's standard search; ranking is keyword
  overlap, not semantic. For semantic ranking, integrate a vector
  search component separately.
- The publisher and consumer share an Ed25519 trust root. Key rotation
  is a manual operator workflow; this reference does not implement
  automatic rotation.
- Skills are sandboxed by the consumer runtime (OpenCode, agent host).
  This reference does not introduce additional sandboxing on top.

## License

[Apache 2.0](LICENSE). See the [LICENSE](LICENSE) file for details.

## Disclaimer

This is not an officially supported Google product.
