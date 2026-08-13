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

# install-skill-publisher.sh
#
# One-line installer for the skill-publisher agentic skill from
# apigee/devrel. Same fetch model as install-skill-finder.sh
# (source from a git ref, no signed release assets, trust by
# provenance) but installs only the publisher skill.
#
# skill-publisher is the author-side companion to skill-finder:
# it orchestrates pack -> sign -> upload -> register for a source
# skill directory. Unlike skill-finder, it does NOT verify
# signatures at runtime -- the author IS the signer -- so no
# trust-root population step is needed.
#
# If you want both skills, prefer install-skill-finder.sh which
# installs both by default (this script's behaviour is a subset).
#
# Usage:
#   install-skill-publisher.sh [--runtime opencode|gemini|antigravity]
#                              [--install-root <dir>]
#                              [--ref <git-ref>]
#                              [--repo <owner/repo>]
#                              [--venv-dir <dir>]
#                              [--use-uv]
#                              [--force]
#                              [--dry-run]
#                              [-h | --help]
#
# See install-skill-finder.sh for the full trust-model rationale
# and PEP-668 explanation. This script is intentionally a thin
# wrapper around install-skill-finder.sh --skip-publisher --skip-finder
# would be prettier, but that would require adding a --skip-finder
# flag to the finder installer -- keeping them separate lets
# operators install only the piece they need without cross-flags.
#
# Exit codes:
#   0  install OK
#   1  user error
#   2  network failure
#   3  install-target write failure

set -u

DEFAULT_REF="main"
DEFAULT_REPO="apigee/devrel"
SKILLS_SUBPATH="references/apigee-skills-serving/skills"

# skill-publisher shells out to the publisher-side Python
# modules (pack_skill, sign_skill, upload_skill, register_skill)
# which need cryptography + google-auth + requests + pyyaml.
PY_DEPS=(cryptography google-auth requests pyyaml)

VENV_DIR="$HOME/.local/share/skill-finder/venv"

RUNTIME=""
INSTALL_ROOT=""
REF="$DEFAULT_REF"
REPO="$DEFAULT_REPO"
USE_UV=0
FORCE=0
DRY_RUN=0

usage() {
  cat <<'USAGE'
Usage:
  install-skill-publisher.sh [--runtime opencode|gemini|antigravity]
                             [--install-root <dir>]
                             [--ref <git-ref>]
                             [--repo <owner/repo>]
                             [--venv-dir <dir>]
                             [--use-uv]
                             [--force]
                             [--dry-run]

Flags:
  --runtime <name>    Runtime to install into. Auto-detected if omitted.
  --install-root <p>  Override the runtime's default skills root.
  --ref <ref>         Git ref (branch, tag, or commit SHA). Default: main.
  --repo <o/r>        GitHub repo. Default: apigee/devrel.
  --venv-dir <p>      Per-user venv. Default: ~/.local/share/skill-finder/venv
  --use-uv            Use `uv` instead of `python3 -m venv`.
  --force             Overwrite an existing install.
  --dry-run           Print what would happen, do nothing.
  -h, --help          Show this help.
USAGE
}

while [ "$#" -gt 0 ]; do
  case "$1" in
    --runtime)         RUNTIME="${2:-}"; shift 2 ;;
    --install-root)    INSTALL_ROOT="${2:-}"; shift 2 ;;
    --ref)             REF="${2:-}"; shift 2 ;;
    --repo)            REPO="${2:-}"; shift 2 ;;
    --venv-dir)        VENV_DIR="${2:-}"; shift 2 ;;
    --use-uv)          USE_UV=1; shift ;;
    --force)           FORCE=1; shift ;;
    --dry-run)         DRY_RUN=1; shift ;;
    -h|--help)         usage; exit 0 ;;
    *)
      echo "[install] FATAL: unknown flag: $1" >&2
      echo "[install] run --help for usage" >&2
      exit 1
      ;;
  esac
done

log() { echo "[install] $*"; }
err() { echo "[install] $*" >&2; }

# ===============================================================
# Step 1: detect runtime, resolve install root
# ===============================================================

if [ -z "$RUNTIME" ]; then
  if [ -d "$HOME/.config/opencode/skills" ]; then
    RUNTIME="opencode"
  elif [ -d "$HOME/.gemini/antigravity-browser-profile" ]; then
    RUNTIME="antigravity"
  elif [ -d "$HOME/.gemini" ]; then
    RUNTIME="gemini"
  else
    RUNTIME="opencode"
  fi
  log "auto-detected runtime: $RUNTIME (override with --runtime)"
