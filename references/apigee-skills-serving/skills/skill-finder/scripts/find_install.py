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

"""skill-finder runtime helper.

Performs the 16-step install pipeline and prints the
Hyrum's-Law-locked output strings.

Round-2 / Round-3 hardening summary:

  - _search applies APIGEE_SKILLS_MIN_KEYWORD_OVERLAP threshold;
    zero-overlap matches are rejected with `match: NONE`.
  - IAM pre-flight HTTP-level guards (status + JSON-decode +
    retry); see scripts/common/iam_preflight.py for the pure
    API. Stdout contract lines are emitted HERE.
  - _install_atomic wraps the body in try/finally with
    shutil.rmtree(staging, ignore_errors=True). BadZipFile and
    YAMLError surface as contract lines.
  - Distinct contract lines for IAM-skipped and
    watcher-undetectable cases; EXDEV failure line.
  - sys.path.insert(0, parent) so `from common.X import Y`
    resolves regardless of invocation form (see docstring on
    the insert below).
  - _verify_signature distinguishes signature-absent vs
    signature-malformed vs signature-invalid. _fetch_spec
    guards base64/utf-8 decode with the same care.
  - _read_skill_md_name normalizes CRLF / CR to LF in memory
    before the byte-prefix check so Windows-authored SKILL.md
    files pass.
  - _WatcherProbeFuture overlaps the 2 s watcher settle with
    network I/O via a background thread.
  - main() rejects empty --project / --location / --query with
    an operator-actionable line BEFORE any other work.
  - --query value is validated for shell-injection blast-
    radius limiting (length cap, printable ASCII, no NUL/CRLF,
    no shell metacharacters $ ` \\ " ' ; & | < > ( ) { }).
"""
from __future__ import annotations

import argparse
import base64
import binascii  # caught when b64decode encounters bad input
import datetime
import errno  # EXDEV detection
import fcntl
import hashlib
import io
import json
import os
import shutil
import sys
import threading  # overlap watcher probe with network I/O
import uuid
import zipfile
from pathlib import Path

# =============================================================
# Venv preflight. The third-party imports below (yaml,
# cryptography, google-auth, requests) live in the venv that the
# installer creates at ~/.local/share/skill-finder/venv. If this
# script is invoked with the system python3 instead of the venv
# wrapper, those imports raise ModuleNotFoundError with no useful
# context -- the agent sees a generic traceback and has no way to
# know it should be using the wrapper.
#
# Detect that failure mode here and exit 78 with a single
# actionable message pointing the agent at the wrapper. Exit code
# 78 is the BSD sysexits.h EX_CONFIG value ("configuration
# error"); we picked it to disambiguate from the other exit codes
# this script uses (0, 1, 2). The agent can read 78 and recognise
# "wrong invocation" vs "real failure".
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
# Cleanup loop-local names so they don't pollute the module
# namespace.
del _VENV_DEPS, _missing_dep, _dep

# These imports are deferred past the venv-guard block above so a
# missing dep surfaces the operator-facing message rather than a
# generic ModuleNotFoundError traceback. flake8 E402 is silenced
# by design.
import yaml  # noqa: E402
from cryptography.exceptions import InvalidSignature  # noqa: E402
from cryptography.hazmat.primitives.asymmetric.ed25519 import (  # noqa: E402
    Ed25519PublicKey,
)

# Packaging boundary. The .skill zip carries scripts/ and
# scripts/common/ side-by-side; at install-time the layout is
# ~/.config/opencode/skills/skill-finder/scripts/{find_install.py,
# common/{canonical,permission_resolver,watcher_probe,
# manifest_schema}.py}. Without this sys.path setup, the
# `from common.X import Y` lines would ImportError because the
# SKILL.md invokes the script directly (`python3
# ${SKILL_DIR}/scripts/find_install.py`), not as a module
# (`python3 -m scripts.find_install`).
#
# Insert at index 0 (highest priority) so we never pick up a
# user-site `common` collision. pack_skill.py asserts that
# scripts/common/ contains exactly the expected modules before
# zipping.
sys.path.insert(0, str(Path(__file__).resolve().parent))

# Dual import. Production zip layout is
# <install-dir>/scripts/{find_install.py, common/*.py}, so the bare
# `from common.X` form resolves via the sys.path.insert above.
# Dev/test layout uses `from scripts.common.X` via the repo-root
# entry tests/conftest.py installs. We try production form first
# (so sys.modules registration matches the production contract),
# then fall back to dev form. CRITICAL for tests:
# the bound names below MUST be referred to as
# `find_install.iam_preflight`, `find_install.http_get_retry`,
# etc. in test monkeypatch.setattr() calls — that is, the
# monkeypatch target is THIS module, not the source module. If a
# test ever does `from scripts.common.iam_preflight import
# iam_preflight; monkeypatch.setattr(iam_preflight_module, ...)`
# the patch will not reach this module's bound name.
try:
    # Production form (used when the .skill zip is extracted and
    # invoked via `python3 ${SKILL_DIR}/scripts/find_install.py`).
    from common.canonical import canonicalize
    from common.permission_resolver import (
        detect_active_agent,
        resolve_skill_permission,
        Verdict,
    )
    from common.watcher_probe import detect_watcher, WatcherState
    from common.manifest_schema import validate_manifest
    from common.iam_preflight import iam_preflight
    from common.http_retry import http_get_retry
    from common import config
except ImportError:
    # Dev / test form (used when invoked from the repo root with
    # tests/conftest.py on the path).
    from scripts.common.canonical import canonicalize
    from scripts.common.permission_resolver import (
        detect_active_agent,
        resolve_skill_permission,
        Verdict,
    )
    from scripts.common.watcher_probe import detect_watcher, WatcherState
    from scripts.common.manifest_schema import validate_manifest
    from scripts.common.iam_preflight import iam_preflight
    from scripts.common.http_retry import http_get_retry
    from scripts.common import config

# google.auth is imported lazily inside _creds() so test code that
# never touches the network does not have to stub it at import
# time. requests is imported here because the HTTP retry helpers
# return requests.Response objects that we need to type-check.
# E402 is silenced by the deferred-import pattern above.
import requests  # noqa: E402

