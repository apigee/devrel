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

# bin/demo-cleanup.sh -- reset local state to pre-demo.
#
# Wipes the "AFTER" state of a demo run so the "BEFORE / AFTER"
# capability moment lands cleanly on the next attempt. Surgical
# by design: only touches the demo-installed artifacts
# (apigee-policy-top10 + staging dirs + breadcrumb).
#
# What this script DOES NOT touch:
#   - GCS bucket contents (.skill zips are immutable artifacts)
#   - API hub registrations (apigee-policy-top10 etc. stay
#     registered so search continues to find them)
#   - Custom attribute definitions in API hub
#   - The ed25519 trust root
#   - Your environment variables (re-source demo-setup.sh if you
#     need them refreshed)
#
# Why bash and not Python: same reasoning as
# check-demo-prerequisites.sh -- the failure mode this catches is
# "operator forgot to wipe state between demo runs", and we want
# the script to work even if a Python virtualenv is broken.
#
# Why `set -u` but not `set -e`: we want EVERY cleanup target to
# be attempted, even if one fails. A missing file or directory
# shouldn't stop us from cleaning the rest.

set -u

readonly OC_SKILLS="${HOME}/.config/opencode/skills"
readonly JS_SKILLS="${HOME}/.gemini/config/skills"
readonly DEMO_INSTALLED_SKILL="apigee-policy-top10"

readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly NC='\033[0m'

main() {
    local dry_run=0
    local verbose=0
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -n|--dry-run)
                dry_run=1
                shift
                ;;
            -v|--verbose)
                verbose=1
                shift
                ;;
            -h|--help)
                _usage
                return 0
                ;;
            *)
                echo "Unknown flag: $1" >&2
                _usage
                return 2
                ;;
        esac
    done

    if [[ "$dry_run" -eq 1 ]]; then
        echo "[cleanup] DRY RUN -- nothing will be removed."
        echo
    fi

    local removed=0
    local kept=0

    # Demo-installed skill in BOTH runtimes.
    #
    # NOTE: we deliberately use `if/then/else` instead of
    # `cmd && ((removed++)) || ((kept++))` here. The shorter
    # form is the SC2015 anti-pattern: `((removed++))` returns
    # exit status 1 when `removed` is still 0 (because the
    # post-increment evaluates the *current* value first, and
    # `((0))` is falsy), so the `||` branch fires and `kept`
    # gets incremented too. Double-counting bug, not just a
    # style nit.
    for root in "${OC_SKILLS}" "${JS_SKILLS}"; do
        if _remove_dir "${root}/${DEMO_INSTALLED_SKILL}" \
            "$dry_run" "$verbose"; then
            ((removed++))
        else
            ((kept++))
        fi
    done

    # Per-install staging dirs (UUID-suffixed; glob expands to
    # nothing if none exist, which is the common case).
    for root in "${OC_SKILLS}" "${JS_SKILLS}"; do
        local staging
        shopt -s nullglob
        for staging in "${root}"/.staging-*; do
            if _remove_dir "${staging}" \
                "$dry_run" "$verbose"; then
                ((removed++))
            else
                ((kept++))
            fi
        done
        shopt -u nullglob
    done

    # Lock file + breadcrumb. These are normal files, not dirs.
    for root in "${OC_SKILLS}" "${JS_SKILLS}"; do
        for f in "${root}/.staging.lock" "${root}/.recent-install"; do
            if _remove_file "$f" \
                "$dry_run" "$verbose"; then
                ((removed++))
            else
                ((kept++))
            fi
        done
    done

    echo
    if [[ "$dry_run" -eq 1 ]]; then
        echo "[cleanup] DRY RUN summary: would remove ${removed} item(s); ${kept} already absent."
        echo "[cleanup] Re-run without --dry-run to actually remove."
    else
        echo -e "${GREEN}[cleanup] DONE${NC} -- removed ${removed} item(s); ${kept} already absent."
        echo
        echo "[cleanup] Ready for next demo run."
        echo "[cleanup] Next: \`./bin/demo-setup.sh\`"
    fi
}

_remove_dir() {
    # Uses BOTH -e (regular exists) AND -L (symlink exists,
    # even if dangling) so we catch leftover symlinks from
    # earlier install variants. A dangling symlink reports -e
    # as false but is still cruft worth removing.
    local path="$1"
    local dry_run="$2"
    local verbose="$3"
    if [[ -e "$path" || -L "$path" ]]; then
        local kind="dir"
        [[ -L "$path" ]] && kind="symlink"
        if [[ "$dry_run" -eq 1 ]]; then
            echo -e "${YELLOW}[cleanup] would remove ${kind}:${NC}  ${path}"
        else
            if rm -rf "$path"; then
                echo -e "${GREEN}[cleanup] removed ${kind}:${NC}        ${path}"
            else
                echo -e "${RED}[cleanup] FAILED to remove:${NC}    ${path}" >&2
                return 1
            fi
        fi
        return 0
    fi
    if [[ "$verbose" -eq 1 ]]; then
        echo "[cleanup] already absent (dir): ${path}"
    fi
    return 1
}

_remove_file() {
    # Mirror of _remove_dir for non-directory targets
    # (.staging.lock + .recent-install). Uses `rm -f` rather
    # than `rm -rf` so a symlink target is untouched: we only
    # want to remove the link/file itself, not whatever it
    # points to.
    local path="$1"
    local dry_run="$2"
    local verbose="$3"
    if [[ -e "$path" || -L "$path" ]]; then
        local kind="file"
        [[ -L "$path" ]] && kind="symlink"
        if [[ "$dry_run" -eq 1 ]]; then
            echo -e "${YELLOW}[cleanup] would remove ${kind}:${NC}  ${path}"
        else
            if rm -f "$path"; then
                echo -e "${GREEN}[cleanup] removed ${kind}:${NC}        ${path}"
            else
                echo -e "${RED}[cleanup] FAILED to remove:${NC}    ${path}" >&2
                return 1
            fi
        fi
        return 0
    fi
    if [[ "$verbose" -eq 1 ]]; then
        echo "[cleanup] already absent (file): ${path}"
    fi
    return 1
}

_usage() {
    cat <<USAGE
Usage: bin/demo-cleanup.sh [-n|--dry-run] [-v|--verbose] [-h|--help]

Resets local state to pre-demo by removing the
'AFTER' state from any prior demo run. Surgical -- only
touches:

  ~/.config/opencode/skills/apigee-policy-top10/
  ~/.gemini/config/skills/apigee-policy-top10/
  ~/.config/opencode/skills/.staging-* (per-install staging dirs)
  ~/.gemini/config/skills/.staging-*
  ~/.config/opencode/skills/.staging.lock
  ~/.gemini/config/skills/.staging.lock
  ~/.config/opencode/skills/.recent-install
  ~/.gemini/config/skills/.recent-install

Does NOT touch:
  GCS bucket contents
  API hub registrations
  Custom attribute definitions
  Trust root
  Environment variables

Flags:
  -n, --dry-run   Print what would be removed; don't remove.
  -v, --verbose   Also print 'already absent' entries.
  -h, --help      Show this help.

Exit code: 0 on success (including 'nothing to do'), non-zero
if any rm failed or bad flags were passed.
USAGE
}

main "$@"