fi

case "$RUNTIME" in
  opencode)     DEFAULT_INSTALL_ROOT="$HOME/.config/opencode/skills" ;;
  gemini)       DEFAULT_INSTALL_ROOT="$HOME/.gemini/skills" ;;
  antigravity)  DEFAULT_INSTALL_ROOT="$HOME/.gemini/antigravity/skills" ;;
  *)
    err "FATAL: --runtime must be opencode | gemini | antigravity (got: $RUNTIME)"
    exit 1
    ;;
esac

if [ -z "$INSTALL_ROOT" ]; then
  INSTALL_ROOT="$DEFAULT_INSTALL_ROOT"
fi

log "runtime:      $RUNTIME"
log "install root: $INSTALL_ROOT"
log "source repo:  $REPO"
log "source ref:   $REF"
log "venv dir:     $VENV_DIR"

# ===============================================================
# Step 2: tool preflight
# ===============================================================

for tool in curl tar python3; do
  if ! command -v "$tool" >/dev/null 2>&1; then
    err "FATAL: required tool not on PATH: $tool"
    exit 1
  fi
done
if [ "$USE_UV" -eq 1 ] && ! command -v uv >/dev/null 2>&1; then
  err "FATAL: --use-uv passed but uv is not on PATH"
  exit 1
fi

PY_VER=$(python3 -c 'import sys; print(f"{sys.version_info.major}.{sys.version_info.minor}")')
case "$PY_VER" in
  3.10|3.11|3.12|3.13|3.14|3.15|3.16|3.17|3.18|3.19)
    log "python:       ${PY_VER} (OK)"
    ;;
  *)
    err "FATAL: python3 must be >= 3.10 (found: ${PY_VER})"
    exit 1
    ;;
esac

# ===============================================================
# Step 3: create venv + install deps (idempotent; shared with
# skill-finder's venv)
# ===============================================================

log "step 3: setting up Python runtime"

if [ "$DRY_RUN" -eq 1 ]; then
  log "DRY RUN: skipping venv create + dep install"
else
  mkdir -p "$(dirname "$VENV_DIR")" || {
    err "FATAL: cannot create venv parent dir"; exit 3;
  }
  VENV_OK=0
  if [ -x "$VENV_DIR/bin/python" ] \
      && "$VENV_DIR/bin/python" -m pip --version >/dev/null 2>&1; then
    VENV_OK=1
  fi
  if [ "$VENV_OK" -eq 0 ]; then
    [ -d "$VENV_DIR" ] && rm -rf "$VENV_DIR"
    log "  creating venv at $VENV_DIR"
    if [ "$USE_UV" -eq 1 ]; then
      uv venv --quiet "$VENV_DIR" || { err "FATAL: uv venv failed"; exit 1; }
    else
      python3 -m venv "$VENV_DIR" \
        || { err "FATAL: python3 -m venv failed"; exit 1; }
    fi
  else
    log "  reusing existing venv (pip is healthy)"
  fi
  log "  installing deps: ${PY_DEPS[*]}"
  if [ "$USE_UV" -eq 1 ]; then
    uv pip install --quiet --python "$VENV_DIR/bin/python" \
       --upgrade "${PY_DEPS[@]}" \
       || { err "FATAL: uv pip install failed"; exit 1; }
  else
    "$VENV_DIR/bin/python" -m pip install --quiet --upgrade \
       "${PY_DEPS[@]}" \
       || { err "FATAL: pip install failed"; exit 1; }
  fi
fi

# ===============================================================
# Step 4: fetch source from apigee/devrel
# ===============================================================

TARBALL_TMP=$(mktemp -t skill-publisher-source-XXXXXX.tar.gz)
trap 'rm -f "$TARBALL_TMP"' EXIT

CANDIDATES=(
  "https://codeload.github.com/${REPO}/tar.gz/refs/tags/${REF}"
  "https://codeload.github.com/${REPO}/tar.gz/refs/heads/${REF}"
  "https://codeload.github.com/${REPO}/tar.gz/${REF}"
)

log "step 4: fetching source from ${REPO} at ref '${REF}'"
if [ "$DRY_RUN" -eq 1 ]; then
  log "DRY RUN: skipping source fetch"
else
  FETCHED=0
  for URL in "${CANDIDATES[@]}"; do
    log "  trying: $URL"
    if curl -fsSL -o "$TARBALL_TMP" "$URL"; then
      log "  OK: fetched $(wc -c <"$TARBALL_TMP") bytes"
      FETCHED=1
      break
    fi
  done
  if [ "$FETCHED" -eq 0 ]; then
    err "FATAL: could not fetch source from any of:"
    for URL in "${CANDIDATES[@]}"; do err "  $URL"; done
    exit 2
  fi
