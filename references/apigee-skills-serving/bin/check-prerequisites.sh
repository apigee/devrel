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

# check-demo-prerequisites.sh -- pre-flight checker.
#
# Iterates the environment variables required by the demo and
# reports each on its own `[prereq]` line. Exits 0 if all required
# prerequisites are satisfied; exits 1 otherwise. Warnings
# (e.g. malformed APIGEE_SKILLS_MIN_KEYWORD_OVERLAP) do not block.
#
# Output is intentionally stable across invocations: same env
# yields byte-identical stdout. Stderr is unused.
#
# Why bash and not Python: the failure mode this script catches
# is operators not having ADC + env exports set up before the
# demo. We do NOT want the script itself to depend on a Python
# virtualenv that may also be missing -- bash + sh + a `gcloud`
# binary is the minimum surface.
#
# Why `set -u` but not `set -e`: we want the script to run every
# check even after a failure, so the operator sees the full
# picture in one go. Indirect expansion with `${var:-}` keeps us
# safe under `set -u`.

set -u

main() {
    local required_total=0
    local required_failed=0
    local advisory_warns=0
    local var

    # ---------------------------------------------------------- #
    # Operator-controlled REQUIRED vars:
    # APIHUB_PROJECT, APIHUB_LOCATION, APIGEE_ORG.
    # ---------------------------------------------------------- #
    for var in APIHUB_PROJECT APIHUB_LOCATION APIGEE_ORG; do
        required_total=$((required_total + 1))
        # Indirect expansion via ${!var}; ${var:-} keeps `set -u`
        # happy if the var is unset.
        local val="${!var:-}"
        if [ -z "${val}" ]; then
            echo "[prereq] FAILED -- ${var} is empty or unset. Export it before invoking the demo (see README.md)."
            required_failed=$((required_failed + 1))
        else
            echo "[prereq] OK -- ${var} is set."
        fi
    done

    # ---------------------------------------------------------- #
    # APIGEE_SKILLS_MIN_KEYWORD_OVERLAP (advisory).
    # Optional; if set, must be a positive integer.
    # ---------------------------------------------------------- #
    if [ -n "${APIGEE_SKILLS_MIN_KEYWORD_OVERLAP+x}" ]; then
        local raw="${APIGEE_SKILLS_MIN_KEYWORD_OVERLAP}"
        local is_positive_int=0
        case "${raw}" in
            ''|*[!0-9]*)
                is_positive_int=0
                ;;
            *)
                # All-digit; positive iff not "0" and the
                # numeric value is > 0. `0`, `00`, `000` all
                # collapse to 0 under arithmetic expansion.
                if [ "$((10#${raw}))" -gt 0 ] 2>/dev/null; then
                    is_positive_int=1
                fi
                ;;
        esac
        if [ "${is_positive_int}" -eq 1 ]; then
            echo "[prereq] OK -- APIGEE_SKILLS_MIN_KEYWORD_OVERLAP=\"${raw}\" (positive int)."
        else
            echo "[prereq] WARNING -- APIGEE_SKILLS_MIN_KEYWORD_OVERLAP=\"${raw}\" is not a positive integer; the consumer will use default 1."
            advisory_warns=$((advisory_warns + 1))
        fi
    else
        echo "[prereq] INFO -- APIGEE_SKILLS_MIN_KEYWORD_OVERLAP not set; the consumer will use default 1."
    fi

    # ---------------------------------------------------------- #
    # Watcher overrides (never required).
    # ---------------------------------------------------------- #
    for var in OPENCODE_EXPERIMENTAL_FILEWATCHER OPENCODE_EXPERIMENTAL_DISABLE_FILEWATCHER; do
        if [ -n "${!var:-}" ]; then
            echo "[prereq] INFO -- ${var} is set (watcher probe will honour the override)."
        else
            echo "[prereq] INFO -- ${var} is unset (default behaviour)."
        fi
    done

    # ---------------------------------------------------------- #
    # Framework-provided vars (set by OpenCode at injection time).
    # We can never verify these pre-demo; just report so the
    # operator does not panic about missing values.
    # ---------------------------------------------------------- #
    for var in ARGUMENTS SKILL_DIR OPENCODE_AGENT; do
        echo "[prereq] INFO -- ${var} is set by OpenCode at SKILL.md injection time; cannot verify pre-demo."
    done

    # ---------------------------------------------------------- #
    # ADC token retrieval. We invoke gcloud and discard output;
    # the exit code is what we care about. Tests inject a fake
    # `gcloud` shim earlier on PATH to control this.
    # ---------------------------------------------------------- #
    required_total=$((required_total + 1))
    if command -v gcloud >/dev/null 2>&1; then
        if gcloud auth application-default print-access-token >/dev/null 2>&1; then
            echo "[prereq] OK -- ADC token retrievable."
        else
            echo "[prereq] FAILED -- ADC token not retrievable. Run 'gcloud auth application-default login' to bootstrap Application Default Credentials."
            required_failed=$((required_failed + 1))
        fi
    else
        echo "[prereq] FAILED -- gcloud CLI not found on PATH. Install Cloud SDK and run 'gcloud auth application-default login'."
        required_failed=$((required_failed + 1))
    fi

    # ---------------------------------------------------------- #
    # Final summary. Exit code is purely a function of
    # required_failed; advisory warnings never block.
    # ---------------------------------------------------------- #
    if [ "${required_failed}" -eq 0 ]; then
        echo "[prereq] PASS -- ${required_total}/${required_total} required prerequisites met (${advisory_warns} advisory warning(s))."
        return 0
    else
        local met=$((required_total - required_failed))
        echo "[prereq] FAIL -- ${required_failed} required prerequisite(s) missing or invalid out of ${required_total} (${advisory_warns} advisory warning(s)); ${met} met."
        return 1
    fi
}

main "$@"
