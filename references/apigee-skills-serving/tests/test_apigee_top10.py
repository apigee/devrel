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

"""Tests for ``skills/apigee-policy-top10/scripts/top10.py``.

Covers the acceptance criteria for the apigee-policy-top10 skill:

- ``ANNOUNCEMENT`` constant exists, importable, and is printed as
  the FIRST stdout line by ``main()`` BEFORE any network call
  (runtime enforcement).
- ``ANNOUNCEMENT`` is byte-identical to
  ``tests/fixtures/announcement.txt`` (static enforcement; CI
  catches drift on either side).
- Ranked output: N+ policy types -> exactly ``--top`` rows in
  descending count order; fewer than ``--top`` -> all rows.
- Malformed XML in a bundle is skipped with an
  ``[apigee-policy-top10] warning:`` line, not fatal.
- Zero proxies -> exit code 1 with a FAILED-style line.
- ``runtime_iam`` list in ``SKILL.md`` frontmatter matches the
  expected dot-form strings verbatim.
- No real network call ever escapes; the announcement still prints
  even when the network is mocked to raise immediately.
"""
from __future__ import annotations

import importlib.util
import io
import re
import sys
import zipfile
from collections import Counter
from pathlib import Path
from unittest import mock

import pytest
import yaml

# ---------------------------------------------------------------------------
# Module loading
#
# ``top10.py`` lives under ``skills/apigee-policy-top10/scripts/`` and is
# bundled with the skill, not imported as part of a package. Load it by
# absolute path so the tests are stable regardless of how pytest is invoked.
# ---------------------------------------------------------------------------
_REPO_ROOT = Path(__file__).resolve().parent.parent
_TOP10_PATH = (
    _REPO_ROOT
    / "skills"
    / "apigee-policy-top10"
    / "scripts"
    / "top10.py"
)
_SKILL_MD_PATH = (
    _REPO_ROOT / "skills" / "apigee-policy-top10" / "SKILL.md"
)
_FIXTURE_PATH = (
    _REPO_ROOT / "tests" / "fixtures" / "announcement.txt"
)


def _load_top10():
    """Import ``top10`` as a standalone module from its file path."""
    spec = importlib.util.spec_from_file_location(
        "top10", str(_TOP10_PATH)
    )
    assert spec is not None and spec.loader is not None
    module = importlib.util.module_from_spec(spec)
    # Cache under the canonical name so subsequent calls return the
    # same object; the contract is that
    # ``from top10 import ANNOUNCEMENT`` is the import surface tests
    # rely on.
    sys.modules["top10"] = module
    spec.loader.exec_module(module)
    return module


@pytest.fixture
def top10_module():
    return _load_top10()


# ---------------------------------------------------------------------------
# Helpers to build fake Apigee API responses
# ---------------------------------------------------------------------------
def _make_bundle_zip(policy_files: dict[str, str]) -> bytes:
    """Build a proxy-bundle zip with the given ``policies/*.xml`` map.

    ``policy_files`` keys are policy filenames (without the
    ``apiproxy/policies/`` prefix). Values are the raw XML body.
    """
    buf = io.BytesIO()
    with zipfile.ZipFile(buf, "w") as zf:
        for fname, body in policy_files.items():
            zf.writestr(f"apiproxy/policies/{fname}", body)
    return buf.getvalue()


class _FakeResponse:
    """Minimal stand-in for ``requests.Response``."""

    def __init__(
        self,
        status_code: int = 200,
        json_data: object | None = None,
        content: bytes = b"",
        reason: str = "OK",
    ) -> None:
        self.status_code = status_code
        self._json = json_data
        self.content = content
        self.reason = reason

    def json(self):
        if self._json is None:
            raise ValueError("no json body")
        return self._json


def _patch_auth(monkeypatch, top10_module) -> None:
    """Bypass real ADC; tests never hit ``google.auth``."""
    monkeypatch.setattr(
        top10_module, "_auth", lambda: ("fake-token", "fake-project")
    )


# ---------------------------------------------------------------------------
# Announcement contract
# ---------------------------------------------------------------------------
def test_announcement_constant_importable(top10_module):
    """``ANNOUNCEMENT`` must be a non-empty ``str`` constant
    importable from the ``top10`` module."""
    assert hasattr(top10_module, "ANNOUNCEMENT")
    assert isinstance(top10_module.ANNOUNCEMENT, str)
    assert top10_module.ANNOUNCEMENT.strip() != ""


