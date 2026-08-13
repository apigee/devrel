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

"""list_skills.py — browse the API hub catalog of agentic skills.

Sibling of `find_install.py`. Where find_install.py SEARCHES for one
matching skill and INSTALLS it, list_skills.py ENUMERATES every
skill in the catalog so the agent can show the user "here is what
is available." No download, no install, no signature verify, no
side effects beyond stdout.

Contract:
- Prints a markdown table to stdout: `name | version | keywords |
  description`. The first row is a header.
- Emits `[skill-finder]` operator log lines to stdout for
  diagnostics (search URL, pagination state).
- On the last line, if API hub returned a `nextPageToken`, emits
  `next-page-token: <token>` (no `[skill-finder]` prefix because
  it is a customer-facing contract value the agent may need to
  pass back as `--page-token`).
- Exit 0 on success, 2 on bad config / arg validation, 3 on
  HTTP / auth / response-parse failure.

Dual-import preamble: production .skill zip layout is
<install-dir>/scripts/{list_skills.py, common/*.py} where bare
`from common.X` resolves via the sys.path.insert below. Dev/test
layout uses `from scripts.common.X` via tests/conftest.py.
"""
from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path
from urllib.parse import quote_plus

# =============================================================
# Venv preflight. See find_install.py for the full rationale --
# this is the same pattern: detect the "invoked with system
# python3 instead of the venv wrapper" failure mode up front and
# exit 78 (BSD sysexits.h EX_CONFIG) with an actionable message.
# list_skills.py needs google.auth and requests transitively
# via common.http_retry / common.config; PyYAML is not used here,
# and cryptography is not loaded by list_skills directly. We
# still probe the full venv dep set because (a) a partial venv
# is itself a bug worth surfacing, and (b) consistency with
# find_install.py makes the agent's behaviour predictable.
# =============================================================
_VENV_DEPS = ("yaml", "cryptography", "google.auth", "requests")
_VENV_EX_CONFIG = 78
_missing_dep: str | None = None
_dep: str = ""  # noqa: appease static checker; rebound in loop
for _dep in _VENV_DEPS:
    try:
        __import__(_dep)
    except ImportError:
        _missing_dep = _dep
        break
if _missing_dep is not None:
    _SKILL_DIR = Path(__file__).resolve().parent.parent
    _WRAPPER = _SKILL_DIR / "bin" / "run-with-venv.sh"
    sys.stderr.write(
        "[skill-finder] FATAL: this script requires the bundled "
        "venv wrapper.\n"
        f"  Missing module: {_missing_dep!r}\n"
        f"  You invoked: python3 {sys.argv[0]}\n"
        f"  You should invoke:\n"
        f"      {_WRAPPER} {sys.argv[0]} <args>\n"
        "  The wrapper activates the per-user venv created by\n"
        "  install-skill-finder.sh, which contains the four\n"
        "  required dependencies. The system python3 does not.\n"
        "  If the wrapper is missing, re-run\n"
        "  bin/install-skill-finder.sh to regenerate it.\n"
    )
    sys.exit(_VENV_EX_CONFIG)
del _VENV_DEPS, _missing_dep, _dep

# Dual import: production .skill zip layout has no
# `scripts/` parent package; bare `common.*` resolves via the
# sys.path.insert below. Dev/test layout uses `scripts.common.*`
# via tests/conftest.py.
sys.path.insert(0, str(Path(__file__).resolve().parent))
try:
    from common import http_retry  # production .skill zip layout
    from common import config
except ImportError:
    from scripts.common import http_retry  # dev/test layout
    from scripts.common import config


CLOUD_PLATFORM_SCOPE = "https://www.googleapis.com/auth/cloud-platform"
APIHUB_BASE = "https://apihub.googleapis.com/v1"


def _say(msg: str) -> None:
    """Emit a `[skill-finder]` operator log line."""
    print(f"[skill-finder] {msg}", flush=True)


def _die(msg: str, *, code: int) -> None:
    """Emit a FAILED contract line and exit non-zero."""
    print(f"[skill-finder] {msg}", flush=True)
    sys.exit(code)


