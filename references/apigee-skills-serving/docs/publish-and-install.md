# Publish and install walkthrough

This walkthrough takes you from a fresh checkout to a signed,
registered skill that an agent runtime can install from API hub. The
examples use the bundled `skills/currency-converter` as the skill being
published.

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

A consumer (an agent runtime, or a developer running `pip install`
analog for skills) performs the inverse flow:

1. Searches API hub by keyword overlap on the skill description, or
   by attribute (e.g., "every skill with `skill-runtime-iam` containing
   `apigee.proxies.create`").
2. Fetches the chosen entry's manifest from API hub.
3. Re-canonicalises the manifest (excluding signature fields),
   verifies the Ed25519 signature against the publisher's known public
   key.
4. Downloads the `.skill` zip from `gs_uri`.
5. Computes SHA-256 and matches it against `zip_sha256` from the
   manifest.
6. Extracts the `.skill` into the consumer's skills directory
   (e.g., `~/.config/opencode/skills/{skill-name}/`).

The consumer-side `find_install.py` reference implementation is **not**
included in this PR; the contract it consumes is fully documented above
and exercised by the test suite. See
`tests/test_register_fetch_integration.py` for a stateful in-process
example.

## Cleanup

To remove the demo artifacts:

```bash
./bin/demo-cleanup.sh
```

This removes locally extracted skills under
`~/.config/opencode/skills/{currency-converter,weather-lookup,
apigee-policy-top10}/`. It does **not** delete anything from API hub
or your GCS bucket — those are remote and the cleanup intentionally
stays local to avoid surprising side-effects in shared projects.
