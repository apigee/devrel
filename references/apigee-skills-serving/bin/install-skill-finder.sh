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

# install-skill-finder.sh
#
# One-line installer for the skill-finder agentic skill from
# apigee/devrel. Fetches source from a specific git ref of the
# apigee/devrel repository, creates a per-user Python venv, and
# installs into the operator's chosen agent runtime.
#
# The skill-finder skill itself is trusted by provenance -- the
# operator fetched THIS script from a known-good URL over TLS
# (raw.githubusercontent.com/apigee/devrel) and the tarball comes
# from the same origin. There are no signed release bundles and
# no sha256 pins: apigee/devrel does not publish signed release
# assets, and adding a signing infrastructure to the repo would
# require organisation-level key management that is out of scope
# for the reference implementation.
#
# Payload skills that skill-finder subsequently installs from the
# customer's own API hub ARE verified by ed25519 signature. Those
# signatures are checked against per-deployment trust roots that
# the operator populates via bin/provision.sh (bootstrap) or by
# dropping a PEM into ~/.<runtime>/skills/skill-finder/keys/.
#
# Usage:
#   install-skill-finder.sh [--runtime opencode|gemini|antigravity]
#                           [--install-root <dir>]
#                           [--ref <git-ref>]
#                           [--repo <owner/repo>]
#                           [--venv-dir <dir>]
#                           [--use-uv]
#                           [--skip-publisher]
#                           [--force]
#                           [--dry-run]
#                           [-h | --help]
#
# Required tools on PATH: bash >= 3.2, curl, tar, python3 >= 3.10,
# the `venv` stdlib module (or `uv` on PATH if --use-uv is passed).
#
# Default behaviour: installs BOTH skill-finder (catalog discovery
# client) AND skill-publisher (author-side publishing tool). Pass
# --skip-publisher to install only the discovery client.
#
# Python dependencies are installed into a per-user venv at
# ~/.local/share/skill-finder/venv (override with --venv-dir). This
# is necessary on distros that enforce PEP 668 (Debian 12+,
# Ubuntu 23.04+, recent macOS Homebrew) where system `pip install`
# is refused. The venv is also safer everywhere else: it isolates
# skill-finder's deps from other Python projects. The same venv is
# shared between skill-finder and skill-publisher.
#
# Exit codes:
#   0  install OK
#   1  user error (bad flag, missing dep, invalid runtime)
#   2  network failure
#   3  install-target write failure

set -u
# We intentionally do NOT set -e. Every step checks its own exit
# code so the error message identifies which step failed.

# ===============================================================
# Defaults
# ===============================================================

DEFAULT_REF="main"
DEFAULT_REPO="apigee/devrel"
# Path INSIDE the devrel monorepo where the skills live.
SKILLS_SUBPATH="references/apigee-skills-serving/skills"

# Python runtime deps needed by find_install.py, list_skills.py,
# and publish.sh (via sign_skill.py which is not shipped in the
# skill bundle -- but skill-publisher shells out to the four
# publisher Python modules that share the same deps).
PY_DEPS=(cryptography google-auth requests pyyaml)

VENV_DIR="$HOME/.local/share/skill-finder/venv"

# ===============================================================
# Arg parsing
# ===============================================================

RUNTIME=""
INSTALL_ROOT=""
REF="$DEFAULT_REF"
REPO="$DEFAULT_REPO"
USE_UV=0
SKIP_PUBLISHER=0
FORCE=0
DRY_RUN=0

usage() {
  cat <<'USAGE'
Usage:
  install-skill-finder.sh [--runtime opencode|gemini|antigravity]
                          [--install-root <dir>]
                          [--ref <git-ref>]
                          [--repo <owner/repo>]
                          [--venv-dir <dir>]
                          [--use-uv]
                          [--skip-publisher]
                          [--force]
                          [--dry-run]

Flags:
  --runtime <name>    Runtime to install into. Auto-detected if omitted.
                      One of: opencode | gemini | antigravity.
  --install-root <p>  Override the runtime's default skills root.
  --ref <ref>         Git ref (branch, tag, or commit SHA) to fetch
                      source from. Default: main.
  --repo <o/r>        GitHub repo to fetch from. Default: apigee/devrel.
  --venv-dir <p>      Per-user venv location. Default:
                      ~/.local/share/skill-finder/venv
  --use-uv            Use `uv` instead of `python3 -m venv`.
  --skip-publisher    Install skill-finder only (skip skill-publisher).
  --force             Overwrite an existing install without prompting.
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
    --skip-publisher)  SKIP_PUBLISHER=1; shift ;;
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
# Step 1: detect runtime and resolve install root
# ===============================================================