SKILL_DIR = Path(__file__).resolve().parent.parent
# Multi-key trust root: every PEM under keys/ is a trusted
# publisher. A manifest is accepted if its signing_key_id
# fingerprint matches ANY installed key. See keys/README.md for
# the operational model (provision.sh drops the key, operators
# can add or remove keys manually).
KEYS_DIR = SKILL_DIR / "keys"


# Antigravity supports two install layouts in the wild:
#   - ~/.gemini/antigravity/skills/ — the layout that
#     bin/install-skill-finder.sh + bin/provision.sh install into
#     (canonical / preferred).
#   - ~/.gemini/config/skills/ — an older layout seen on some
#     Antigravity builds; kept for backward compatibility.
# Both are matched during detection, and both are treated as
# agentic runtimes for the reload-hint trailer. The first entry
# is the canonical root and is what _detect_skills_root() returns
# when detection matches by ancestor rather than by exact match.
_ANTIGRAVITY_ROOTS = (
    Path.home() / ".gemini" / "antigravity" / "skills",
    Path.home() / ".gemini" / "config" / "skills",
)
# Back-compat alias for the primary root — callers that want the
# single canonical Antigravity path (e.g. dry-run reporting) can
# use this without knowing about the tuple.
_ANTIGRAVITY_ROOT = _ANTIGRAVITY_ROOTS[0]
_GEMINI_CLI_ROOT = Path.home() / ".gemini" / "skills"
_OPENCODE_ROOT = Path.home() / ".config" / "opencode" / "skills"


def _detect_skills_root() -> Path:
    """Determine where to install newly-discovered skills.

    Resolution order:
      1. APIGEE_SKILLS_INSTALL_ROOT env var (operator override) —
         use this verbatim. Always the explicit win.
      2. Auto-detect Gemini CLI: invocation under
         ~/.gemini/skills/ (the canonical Gemini CLI install
         root, distinct from any Antigravity path).
      3. Auto-detect Antigravity layout: invocation under EITHER
         ~/.gemini/antigravity/skills/ (canonical, matches the
         installer + provision.sh) OR ~/.gemini/config/skills/
         (legacy layout seen on older Antigravity builds).
      4. Default: ~/.config/opencode/skills/ (OpenCode layout).

    The Gemini CLI check runs BEFORE the Antigravity check because
    all three Antigravity/CLI paths live under ~/.gemini/, but are
    distinct sibling directories. Order matters only for the
    pathologic case where someone configures the same install
    in both runtimes; we'd rather pick the runtime whose
    matching path is more specific to the invocation.

    When the invocation matches an Antigravity root, we return
    the *actual matched root* rather than always returning the
    canonical one — this keeps skills installed under the legacy
    ~/.gemini/config/skills/ path stable in place (they still get
    the agentic-runtime reload-hint trailer via
    `is_agentic_runtime`, which also matches both roots).

    Detection considers TWO candidates: the realpath-resolved
    SKILL_DIR (real on-disk location, follows symlinks) and the
    unresolved invocation path (`__file__`-derived, preserves the
    path the agent/user actually supplied). The dual check handles
    every install pattern we've seen: extracted .skill zips and
    dev-checkout symlinks.

    Two-path matching: `is_relative_to` is exact; `os.path.samefile`
    is symlink-aware. We use both because each catches cases the
    other misses.
    """
    override = os.environ.get("APIGEE_SKILLS_INSTALL_ROOT", "").strip()
    if override:
        return Path(override).expanduser()
    invocation_dir = Path(__file__).parent.parent
    candidates = (SKILL_DIR, invocation_dir)

    # Gemini CLI (~/.gemini/skills/) — canonical, single path.
    for candidate in candidates:
        if _path_is_under(candidate, _GEMINI_CLI_ROOT):
            return _GEMINI_CLI_ROOT

    # Antigravity — canonical first, then legacy fallback. Return
    # whichever root actually matched; both are valid install
    # locations and both feed into `is_agentic_runtime` below.
    for antigravity_root in _ANTIGRAVITY_ROOTS:
        for candidate in candidates:
            if _path_is_under(candidate, antigravity_root):
                return antigravity_root

    return _OPENCODE_ROOT


def _path_is_under(child: Path, ancestor: Path) -> bool:
    """Return True iff `child` is at or under `ancestor`, treating
    symlinks as equivalent to their targets.

    We try `is_relative_to` first (exact string prefix); if that
    fails, we walk up child's parents and compare each with
    `samefile` against ancestor. The latter handles cases where
    the legacy alias and the current path resolve to the same
    inode but have different textual representations.
    """
    try:
        if child.is_relative_to(ancestor):
            return True
    except (AttributeError, ValueError):
        pass
    if not ancestor.exists():
        return False
    # Walk up; on each step, see if this dir IS the ancestor (in
    # inode terms). Bounded to ~10 levels to avoid pathological
    # walks on bad inputs.
    p = child
    for _ in range(10):
        try:
            if p.exists() and os.path.samefile(p, ancestor):
                return True
        except (OSError, ValueError):
            pass
        parent = p.parent
        if parent == p:
            return False
        p = parent
    return False


SKILLS_ROOT = _detect_skills_root()
STAGING_LOCK = SKILLS_ROOT / ".staging.lock"
BREADCRUMB = SKILLS_ROOT / ".recent-install"
RECOGNIZED_SCHEMA_VERSIONS = ["1"]
APIHUB_BASE = "https://apihub.googleapis.com/v1"
CLOUD_PLATFORM_SCOPE = (
    "https://www.googleapis.com/auth/cloud-platform"
)

# Zip-bomb / zip-slip defense caps (P0.2).
MAX_ZIP_MEMBERS = 10_000
MAX_ZIP_DECOMPRESSED_BYTES = 100 * 1024 * 1024  # 100 MiB
# SKILL.md frontmatter parser cap (P1.2).
MAX_FRONTMATTER_BYTES = 8192