fi

EXTRACT_TMP=$(mktemp -d -t skill-publisher-extract-XXXXXX)
trap 'rm -f "$TARBALL_TMP"; rm -rf "$EXTRACT_TMP"' EXIT

if [ "$DRY_RUN" -eq 1 ]; then
  log "DRY RUN: skipping tarball extract"
else
  tar -xzf "$TARBALL_TMP" -C "$EXTRACT_TMP" \
    || { err "FATAL: tar extract failed"; exit 2; }
  TOPDIR=$(find "$EXTRACT_TMP" -mindepth 1 -maxdepth 1 -type d)
  SRC_SKILL_PUBLISHER="$TOPDIR/${SKILLS_SUBPATH}/skill-publisher"
  if [ ! -d "$SRC_SKILL_PUBLISHER" ]; then
    err "FATAL: tarball does not contain ${SKILLS_SUBPATH}/skill-publisher"
    err "Wrong --ref or wrong --repo?"
    exit 2
  fi
  if [ -d "$TOPDIR/references/apigee-skills-serving/scripts/common" ]; then
    SRC_COMMON_PACKAGE="$TOPDIR/references/apigee-skills-serving/scripts/common"
  else
    SRC_COMMON_PACKAGE=""
  fi
fi

# ===============================================================
# Step 5: install
# ===============================================================

TARGET_DIR="$INSTALL_ROOT/skill-publisher"
log "step 5: installing to $TARGET_DIR"

if [ -d "$TARGET_DIR" ] && [ "$FORCE" -eq 0 ]; then
  err "FATAL: $TARGET_DIR already exists (pass --force to overwrite)"
  exit 3
fi

if [ "$DRY_RUN" -eq 1 ]; then
  log "DRY RUN: would install to $TARGET_DIR"
else
  [ -d "$TARGET_DIR" ] && rm -rf "$TARGET_DIR"
  mkdir -p "$INSTALL_ROOT"
  STAGING=$(mktemp -d -p "$INSTALL_ROOT" ".staging-XXXXXX")
  cp -r "$SRC_SKILL_PUBLISHER/." "$STAGING/" \
    || { err "FATAL: cp failed"; rm -rf "$STAGING"; exit 3; }
  if [ -n "$SRC_COMMON_PACKAGE" ] && [ -d "$STAGING/scripts" ]; then
    cp -r "$SRC_COMMON_PACKAGE" "$STAGING/scripts/common" \
      || { err "FATAL: cp of common/ failed"; rm -rf "$STAGING"; exit 3; }
  fi
  mkdir -p "$STAGING/bin"
  cat >"$STAGING/bin/run-with-venv.sh" <<WRAPPER
#!/usr/bin/env bash
# Auto-generated by install-skill-publisher.sh at install time.
exec "$VENV_DIR/bin/python" "\$@"
WRAPPER
  chmod +x "$STAGING/bin/run-with-venv.sh"
  # Rewrite SKILL.md invocations (same as install-skill-finder.sh).
  if [ -f "$STAGING/SKILL.md" ]; then
    python3 - "$STAGING/SKILL.md" <<'PYREWRITE'
import sys
path = sys.argv[1]
old = open(path).read()
new = old.replace(
    'python3 ${SKILL_DIR}/scripts/',
    '${SKILL_DIR}/bin/run-with-venv.sh ${SKILL_DIR}/scripts/',
)
new = new.replace(
    'bash ${SKILL_DIR}/scripts/',
    '${SKILL_DIR}/bin/run-with-venv.sh ${SKILL_DIR}/scripts/',
)
if new != old:
    open(path, 'w').write(new)
    print(f'    rewrote {path} to invoke scripts via the venv wrapper')
PYREWRITE
  fi
  mv "$STAGING" "$TARGET_DIR" \
    || { err "FATAL: mv into place failed"; rm -rf "$STAGING"; exit 3; }
  log "  installed: $TARGET_DIR"
fi

log ""
log "skill-publisher installed to $TARGET_DIR"
log ""
log "To publish your own skills, invoke the skill in your agent"
log "with a source directory. Or run publish.sh directly:"
log "  $TARGET_DIR/scripts/publish.sh --src <skill-dir> \\"
log "    --bucket <gcs-bucket> --priv-key <ed25519.raw> \\"
log "    --project <apihub-project> --location <apihub-location>"
