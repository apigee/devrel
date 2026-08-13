#!/usr/bin/env bash
# Copyright 2026 Google LLC
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

# provision.sh
#
# End-to-end bootstrap for the apigee-skills-serving reference
# implementation. Given an empty GCP project (with an existing
# Apigee organisation and an API hub instance), this script:
#
#   1. Enables the GCP APIs skill-finder + skill-publisher need.
#   2. Creates a public-read GCS bucket for signed .skill bundles.
#   3. Creates the API hub custom attribute taxonomy (agentic_skill,
#      keywords, gs_uri, signing_key_id) and patches the
#      skill-spec value into system-spec-type.
#   4. Generates a fresh ed25519 signing keypair on THIS machine.
#      The private key never leaves this machine and is never
#      committed to any repo.
#   5. Packs + signs + uploads + registers the three example
#      payload skills (currency-converter, weather-lookup,
#      apigee-policy-top10) using the fresh key.
#   6. Installs the public key into an already-installed
#      skill-finder's keys/ directory so it will trust the
#      just-published catalog. Silently skips this step if
#      skill-finder is not installed yet -- the operator can
#      install skill-finder later and drop the printed key into
#      keys/ by hand.
#
# Every step is idempotent. Re-running against a partially-
# provisioned project detects what exists and no-ops those
# steps. Selective skip flags (--skip-apis, --skip-bucket, etc.)
# let you re-run one narrow step for troubleshooting.
#
# NOT provisioned by this script (out of scope):
#
#   - The API hub INSTANCE itself. Provisioning takes 40+ minutes,
#     requires several console-only decisions (CMEK vs GMEK,
#     Vertex region), and is a customer-lifecycle decision.
#     provision.sh REQUIRES an existing API hub instance and
#     fails fast with a clear message if none exists.
#
#   - The Apigee organisation. Same reasons.
#
#   - IAM bindings for the demo caller. The caller is expected to
#     have roles/owner (or the fine-grained equivalent). The script
#     tests every API call and surfaces the specific missing perm
#     if any call fails with 403.
#
# Usage:
#   bin/provision.sh --project <gcp-project> [flags]
#
# See --help for the full flag list.
#
# Exit codes:
#   0  success
#   1  user error (bad flag, missing tool, missing prereq)
#   2  network / GCP API failure
#   3  cryptographic error (key generation failed)
#   4  publish pipeline failure (pack / sign / upload / register)

set -u

# ===============================================================
# Locate self, discover devrel checkout
# ===============================================================
#
# provision.sh depends on sibling scripts in ../scripts/*.py and
# on the three example skills in ../skills/. We resolve relative
# to $0 so the script works from any cwd as long as it's run
# from a devrel checkout.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

if [ ! -d "${REPO_ROOT}/scripts" ] \
    || [ ! -d "${REPO_ROOT}/skills" ]; then
  echo "[provision] FATAL: cannot find scripts/ and skills/ next to bin/" >&2
  echo "[provision]   REPO_ROOT resolved to: ${REPO_ROOT}" >&2
  echo "[provision]   Run this from a devrel checkout of" >&2
  echo "[provision]   references/apigee-skills-serving/." >&2
  exit 1
fi

# ===============================================================
# Defaults
# ===============================================================

DEFAULT_LOCATION="us-west1"
DEFAULT_KEY_PATH="${HOME}/.config/apigee-skills-demo/signing.raw"
EXAMPLE_SKILLS=(currency-converter weather-lookup apigee-policy-top10)

# ===============================================================
# Arg parsing
# ===============================================================

PROJECT=""
LOCATION="$DEFAULT_LOCATION"
BUCKET=""
APIGEE_ORG=""
KEY_PATH="$DEFAULT_KEY_PATH"
RUNTIME=""
SKIP_APIS=0
SKIP_BUCKET=0
SKIP_TAXONOMY=0
SKIP_SKILLS=0
SKIP_KEY=0
SKIP_TRUST_ROOT_INSTALL=0
CHECK_ONLY=0
DRY_RUN=0
FORCE=0
YES=0