def _say(line: str) -> None:
    """Emit one prefixed contract line. flush=True keeps stdout
    ordering deterministic across helper-call boundaries (important
    for the end-to-end tests that assert exact line sequencing)."""
    print(f"[skill-finder] {line}", flush=True)


def _say_advisory(line: str) -> None:
    """Operator-advisory line, NOT prefixed with [skill-finder].

    The
    `config: APIGEE_SKILLS_MIN_KEYWORD_OVERLAP=... invalid` advisory
    is NOT part of the Hyrum's Law contract; it appears unprefixed
    and only fires when an operator misconfigures the env var.
    Kept separate from _say() so the distinction is visible at the
    call site."""
    print(line, flush=True)


def _die(line: str, code: int = 1) -> None:
    _say(line)
    sys.exit(code)


def _min_keyword_overlap() -> int:
    """Resolve APIGEE_SKILLS_MIN_KEYWORD_OVERLAP with
    silent fallback.

    Default 1 (require at least one keyword in common). On
    malformed or non-positive values, falls back to 1 silently and
    emits a single advisory line so operator misconfiguration is
    visible in run output without changing the documented
    Hyrum's Law contract."""
    raw = os.environ.get("APIGEE_SKILLS_MIN_KEYWORD_OVERLAP", "1")
    try:
        n = int(raw)
        if n < 1:
            raise ValueError("must be >= 1")
        return n
    except (ValueError, TypeError):
        _say_advisory(
            f'config: APIGEE_SKILLS_MIN_KEYWORD_OVERLAP="{raw}" '
            f"invalid; using default 1"
        )
        return 1


def _creds() -> tuple[object, object]:
    """Single source of truth for ADC scopes.

    All call sites (search, IAM pre-flight, versions/specs fetch)
    MUST go through this helper. Mixing scoped and unscoped ADC
    silently breaks in workload-identity and service-account
    contexts where the unscoped path returns a token that fails
    downstream calls.

    The returned credentials object is refreshed before return so
    callers can read ``creds.token`` immediately. A fresh
    ``google.auth.default()`` returns credentials with ``token=None``
    until the first refresh, which is the gotcha that produces
    silent HTTP 401 responses on the very first call."""
    import google.auth as google_auth
    from google.auth.transport.requests import Request
    creds, project_id = google_auth.default(
        scopes=[CLOUD_PLATFORM_SCOPE]
    )
    creds.refresh(Request())
    return creds, project_id


def _auth_headers(creds: object) -> dict[str, str]:
    """Build the Authorization header. Defensive: the test
    harness stubs ``creds`` with a simple object that exposes
    ``token``; production code gets a real Credentials instance.
    A missing token resolves to empty string so the header is
    still well-formed and request-level mocking can short-circuit
    before any real network call."""
    token = getattr(creds, "token", None) or ""
    return {"Authorization": f"Bearer {token}"}


def _on_retry(status: int, sleep_seconds: float) -> None:
    """Callback passed to scripts.common.http_retry so the
    transient-failure line is emitted from this module
    (which owns the Hyrum's Law surface) before the retry
    sleep fires."""
    backoff_ms = int(round(sleep_seconds * 1000))
    _say(
        f"transient failure (HTTP {status}); "
        f"retry 1/1 after {backoff_ms}ms"
    )


# ---------------------------------------------------------------------------
# Background watcher probe future.
# ---------------------------------------------------------------------------


class _WatcherProbeFuture:
    """Run detect_watcher() in a background thread so its
    PROBE_SETTLE_SECONDS=2.0 sleep overlaps the ~10s of network I/O
    in steps 2-9 (search, fetch-spec, IAM pre-flight, versions
    GET, zip download). Net wall-clock cost of the probe: ~0ms.

    Pre-fix accounting: the 2s probe consumed 13% of the 15s p95
    SLO. Post-fix: amortized to zero because the network calls
    take longer than the probe.

    Failure mode: if the probe thread raises, we surface
    WATCHER_UNDETECTABLE (the same fallback the synchronous probe
    used) rather than crashing the install."""

    def __init__(self) -> None:
        self._state: WatcherState | None = None
        self._exc: BaseException | None = None
        self._thread = threading.Thread(
            target=self._run, name="watcher-probe", daemon=True
        )

    def start(self) -> None:
        self._thread.start()

    def _run(self) -> None:
        try:
            self._state = detect_watcher()
        except BaseException as e:  # noqa: BLE001 — see docstring
            self._exc = e

    def result(self, timeout: float = 10.0) -> WatcherState:
        self._thread.join(timeout=timeout)
        if self._thread.is_alive():
            # Thread didn't finish within timeout. Treat as
            # UNDETECTABLE rather than blocking forever.
            return WatcherState.WATCHER_UNDETECTABLE
        if self._exc is not None:
            return WatcherState.WATCHER_UNDETECTABLE
        assert self._state is not None  # nosec B101 - defensive invariant
        return self._state


# ---------------------------------------------------------------------------
# Steps 1-2: load trusted key, search API hub.
# ---------------------------------------------------------------------------


def _load_one_pubkey(path: Path) -> tuple[Ed25519PublicKey, str]:
    """Load a single PEM (or raw 32-byte) public key and return
    (key, fingerprint). Fingerprint format:
    ``sha256:<hex-of-sha256-of-raw-32-byte-pubkey>``."""
    raw = path.read_bytes()
    if raw.startswith(b"-----BEGIN"):
        from cryptography.hazmat.primitives.serialization import (
            load_pem_public_key,
        )
        pk = load_pem_public_key(raw)
        from cryptography.hazmat.primitives import serialization
        raw32 = pk.public_bytes(
            encoding=serialization.Encoding.Raw,
            format=serialization.PublicFormat.Raw,
        )
    else:
        raw32 = raw
        pk = Ed25519PublicKey.from_public_bytes(raw32)
    fp = "sha256:" + hashlib.sha256(raw32).hexdigest()
    return pk, fp