def test_announcement_matches_design(top10_module):
    """Byte-equality between ``ANNOUNCEMENT`` (UTF-8) and the
    pinned fixture file. CI catches drift on either side."""
    assert _FIXTURE_PATH.is_file(), (
        f"missing fixture: {_FIXTURE_PATH}"
    )
    fixture_bytes = _FIXTURE_PATH.read_bytes()
    assert (
        top10_module.ANNOUNCEMENT.encode("utf-8") == fixture_bytes
    )


def test_announcement_is_unprefixed(top10_module):
    """The announcement is customer-facing and MUST NOT carry the
    ``[apigee-policy-top10]`` log prefix."""
    assert not top10_module.ANNOUNCEMENT.startswith(
        "[apigee-policy-top10]"
    )


def test_announcement_is_first_line(
    top10_module, monkeypatch, capsys
):
    """End-to-end mocked run: ``stdout.splitlines()[0]`` must equal
    ``ANNOUNCEMENT``. Verified against a tiny fake org with one
    deployed revision so ``main()`` reaches the table render path."""
    _patch_auth(monkeypatch, top10_module)

    bundle = _make_bundle_zip({
        "p1.xml": '<SpikeArrest name="sa1"/>',
        "p2.xml": '<OAuthV2 name="o1"/>',
    })

    def fake_get(url, headers=None, timeout=None):
        if url.endswith("/apis"):
            return _FakeResponse(json_data={
                "proxies": [{"name": "organizations/org/apis/proxyA"}]
            })
        if url.endswith("/apis/proxyA/deployments"):
            return _FakeResponse(json_data={
                "deployments": [{"revision": "1"}]
            })
        if "revisions/1?format=bundle" in url:
            return _FakeResponse(content=bundle)
        raise AssertionError(f"unexpected URL: {url}")

    monkeypatch.setattr(
        top10_module.requests, "get", fake_get
    )
    monkeypatch.setattr(
        sys, "argv", ["top10.py", "--org", "fake-org"]
    )

    top10_module.main()
    out = capsys.readouterr().out
    lines = out.splitlines()
    assert lines, "no stdout produced"
    assert lines[0] == top10_module.ANNOUNCEMENT


def test_no_real_network(top10_module, monkeypatch, capsys):
    """Even when the very first network call raises, the
    announcement is already on stdout. Confirms the print
    happens BEFORE ``_auth()`` / any network I/O."""

    def boom():
        raise RuntimeError(
            "auth should not run before announcement"
        )

    # _auth is the first thing main() does after the print; rig it
    # to raise. We also rig requests.get to raise so a regression
    # that moves the print after _auth still cannot silently hit
    # the network.
    def fake_get(*a, **kw):
        raise RuntimeError("network must not be touched")

    monkeypatch.setattr(top10_module, "_auth", boom)
    monkeypatch.setattr(top10_module.requests, "get", fake_get)
    monkeypatch.setattr(
        sys, "argv", ["top10.py", "--org", "fake-org"]
    )

    with pytest.raises(RuntimeError):
        top10_module.main()

    out = capsys.readouterr().out
    lines = out.splitlines()
    assert lines, "announcement was not printed before _auth()"
    assert lines[0] == top10_module.ANNOUNCEMENT


# ---------------------------------------------------------------------------
# Ranked-output contract
# ---------------------------------------------------------------------------
def _run_main_with_bundles(
    top10_module,
    monkeypatch,
    bundles_by_rev: dict[str, bytes],
    deployments: list[str],
    top: int | None = None,
    proxies: list[str] | None = None,
) -> None:
    """Drive ``main()`` end-to-end with mocked HTTP.

    Caller pulls stdout via the ``capsys`` fixture they own; this
    helper has no return value because mixing ``capsys`` ownership
    across helper/caller boundaries is brittle.
    """
    _patch_auth(monkeypatch, top10_module)
    proxies = proxies if proxies is not None else ["proxyA"]

    def fake_get(url, headers=None, timeout=None):
        if url.endswith("/apis"):
            return _FakeResponse(json_data={
                "proxies": [
                    {"name": f"organizations/org/apis/{p}"}
                    for p in proxies
                ],
            })
        m = re.search(r"/apis/([^/]+)/deployments$", url)
        if m:
            return _FakeResponse(json_data={
                "deployments": [
                    {"revision": rev} for rev in deployments
                ],
            })
        m = re.search(r"/apis/([^/]+)/revisions/([^/?]+)\?format=bundle", url)
        if m:
            rev = m.group(2)
            assert rev in bundles_by_rev, (
                f"unexpected rev download: {rev}"
            )
            return _FakeResponse(content=bundles_by_rev[rev])
        raise AssertionError(f"unexpected URL: {url}")

    monkeypatch.setattr(top10_module.requests, "get", fake_get)

    argv = ["top10.py", "--org", "fake-org"]
    if top is not None:
        argv.extend(["--top", str(top)])
    monkeypatch.setattr(sys, "argv", argv)

    top10_module.main()
    return None  # caller pulls stdout via capsys