usage() {
  cat <<USAGE
Usage:
  bin/provision.sh --project <gcp-project> [flags]

Required:
  --project <p>              GCP project id to provision.

Optional:
  --location <l>             API hub / GCS bucket location.
                             Default: ${DEFAULT_LOCATION}
  --bucket <b>               GCS bucket name for signed .skill
                             bundles. Default:
                             <project>-skills-<location>
  --apigee-org <o>           Apigee organisation used by the
                             apigee-policy-top10 example skill.
                             Default: same as --project.
  --key-path <p>             Path to write / read the ed25519
                             private key. Default: ${DEFAULT_KEY_PATH}
  --runtime <r>              Agent runtime whose skill-finder
                             install should receive the trust root
                             PEM. One of opencode | gemini |
                             antigravity. Auto-detected if omitted.

Selective skips (idempotent re-runs):
  --skip-apis                Skip enabling GCP APIs.
  --skip-bucket              Skip GCS bucket create/config.
  --skip-taxonomy            Skip API hub attribute taxonomy.
  --skip-skills              Skip publishing the 3 example skills.
  --skip-key                 Skip key generation (reuse existing).
  --skip-trust-root-install  Skip dropping the pubkey into
                             skill-finder's keys/ (e.g. if
                             skill-finder is not installed yet).

Modes:
  --check-only               Read-only preflight. Reports what's
                             missing without making any changes.
  --dry-run                  Print what would be done, do nothing.
  --force                    Overwrite an existing signing key
                             (default: reuse existing to avoid
                             invalidating prior signatures).
  --yes                      No interactive prompts.

  -h, --help                 Show this help.
USAGE
}

while [ "$#" -gt 0 ]; do
  case "$1" in
    --project)                    PROJECT="${2:-}"; shift 2 ;;
    --location)                   LOCATION="${2:-}"; shift 2 ;;
    --bucket)                     BUCKET="${2:-}"; shift 2 ;;
    --apigee-org)                 APIGEE_ORG="${2:-}"; shift 2 ;;
    --key-path)                   KEY_PATH="${2:-}"; shift 2 ;;
    --runtime)
      RUNTIME="${2:-}"
      # Fail fast on unknown runtime values. Without this, an
      # unrecognized value falls through the case statement at
      # the "Compute SKILLS_ROOT" step, leaves SKILLS_ROOT unset,
      # and under `set -u` blows up on the KEYS_DIR assignment
      # with an opaque "unbound variable" error.
      case "$RUNTIME" in
        opencode|gemini|antigravity) ;;
        *)
          echo "[provision] FATAL: --runtime must be one of" \
               "opencode | gemini | antigravity (got: '$RUNTIME')" >&2
          exit 1
          ;;
      esac
      shift 2
      ;;
    --skip-apis)                  SKIP_APIS=1; shift ;;
    --skip-bucket)                SKIP_BUCKET=1; shift ;;
    --skip-taxonomy)              SKIP_TAXONOMY=1; shift ;;
    --skip-skills)                SKIP_SKILLS=1; shift ;;
    --skip-key)                   SKIP_KEY=1; shift ;;
    --skip-trust-root-install)    SKIP_TRUST_ROOT_INSTALL=1; shift ;;
    --check-only)                 CHECK_ONLY=1; shift ;;
    --dry-run)                    DRY_RUN=1; shift ;;
    --force)                      FORCE=1; shift ;;
    --yes)                        YES=1; shift ;;
    -h|--help)                    usage; exit 0 ;;
    *)
      echo "[provision] FATAL: unknown flag: $1" >&2
      echo "[provision] run --help for usage" >&2
      exit 1
      ;;
  esac
done

# Resolve default project from gcloud if not passed.
if [ -z "$PROJECT" ]; then
  PROJECT=$(gcloud config get-value project 2>/dev/null || echo "")
  if [ -z "$PROJECT" ]; then
    echo "[provision] FATAL: --project not given and no default in gcloud config." >&2
    echo "[provision] Either pass --project or run:" >&2
    echo "[provision]   gcloud config set project <your-project>" >&2
    exit 1
  fi
fi

# Derive defaults that depend on --project / --location.
if [ -z "$BUCKET" ]; then
  BUCKET="${PROJECT}-skills-${LOCATION}"
fi
if [ -z "$APIGEE_ORG" ]; then
  APIGEE_ORG="$PROJECT"
fi