def _load_pubkeys() -> dict[str, Ed25519PublicKey]:
    """Load every ``keys/*.pem`` (and legacy ``keys/*.raw``) file
    into a fingerprint->key map. If the directory is empty or
    missing, emit a clear diagnostic and exit -- installing
    anything without a trust root would defeat the point.

    Note: files starting with ``.`` (dotfiles like ``.gitkeep``)
    are ignored so the source-tree placeholder does not trip us
    up. ``README.md`` and any non-PEM/non-raw file that fails to
    parse is skipped with a warning, not a hard error, so
    dropping unrelated files into keys/ (e.g. an operator's
    notes) does not brick skill-finder."""
    if not KEYS_DIR.is_dir():
        _die(
            f"trust root: FAILED — no keys/ directory found at "
            f"{KEYS_DIR}. Run bin/provision.sh (bootstrap mode) "
            f"or drop your org's public key PEM into "
            f"{KEYS_DIR}/<fingerprint>.pem before installing.",
            code=3,
        )
    trusted: dict[str, Ed25519PublicKey] = {}
    candidates = sorted(
        p for p in KEYS_DIR.iterdir()
        if p.is_file() and not p.name.startswith(".")
        and p.suffix in (".pem", ".raw")
    )
    for path in candidates:
        try:
            pk, fp = _load_one_pubkey(path)
        except (ValueError, TypeError, OSError) as exc:
            _say(
                f"trust root: warning: skipped {path.name} "
                f"({exc.__class__.__name__}: {exc})"
            )
            continue
        if fp in trusted:
            # Duplicate key material under a different filename
            # -- warn but keep the first (deterministic sort
            # order, so 'first' is stable).
            _say(
                f"trust root: warning: {path.name} duplicates an "
                f"already-loaded key ({fp}); keeping first"
            )
            continue
        trusted[fp] = pk
    if not trusted:
        _die(
            f"trust root: FAILED — no valid keys loaded from "
            f"{KEYS_DIR}. Add at least one <fingerprint>.pem "
            f"or run bin/provision.sh to generate one.",
            code=3,
        )
    return trusted


def _search(
    project: str, location: str, query: str, min_overlap: int
) -> list[dict]:
    creds, _ = _creds()
    base = (
        f"{APIHUB_BASE}/projects/{project}"
        f"/locations/{location}/apis"
    )
    # API hub filter syntax: attributes.<FQ-name>.string_values
    # .values:"X". Discovered during real-infra dry-run; the bare
    # `agentic_skill=true` form rejected with INVALID_ARGUMENT.
    attr_fq = (
        f"projects/{project}/locations/{location}"
        f"/attributes/agentic_skill"
    )
    filter_q = (
        f'attributes.{attr_fq}.string_values.values:"true"'
    )
    from urllib.parse import quote_plus
    url = f"{base}?filter={quote_plus(filter_q)}&pageSize=100"
    _say(f"search: GET {url}")
    try:
        r = http_get_retry(
            url,
            on_retry=_on_retry,
            timeout=30,
            headers=_auth_headers(creds),
        )
    except requests.HTTPError as exc:
        resp = exc.response
        code = getattr(resp, "status_code", "???")
        reason = getattr(resp, "reason", "")
        _die(
            f"search: FAILED — HTTP {code} {reason} from {url}.",
            code=2,
        )
    apis = (r.json() or {}).get("apis", []) or []
    # Trivial stem: strip trailing 's' from query tokens so
    # "policies" matches keyword "policy". Apigee is the demo
    # punchline; reasonable to over-fit a little.
    raw_tokens = set(query.lower().split())
    q_tokens = raw_tokens | {
        t.rstrip("s") for t in raw_tokens
        if t.endswith("s") and len(t) > 3
    }

    # API hub returns keywords as nested
    # {FQ-attribute-name: {stringValues: {values: [...]}}}.
    # Pull the values from any attribute whose key ends in
    # "/attributes/keywords" — this avoids hardcoding the project
    # and location in the lookup.
    def _keywords(api: dict) -> list[str]:
        for k, v in (api.get("attributes") or {}).items():
            if k.endswith("/attributes/keywords"):
                return (v.get("stringValues") or {}).get("values") or []
        return []

    def score(api: dict) -> int:
        return len(q_tokens & {k.lower() for k in _keywords(api)})

    # Drop results below the configured minimum overlap so
    # `apis[0]` cannot silently install a non-matching skill.
    matched = [a for a in apis if score(a) >= min_overlap]
    return sorted(matched, key=score, reverse=True)


def _fetch_spec(creds: object, spec_path: str) -> str:
    url = f"{APIHUB_BASE}/{spec_path}:contents"
    try:
        r = http_get_retry(
            url,
            on_retry=_on_retry,
            timeout=30,
            headers=_auth_headers(creds),
        )
    except requests.HTTPError as exc:
        resp = exc.response
        code = getattr(resp, "status_code", "???")
        reason = getattr(resp, "reason", "")
        _die(
            f"search: FAILED — HTTP {code} {reason} from {url}.",
            code=2,
        )
    body = (r.json() or {}).get("contents", "")
    # Convert binascii.Error / UnicodeDecodeError to a
    # contract line instead of a Python traceback.
    try:
        return base64.b64decode(body, validate=True).decode("utf-8")
    except (binascii.Error, UnicodeDecodeError, ValueError) as e:
        _die(
            f"spec contents: FAILED — malformed base64 or non-utf8 "
            f"body from {url}: {e.__class__.__name__}",
            code=2,
        )
        return ""  # unreachable; satisfies the type checker


# ---------------------------------------------------------------------------
# Steps 4-5b: signature, schema, cross-check.
# ---------------------------------------------------------------------------


