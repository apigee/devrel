#!/usr/bin/env python3
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
"""apigee-policy-top10 enumerator.

Strategy: full bundle download per deployed proxy revision, XML
root-element parsing, frequency aggregation. The script is the
source of truth for the customer-facing ANNOUNCEMENT string --
the SKILL.md does NOT contain a verbatim copy that the agent
must remember; instead it instructs the agent to surface this
script's FIRST stdout line verbatim.

Output contract:

- The FIRST line of stdout is ``ANNOUNCEMENT`` (unprefixed,
  customer-facing). Printed BEFORE any network call.
- Operator log lines carry the ``[apigee-policy-top10] `` prefix
  and MAY change wording across versions. SKILL.md suppresses them
  from the answer EXCEPT lines containing ``FAILED``.
- The final markdown table (unprefixed) is the answer the agent
  reproduces verbatim.
"""
from __future__ import annotations

import argparse
import io
import sys
import zipfile
from collections import Counter
from pathlib import Path
from xml.etree import ElementTree as ET  # nosec B405 - trusted Apigee proxy XML

import google.auth
import google.auth.transport.requests
import requests

# Dual import: production .skill zip layout has no `scripts/`
# parent package; bare `common.*` resolves via the sys.path.insert
# below. Dev/test layout uses `scripts.common.*` via
# tests/conftest.py.
sys.path.insert(0, str(Path(__file__).resolve().parent))
try:
    from common import config  # production .skill zip layout
except ImportError:
    from scripts.common import config  # dev/test layout

APIGEE_BASE = "https://apigee.googleapis.com/v1"

# Announcement string is enforced at runtime by being printed
# directly by this script (rather than relying on the agent to
# recall it from SKILL.md). The static test in
# tests/test_apigee_top10.py imports this constant and asserts
# byte-equality against tests/fixtures/announcement.txt.
#
# Printed unprefixed (no "[apigee-policy-top10] ") because this is
# a customer-facing string, not a log line.
ANNOUNCEMENT = (
    "Querying your Apigee org now \u2014 this enumerates every deployed "
    "proxy revision and may take 20-60 seconds for orgs with 50+ "
    "proxies. No data is modified."
)


def _say(line: str) -> None:
    """Emit an operator log line (prefixed for log discipline)."""
    print(f"[apigee-policy-top10] {line}", flush=True)


def _die(line: str, code: int = 1) -> None:
    """Emit an operator log line and exit with ``code``."""
    _say(line)
    sys.exit(code)


def _auth() -> tuple[str, str]:
    """Resolve ADC token and project id."""
    creds, project = google.auth.default(
        scopes=["https://www.googleapis.com/auth/cloud-platform"]
    )
    creds.refresh(google.auth.transport.requests.Request())
    return creds.token, project


def _list_proxies(token: str, org: str) -> list[str]:
    """List API proxy short names for the org."""
    url = f"{APIGEE_BASE}/organizations/{org}/apis"
    r = requests.get(
        url,
        headers={"Authorization": f"Bearer {token}"},
        timeout=30,
    )
    if r.status_code != 200:
        _die(
            f"list proxies: FAILED \u2014 HTTP {r.status_code} "
            f"{r.reason}",
            code=2,
        )
    return [
        p["name"].rsplit("/", 1)[-1]
        for p in r.json().get("proxies", [])
    ]


def _deployed_revisions(
    token: str, org: str, api: str
) -> set[str]:
    """Return the set of revisions of ``api`` deployed to any env."""
    url = (
        f"{APIGEE_BASE}/organizations/{org}/apis/{api}/deployments"
    )
    r = requests.get(
        url,
        headers={"Authorization": f"Bearer {token}"},
        timeout=30,
    )
    if r.status_code != 200:
        return set()
    return {
        d["revision"] for d in r.json().get("deployments", [])
    }


def _download_bundle(
    token: str, org: str, api: str, rev: str
) -> bytes:
    """Download the proxy bundle zip for ``(api, rev)``."""
    url = (
        f"{APIGEE_BASE}/organizations/{org}/apis/{api}/"
        f"revisions/{rev}?format=bundle"
    )
    r = requests.get(
        url,
        headers={
            "Authorization": f"Bearer {token}",
            "Accept": "application/zip",
        },
        timeout=60,
    )
    if r.status_code != 200:
        _die(
            f"bundle download {api}@{rev}: FAILED \u2014 "
            f"HTTP {r.status_code} {r.reason}",
            code=2,
        )
    return r.content


def _policy_types_in_bundle(zip_bytes: bytes) -> list[str]:
    """Parse ``apiproxy/policies/*.xml``; return root element names."""
    types: list[str] = []
    with zipfile.ZipFile(io.BytesIO(zip_bytes)) as zf:
        for name in zf.namelist():
            if not name.startswith("apiproxy/policies/"):
                continue
            if not name.endswith(".xml"):
                continue
            try:
                tree = ET.fromstring(zf.read(name))  # nosec B314 - trusted Apigee proxy XML
                types.append(tree.tag)
            except ET.ParseError:
                _say(f"warning: unparseable policy file {name}")
    return types


def main() -> None:
    ap = argparse.ArgumentParser()
    # --org defaults to (1) $APIGEE_ORG, (2) the APIGEE_ORG line
    # in ~/.config/apigee-skills-demo/config.env (written by
    # ./bin/demo-setup.sh). The flag is no longer required=True
    # because the resolver handles the env-or-file lookup; we
    # validate emptiness AFTER the announcement so the LOCKED
    # first-line invariant still holds even when the config is
    # missing.
    ap.add_argument(
        "--org",
        default=config.get("APIGEE_ORG"),
        help=(
            "Apigee organization id (defaults to $APIGEE_ORG or "
            "the APIGEE_ORG line in "
            "~/.config/apigee-skills-demo/config.env)."
        ),
    )
    ap.add_argument("--top", type=int, default=10)
    args = ap.parse_args()

    # Announcement is the FIRST line on stdout, before any network
    # call. Locked Hyrum's Law surface -- change requires
    # manifest_schema_version bump.
    print(ANNOUNCEMENT, flush=True)

    # Now safe to enforce required-ness on --org. We emit a
    # [apigee-policy-top10] FAILED line (prefixed log line) so
    # SKILL.md surfaces it verbatim.
    if not (args.org or "").strip():
        print(
            "[apigee-policy-top10] config: FAILED -- --org is "
            "empty. Set $APIGEE_ORG OR add `APIGEE_ORG=...` to "
            "~/.config/apigee-skills-demo/config.env (run "
            "`./bin/demo-setup.sh` to write the config file).",
            flush=True,
        )
        sys.exit(2)

    token, _ = _auth()
    proxies = _list_proxies(token, args.org)
    counter: Counter[str] = Counter()
    for api in proxies:
        for rev in _deployed_revisions(token, args.org, api):
            bundle = _download_bundle(token, args.org, api, rev)
            counter.update(_policy_types_in_bundle(bundle))
    if not counter:
        _die(
            f"No deployed policies found in org {args.org}. "
            "Either no proxies are deployed, or IAM denies bundle "
            "download.",
            code=1,
        )
    print("| policy_type | count |")
    print("|:------------|------:|")
    for policy_type, count in counter.most_common(args.top):
        print(f"| {policy_type} | {count} |")


if __name__ == "__main__":
    main()