# ===============================================================
# Colour + logging helpers
# ===============================================================

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log() { echo "[provision] $*"; }
ok() { echo -e "[provision] ${GREEN}OK${NC}: $*"; }
warn() { echo -e "[provision] ${YELLOW}WARN${NC}: $*"; }
err() { echo -e "[provision] ${RED}FAIL${NC}: $*" >&2; }

step() {
  echo
  echo "==============================================="
  echo "  $*"
  echo "==============================================="
}

confirm() {
  # Ask the user y/N. Auto-yes if --yes was passed. Returns 0 for
  # yes, 1 for no.
  local prompt="$1"
  if [ "$YES" -eq 1 ]; then
    log "  auto-yes (--yes): $prompt"
    return 0
  fi
  read -r -p "[provision] $prompt [y/N]: " ans
  case "$ans" in
    y|Y|yes|YES) return 0 ;;
    *) return 1 ;;
  esac
}

# ===============================================================
# Header
# ===============================================================

step "apigee-skills-serving provisioner"
log "project:     $PROJECT"
log "location:    $LOCATION"
log "bucket:      $BUCKET"
log "apigee org:  $APIGEE_ORG"
log "key path:    $KEY_PATH"
if [ -n "$RUNTIME" ]; then
  log "runtime:     $RUNTIME (explicit)"
fi
if [ "$CHECK_ONLY" -eq 1 ]; then
  log "MODE:        --check-only (read-only preflight)"
elif [ "$DRY_RUN" -eq 1 ]; then
  log "MODE:        --dry-run (no changes will be made)"
fi

# ===============================================================
# Step 0: preflight (tools, ADC, venv)
# ===============================================================

step "Step 0: preflight"

# Required tools.
for tool in gcloud python3 curl; do
  if ! command -v "$tool" >/dev/null 2>&1; then
    err "required tool missing: $tool"
    exit 1
  fi
done
ok "required tools present (gcloud, python3, curl)"

# ADC.
if ! gcloud auth application-default print-access-token >/dev/null 2>&1; then
  err "ADC token not available. Run:"
  err "    gcloud auth application-default login"
  exit 1
fi
ok "ADC token available"

# Confirm the caller's identity so we don't accidentally provision
# under the wrong account.
ACTIVE_ACCOUNT=$(gcloud auth list --filter=status:ACTIVE --format="value(account)" 2>/dev/null | head -1)
ok "active gcloud account: ${ACTIVE_ACCOUNT}"

# Python venv for the publisher scripts. Reuse skill-finder's
# venv if it exists (installed by install-skill-finder.sh).
VENV_DIR="${HOME}/.local/share/skill-finder/venv"
if [ -x "${VENV_DIR}/bin/python" ] \
    && "${VENV_DIR}/bin/python" -m pip --version >/dev/null 2>&1; then
  PY="${VENV_DIR}/bin/python"
  ok "reusing skill-finder venv at ${VENV_DIR}"
else
  # Bootstrap a fresh venv if skill-finder isn't installed yet.
  # We need one for pack_skill.py / sign_skill.py (they import
  # cryptography and pyyaml).
  log "  creating temporary venv at ${VENV_DIR}"
  if [ "$CHECK_ONLY" -eq 0 ] && [ "$DRY_RUN" -eq 0 ]; then
    mkdir -p "$(dirname "${VENV_DIR}")"
    python3 -m venv "${VENV_DIR}" \
      || { err "python3 -m venv failed"; exit 1; }
    "${VENV_DIR}/bin/python" -m pip install --quiet --upgrade \
      cryptography google-auth requests pyyaml \
      || { err "pip install of venv deps failed"; exit 1; }
  fi
  PY="${VENV_DIR}/bin/python"
  ok "created venv at ${VENV_DIR}"
fi

# Every python invocation needs PYTHONPATH so `from scripts.common
# import X` resolves.
export PYTHONPATH="${REPO_ROOT}"

# ===============================================================
# Step 1: enable APIs
# ===============================================================

step "Step 1: enable GCP APIs"

REQUIRED_APIS=(
  apigee.googleapis.com
  apihub.googleapis.com
  storage.googleapis.com
  iam.googleapis.com
)

if [ "$SKIP_APIS" -eq 1 ]; then
  log "  skipped (--skip-apis)"