if [ -z "$RUNTIME" ]; then
  # Heuristic detection. Operator can always override with --runtime.
  # Detection order:
  #   1. OpenCode if its skills dir exists.
  #   2. Antigravity if its browser-profile marker exists.
  #   3. Gemini CLI: canonical user-skills root is ~/.gemini/skills.
  #   4. Fallback to opencode.
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
  opencode)
    DEFAULT_INSTALL_ROOT="$HOME/.config/opencode/skills"
    ;;
  gemini)
    # Per Gemini CLI docs (docs/cli/skills.md), user skills live at
    # ~/.gemini/skills/ -- NOT ~/.gemini/config/skills/ (that's the
    # Antigravity path).
    DEFAULT_INSTALL_ROOT="$HOME/.gemini/skills"
    ;;
  antigravity)
    # Antigravity's global install root is ~/.gemini/antigravity/skills/.
    DEFAULT_INSTALL_ROOT="$HOME/.gemini/antigravity/skills"
    ;;
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
if [ "$USE_UV" -eq 1 ]; then
  log "venv tool:    uv (forced via --use-uv)"
else
  log "venv tool:    python3 -m venv (stdlib)"
fi
if [ "$SKIP_PUBLISHER" -eq 1 ]; then
  log "skills:       skill-finder only (--skip-publisher set)"
else
  log "skills:       skill-finder + skill-publisher (default)"
fi

# ===============================================================
# Step 2: tool preflight
# ===============================================================

need_tool() {
  local tool="$1"
  if ! command -v "$tool" >/dev/null 2>&1; then
    err "FATAL: required tool not on PATH: $tool"
    exit 1
  fi
}

need_tool curl
need_tool tar
need_tool python3
if [ "$USE_UV" -eq 1 ]; then
  need_tool uv
fi

# python3 must be >= 3.10 (matches the venv skill runtimes).
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
# Step 3: create the per-user venv and install runtime deps
# ===============================================================

log "step 3: setting up Python runtime"
log "  venv dir: $VENV_DIR"

if [ "$DRY_RUN" -eq 1 ]; then
  log "DRY RUN: skipping venv create + dep install"
else
  if ! mkdir -p "$(dirname "$VENV_DIR")"; then
    err "FATAL: cannot create venv parent dir: $(dirname "$VENV_DIR")"
    exit 3
  fi

  # Reuse an existing venv only if it's healthy (has bin/python
  # AND a working pip). A half-built venv from a prior failed run
  # would cascade into 'No module named pip' errors. In that case
  # rebuild from scratch.
  VENV_OK=0
  if [ -x "$VENV_DIR/bin/python" ]; then
    if "$VENV_DIR/bin/python" -m pip --version >/dev/null 2>&1; then
      VENV_OK=1
    fi
  fi
  if [ "$VENV_OK" -eq 0 ]; then
    if [ -d "$VENV_DIR" ]; then
      log "  existing venv at $VENV_DIR is broken; removing and recreating"
      rm -rf "$VENV_DIR"
    else
      log "  creating venv at $VENV_DIR"
    fi
    if [ "$USE_UV" -eq 1 ]; then
      if ! uv venv --quiet "$VENV_DIR"; then
        err "FATAL: uv venv failed"
        exit 1
      fi
    else
      if ! python3 -m venv "$VENV_DIR"; then
        err "FATAL: python3 -m venv failed"
        exit 1
      fi
    fi
  else
    log "  reusing existing venv (pip is healthy)"
  fi

  log "  installing deps: ${PY_DEPS[*]}"
  if [ "$USE_UV" -eq 1 ]; then
    if ! uv pip install --quiet --python "$VENV_DIR/bin/python" \
         --upgrade "${PY_DEPS[@]}"; then
      err "FATAL: uv pip install failed for runtime deps"
      exit 1
    fi
  else
    if ! "$VENV_DIR/bin/python" -m pip install --quiet --upgrade \
         "${PY_DEPS[@]}"; then
      err "FATAL: pip install failed for runtime deps in venv"
      exit 1
    fi
  fi
fi