def _creds():
    """Return (credentials, project_id) from ADC, refreshed.

    Same pattern as find_install._creds(): the refresh-before-return
    is the lesson learned from the real-infra demo (a fresh
    `google.auth.default()` returns `creds.token = None` until the
    first explicit refresh, producing silent HTTP 401 responses
    otherwise).
    """
    import google.auth as google_auth
    from google.auth.transport.requests import Request

    credentials, project_id = google_auth.default(
        scopes=[CLOUD_PLATFORM_SCOPE]
    )
    credentials.refresh(Request())
    return credentials, project_id


def _attr_string(attrs: dict, suffix: str) -> str:
    """Pull the first string value out of an API-hub attribute
    map keyed by fully-qualified attribute name.

    Same shape-handling as find_install.py's `_cross_check`:
    attributes look like
        {`projects/<p>/locations/<l>/attributes/<id>`:
            {`stringValues`: {`values`: [...]}}}
    and we don't want to hard-code the project/location prefix.
    """
    for k, v in (attrs or {}).items():
        if k.endswith(suffix):
            vals = (v.get("stringValues") or {}).get("values") or []
            return vals[0] if vals else ""
    return ""


def _attr_list(attrs: dict, suffix: str) -> list[str]:
    """Pull every string value out of an API-hub attribute (used
    for `keywords` which has cardinality > 1)."""
    for k, v in (attrs or {}).items():
        if k.endswith(suffix):
            return list((v.get("stringValues") or {}).get("values") or [])
    return []


def _validate_args(ns: argparse.Namespace) -> None:
    """Enforce non-empty required fields and bounds on
    --page-size and --page-token.

    The values flow into an HTTP query string, so we want to
    reject anything that looks like injection or accidental
    misuse.
    """
    for flag, val in (
        ("--project", ns.project),
        ("--location", ns.location),
    ):
        if not (val or "").strip():
            _die(
                f"config: FAILED — {flag} is empty (typically "
                f"sourced from an environment variable). Set "
                f"the environment variable before invoking "
                f"list_skills.",
                code=2,
            )
    if not (1 <= ns.page_size <= 200):
        _die(
            f"config: FAILED — --page-size must be 1..200, got "
            f"{ns.page_size}.",
            code=2,
        )
    # Page token is opaque to us; just bound its length and
    # forbid newline / null / control characters.
    pt = ns.page_token or ""
    if len(pt) > 2048:
        _die(
            "config: FAILED — --page-token too long "
            "(>2048 chars). Truncated or corrupted token?",
            code=2,
        )
    for c in pt:
        if ord(c) < 0x20 or ord(c) == 0x7f:
            _die(
                "config: FAILED — --page-token contains a "
                "non-printable character. Token corrupted in "
                "transit?",
                code=2,
            )


def _list_one_page(
    creds,
    project: str,
    location: str,
    page_size: int,
    page_token: str,
) -> tuple[list[dict], str]:
    """Call API hub list_apis filtered to agentic skills. Returns
    `(apis, next_page_token)`. next_page_token is empty when the
    catalog is exhausted."""
    base = (
        f"{APIHUB_BASE}/projects/{project}"
        f"/locations/{location}/apis"
    )
    attr_fq = (
        f"projects/{project}/locations/{location}"
        f"/attributes/agentic_skill"
    )
    filter_q = (
        f'attributes.{attr_fq}.string_values.values:"true"'
    )
    params = [
        f"filter={quote_plus(filter_q)}",
        f"pageSize={page_size}",
    ]
    if page_token:
        params.append(f"pageToken={quote_plus(page_token)}")
    url = base + "?" + "&".join(params)
    _say(f"list: GET {url}")
    headers = {"Authorization": f"Bearer {creds.token}"}

    def _on_retry(status: int, sleep_s: float) -> None:
        _say(
            f"transient failure (HTTP {status}); retry 1/1 "
            f"after {int(round(sleep_s * 1000))}ms"
        )

    r = http_retry.http_get_retry(url, headers=headers, on_retry=_on_retry)
    if r.status_code >= 400:
        _die(
            f"list: FAILED — HTTP {r.status_code} {r.reason} "
            f"from list_apis; check ADC and "
            f"projects/{project}/locations/{location} permissions.",
            code=3,
        )
    try:
        body = r.json()
    except json.JSONDecodeError as e:
        _die(
            f"list: FAILED — HTTP {r.status_code} non-JSON body "
            f"from list_apis: {e.__class__.__name__}",
            code=3,
        )
    apis = body.get("apis", []) or []
    next_token = body.get("nextPageToken") or ""
    return apis, next_token