def test_ranked_output_exact_N(
    top10_module, monkeypatch, capsys
):
    """N+ policy types -> exactly ``--top`` rows, sorted by count
    descending. Use ``--top 3`` against 5 distinct types."""
    bundle = _make_bundle_zip({
        "a1.xml": '<SpikeArrest name="a1"/>',
        "a2.xml": '<SpikeArrest name="a2"/>',
        "a3.xml": '<SpikeArrest name="a3"/>',
        "b1.xml": '<OAuthV2 name="b1"/>',
        "b2.xml": '<OAuthV2 name="b2"/>',
        "c1.xml": '<AssignMessage name="c1"/>',
        "d1.xml": '<ResponseCache name="d1"/>',
        "e1.xml": '<Quota name="e1"/>',
    })
    _run_main_with_bundles(
        top10_module,
        monkeypatch,
        bundles_by_rev={"1": bundle},
        deployments=["1"],
        top=3,
    )
    out = capsys.readouterr().out
    lines = out.splitlines()
    # Drop announcement and table header lines.
    data_rows = [
        ln for ln in lines
        if ln.startswith("| ") and "policy_type" not in ln
        and not ln.startswith("|:")
    ]
    assert len(data_rows) == 3
    # Counts must be in non-increasing order.
    counts: list[int] = []
    for row in data_rows:
        # ``| Type | N |``
        parts = [c.strip() for c in row.strip("|").split("|")]
        counts.append(int(parts[1]))
    assert counts == sorted(counts, reverse=True)
    # Top row is the SpikeArrest with count 3.
    assert "SpikeArrest" in data_rows[0]
    assert data_rows[0].rstrip().endswith("| 3 |")


def test_smaller_than_N(top10_module, monkeypatch, capsys):
    """Fewer than ``--top`` types -> all rows returned, no
    padding."""
    bundle = _make_bundle_zip({
        "a.xml": '<SpikeArrest name="a"/>',
        "b.xml": '<OAuthV2 name="b"/>',
    })
    _run_main_with_bundles(
        top10_module,
        monkeypatch,
        bundles_by_rev={"1": bundle},
        deployments=["1"],
        top=10,
    )
    out = capsys.readouterr().out
    lines = out.splitlines()
    data_rows = [
        ln for ln in lines
        if ln.startswith("| ") and "policy_type" not in ln
        and not ln.startswith("|:")
    ]
    assert len(data_rows) == 2


# ---------------------------------------------------------------------------
# Robustness: malformed XML, zero proxies
# ---------------------------------------------------------------------------
def test_corrupt_xml_skipped(top10_module, monkeypatch, capsys):
    """Malformed XML in a bundle is skipped with a warning, not
    fatal. Good policies in the same bundle still count."""
    bundle = _make_bundle_zip({
        "good.xml": '<SpikeArrest name="g"/>',
        "broken.xml": '<<<this is not xml',
    })
    _run_main_with_bundles(
        top10_module,
        monkeypatch,
        bundles_by_rev={"1": bundle},
        deployments=["1"],
    )
    out = capsys.readouterr().out
    assert "[apigee-policy-top10] warning:" in out
    assert "broken.xml" in out
    # Good policy still produces a table row.
    assert "SpikeArrest" in out
    assert "| 1 |" in out


def test_zero_proxies_exit_1(top10_module, monkeypatch, capsys):
    """Zero proxies returned -> exit code 1 with a FAILED-style
    operator line. The announcement still printed first."""
    _patch_auth(monkeypatch, top10_module)

    def fake_get(url, headers=None, timeout=None):
        if url.endswith("/apis"):
            return _FakeResponse(json_data={"proxies": []})
        raise AssertionError(f"unexpected URL: {url}")

    monkeypatch.setattr(top10_module.requests, "get", fake_get)
    monkeypatch.setattr(
        sys, "argv", ["top10.py", "--org", "fake-org"]
    )

    with pytest.raises(SystemExit) as excinfo:
        top10_module.main()
    assert excinfo.value.code == 1

    out = capsys.readouterr().out
    lines = out.splitlines()
    assert lines[0] == top10_module.ANNOUNCEMENT
    # The contract says operator log lines (including the no-
    # proxies failure) carry the bracket prefix.
    assert any(
        ln.startswith("[apigee-policy-top10]") for ln in lines
    )