# ===============================================================
# Step 4: fetch source from apigee/devrel
# ===============================================================
#
# Strategy: fetch the entire repo as a tarball at $REF and extract
# only the two skill directories we care about. This avoids
# requiring `git` on the operator's machine (curl + tar are more
# portable) and avoids fetching the whole history.
#
# GitHub tarball URL format:
#   https://codeload.github.com/{repo}/tar.gz/refs/heads/{branch}
#   https://codeload.github.com/{repo}/tar.gz/refs/tags/{tag}
#   https://codeload.github.com/{repo}/tar.gz/{sha}
#
# We probe the tag URL first, then the branch URL, then the raw
# SHA URL. Whichever returns 200 wins.

TARBALL_TMP=$(mktemp -t skill-finder-source-XXXXXX.tar.gz)
# Clean up the tarball on exit no matter how we got here.
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
    err "Check that --repo and --ref name a real ref, and that"
    err "you have network access to codeload.github.com."
    exit 2
  fi
fi

# Extract into a staging dir. GitHub tarballs have a top-level
# directory named {repo-name}-{sha-or-ref}; we don't care about
# that name, just the subpath we want.
EXTRACT_TMP=$(mktemp -d -t skill-finder-extract-XXXXXX)
trap 'rm -f "$TARBALL_TMP"; rm -rf "$EXTRACT_TMP"' EXIT

if [ "$DRY_RUN" -eq 1 ]; then
  log "DRY RUN: skipping tarball extract"
else
  if ! tar -xzf "$TARBALL_TMP" -C "$EXTRACT_TMP"; then
    err "FATAL: could not extract tarball"
    exit 2
  fi
  # Find the extracted top-level dir (there's exactly one).
  TOPDIR=$(find "$EXTRACT_TMP" -mindepth 1 -maxdepth 1 -type d)
  if [ -z "$TOPDIR" ] || [ ! -d "$TOPDIR/${SKILLS_SUBPATH}/skill-finder" ]; then
    err "FATAL: tarball does not contain ${SKILLS_SUBPATH}/skill-finder."
    err "Wrong --ref or wrong --repo? Extracted structure:"
    ls -la "$EXTRACT_TMP" >&2
    exit 2
  fi
  SRC_SKILL_FINDER="$TOPDIR/${SKILLS_SUBPATH}/skill-finder"
  # Publisher may not exist in older refs; check separately.
  if [ -d "$TOPDIR/${SKILLS_SUBPATH}/skill-publisher" ]; then
    SRC_SKILL_PUBLISHER="$TOPDIR/${SKILLS_SUBPATH}/skill-publisher"
  else
    SRC_SKILL_PUBLISHER=""
    if [ "$SKIP_PUBLISHER" -eq 0 ]; then
      log "  warning: ${SKILLS_SUBPATH}/skill-publisher not found at ref '$REF'"
      log "  installing skill-finder only"
      SKIP_PUBLISHER=1
    fi
  fi
  # skill-publisher also needs the scripts/common/ package (same
  # code the devrel publisher pipeline uses). Locate it once so
  # install_one_skill can splice it in.
  if [ -d "$TOPDIR/references/apigee-skills-serving/scripts/common" ]; then
    SRC_COMMON_PACKAGE="$TOPDIR/references/apigee-skills-serving/scripts/common"
  else
    SRC_COMMON_PACKAGE=""
  fi
fi

# ===============================================================
# Step 5: install skills into the runtime's skills root
# ===============================================================

