# Publish and install walkthrough

This walkthrough takes you from a fresh checkout to a signed,
registered skill that an agent runtime can install from API hub.
The examples use the bundled `skills/currency-converter` as the
skill being published.

## For most people: use `bin/provision.sh`

If you just want a working reference deployment, skip the rest
of this document and read [`provisioning.md`](provisioning.md).
The five-minute path is:

```bash
# 1. Install skill-finder on your machine
curl -fsSL https://raw.githubusercontent.com/apigee/devrel/main/\
references/apigee-skills-serving/bin/install-skill-finder.sh \
  | bash -s -- --runtime gemini

# 2. Clone the reference and provision your project
git clone https://github.com/apigee/devrel.git
cd devrel/references/apigee-skills-serving
bash bin/provision.sh --project MY_PROJECT --yes
```

`provision.sh` runs everything in this walkthrough end to end:
enables APIs, creates the GCS bucket, sets up the taxonomy,
generates a fresh signing keypair on your machine, and publishes
the three example skills. It is idempotent — re-run it any time
to reconcile drift.

**Keep reading this document if:**

- You want to understand what `provision.sh` does under the hood.
- You want to publish your own skill (not one of the bundled
  examples). See especially section 6 (Pack) and section 7 (Sign)
  for the per-skill inputs.
- You are troubleshooting a failure at a specific step.

## 1. Prerequisites

You will need:

- An Apigee X / hybrid organization.
- An Apigee API hub instance in the same GCP project.
- A GCS bucket you can write to (for `.skill` archives).
- Roles on the project: `roles/apihub.editor`,
  `roles/storage.objectCreator`.
- Local tools: Python 3.11+, `gcloud`, `jq`, `curl`, `unzip`.

Verify with:

```bash
gcloud auth application-default login
./bin/check-prerequisites.sh
```

The script returns exit code `0` if all required environment variables
are set and `gcloud` can produce ADC. It returns non-zero with a
diagnostic per failed check otherwise.

## 2. Configure environment

```bash
cp env.sh.example env.sh
# Edit env.sh — set APIHUB_PROJECT, APIHUB_LOCATION, APIGEE_ORG,
# GCS_BUCKET to match your project.
. ./env.sh
```

## 3. Install Python dependencies

```bash
python3 -m venv .venv
. .venv/bin/activate
pip install -r requirements.txt
```

## 4. Generate (or import) an Ed25519 signing key

If you don't already have one:

```bash
python3 -c "
from cryptography.hazmat.primitives.asymmetric.ed25519 import Ed25519PrivateKey
from cryptography.hazmat.primitives import serialization
priv = Ed25519PrivateKey.generate()
raw = priv.private_bytes(
    encoding=serialization.Encoding.Raw,
    format=serialization.PrivateFormat.Raw,
    encryption_algorithm=serialization.NoEncryption(),
)
open('signing.key', 'wb').write(raw)
print('Wrote signing.key (32 bytes, raw Ed25519)')
"
chmod 600 signing.key
```

The corresponding public key is derived from the private key on
demand by `sign_skill.py`; consumers will use its SHA-256 fingerprint
to identify your signing identity.

**Operational note.** The signing key is your trust root. In a real
deployment, store it in a KMS or HSM rather than on disk, and run
`sign_skill.py` from a build environment that can call the KMS
signing API. This reference uses a local key for clarity.

## 5. Create the API hub attribute taxonomy (one-time)

```bash
python3 scripts/update_taxonomy.py \
  --project "$APIHUB_PROJECT" \
  --location "$APIHUB_LOCATION"
```

This creates four user-defined attributes in API hub
(`skill-compatible`, `skill-runtime-iam`, `skill-signing-key-id`,
`skill-bundle-gs-uri`). The script is idempotent — re-running it on
a project that already has the attributes is a no-op.

## 6. Pack the skill

```bash
python3 scripts/pack_skill.py \
  skills/currency-converter \
  /tmp/currency-converter.skill
```

A `.skill` is a zip with a defined internal layout: `SKILL.md` at the
top, `manifest.yaml` at the top, optional `scripts/` directory. The
packer enforces the layout, validates the manifest against
`schema/skill-manifest.schema.yaml`, and computes the bundle's
SHA-256.

## 7. Sign the skill

```bash
python3 scripts/sign_skill.py \
  /tmp/currency-converter.skill \
  --key-file ./signing.key
```

The signer reads the manifest from the zip, canonicalises it, signs
the canonical bytes with Ed25519, and rewrites the zip with the
signature and public-key fingerprint patched into the manifest.

Verify the signature locally:

