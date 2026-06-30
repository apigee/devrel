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

# bin/demo-setup.sh -- one-command demo readiness check.
#
# Usage:
#
#     ./bin/demo-setup.sh             # verify + write config file
#     ./bin/demo-setup.sh --help      # full docs
#
# What the script does (in order):
#   1. Verifies ADC + runs bin/check-prerequisites.sh.
#   2. Exports the demo env vars in THIS script's process and
#      writes a persistent config file consumers can read when
#      env vars are not set in their own process.
#   3. Prints "READY" and exits. Launch your preferred agent
#      runtime (Gemini CLI, Claude Code, or another agent) in
#      a shell that has the env vars exported, or have the
#      agent read them from the persistent config file.
#
# Why the env vars don't need to be in every shell:
#   - The persistent config file written by this script is read
#     by scripts/common/config.py whenever the corresponding env
#     var is unset in the calling process. Any agent that runs
#     these scripts as subprocesses will resolve the values from
#     the file even if its own environment is empty.
#   - Operators who want to run the scripts manually in a fresh
#     shell can use `./bin/demo-setup.sh --print-env` to get a
#     copy-pasteable export block.

set -u

# ---- Locate ourselves regardless of cwd ------------------

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

# ---- Demo-specific env values ----------------------------
# If you re-target the demo at a different GCP project, edit
# these four lines. Everything else flows from here.

readonly DEMO_APIHUB_PROJECT="apigee-product-demo"
readonly DEMO_APIHUB_LOCATION="us-west1"
readonly DEMO_APIGEE_ORG="apigee-product-demo"
readonly DEMO_KEYWORD_OVERLAP="1"

# ---- Color codes -----------------------------------------

readonly GREEN='\033[0;32m'
readonly RED='\033[0;31m'
readonly NC='\033[0m'

# ---- Helpers ---------------------------------------------

_check() {
    local label="$1"
    local ok="$2"
    local detail="${3:-}"
    if [ "$ok" -eq 0 ]; then
        printf "  ${GREEN}\u2713${NC} %s" "$label"
    else
        printf "  ${RED}\u2717${NC} %s" "$label"
    fi
    [ -n "$detail" ] && printf " (%s)" "$detail"
    printf "\n"
}

_export_demo_env() {
    export APIHUB_PROJECT="${DEMO_APIHUB_PROJECT}"
    export APIHUB_LOCATION="${DEMO_APIHUB_LOCATION}"
    export APIGEE_ORG="${DEMO_APIGEE_ORG}"
    export APIGEE_SKILLS_MIN_KEYWORD_OVERLAP="${DEMO_KEYWORD_OVERLAP}"
}

# Persistent config file read by scripts/common/config.py when
# the env vars aren't set in the process. This breaks the
# coupling between "operator launched the agent before sourcing
# the demo env" and "agent subprocesses see no demo config":
# any process can read the config regardless of when its parent
# was launched.
_write_demo_config_file() {
    local config_dir="${HOME}/.config/apigee-skills-demo"
    local config_file="${config_dir}/config.env"
    mkdir -p "${config_dir}"
    cat >"${config_file}" <<EOF
# apigee-skills-demo persistent config (written by
# bin/demo-setup.sh). Read by scripts/common/config.py when
# the corresponding env var is unset in a process.
#
# Format: one KEY=value per line. \`#\` comments OK. \`export\`
# prefix is tolerated so you can source this file from a shell.
#
# Edit DEMO_* constants in bin/demo-setup.sh, then re-run
# \`./bin/demo-setup.sh\` to regenerate this file.

APIHUB_PROJECT=${DEMO_APIHUB_PROJECT}
APIHUB_LOCATION=${DEMO_APIHUB_LOCATION}
APIGEE_ORG=${DEMO_APIGEE_ORG}
APIGEE_SKILLS_MIN_KEYWORD_OVERLAP=${DEMO_KEYWORD_OVERLAP}
EOF
    chmod 0644 "${config_file}"
    # Use printf for terminal color escapes (echo "${GREEN}..."
    # would print the literal backslash sequence).
    printf "  ${GREEN}wrote${NC} %s\n" "${config_file}"
}