def _verify_signature(
    manifest_yaml: str,
    trusted_pubkeys: dict[str, Ed25519PublicKey],
) -> dict:
    """Verify a signed manifest against the multi-key trust root.

    A manifest is accepted if its ``signing_key_id`` matches ANY
    installed trust root. This supports multi-publisher orgs and
    zero-downtime key rotation (new key added, old key not yet
    removed -- both keys accept until rotation completes).

    The stdout contract preserves the LOCKED phrasing
    ``key-id check: trusted (...)`` and
    ``manifest signature: OK (...)`` but reports the specific
    fingerprint that matched rather than a single ``trusted_fp``
    -- helpful when troubleshooting which key was actually used.
    """
    obj = yaml.safe_load(manifest_yaml)
    declared_fp = (
        obj.get("signing_key_id", "") if isinstance(obj, dict) else ""
    )
    if declared_fp not in trusted_pubkeys:
        trusted_list = ", ".join(sorted(trusted_pubkeys)) or "(none)"
        _die(
            f"key-id check: FAILED — manifest declares "
            f"signing_key_id {declared_fp}, but skill-finder "
            f"only trusts: {trusted_list}",
            code=3,
        )
    pubkey = trusted_pubkeys[declared_fp]
    _say(
        f"key-id check: trusted (matches installed key {declared_fp})"
    )
    # Distinguish missing-field from malformed-value and
    # from invalid-signature. The pre-fix behaviour was that a
    # missing 'signature' field decoded to b"" and silently fell
    # through to ed25519 verify, producing a misleading
    # "ed25519 verify rejected" error. Three distinct contract lines
    # now cover the three cases. Order matters: absent FIRST, then
    # malformed base64, then crypto verify.
    if "signature" not in obj:
        _die(
            f"manifest signature: FAILED — signature field absent "
            f"from manifest (key={declared_fp})",
            code=3,
        )
    sig_b64 = obj["signature"]
    try:
        sig = base64.b64decode(sig_b64, validate=True)
    except (binascii.Error, ValueError, TypeError) as e:
        _die(
            f"manifest signature: FAILED — malformed base64 in "
            f"signature field (key={declared_fp}): "
            f"{e.__class__.__name__}",
            code=3,
        )
    canonical = canonicalize(obj)
    try:
        pubkey.verify(sig, canonical)
    except InvalidSignature:
        _die(
            f"manifest signature: FAILED — ed25519 verify rejected "
            f"(key={declared_fp})",
            code=3,
        )
    _say(f"manifest signature: OK (ed25519 / {declared_fp})")
    return obj


def _check_schema_version(manifest: dict) -> None:
    """Emit `manifest schema: OK (version=N)` or fail-line (P0.5)."""
    declared = manifest.get("manifest_schema_version")
    if declared not in RECOGNIZED_SCHEMA_VERSIONS:
        _die(
            f"manifest schema: FAILED — declared {declared}; "
            f"recognized {RECOGNIZED_SCHEMA_VERSIONS}. "
            f"Upgrade skill-finder.",
            code=3,
        )
    _say(f"manifest schema: OK (version={declared})")


def _cross_check(api: dict, manifest: dict) -> None:
    # API hub returns attributes as {FQ-name: {stringValues:
    # {values: [...]}}}. Pull by suffix match so we don't need
    # to know the project/location at this layer.
    attrs = api.get("attributes") or {}

    def _attr_string(field: str) -> str | None:
        suffix = f"/attributes/{field}"
        for k, v in attrs.items():
            if k.endswith(suffix):
                vals = (v.get("stringValues") or {}).get("values") or []
                return vals[0] if vals else None
        return None

    for field in ("gs_uri", "signing_key_id"):
        attr_val = _attr_string(field)
        man_val = manifest.get(field)
        if attr_val != man_val:
            _die(
                f"attribute cross-check: FAILED — {field} differs: "
                f"attr={attr_val} manifest={man_val}",
                code=3,
            )
    _say("attribute cross-check: OK (gs_uri, signing_key_id agree)")


# ---------------------------------------------------------------------------
# Step 7: IAM pre-flight.
# ---------------------------------------------------------------------------


def _iam_preflight_with_contract(
    project: str, perms: list[str]
) -> None:
    """Call the pure iam_preflight() API and emit the contract line.

    The library function returns an IamPreflightResult dataclass
    with one of five status values; we own the wording of the
    resulting contract lines (the library is intentionally
    stdout-free per its module docstring).
    """
    result = iam_preflight(project, perms)
    if result.status == "SKIPPED":
        _say("IAM pre-flight: skipped (no runtime_iam declared)")
        return
    if result.status == "GRANTED":
        # P0.5: comma-joined list, alphabetically sorted ascending
        # so the line is stable across reorderings of the manifest
        # runtime_iam list.
        sorted_perms = sorted(result.granted)
        _say(
            f"IAM pre-flight: OK "
            f"({', '.join(sorted_perms)}: granted)"
        )
        return
    if result.status == "DENIED":
        # The contract is one FAILED line per missing permission.
        # Emit one line per perm in input order (the
        # IamPreflightResult preserves request order in `missing`),
        # then exit 3.
        for perm in result.missing:
            _say(
                f"IAM pre-flight: FAILED — {perm} not granted "
                f"to caller. Install aborted."
            )
        sys.exit(3)
    if result.status == "HTTP_ERROR":
        _die(
            f"IAM pre-flight: FAILED — HTTP {result.http_status} "
            f"{result.http_reason} from testIamPermissions; "
            f"install aborted.",
            code=3,
        )
    if result.status == "NON_JSON":
        # The library does not record the HTTP status when the
        # body is non-JSON (only the exception class). 200 is the
        # documented case per the library docstring; emit the
        # contract line with that assumption.
        _die(
            "IAM pre-flight: FAILED — HTTP 200 non-JSON body "
            "from testIamPermissions; install aborted.",
            code=3,
        )
    # Defensive: any unrecognised status string is a library bug.
    _die(
        f"IAM pre-flight: FAILED — unrecognised pre-flight "
        f"result status {result.status!r}",
        code=3,
    )


# ---------------------------------------------------------------------------
# Steps 8-9: download, hash verify.
# ---------------------------------------------------------------------------


def _download_zip(gs_uri: str) -> bytes:
    """Anonymous HTTPS GET against the public-read GCS object.

    No ADC scope -- the bucket is public-read. We still
    route through http_get_retry so 5xx surfaces the same
    transient-failure line as the authenticated paths."""
    assert gs_uri.startswith("gs://")  # nosec B101 - caller invariant
    bucket, _, obj = gs_uri[5:].partition("/")
    url = f"https://storage.googleapis.com/{bucket}/{obj}"
    try:
        r = http_get_retry(url, on_retry=_on_retry, timeout=60)
    except requests.HTTPError as exc:
        resp = exc.response
        code = getattr(resp, "status_code", "???")
        reason = getattr(resp, "reason", "")
        _die(
            f"zip download: FAILED — HTTP {code} {reason} "
            f"from {url}.",
            code=2,
        )
    _say(f"zip download: {gs_uri} -> {len(r.content)}B")
    return r.content