else
  ENABLED_APIS=$(gcloud services list --enabled \
    --project="$PROJECT" --format="value(config.name)" 2>/dev/null || echo "")
  TO_ENABLE=()
  for api in "${REQUIRED_APIS[@]}"; do
    if echo "$ENABLED_APIS" | grep -qFx "$api"; then
      ok "$api already enabled"
    else
      TO_ENABLE+=("$api")
    fi
  done
  if [ "${#TO_ENABLE[@]}" -gt 0 ]; then
    if [ "$CHECK_ONLY" -eq 1 ]; then
      warn "would enable: ${TO_ENABLE[*]}"
    elif [ "$DRY_RUN" -eq 1 ]; then
      log "  DRY RUN: would enable ${TO_ENABLE[*]}"
    else
      log "  enabling: ${TO_ENABLE[*]}"
      gcloud services enable "${TO_ENABLE[@]}" --project="$PROJECT" \
        || { err "gcloud services enable failed"; exit 2; }
      ok "enabled ${TO_ENABLE[*]}"
    fi
  fi
fi

# ===============================================================
# Step 2: verify API hub instance + Apigee org exist
# ===============================================================

step "Step 2: verify prereqs (API hub instance, Apigee org)"

# API hub instance. Creating one takes 40+ min and has console-
# only choices, so we insist it exists rather than automating.
APIHUB_INSTANCE=$(gcloud apihub api-hub-instances lookup \
  --project="$PROJECT" --location="$LOCATION" \
  --format="value(apiHubInstance.name)" 2>/dev/null || echo "")
if [ -z "$APIHUB_INSTANCE" ]; then
  err "no API hub instance in ${PROJECT} / ${LOCATION}"
  err "Provision one in the Cloud Console:"
  err "  https://console.cloud.google.com/apigee/api-hub/setup?project=${PROJECT}"
  err "This takes 40+ min. Re-run provision.sh when it's ACTIVE."
  exit 1
fi
ok "API hub instance: ${APIHUB_INSTANCE}"

# Apigee organisation.
TOKEN=$(gcloud auth application-default print-access-token)
ORG_JSON=$(curl -sf -H "Authorization: Bearer $TOKEN" \
  "https://apigee.googleapis.com/v1/organizations/${APIGEE_ORG}" 2>/dev/null || echo "")
if [ -z "$ORG_JSON" ]; then
  err "Apigee organisation '${APIGEE_ORG}' not accessible."
  err "Either --apigee-org is wrong, or the caller lacks"
  err "apigee.organizations.get permission on it."
  err "The apigee-policy-top10 skill needs this org; other"
  err "skills do not. Pass --skip-skills to skip publishing"
  err "if you only want the infrastructure provisioned."
  exit 1
fi
ok "Apigee organisation: ${APIGEE_ORG}"

# ===============================================================
# Step 3: create GCS bucket
# ===============================================================

step "Step 3: GCS bucket for signed skill bundles"

if [ "$SKIP_BUCKET" -eq 1 ]; then
  log "  skipped (--skip-bucket)"
else
  BUCKET_URI="gs://${BUCKET}"
  if gcloud storage buckets describe "$BUCKET_URI" \
       --project="$PROJECT" >/dev/null 2>&1; then
    ok "bucket ${BUCKET_URI} exists"
  else
    if [ "$CHECK_ONLY" -eq 1 ]; then
      warn "would create bucket ${BUCKET_URI}"
    elif [ "$DRY_RUN" -eq 1 ]; then
      log "  DRY RUN: would create ${BUCKET_URI}"
    else
      log "  creating ${BUCKET_URI}"
      gcloud storage buckets create "$BUCKET_URI" \
        --project="$PROJECT" --location="$LOCATION" \
        --uniform-bucket-level-access \
        --no-public-access-prevention 2>&1 | tail -3
      ok "created ${BUCKET_URI}"
    fi
  fi

  # Grant allUsers reader. This is a demo-only choice --
  # skill-finder does anonymous HTTPS GET for the .skill zips,
  # so the bucket must be public-read. In production you'd
  # bind roles/storage.objectViewer to a specific service
  # account (or use signed URLs) instead.
  if [ "$CHECK_ONLY" -eq 0 ] && [ "$DRY_RUN" -eq 0 ]; then
    log "  granting allUsers:objectViewer (needed for skill-finder"
    log "  anonymous downloads -- demo choice)"
    gcloud storage buckets add-iam-policy-binding "$BUCKET_URI" \
      --member=allUsers --role=roles/storage.objectViewer \
      >/dev/null 2>&1 || warn "allUsers binding may already exist"
    ok "public-read enabled on ${BUCKET_URI}"
  fi