```bash
python3 -c "
import zipfile, yaml
from cryptography.hazmat.primitives.asymmetric.ed25519 import Ed25519PrivateKey
from cryptography.hazmat.primitives import serialization
import base64, sys
sys.path.insert(0, '.')
from scripts.common.canonical import canonicalize

with zipfile.ZipFile('/tmp/currency-converter.skill') as z:
    m = yaml.safe_load(z.read('manifest.yaml'))
sig = base64.b64decode(m.pop('signature'))
m.pop('signing_key_id')
canon = canonicalize(m).encode('utf-8')

priv = Ed25519PrivateKey.from_private_bytes(open('signing.key','rb').read())
pub = priv.public_key()
pub.verify(sig, canon)
print('signature verifies')
"
```

## 8. Upload to GCS

```bash
python3 scripts/upload_skill.py \
  /tmp/currency-converter.skill \
  --bucket "$GCS_BUCKET"
```

The script:

- Uses ADC to obtain a GCS upload token.
- Writes the bundle to
  `gs://$GCS_BUCKET/{skill-name}-{version}.skill`.
- Computes the SHA-256 of the bundle on the wire and verifies it
  matches the manifest's `zip_sha256`.
- Prints the final `gs://` URI to stdout.

## 9. Register with API hub

```bash
python3 scripts/register_skill.py \
  --project "$APIHUB_PROJECT" \
  --location "$APIHUB_LOCATION" \
  --manifest /tmp/currency-converter.skill
```

The registrar:

- Reads the manifest from the zip.
- Computes the API hub `api_id` from the skill name (lower-cased,
  hyphen-separated, `<=` 63 chars).
- Creates (or updates) the API hub `Api` resource with the skill's
  metadata and the four `skill-*` attributes.
- Is idempotent — re-running for the same `name+version` is a no-op;
  re-running with a new version creates a new `ApiVersion` under the
  same `Api`.

## 10. Verify visibility

```bash
# Direct API hub query
gcloud apigee apihub apis list \
  --project="$APIHUB_PROJECT" \
  --location="$APIHUB_LOCATION" \
  --filter="attributes.skill-compatible.enumValues.values=true"
```

You should see your `currency-converter` entry in the list.

## 11. Consumer side: install the skill

The consumer-side reference implementation lives at
`skills/skill-finder/scripts/find_install.py`. It performs the
inverse flow:

1. Searches API hub for APIs where the `agentic_skill` attribute
   is `"true"`, ranks results by keyword overlap on the user's
   query, picks the top match.
2. Fetches the chosen entry's manifest (base64-encoded in the
   API hub Spec resource).
3. Re-canonicalises the manifest (excluding signature fields),
   verifies the Ed25519 signature against **every trust root**
   under `~/.<runtime>/skills/skill-finder/keys/*.pem`. Accepts
   the manifest if the `signing_key_id` matches any installed
   trust root (multi-key model — see
   [`architecture.md#multi-key-trust-roots`](architecture.md#multi-key-trust-roots)).
4. Runs an IAM pre-flight against the skill's declared
   `runtime_iam` permissions — fails fast if the caller lacks
   any of them.
5. Downloads the `.skill` zip from `gs_uri` via anonymous HTTPS
   (the bucket must be public-read; see
   [`architecture.md#trust-model`](architecture.md#trust-model)).
6. Computes SHA-256 and matches it against `zip_sha256` from
   the manifest.
7. Extracts the `.skill` into the consumer's skills directory
   (`~/.gemini/skills/{skill-name}/`,
   `~/.config/opencode/skills/{skill-name}/`, or
   `~/.gemini/antigravity/skills/{skill-name}/` per runtime).

The whole flow is emitted as a locked 16-line
[Hyrum's Law contract](https://www.hyrumslaw.com/) on stdout so
the agent runtime can surface each verification step to the user
verbatim.

To install skill-finder itself, use
`bin/install-skill-finder.sh` (see
[`provisioning.md`](provisioning.md)).

## Cleanup

To remove the demo artifacts installed by skill-finder:

```bash
./bin/demo-cleanup.sh
```

This removes locally extracted PAYLOAD skills under
`~/.config/opencode/skills/{currency-converter,weather-lookup,
apigee-policy-top10}/`. It does **not** delete anything from API
hub or your GCS bucket, and it does **not** remove skill-finder
or skill-publisher themselves — those are meant to persist
across demo runs.

To remove skill-finder + skill-publisher too:

```bash
rm -rf ~/.gemini/skills/skill-finder ~/.gemini/skills/skill-publisher
# or for opencode:
rm -rf ~/.config/opencode/skills/skill-finder ~/.config/opencode/skills/skill-publisher
```

For a full teardown (including remote resources), see
[`provisioning.md#remove-a-deployment`](provisioning.md#remove-a-deployment).