# ---------------------------------------------------------------------------
# SKILL.md frontmatter contract
# ---------------------------------------------------------------------------
def test_skill_md_exists():
    assert _SKILL_MD_PATH.is_file(), (
        f"missing SKILL.md: {_SKILL_MD_PATH}"
    )


def _parse_frontmatter(skill_md_path: Path) -> dict:
    """Parse the leading ``---``-delimited YAML block."""
    text = skill_md_path.read_text(encoding="utf-8")
    assert text.startswith("---\n"), (
        "SKILL.md must start with a YAML frontmatter block"
    )
    end = text.find("\n---\n", 4)
    assert end != -1, "frontmatter has no closing ``---``"
    yaml_text = text[4:end]
    return yaml.safe_load(yaml_text)


def test_runtime_iam_in_skill_md():
    """``metadata.runtime_iam`` lists the three dot-form
    permissions in order."""
    fm = _parse_frontmatter(_SKILL_MD_PATH)
    expected = [
        "apigee.proxies.list",
        "apigee.deployments.list",
        "apigee.proxyrevisions.get",
    ]
    metadata = fm.get("metadata") or {}
    runtime_iam = metadata.get("runtime_iam")
    assert runtime_iam == expected


def test_runtime_iam_is_dot_form():
    """Each entry MUST match the dot-form regex used by
    ``scripts/common/manifest_schema.py`` (rejects the
    service-host-prefix form)."""
    fm = _parse_frontmatter(_SKILL_MD_PATH)
    runtime_iam = (fm.get("metadata") or {}).get("runtime_iam") or []
    dot_form = re.compile(r"^[a-z]+\.[a-z0-9.]+$")
    for perm in runtime_iam:
        assert dot_form.match(perm), (
            f"permission {perm!r} is not dot-form"
        )
        assert "/" not in perm
        assert "googleapis.com" not in perm


# ---------------------------------------------------------------------------
# --org config resolution
#
# top10.py used to require --org as an argparse flag. After the
# demo-resilience refactor, --org defaults to resolution via
# scripts/common/config: env var APIGEE_ORG > the APIGEE_ORG
# line in ~/.config/apigee-skills-demo/config.env > empty.
# Emptiness is enforced AFTER the ANNOUNCEMENT print so the
# first-line invariant still holds even in the failure case.
# ---------------------------------------------------------------------------


@pytest.fixture
def _isolate_config(tmp_path, monkeypatch):
    """Point the config helper at a nonexistent file so the
    host's ~/.config/apigee-skills-demo/config.env doesn't leak
    in, and clear the cache between tests."""
    monkeypatch.setenv(
        "APIGEE_SKILLS_CONFIG_FILE",
        str(tmp_path / "nope.env"),
    )
    for k in ("APIGEE_ORG",):
        monkeypatch.delenv(k, raising=False)
    # The config helper is imported by top10 lazily; reach in
    # via the test-loaded module to clear its cache. Use a
    # sys.path-aware import that matches top10's dual-import.
    _REPO_ROOT_LOCAL = Path(__file__).resolve().parent.parent
    sys.path.insert(0, str(_REPO_ROOT_LOCAL))
    from scripts.common import config as _config
    _config.clear_cache()
    yield tmp_path
    _config.clear_cache()


def test_org_falls_back_to_env_var(
    top10_module, monkeypatch, capsys, _isolate_config
):
    """When --org isn't passed, APIGEE_ORG from the env wins."""
    monkeypatch.setenv("APIGEE_ORG", "from-env-org")

    captured = {}

    def fake_auth():
        return "tok", "p"

    def fake_list_proxies(token, org):
        captured["org"] = org
        return []  # empty list -> exits 1 before we hit XML

    monkeypatch.setattr(top10_module, "_auth", fake_auth)
    monkeypatch.setattr(top10_module, "_list_proxies", fake_list_proxies)
    monkeypatch.setattr(sys, "argv", ["top10.py"])

    with pytest.raises(SystemExit) as exc:
        top10_module.main()
    # zero proxies -> exit 1 per the existing contract
    assert exc.value.code == 1
    # The org that reached _list_proxies came from the env var.
    assert captured["org"] == "from-env-org"