fi

# ===============================================================
# Step 4: API hub attribute taxonomy
# ===============================================================

step "Step 4: API hub attribute taxonomy"

if [ "$SKIP_TAXONOMY" -eq 1 ]; then
  log "  skipped (--skip-taxonomy)"
else
  # Detect existing state before deciding whether to create.
  # Query the four user-defined attrs and system-spec-type.
  ATTRS_URL="https://apihub.googleapis.com/v1/projects/${PROJECT}/locations/${LOCATION}/attributes"
  EXPECTED_ATTRS=(agentic_skill keywords gs_uri signing_key_id)
  MISSING_ATTRS=()
  for a in "${EXPECTED_ATTRS[@]}"; do
    if ! curl -sf -H "Authorization: Bearer $TOKEN" "${ATTRS_URL}/${a}" \
         >/dev/null 2>&1; then
      MISSING_ATTRS+=("$a")
    fi
  done
  # Check that system-spec-type includes skill-spec.
  SST_JSON=$(curl -sf -H "Authorization: Bearer $TOKEN" \
    "${ATTRS_URL}/system-spec-type" 2>/dev/null || echo "")
  if echo "$SST_JSON" | grep -q '"id": "skill-spec"'; then
    HAS_SKILL_SPEC=1
  else
    HAS_SKILL_SPEC=0
  fi

  if [ "${#MISSING_ATTRS[@]}" -eq 0 ] && [ "$HAS_SKILL_SPEC" -eq 1 ]; then
    ok "user-defined attributes: all 4 present"
    ok "system-spec-type includes skill-spec"
  elif [ "$CHECK_ONLY" -eq 1 ]; then
    if [ "${#MISSING_ATTRS[@]}" -gt 0 ]; then
      warn "would create missing user-defined attrs: ${MISSING_ATTRS[*]}"
    fi
    if [ "$HAS_SKILL_SPEC" -eq 0 ]; then
      warn "would add 'skill-spec' to system-spec-type enum"
    fi
  elif [ "$DRY_RUN" -eq 1 ]; then
    log "  DRY RUN: would create ${MISSING_ATTRS[*]}, patch system-spec-type"
  else
    log "  creating user-defined attributes (idempotent)"
    "$PY" -m scripts.update_taxonomy \
      --project "$PROJECT" --location "$LOCATION" \
      || { err "update_taxonomy.py failed"; exit 2; }
    ok "user-defined attributes created/verified"

    log "  patching skill-spec into system-spec-type enum"
    # Idempotent: PATCHing with the same allowed_values list is
    # a no-op if the value already exists.
    curl -sf -X PATCH \
      -H "Authorization: Bearer $TOKEN" \
      -H "Content-Type: application/json" \
      "https://apihub.googleapis.com/v1/projects/${PROJECT}/locations/${LOCATION}/attributes/system-spec-type?updateMask=allowed_values" \
      -d '{
        "allowedValues": [
          {"id":"openapi","displayName":"OpenAPI Spec","description":"OpenAPI Spec","immutable":true},
          {"id":"proto","displayName":"Proto","description":"Proto","immutable":true},
          {"id":"wsdl","displayName":"WSDL","description":"WSDL","immutable":true},
          {"id":"mcp-spec","displayName":"MCP Spec","description":"MCP Spec","immutable":true},
          {"id":"skill-spec","displayName":"Skill Spec","description":"Signed agent skill manifest (apigee-skills-serving reference)"}
        ]
      }' >/dev/null \
      || { err "system-spec-type PATCH failed"; exit 2; }
    ok "skill-spec added to system-spec-type"
  fi
fi

# ===============================================================
# Step 5: generate signing keypair
# ===============================================================

step "Step 5: ed25519 signing keypair"

if [ "$SKIP_KEY" -eq 1 ]; then
  log "  skipped (--skip-key); reusing existing key at ${KEY_PATH}"
  if [ ! -f "$KEY_PATH" ]; then
    err "--skip-key passed but no key found at ${KEY_PATH}"
    exit 1
  fi
