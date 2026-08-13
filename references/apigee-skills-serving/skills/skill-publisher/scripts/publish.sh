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

# publish.sh — orchestrate pack → sign → upload → register.
#
# This is the entire runtime surface of the skill-publisher skill.
# SKILL.md invokes it once; it shells out to the four sibling Python
# modules in ${REPO_ROOT}/scripts/ in order and exits on the first
# failing step. The exit-code remap is documented in SKILL.md
# ("Exit code mapping" table). Re-running with the same inputs is
# safe (all four underlying scripts are idempotent).
#
# Usage:
#   publish.sh --src <skill-dir>
#              --bucket <gcs-bucket>
#              --priv-key <ed25519-priv-key-path>
#              --project <apihub-project>
#              --location <apihub-location>
#              [--out <zip-path>]
#              [--repo-root <path>]
#              [--bootstrap]
#
# All flags are required except --out, --repo-root, and --bootstrap.
# --out defaults to /tmp/${name}-${version}.skill derived from the
# manifest. --repo-root defaults to $(pwd). --bootstrap is a marker
# flag; see SKILL.md "Mode 2: Bootstrap" for semantics.

set -u
# NOTE: we intentionally do NOT set -e. We want to capture the
# exit code of each step explicitly, surface a structured failure
# line, and remap the exit code per the SKILL.md table.

# ---------------------------------------------------------------
# Python interpreter resolution.
# By default we use `python3` from PATH. On PEP 668 distros that
# Python cannot import the runtime deps (cryptography, requests,
# google-auth, pyyaml). The install-skill-publisher.sh installer
# sets PYTHON to the per-user venv's interpreter and exports it
# in the SKILL.md wrapper invocation. Direct callers can also
# override by exporting PYTHON before invoking publish.sh.
# ---------------------------------------------------------------
PYTHON="${PYTHON:-python3}"

# ---------------------------------------------------------------
# Argument parsing (no getopt — keep it portable to mac bash 3.2)
# ---------------------------------------------------------------
SRC=""
BUCKET=""
PRIV_KEY=""
PROJECT=""
LOCATION=""
OUT=""
REPO_ROOT="$(pwd)"
BOOTSTRAP=0

while [ $# -gt 0 ]; do
  case "$1" in
    --src)        SRC="$2"; shift 2 ;;
    --bucket)     BUCKET="$2"; shift 2 ;;
    --priv-key)   PRIV_KEY="$2"; shift 2 ;;
    --project)    PROJECT="$2"; shift 2 ;;
    --location)   LOCATION="$2"; shift 2 ;;
    --out)        OUT="$2"; shift 2 ;;
    --repo-root)  REPO_ROOT="$2"; shift 2 ;;
    --bootstrap)  BOOTSTRAP=1; shift ;;
    -h|--help)
      sed -n '1,30p' "$0"
      exit 0
      ;;
    *)
      echo "[skill-publisher] FATAL: unknown flag: $1" >&2
      exit 1
      ;;
  esac
done

log()  { echo "[skill-publisher] $*"; }
err()  { echo "[skill-publisher] $*" >&2; }

# ---------------------------------------------------------------
# Pre-flight: required flags present and non-empty
# ---------------------------------------------------------------
for var in SRC BUCKET PRIV_KEY PROJECT LOCATION; do
  if [ -z "${!var}" ]; then
    # Use tr rather than ${var,,} to stay portable to macOS
    # /bin/bash (3.2), which lacks the ,, expansion.
    flag_name="$(echo "$var" | tr '[:upper:]' '[:lower:]' | tr '_' '-')"
    err "FATAL: --${flag_name} is required (got empty)"
    exit 1
  fi
done

if [ ! -d "$SRC" ]; then
  err "FATAL: --src is not a directory: $SRC"
  exit 1
fi

MANIFEST="$SRC/manifest.yaml"
if [ ! -f "$MANIFEST" ]; then
  err "FATAL: manifest not found: $MANIFEST"
  exit 1
fi

if [ ! -f "$PRIV_KEY" ]; then
  err "FATAL: --priv-key file not found: $PRIV_KEY"
  exit 1
fi

if [ ! -d "$REPO_ROOT/scripts" ]; then
  err "FATAL: --repo-root has no scripts/ directory: $REPO_ROOT"
  err "       (the four pack/sign/upload/register modules must"
  err "        be importable as 'scripts.*' from REPO_ROOT)"
  exit 1
fi

# ---------------------------------------------------------------
# Derive name / version / default OUT from the manifest
# We use a tiny Python one-liner instead of grep so we don't have
# to YAML-parse in bash. PyYAML is already a hard runtime dep
# (see requirements.txt).
# ---------------------------------------------------------------
read_manifest_field() {
  local field="$1"
  "$PYTHON" -c "
import sys, yaml
with open('${MANIFEST}') as fh:
    m = yaml.safe_load(fh)
v = m.get('${field}')
if v is None:
    sys.exit(2)
print(v)
"
}