def test_org_falls_back_to_config_file(
    top10_module, monkeypatch, capsys, _isolate_config
):
    """When --org isn't passed AND env is unset, the value in
    the config file wins. This is the agent-launched-without-env
    fix path."""
    cfg = _isolate_config / "config.env"
    cfg.write_text("APIGEE_ORG=from-file-org\n")
    # Point the helper at our test file. _isolate_config already
    # set APIGEE_SKILLS_CONFIG_FILE to a non-existent path; swap
    # it now.
    monkeypatch.setenv("APIGEE_SKILLS_CONFIG_FILE", str(cfg))
    # Re-clear the cache so the new file is read.
    from scripts.common import config as _config
    _config.clear_cache()

    # Re-load top10 so argparse re-evaluates its default. The
    # default is computed at parse_args time but argparse
    # captures the default at `add_argument` time -- which means
    # we need a fresh module to pick up the new config value.
    captured = {}

    def fake_auth():
        return "tok", "p"

    def fake_list_proxies(token, org):
        captured["org"] = org
        return []

    # Force the module to re-evaluate config.get() for the
    # default. argparse stores the default value when
    # add_argument runs, which is at main() time -- so a fresh
    # call to main() does re-read.
    monkeypatch.setattr(top10_module, "_auth", fake_auth)
    monkeypatch.setattr(top10_module, "_list_proxies", fake_list_proxies)
    monkeypatch.setattr(sys, "argv", ["top10.py"])

    with pytest.raises(SystemExit) as exc:
        top10_module.main()
    assert exc.value.code == 1
    assert captured["org"] == "from-file-org"


def test_org_explicit_flag_beats_config(
    top10_module, monkeypatch, capsys, _isolate_config
):
    """--org on the command line beats both env and config
    file. Standard precedence."""
    cfg = _isolate_config / "config.env"
    cfg.write_text("APIGEE_ORG=from-file-org\n")
    monkeypatch.setenv("APIGEE_SKILLS_CONFIG_FILE", str(cfg))
    monkeypatch.setenv("APIGEE_ORG", "from-env-org")
    from scripts.common import config as _config
    _config.clear_cache()

    captured = {}

    def fake_auth():
        return "tok", "p"

    def fake_list_proxies(token, org):
        captured["org"] = org
        return []

    monkeypatch.setattr(top10_module, "_auth", fake_auth)
    monkeypatch.setattr(top10_module, "_list_proxies", fake_list_proxies)
    monkeypatch.setattr(
        sys, "argv", ["top10.py", "--org", "from-flag-org"]
    )

    with pytest.raises(SystemExit) as exc:
        top10_module.main()
    assert exc.value.code == 1
    assert captured["org"] == "from-flag-org"


def test_org_missing_emits_failed_line_and_exits_2(
    top10_module, monkeypatch, capsys, _isolate_config
):
    """When --org cannot be resolved from any source, top10
    prints the ANNOUNCEMENT (first-line invariant holds) then a
    [apigee-policy-top10] FAILED line and exits 2."""
    # No env, no config file (the autouse fixture pointed at a
    # non-existent file). Also rig _auth and the network so any
    # accidental fall-through is loud rather than silent.
    monkeypatch.setattr(
        top10_module, "_auth",
        lambda: (_ for _ in ()).throw(
            RuntimeError("must not reach _auth when --org missing")
        ),
    )
    monkeypatch.setattr(sys, "argv", ["top10.py"])

    with pytest.raises(SystemExit) as exc:
        top10_module.main()
    assert exc.value.code == 2

    out = capsys.readouterr().out
    lines = out.splitlines()
    # Announcement is STILL the first line, even on config
    # failure. This is the invariant the production ordering
    # preserves.
    assert lines and lines[0] == top10_module.ANNOUNCEMENT
    # The FAILED line is the second non-empty line.
    failed_lines = [
        line for line in lines
        if "[apigee-policy-top10] config: FAILED" in line
    ]
    assert failed_lines, (
        f"expected a [apigee-policy-top10] config: FAILED line, "
        f"got: {out!r}"
    )
    fl = failed_lines[0]
    # The message must reference BOTH the env var and the config
    # file path so the operator can fix either route.
    assert "APIGEE_ORG" in fl
    assert "config.env" in fl
    assert "demo-setup.sh" in fl