elif [ -f "$KEY_PATH" ] && [ "$FORCE" -eq 0 ]; then
  ok "existing key at ${KEY_PATH} (reusing; pass --force to regenerate)"
else
  if [ "$CHECK_ONLY" -eq 1 ]; then
    warn "would generate keypair at ${KEY_PATH}"
  elif [ "$DRY_RUN" -eq 1 ]; then
    log "  DRY RUN: would generate keypair"
  else
    if [ -f "$KEY_PATH" ] && [ "$FORCE" -eq 1 ]; then
      warn "--force: overwriting existing key at ${KEY_PATH}"
      warn "  Prior signatures made with the old key will no longer"
      warn "  verify against the new one -- re-publish all skills"
      warn "  after this step."
      if ! confirm "Proceed with key regeneration?"; then
        err "aborted at key regeneration"
        exit 1
      fi
    fi
    log "  generating fresh ed25519 keypair at ${KEY_PATH}"
    mkdir -p "$(dirname "$KEY_PATH")"
    "$PY" <<PYEOF
import hashlib, sys
from cryptography.hazmat.primitives.asymmetric.ed25519 import Ed25519PrivateKey
from cryptography.hazmat.primitives import serialization

priv = Ed25519PrivateKey.generate()
raw = priv.private_bytes(
    encoding=serialization.Encoding.Raw,
    format=serialization.PrivateFormat.Raw,
    encryption_algorithm=serialization.NoEncryption(),
)
with open("${KEY_PATH}", "wb") as f:
    f.write(raw)

pub_raw = priv.public_key().public_bytes(
    encoding=serialization.Encoding.Raw,
    format=serialization.PublicFormat.Raw,
)
fp = "sha256:" + hashlib.sha256(pub_raw).hexdigest()
print(fp)
PYEOF
    if [ ! -s "$KEY_PATH" ]; then
      err "key generation failed (empty key file at ${KEY_PATH})"
      exit 3
    fi
    chmod 600 "$KEY_PATH"
    ok "generated keypair (private: ${KEY_PATH}, mode 0600)"
  fi
fi

# Compute fingerprint (needed for the trust-root-install step
# regardless of whether we generated a new key or reused one).
if [ -f "$KEY_PATH" ]; then
  FINGERPRINT=$("$PY" <<PYEOF
import hashlib
from cryptography.hazmat.primitives.asymmetric.ed25519 import Ed25519PrivateKey
from cryptography.hazmat.primitives import serialization
priv = Ed25519PrivateKey.from_private_bytes(open("${KEY_PATH}", "rb").read())
pub_raw = priv.public_key().public_bytes(
    encoding=serialization.Encoding.Raw,
    format=serialization.PublicFormat.Raw,
)
print("sha256:" + hashlib.sha256(pub_raw).hexdigest())
PYEOF
)
  ok "fingerprint: ${FINGERPRINT}"
fi

# ===============================================================
# Step 6: publish the 3 example skills
# ===============================================================

step "Step 6: publish example skills"

if [ "$SKIP_SKILLS" -eq 1 ]; then
  log "  skipped (--skip-skills)"