def _verify_zip_hash(zip_bytes: bytes, expected: str) -> None:
    actual = hashlib.sha256(zip_bytes).hexdigest()
    if actual != expected:
        _die(
            f"zip hash: FAILED — expected sha256={expected}, "
            f"got sha256={actual}. Install aborted.",
            code=3,
        )
    _say(f"zip hash: OK (sha256={expected} == actual)")


# ---------------------------------------------------------------------------
# Step 11: atomic install + safety nets.
# ---------------------------------------------------------------------------


def _safe_extract(
    zf: zipfile.ZipFile,
    dest: Path,
    max_members: int | None = None,
    max_total_bytes: int | None = None,
) -> None:
    """P0.2: zip-slip + zip-bomb safe extractor.

    Three classes of abort, each surfacing a failure line:
      - member count > cap
      - decompressed total > cap
      - any member's resolved path escapes `dest`

    Caps default to ``MAX_ZIP_MEMBERS`` / ``MAX_ZIP_DECOMPRESSED_BYTES``
    resolved from module-level globals at CALL time (not def time)
    so tests can monkeypatch the constants without re-binding the
    default parameter values.
    """
    if max_members is None:
        max_members = MAX_ZIP_MEMBERS
    if max_total_bytes is None:
        max_total_bytes = MAX_ZIP_DECOMPRESSED_BYTES
    members = zf.infolist()
    if len(members) > max_members:
        _die(
            f"install: FAILED - zip member count {len(members)} "
            f"> cap {max_members}",
            code=3,
        )
    total = sum(m.file_size for m in members)
    if total > max_total_bytes:
        _die(
            f"install: FAILED - zip decompressed size {total} "
            f"> cap {max_total_bytes}",
            code=3,
        )
    dest_resolved = dest.resolve()
    for m in members:
        target = (dest_resolved / m.filename).resolve()
        if (
            not str(target).startswith(str(dest_resolved) + os.sep)
            and target != dest_resolved
        ):
            _die(
                f"install: FAILED - zip path traversal: "
                f"'{m.filename}' escapes staging dir",
                code=3,
            )
    zf.extractall(dest_resolved)


def _read_skill_md_name(
    skill_md: Path,
    max_frontmatter_bytes: int = MAX_FRONTMATTER_BYTES,
) -> str:
    """P1.2: size-bounded, line-ending-tolerant frontmatter
    reader.

    Replaces the brittle ``text.split('---')[1]`` approach. CRLF
    and CR-only line endings are normalized to LF in memory before
    the byte-prefix check; the on-disk file is untouched. This lets
    Windows-authored SKILL.md files pass without a re-export step.
    """
    raw_on_disk = skill_md.read_bytes()
    raw = (
        raw_on_disk.replace(b"\r\n", b"\n").replace(b"\r", b"\n")
    )
    if not raw.startswith(b"---\n"):
        _die(
            "install: FAILED - bundled SKILL.md missing leading "
            "'---' frontmatter",
            code=3,
        )
    end = raw.find(b"\n---\n", 4)
    if end == -1 or end > max_frontmatter_bytes:
        _die(
            f"install: FAILED - bundled SKILL.md frontmatter "
            f"exceeds {max_frontmatter_bytes} bytes or missing "
            f"closing '---'",
            code=3,
        )
    try:
        fm = yaml.safe_load(raw[4:end].decode("utf-8"))
    except yaml.YAMLError as e:
        # Convert YAMLError to a contract line instead
        # of leaking a traceback (which would also leak the staging
        # dir before the try/finally cleanup).
        _die(
            f"install: FAILED - bundled SKILL.md frontmatter YAML "
            f"invalid: {e.__class__.__name__}",
            code=3,
        )
    if not isinstance(fm, dict) or "name" not in fm:
        _die(
            "install: FAILED - bundled SKILL.md frontmatter "
            "missing 'name' field",
            code=3,
        )
    return fm["name"]


def _write_breadcrumb(name: str) -> None:
    """P1.3: cross-session breadcrumb for fallback-required path.

    Written when the watcher is not ENABLED so a debugging
    operator can later confirm 'yes, the install happened, the
    user just missed the /reload-skills prompt.' Best-effort: any
    OSError is swallowed so a missing breadcrumb never aborts a
    successful install.
    """
    try:
        SKILLS_ROOT.mkdir(parents=True, exist_ok=True)
        BREADCRUMB.write_text(
            json.dumps(
                {
                    "name": name,
                    "installed_at": (
                        datetime.datetime.now(
                            datetime.timezone.utc
                        ).isoformat()
                    ),
                    "fallback_required": True,
                }
            )
        )
    except OSError:
        # Breadcrumb is best-effort; never abort install for it.
        pass