_print_env() {
    cat <<EOF
# Paste these in any shell where you want to run the demo
# scripts (top10.py, register_skill.py, etc.) manually. They
# are also written to ~/.config/apigee-skills-demo/config.env
# so scripts/common/config.py can pick them up automatically.

export APIHUB_PROJECT="${DEMO_APIHUB_PROJECT}"
export APIHUB_LOCATION="${DEMO_APIHUB_LOCATION}"
export APIGEE_ORG="${DEMO_APIGEE_ORG}"
export APIGEE_SKILLS_MIN_KEYWORD_OVERLAP="${DEMO_KEYWORD_OVERLAP}"
EOF
}

_usage() {
    cat <<USAGE
Usage: ./bin/demo-setup.sh [flags]

Verifies demo readiness, exports the demo env vars in THIS
script's process, and writes a persistent config file so
subsequent processes can read the values even when launched
in a shell that did not source the env.

Flags:
  --skip-preflight         Skip bin/check-prerequisites.sh
                           (env vars + ADC are exported and
                           verified automatically anyway).
  --print-env              Print copy-pasteable export
                           statements for the demo env vars,
                           then exit. Useful for shells that
                           want to run scripts manually.
  -h, --help               Show this help.

Demo environment exported into this script's process AND
written to ~/.config/apigee-skills-demo/config.env:
  APIHUB_PROJECT=${DEMO_APIHUB_PROJECT}
  APIHUB_LOCATION=${DEMO_APIHUB_LOCATION}
  APIGEE_ORG=${DEMO_APIGEE_ORG}
  APIGEE_SKILLS_MIN_KEYWORD_OVERLAP=${DEMO_KEYWORD_OVERLAP}

Change the targets by editing the DEMO_* constants near the
top of this script.

Reset state between demo runs:
  bash bin/demo-cleanup.sh
USAGE
}

# ---- Argument handling -----------------------------------

skip_preflight=0

while [ $# -gt 0 ]; do
    case "$1" in
        --skip-preflight) skip_preflight=1; shift ;;
        --print-env)
            _print_env
            exit 0
            ;;
        -h|--help) _usage; exit 0 ;;
        *)
            echo "Unknown flag: $1" >&2
            echo "Run: ./bin/demo-setup.sh --help" >&2
            exit 2
            ;;
    esac
done

# ---- Step 1: prereq check + ADC --------------------------

echo "[setup] Verifying Application Default Credentials..."
if gcloud auth application-default print-access-token \
        >/dev/null 2>&1; then
    _check "ADC token retrievable" 0
else
    _check "ADC token retrievable" 1 \
        "run: gcloud auth application-default login"
    echo
    echo "Fix the above, then re-run: ./bin/demo-setup.sh"
    exit 1
fi

if [ "$skip_preflight" -eq 0 ]; then
    echo
    echo "[setup] Running pre-flight checker..."
    if bash "${REPO_ROOT}/bin/check-prerequisites.sh"; then
        _check "All required prerequisites met" 0
    else
        _check "Pre-flight failed" 1 \
            "see [prereq] lines above"
        echo
        echo "Fix the failing prereqs, then re-run:"
        echo "    ./bin/demo-setup.sh"
        exit 1
    fi
else
    echo "[setup] --skip-preflight given; pre-flight check skipped."
fi

# ---- Step 2: env export + persistent config --------------

_export_demo_env

echo
echo "[setup] Demo environment (set in THIS script's process):"
echo "  APIHUB_PROJECT=${APIHUB_PROJECT}"
echo "  APIHUB_LOCATION=${APIHUB_LOCATION}"
echo "  APIGEE_ORG=${APIGEE_ORG}"
echo "  APIGEE_SKILLS_MIN_KEYWORD_OVERLAP=${APIGEE_SKILLS_MIN_KEYWORD_OVERLAP}"
echo
echo "[setup] Writing persistent config file (read by"
echo "[setup] scripts/common/config.py when env vars aren't set"
echo "[setup] in the calling process)..."
_write_demo_config_file
echo

# ---- Step 3: ready --------------------------------------

echo -e "${GREEN}[setup] READY.${NC}"
echo "[setup] Launch your preferred agent runtime (Gemini CLI,"
echo "[setup] Claude Code, or other) in a shell that has the env"
echo "[setup] vars exported, or rely on the persistent config"
echo "[setup] file written above."
echo
echo "[setup] To export the env into an existing shell, run:"
echo "        eval \"\$(./bin/demo-setup.sh --print-env)\""
echo
echo "[setup] Publish-and-install guide: ${REPO_ROOT}/docs/publish-and-install.md"
echo "[setup] Reset state with: bash bin/demo-cleanup.sh"