else
  # Detect which skills are already published so a re-run
  # skips already-registered ones. We check the API hub 'apis'
  # collection for a matching displayName. Publishing is
  # idempotent anyway (register_skill.py handles the update
  # path) but skipping avoids ~5s of pack+upload+sign work
  # per already-published skill.
  APIS_URL="https://apihub.googleapis.com/v1/projects/${PROJECT}/locations/${LOCATION}/apis"
  EXISTING_APIS=$(curl -sf -H "Authorization: Bearer $TOKEN" \
    "${APIS_URL}?pageSize=100" 2>/dev/null \
    | "$PY" -c "
import json, sys
try:
    d = json.load(sys.stdin)
except Exception:
    sys.exit(0)
for a in d.get('apis', []):
    print(a.get('displayName', ''))
" 2>/dev/null || echo "")
  MISSING_SKILLS=()
  PRESENT_SKILLS=()
  for skill in "${EXAMPLE_SKILLS[@]}"; do
    if echo "$EXISTING_APIS" | grep -qFx "$skill"; then
      PRESENT_SKILLS+=("$skill")
    else
      MISSING_SKILLS+=("$skill")
    fi
  done

  if [ "${#PRESENT_SKILLS[@]}" -gt 0 ]; then
    ok "already published: ${PRESENT_SKILLS[*]}"
  fi
  if [ "${#MISSING_SKILLS[@]}" -eq 0 ]; then
    ok "all example skills already published"
    # Skip the entire publish loop.
    SKIP_SKILLS=1
  fi
fi

if [ "$SKIP_SKILLS" -eq 1 ]; then
  :  # already handled above
elif [ "$CHECK_ONLY" -eq 1 ]; then
  warn "would publish: ${MISSING_SKILLS[*]}"
elif [ "$DRY_RUN" -eq 1 ]; then
  log "  DRY RUN: would publish ${MISSING_SKILLS[*]}"
else
  # Working dir for patched manifests + signed manifests. Kept
  # outside the source tree so the source tree stays clean.
  WORKDIR="${HOME}/.local/share/apigee-skills-serving/publish-workdir"
  mkdir -p "$WORKDIR"

  for skill in "${MISSING_SKILLS[@]}"; do
    log "  --- publishing $skill ---"
    SRC_MANIFEST="${REPO_ROOT}/skills/${skill}/manifest.yaml"
    WORK_MANIFEST="${WORKDIR}/${skill}.manifest.yaml"
    SIGNED_MANIFEST="${WORKDIR}/${skill}.signed.yaml"
    SKILL_ZIP="/tmp/${skill}.skill"

    # Patch gs_uri (source manifest has no gs_uri; publisher
    # scripts require it to be present before signing).
    cp "$SRC_MANIFEST" "$WORK_MANIFEST"
    "$PY" -c "
import yaml
p = '${WORK_MANIFEST}'
m = yaml.safe_load(open(p))
m['gs_uri'] = 'gs://${BUCKET}/${skill}.skill'
open(p, 'w').write(yaml.safe_dump(m, sort_keys=True))
"
    # Pack.
    "$PY" -m scripts.pack_skill \
      --src "${REPO_ROOT}/skills/${skill}" \
      --out "$SKILL_ZIP" \
      || { err "pack failed for $skill"; exit 4; }
    # Upload.
    "$PY" -m scripts.upload_skill \
      --zip "$SKILL_ZIP" --bucket "$BUCKET" \
      || { err "upload failed for $skill"; exit 4; }
    # Sign.
    "$PY" -m scripts.sign_skill \
      --manifest "$WORK_MANIFEST" \
      --zip "$SKILL_ZIP" \
      --priv-key "$KEY_PATH" \
      --out "$SIGNED_MANIFEST" \
      || { err "sign failed for $skill"; exit 4; }
    # Register.
    "$PY" -m scripts.register_skill \
      --manifest "$SIGNED_MANIFEST" \
      --project "$PROJECT" --location "$LOCATION" \
      || { err "register failed for $skill"; exit 4; }
    ok "$skill published"
  done
fi

# ===============================================================
# Step 7: install trust root into skill-finder's keys/
# ===============================================================

step "Step 7: install trust root into skill-finder"

if [ "$SKIP_TRUST_ROOT_INSTALL" -eq 1 ]; then
  log "  skipped (--skip-trust-root-install)"
elif [ "$CHECK_ONLY" -eq 1 ] || [ "$DRY_RUN" -eq 1 ]; then
  log "  would install ${FINGERPRINT:-<unknown>}.pem into skill-finder/keys/"
else
  # Auto-detect runtime if not passed.
  if [ -z "$RUNTIME" ]; then
    if [ -d "$HOME/.gemini/skills/skill-finder" ]; then
      RUNTIME="gemini"
    elif [ -d "$HOME/.gemini/antigravity/skills/skill-finder" ]; then
      RUNTIME="antigravity"
    elif [ -d "$HOME/.config/opencode/skills/skill-finder" ]; then
      RUNTIME="opencode"
    else
      warn "skill-finder is not installed in any known runtime."
      warn "The example skills ARE published, but skill-finder"
      warn "won't trust them until you install skill-finder and"
      warn "drop the following PEM into keys/:"
      warn ""
      "$PY" <<PYEOF
from cryptography.hazmat.primitives.asymmetric.ed25519 import Ed25519PrivateKey
from cryptography.hazmat.primitives import serialization
priv = Ed25519PrivateKey.from_private_bytes(open("${KEY_PATH}", "rb").read())
pem = priv.public_key().public_bytes(
    encoding=serialization.Encoding.PEM,
    format=serialization.PublicFormat.SubjectPublicKeyInfo,
)
print(pem.decode())
PYEOF
      warn "Save the above as: <fingerprint-without-sha256->.pem"
      warn "  fingerprint: ${FINGERPRINT}"
      RUNTIME=""
    fi
  fi

  if [ -n "$RUNTIME" ]; then
    case "$RUNTIME" in
      opencode)     SKILLS_ROOT="$HOME/.config/opencode/skills" ;;
      gemini)       SKILLS_ROOT="$HOME/.gemini/skills" ;;
      antigravity)  SKILLS_ROOT="$HOME/.gemini/antigravity/skills" ;;
      # Defense in depth: the arg-parse block above rejects
      # unknown --runtime values, and auto-detect can only set
      # RUNTIME to a known value or empty. Anything else here
      # means an invariant was broken upstream.
      *)
        err "internal error: unknown RUNTIME '$RUNTIME' reached SKILLS_ROOT"
        exit 1
        ;;
    esac
    KEYS_DIR="${SKILLS_ROOT}/skill-finder/keys"
    if [ ! -d "$KEYS_DIR" ]; then
      warn "skill-finder is not installed at ${SKILLS_ROOT}/skill-finder"
      warn "Install it first with:"
      warn "  bash bin/install-skill-finder.sh --runtime ${RUNTIME}"
    else
      # <fingerprint-without-sha256:->.pem
      FP_STEM="${FINGERPRINT#sha256:}"
      PEM_PATH="${KEYS_DIR}/${FP_STEM}.pem"
      if [ -f "$PEM_PATH" ]; then
        ok "trust root already installed: ${PEM_PATH}"
      elif [ "$CHECK_ONLY" -eq 1 ] || [ "$DRY_RUN" -eq 1 ]; then
        log "  would install trust root to: ${PEM_PATH}"
      else
        "$PY" <<PYEOF