def _install_atomic(name: str, zip_bytes: bytes) -> Path:
    SKILLS_ROOT.mkdir(parents=True, exist_ok=True)
    STAGING_LOCK.touch(exist_ok=True)
    target = SKILLS_ROOT / name
    staging = SKILLS_ROOT / f".staging-{uuid.uuid4().hex}"
    with open(STAGING_LOCK, "w") as lock_fd:
        fcntl.flock(lock_fd, fcntl.LOCK_EX)
        if target.exists():
            _die(
                f"install: REFUSED — skill {name} already "
                f"installed at {target}. Uninstall first.",
                code=1,
            )
        staging.mkdir()
        try:
            try:
                with zipfile.ZipFile(io.BytesIO(zip_bytes)) as zf:
                    _safe_extract(zf, staging)
            except zipfile.BadZipFile as e:
                # Convert BadZipFile to a contract line.
                # try/finally below still runs and removes staging.
                _die(
                    f"install: FAILED - corrupt zip archive: "
                    f"{e.__class__.__name__}",
                    code=3,
                )
            # pack_skill.py wraps the zip contents in a top-level
            # directory matching the skill name. Detect-and-promote
            # so the rest of the install logic sees the SKILL.md at
            # the staging root.
            wrapper = staging / name
            if wrapper.is_dir() and not (staging / "SKILL.md").exists():
                # Move children of the wrapper up one level.
                for child in wrapper.iterdir():
                    child.rename(staging / child.name)
                wrapper.rmdir()
            inner_name = _read_skill_md_name(staging / "SKILL.md")
            if inner_name != name:
                _die(
                    f"package: FAILED — manifest.name={name} but "
                    f"bundled SKILL.md declares name: {inner_name}. "
                    f"Install aborted.",
                    code=3,
                )
            try:
                os.rename(staging, target)
            except OSError as e:
                if e.errno == errno.EXDEV:
                    # Explicit EXDEV contract line. Exit
                    # code 2 (operator fixable, not a security
                    # failure).
                    _die(
                        "install: FAILED — EXDEV: staging dir on "
                        "different filesystem than skills dir. "
                        "Operator must colocate.",
                        code=2,
                    )
                raise
        finally:
            # Cleanup runs on ALL failure paths
            # (BadZipFile, YAMLError-from-_read_skill_md_name,
            # SystemExit from _die, EXDEV, name-mismatch). On
            # success os.rename has already consumed staging, so
            # ignore_errors=True makes this a safe no-op.
            shutil.rmtree(staging, ignore_errors=True)
    _say(f"install: {target}/")
    return target


# ---------------------------------------------------------------------------
# main()
# ---------------------------------------------------------------------------


def _validate_env_preflight(args: argparse.Namespace) -> None:
    """Fail-fast pre-flight on operator-controlled env
    vars surfaced via SKILL.md shell expansion.

    argparse already rejects missing flags (required=True), but a
    SKILL.md ``${APIHUB_PROJECT}`` that expanded to the empty
    string would pass argparse and then fail mysteriously at API
    hub with a 400. Catch empty strings here with an explicit
    contract line. The "config:" prefix matches the existing
    advisory line convention."""
    for flag, val, env_var in (
        ("--project", args.project, "APIHUB_PROJECT"),
        ("--location", args.location, "APIHUB_LOCATION"),
        ("--query", args.query, "ARGUMENTS"),
    ):
        if not val or not val.strip():
            _die(
                f"config: FAILED — {flag} is empty (typically "
                f"sourced from ${{{env_var}}}). Set the environment "
                f"variable before invoking skill-finder.",
                code=2,
            )


def _validate_query(query: str) -> None:
    """Defense-in-depth shell-injection blast-radius limiter.

    The SKILL.md invocation passes ``--query "${ARGUMENTS}"`` via
    a bash !`...` injection. If OpenCode's ``${ARGUMENTS}``
    expansion is literal text substitution (NOT shell-safe
    quoted), a user query containing an unescaped quote could
    break out of the surrounding "" and inject shell commands.
    We CANNOT fully prevent this from the Python script side
    because the shell has already executed by the time we run.
    What we CAN do is limit the blast radius: reject queries that
    look like injection attempts BEFORE making any HTTP call.

    Allowlist: printable ASCII only (``0x20 <= ord(c) < 0x7f``),
    no newlines, no NUL bytes, length cap 500, and NO shell
    metacharacters ($ ` \\ " ' ; & | < > ( ) { }). Apigee API hub
    keywords are alphanumeric + dash, so legitimate queries stay
    well within this band.

    Shell metacharacters are forbidden because the SKILL.md
    invocation passes ``--query "${ARGUMENTS}"`` via a bash !`...`
    injection: POSIX double quotes do NOT suppress ``$(...)``
    command substitution or backtick expansion, so the shell would
    execute those constructs BEFORE find_install.py starts.
    Rejecting them here is defense-in-depth; the SKILL.md tells
    the agent to refuse them at the AGENT layer before the bash
    expansion fires."""
    _SHELL_METACHARS = frozenset('$`\\"\';&|<>(){}')
    if (
        len(query) > 500
        or "\x00" in query
        or "\n" in query
        or "\r" in query
        or not all(0x20 <= ord(c) < 0x7f for c in query)
        or any(c in _SHELL_METACHARS for c in query)
    ):
        _die(
            "config: FAILED — query contains disallowed "
            "characters (non-printable, newline, null, shell "
            "metachar, or length > 500). Refusing to proceed to "
            "limit shell-injection blast radius if SKILL.md "
            "expansion was unsafe.",
            code=2,
        )