install_one_skill() {
  local skill_name="$1"
  local skill_src="$2"
  local target_dir="$INSTALL_ROOT/$skill_name"

  log "step 5.$skill_name: installing to $target_dir"

  # Refuse to overwrite an existing install unless --force.
  if [ -d "$target_dir" ]; then
    if [ "$FORCE" -eq 0 ]; then
      err "FATAL: $target_dir already exists (pass --force to overwrite)"
      exit 3
    fi
    log "  removing existing install at $target_dir (--force)"
    if [ "$DRY_RUN" -eq 0 ]; then
      rm -rf "$target_dir"
    fi
  fi

  if [ "$DRY_RUN" -eq 1 ]; then
    log "DRY RUN: skipping copy + venv-wrapper install"
    return
  fi

  # Atomic install: build in a staging dir, mv into place.
  # Ensure INSTALL_ROOT exists before mktemp -p (needed on fresh systems
  # where the mkdir at the "install" phase below has not yet run).
  mkdir -p "$INSTALL_ROOT"
  local staging
  staging=$(mktemp -d -p "$INSTALL_ROOT" ".staging-XXXXXX")
  if ! cp -r "$skill_src/." "$staging/"; then
    err "FATAL: cp failed from $skill_src to $staging"
    rm -rf "$staging"
    exit 3
  fi

  # Splice in scripts/common/ so `from common.X import Y` resolves
  # at runtime. skill-finder and skill-publisher both share the
  # same common package.
  if [ -n "$SRC_COMMON_PACKAGE" ] && [ -d "$staging/scripts" ]; then
    if ! cp -r "$SRC_COMMON_PACKAGE" "$staging/scripts/common"; then
      err "FATAL: cp of scripts/common failed"
      rm -rf "$staging"
      exit 3
    fi
  fi

  # Install the venv wrapper. The wrapper is a tiny shim that
  # invokes $VENV_DIR/bin/python on the script passed as argv[1].
  # SKILL.md invocations are rewritten to go through it so agents
  # that would otherwise use system python (which may lack our
  # deps) instead use our venv.
  mkdir -p "$staging/bin"
  cat >"$staging/bin/run-with-venv.sh" <<WRAPPER
#!/usr/bin/env bash
# Auto-generated by install-skill-finder.sh at install time.
# Invokes the shipped scripts through the per-user venv so the
# required Python deps (cryptography, google-auth, requests,
# pyyaml) are always available regardless of what \`python3\` the
# agent runtime would otherwise pick.
exec "$VENV_DIR/bin/python" "\$@"
WRAPPER
  chmod +x "$staging/bin/run-with-venv.sh"

  # Rewrite SKILL.md so agent invocations of ${SKILL_DIR}/scripts/*.py
  # go through bin/run-with-venv.sh. This is a targeted sed on the
  # exact substring the author's SKILL.md uses; if a future SKILL.md
  # changes the invocation shape, this substitution silently no-ops
  # (worst case: the agent uses system python, same as pre-install).
  if [ -f "$staging/SKILL.md" ]; then
    # Rewrite python3 ${SKILL_DIR}/scripts/X.py -> ${SKILL_DIR}/bin/run-with-venv.sh ${SKILL_DIR}/scripts/X.py
    if command -v python3 >/dev/null 2>&1; then
      python3 - "$staging/SKILL.md" <<'PYREWRITE'
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
else:
    print(f'    SKILL.md at {path} needs no rewrite (unrecognised invocation shape)')
PYREWRITE
    fi
  fi

  # Atomic mv into place.
  mkdir -p "$INSTALL_ROOT"
  if ! mv "$staging" "$target_dir"; then
    err "FATAL: mv into place failed: $staging -> $target_dir"
    rm -rf "$staging"
    exit 3
  fi
  log "  installed: $target_dir"
}

if [ "$DRY_RUN" -eq 1 ]; then
  log "DRY RUN: would install skill-finder to $INSTALL_ROOT/skill-finder"
  if [ "$SKIP_PUBLISHER" -eq 0 ]; then
    log "DRY RUN: would install skill-publisher to $INSTALL_ROOT/skill-publisher"
  fi
else
  install_one_skill "skill-finder" "$SRC_SKILL_FINDER"
  if [ "$SKIP_PUBLISHER" -eq 0 ] && [ -n "${SRC_SKILL_PUBLISHER:-}" ]; then
    install_one_skill "skill-publisher" "$SRC_SKILL_PUBLISHER"
  fi
fi

# ===============================================================
# Step 6: next-steps message
# ===============================================================

log ""
log "skill-finder installed successfully to $INSTALL_ROOT/skill-finder"
if [ "$SKIP_PUBLISHER" -eq 0 ] && [ -n "${SRC_SKILL_PUBLISHER:-}" ]; then
  log "skill-publisher installed to      $INSTALL_ROOT/skill-publisher"
fi
log ""
log "IMPORTANT: skill-finder cannot verify any downloaded skill"
log "manifests until at least one trust root PEM is present in"
log "$INSTALL_ROOT/skill-finder/keys/. Two ways to populate it:"
log ""
log "  1. Run bin/provision.sh from the apigee/devrel checkout"
log "     to generate a fresh ed25519 keypair, publish the initial"
log "     example skills to your API hub signed with the new key,"
log "     and drop the corresponding public key into keys/."
log ""
log "  2. Drop your org's existing public key PEM into"
log "     $INSTALL_ROOT/skill-finder/keys/<fingerprint>.pem"
log "     manually. Any file matching keys/*.pem is loaded."
log ""
log "See docs/architecture.md#trust-model for the full trust-model discussion."