from cryptography.hazmat.primitives.asymmetric.ed25519 import Ed25519PrivateKey
from cryptography.hazmat.primitives import serialization
priv = Ed25519PrivateKey.from_private_bytes(open("${KEY_PATH}", "rb").read())
pem = priv.public_key().public_bytes(
    encoding=serialization.Encoding.PEM,
    format=serialization.PublicFormat.SubjectPublicKeyInfo,
)
open("${PEM_PATH}", "wb").write(pem)
PYEOF
        ok "installed trust root: ${PEM_PATH}"
      fi
    fi
  fi
fi

# ===============================================================
# Ready banner
# ===============================================================

echo
echo "==============================================="
echo -e "  ${GREEN}READY${NC} -- apigee-skills-serving provisioned"
echo "==============================================="
log ""
log "Project:       ${PROJECT}"
log "Location:      ${LOCATION}"
log "Bucket:        gs://${BUCKET}"
log "Apigee org:    ${APIGEE_ORG}"
log "Trust root:    ${FINGERPRINT:-<unknown>}"
if [ -n "${RUNTIME:-}" ]; then
  log "Runtime:       ${RUNTIME}"
fi
log ""
log "Next steps:"
log "  1. If skill-finder is not yet installed on this machine:"
log "       bash bin/install-skill-finder.sh --runtime <r>"
log "     Then re-run: bash bin/provision.sh --project ${PROJECT} \\"
log "       --skip-apis --skip-bucket --skip-taxonomy --skip-skills"
log "     to install just the trust root."
log ""
log "  2. Launch your agent runtime and ask a question that matches"
log "     one of the published skill keywords (e.g. 'currency',"
log "     'weather', 'apigee policies'). skill-finder will find the"
log "     matching skill in API hub, verify its signature against"
log "     the trust root we just installed, and install it into"
log "     the runtime skills dir."
log ""
log "  3. Re-run this script any time to reconcile drift. All"
log "     steps are idempotent. Use --skip-* flags to narrow the"
log "     re-run to specific steps."