def main(argv: list[str] | None = None) -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--query", required=True)
    # --project and --location fall back to env vars OR the
    # persistent config file at ~/.config/apigee-skills-demo/
    # config.env. This makes find_install resilient to the
    # operator launching the agent runtime before sourcing the env --
    # the agent's bash subprocesses see no env vars in that
    # case, but they CAN read the config file. The flags are
    # still required (argparse will reject genuinely-missing
    # values from BOTH paths), but the default lookup means
    # the agent doesn't have to pass them explicitly when the
    # demo is configured.
    ap.add_argument(
        "--project",
        default=config.get("APIHUB_PROJECT"),
    )
    ap.add_argument(
        "--location",
        default=config.get("APIHUB_LOCATION"),
    )
    args = ap.parse_args(argv)

    # Env pre-flight and query allowlist run
    # BEFORE any other work (no stdout, no watcher probe, no
    # HTTP) so the operator sees an actionable line and we never
    # touch the network with a malformed input.
    _validate_env_preflight(args)
    _validate_query(args.query)

    # Resolve env var AFTER the query / project validation so an
    # advisory line never appears before the contract lines.
    min_overlap = _min_keyword_overlap()

    _say(f'query: "{args.query}"')

    # Kick off the watcher probe BEFORE any network call.
    # Its 2s settle overlaps the search/fetch/iam/download HTTP
    # I/O so by the time we need the result at step 12a, the
    # probe has already completed. Background thread runs
    # detect_watcher().
    watcher_probe = _WatcherProbeFuture()
    watcher_probe.start()

    trusted_pubkeys = _load_pubkeys()
    apis = _search(args.project, args.location, args.query, min_overlap)
    if not apis:
        # Covers both "API hub returned []" and "nothing
        # cleared MIN_KEYWORD_OVERLAP". Single line in the
        # Hyrum's Law contract.
        _die(
            f'match: NONE — zero skills met minimum keyword '
            f'overlap (threshold={min_overlap}) for query '
            f'"{args.query}".',
            code=1,
        )
    top = apis[0]
    name_from_api = top.get("name", "").rsplit("/", 1)[-1]
    # signing_key_id is nested under
    # {FQ-attr-name: {stringValues: {values: [...]}}}, same shape
    # as keywords. Pull from any attribute key ending in
    # /attributes/signing_key_id.
    declared_key_id = ""
    for k, v in (top.get("attributes") or {}).items():
        if k.endswith("/attributes/signing_key_id"):
            vals = (v.get("stringValues") or {}).get("values") or []
            declared_key_id = vals[0] if vals else ""
            break
    _say(
        f"match (1 of {len(apis)}): name={name_from_api} "
        f"signing_key_id={declared_key_id}"
    )

    creds, _project_id = _creds()
    # P0.3: explicit length checks on versions[] and specs[]
    # before indexing so an empty result surfaces as a
    # contract line, not an IndexError traceback.
    versions_url = f"{APIHUB_BASE}/{top['name']}/versions"
    try:
        vresp = http_get_retry(
            versions_url,
            on_retry=_on_retry,
            timeout=30,
            headers=_auth_headers(creds),
        )
    except requests.HTTPError as exc:
        resp = exc.response
        code = getattr(resp, "status_code", "???")
        reason = getattr(resp, "reason", "")
        _die(
            f"search: FAILED — HTTP {code} {reason} from "
            f"{versions_url}.",
            code=2,
        )
    versions = (vresp.json() or {}).get("versions", []) or []
    if not versions:
        _die(
            f"install: FAILED - registered skill '{name_from_api}' "
            f"has zero versions (race with register-skill.py?)",
            code=2,
        )
    specs = versions[0].get("specs", []) or []
    if not specs:
        _die(
            f"install: FAILED - registered skill '{name_from_api}' "
            f"version '{versions[0]['name']}' has zero specs",
            code=2,
        )
    # API hub returns specs[] as a list of resource name STRINGS
    # in the version's list view (not nested objects). Accept both
    # shapes defensively.
    first = specs[0]
    spec_path = first if isinstance(first, str) else first.get("name")
    if not spec_path:
        _die(
            f"install: FAILED - registered skill '{name_from_api}' "
            f"version returned malformed spec reference",
            code=2,
        )
    # _fetch_spec wants the bare spec resource path WITHOUT the
    # leading APIHUB_BASE; strip if it slipped in.
    if spec_path.startswith(APIHUB_BASE + "/"):
        spec_path = spec_path[len(APIHUB_BASE) + 1:]
    manifest_yaml = _fetch_spec(creds, spec_path)

    manifest = _verify_signature(manifest_yaml, trusted_pubkeys)
    _check_schema_version(manifest)
    validate_manifest(manifest)
    _cross_check(top, manifest)
    _iam_preflight_with_contract(
        args.project, list(manifest.get("runtime_iam", []) or [])
    )

    zip_bytes = _download_zip(manifest["gs_uri"])
    _verify_zip_hash(zip_bytes, manifest["zip_sha256"])
    target = _install_atomic(manifest["name"], zip_bytes)
    _ = target  # silence unused-var; emitted via _say in _install_atomic

    # Join the background probe. On the network-fast
    # path the probe is already done; result() returns
    # immediately. 10s timeout caps the test/mocked path.
    watcher = watcher_probe.result(timeout=10.0)
    agent = detect_active_agent()
    perm = resolve_skill_permission(manifest["name"], agent)
    if perm.verdict == Verdict.DENY:
        _die(
            f"agent `skill` tool: DENIED for agent={agent}. "
            f"Switch agents and re-ask.",
            code=3,
        )
    # Detect runtime by where we installed. Antigravity and Gemini
    # CLI rescan the skills directory on the next conversation
    # turn — no slash command needed. OpenCode requires
    # /reload-skills if the file-watcher path didn't fire.
    # Non-OpenCode runtimes (Antigravity + Gemini CLI) get the
    # "re-ask your question" trailer because neither has the
    # OpenCode /reload-skills slash command. Both rescan
    # their skills directory on the next conversation turn.
    is_agentic_runtime = SKILLS_ROOT in (
        *_ANTIGRAVITY_ROOTS,
        _GEMINI_CLI_ROOT,
    )
    if watcher == WatcherState.WATCHER_ENABLED:
        _say("OpenCode file-watcher detected: yes")
        _say(f"agent `skill` tool: allowed for agent={agent}")
        _say(
            f"Skill {manifest['name']} is now available — "
            f"try your request again."
        )
    else:
        # Distinguish the DISABLED (clean "NO") line from
        # the UNDETECTABLE ("NO (probe inconclusive)") line.
        suffix = (
            " (probe inconclusive)"
            if watcher == WatcherState.WATCHER_UNDETECTABLE
            else ""
        )
        _say(f"OpenCode file-watcher detected: NO{suffix}")
        _say(f"agent `skill` tool: allowed for agent={agent}")
        _write_breadcrumb(manifest["name"])  # P1.3
        if is_agentic_runtime:
            # Antigravity and Gemini CLI both rescan their skills
            # directory on the next conversation turn. The user
            # just re-asks; neither has a /reload-skills slash
            # command. The trailer wording deliberately omits the
            # runtime name so the message is correct on both.
            _say(
                f"*** ACTION REQUIRED: re-ask your question — "
                f"the agent runtime will pick up "
                f"{manifest['name']} on the next turn. ***"
            )
        else:
            _say(
                '*** ACTION REQUIRED: type "/reload-skills" before '
                're-asking your question. ***'
            )


if __name__ == "__main__":
    main()