NAME="$(read_manifest_field name)" || {
  err "FATAL: manifest missing 'name' field: $MANIFEST"
  exit 1
}
VERSION="$(read_manifest_field version)" || {
  err "FATAL: manifest missing 'version' field: $MANIFEST"
  exit 1
}

if [ -z "$OUT" ]; then
  OUT="/tmp/${NAME}-${VERSION}.skill"
fi

OBJECT_NAME="${NAME}-${VERSION}.skill"

# ---------------------------------------------------------------
# Bootstrap mode is a marker only — the four-step pipeline below
# is identical. We log it so the operator sees their intent
# echoed, and so the run is grep-able in operator logs.
# ---------------------------------------------------------------
if [ "$BOOTSTRAP" -eq 1 ]; then
  log "BOOTSTRAP mode — publishing skill-publisher itself."
  log "  src=$SRC name=$NAME version=$VERSION"
fi

log "config: src=$SRC out=$OUT bucket=$BUCKET"
log "config: project=$PROJECT location=$LOCATION"
log "config: name=$NAME version=$VERSION object=$OBJECT_NAME"

# ---------------------------------------------------------------
# Step runner. Captures the underlying script's exit code,
# prints a structured failure line on non-zero, and remaps
# the exit code per the SKILL.md table.
# ---------------------------------------------------------------
run_step() {
  local step_num="$1"
  local step_name="$2"
  shift 2
  log "step ${step_num}/4 START: ${step_name}"
  # Run the command and capture exit. Inherit stdout/stderr so
  # the underlying script's own structured logging is preserved.
  "$@"
  local rc=$?
  if [ $rc -ne 0 ]; then
    err "step ${step_num}/4 FAILED: ${step_name} (raw exit=${rc})"
  else
    log "step ${step_num}/4 OK: ${step_name}"
  fi
  return $rc
}

# ---------------------------------------------------------------
# Step 1: pack
# Exit-code remap: pack_skill.py uses exit 3 for "packaging
# policy violation" (missing SKILL.md, wrong common/ file set).
# We remap that to 5 so it doesn't collide with sign/IAM's 3.
# ---------------------------------------------------------------
run_step 1 "pack ${SRC} → ${OUT}" \
  env PYTHONPATH="${REPO_ROOT}:${PYTHONPATH:-}" \
  "$PYTHON" -m scripts.pack_skill \
    --src "$SRC" \
    --out "$OUT" \
    --repo-root "$REPO_ROOT"
rc=$?
if [ $rc -ne 0 ]; then
  if [ $rc -eq 3 ]; then
    exit 5
  fi
  exit $rc
fi

# ---------------------------------------------------------------
# Step 2: sign (in-place — overwrites zip_sha256, signing_key_id,
# signature in $MANIFEST)
# Exit codes pass through unchanged (1=user, 2=system, 3=crypto).
# ---------------------------------------------------------------
run_step 2 "sign ${MANIFEST} (in-place)" \
  env PYTHONPATH="${REPO_ROOT}:${PYTHONPATH:-}" \
  "$PYTHON" -m scripts.sign_skill \
    --manifest "$MANIFEST" \
    --zip "$OUT" \
    --priv-key "$PRIV_KEY" \
    --in-place
rc=$?
if [ $rc -ne 0 ]; then exit $rc; fi

# ---------------------------------------------------------------
# Step 3: upload to GCS
# Exit codes pass through unchanged (1=user, 2=system, 3=IAM).
# ---------------------------------------------------------------
run_step 3 "upload ${OUT} → gs://${BUCKET}/${OBJECT_NAME}" \
  env PYTHONPATH="${REPO_ROOT}:${PYTHONPATH:-}" \
  "$PYTHON" -m scripts.upload_skill \
    --zip "$OUT" \
    --bucket "$BUCKET" \
    --object-name "$OBJECT_NAME"
rc=$?
if [ $rc -ne 0 ]; then exit $rc; fi

# ---------------------------------------------------------------
# Step 4: register in API hub
# Exit codes pass through unchanged (1=user, 2=system, 3=IAM,
# 4=taxonomy not initialised).
# ---------------------------------------------------------------
run_step 4 "register ${MANIFEST} → API hub ${PROJECT}/${LOCATION}" \
  env PYTHONPATH="${REPO_ROOT}:${PYTHONPATH:-}" \
  "$PYTHON" -m scripts.register_skill \
    --manifest "$MANIFEST" \
    --project "$PROJECT" \
    --location "$LOCATION"
rc=$?
if [ $rc -ne 0 ]; then exit $rc; fi

# ---------------------------------------------------------------
# Success summary — stable contract surface for the SKILL.md
# "Surface stdout verbatim" instruction.
# ---------------------------------------------------------------
log "PUBLISH OK"
log "  gs_uri:    gs://${BUCKET}/${OBJECT_NAME}"
log "  apihub:    projects/${PROJECT}/locations/${LOCATION}/apis/${NAME}"
log "  manifest:  ${MANIFEST} (signed in place)"
log "  zip:       ${OUT}"
exit 0