def _render_table(apis: list[dict]) -> str:
    """Render the list of API hub catalog entries as a markdown
    table. The columns are chosen for what an agent / user wants
    to see when browsing: name, version (from manifest if listed),
    keywords (the search-relevance signal), one-line description."""
    if not apis:
        return "_(no skills in catalog)_"
    rows = [
        "| name | keywords | description |",
        "|:---|:---|:---|",
    ]
    for api in apis:
        name = (api.get("name") or "").rsplit("/", 1)[-1]
        attrs = api.get("attributes") or {}
        keywords = _attr_list(attrs, "/attributes/keywords")
        description = (api.get("description") or "").strip()
        # Markdown: collapse newlines + escape pipes to keep
        # table layout intact.
        description = description.replace("\n", " ").replace("|", "\\|")
        kw = ", ".join(keywords) if keywords else "_(none)_"
        rows.append(f"| `{name}` | {kw} | {description} |")
    return "\n".join(rows)


def _parse_args(argv: list[str]) -> argparse.Namespace:
    p = argparse.ArgumentParser(
        prog="list_skills.py",
        description=(
            "Browse the API hub catalog of agentic skills. "
            "Prints a markdown table of (name, keywords, "
            "description) for every skill registered with "
            "agentic_skill=true. Cursor-paginated via "
            "--page-size + --page-token."
        ),
    )
    # Defaults resolve from (1) env var, (2) the persistent
    # config file at ~/.config/apigee-skills-demo/config.env.
    # This decouples readiness from the operator having sourced
    # env into the right shell at the right time (notably: when
    # the agent runtime was started before the env was set, the
    # agent's bash subprocesses see no env vars, but they CAN
    # read the config file).
    p.add_argument(
        "--project",
        default=config.get("APIHUB_PROJECT"),
        help=(
            "API hub project (defaults to $APIHUB_PROJECT or "
            "the APIHUB_PROJECT line in "
            "~/.config/apigee-skills-demo/config.env)."
        ),
    )
    p.add_argument(
        "--location",
        default=config.get("APIHUB_LOCATION"),
        help=(
            "API hub location (defaults to $APIHUB_LOCATION or "
            "the APIHUB_LOCATION line in "
            "~/.config/apigee-skills-demo/config.env)."
        ),
    )
    p.add_argument(
        "--page-size",
        type=int,
        default=20,
        help="Number of skills per page (1..200, default 20).",
    )
    p.add_argument(
        "--page-token",
        default="",
        help=(
            "Opaque pagination token from a prior call's "
            "`next-page-token:` line. Empty means start at "
            "the beginning."
        ),
    )
    return p.parse_args(argv)


def main(argv: list[str] | None = None) -> int:
    ns = _parse_args(argv if argv is not None else sys.argv[1:])
    _validate_args(ns)

    creds, _ = _creds()
    apis, next_token = _list_one_page(
        creds,
        ns.project,
        ns.location,
        ns.page_size,
        ns.page_token,
    )

    _say(f"list: OK ({len(apis)} skills returned)")
    print(_render_table(apis), flush=True)
    if next_token:
        # Unprefixed customer-facing contract line: the agent
        # surfaces this so the user knows there's more, and so
        # the agent can pass it back as --page-token on a
        # follow-up call.
        print(f"\nnext-page-token: {next_token}", flush=True)
    else:
        _say("list: end of catalog (no more pages)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
