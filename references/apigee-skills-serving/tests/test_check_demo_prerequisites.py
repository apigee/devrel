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

"""Pre-flight env-var checker tests.

``bin/check-prerequisites.sh`` is the operator's last-mile gate
before a live demo. It iterates the required environment variables
and emits one ``[prereq]`` log line per variable so the operator
can see exactly what passed, what failed, and what was advisory.

Required behaviour (all locked by these tests):

* If every operator-controlled required var is set AND ADC tokens
  are retrievable, exit 0 and final line says ``PASS``.
* If any one of {``APIHUB_PROJECT``, ``APIHUB_LOCATION``,
  ``APIGEE_ORG``} is unset or empty, that produces a
  ``[prereq] FAILED`` line and exit 1.
* If ``APIGEE_SKILLS_MIN_KEYWORD_OVERLAP`` is set to a non-positive-
  int string, the script emits a ``[prereq] WARNING`` advisory
  line but does NOT fail; the runtime falls back to default 1
  silently.
* If ``APIGEE_SKILLS_MIN_KEYWORD_OVERLAP`` is unset, the script
  emits no warning for that variable.
* If ADC tokens cannot be retrieved (mocked via fake ``gcloud``
  shim that exits non-zero), the script emits the ADC FAILED
  line and exits 1 even if everything else is fine.
* Watcher overrides (``OPENCODE_EXPERIMENTAL_FILEWATCHER`` and
  ``OPENCODE_EXPERIMENTAL_DISABLE_FILEWATCHER``) and framework-
  provided vars (``ARGUMENTS``, ``SKILL_DIR``, ``OPENCODE_AGENT``)
  are advisory only -- their absence never fails the script.
"""
from __future__ import annotations

import os
import stat
import subprocess
from pathlib import Path

import pytest

_REPO_ROOT = Path(__file__).resolve().parent.parent
_SCRIPT = _REPO_ROOT / "bin" / "check-prerequisites.sh"

# Minimal env that the script's pre-flight considers "valid".
# Includes the three operator-required vars + a path-injectable
# stub gcloud shim. We intentionally do NOT set the watcher,
# framework, or optional vars: those are advisory by spec.
_BASE_OK_ENV = {
    "APIHUB_PROJECT": "demo-project-123",
    "APIHUB_LOCATION": "us-central1",
    "APIGEE_ORG": "demo-apigee-org",
    # Required for the script itself to find sh, awk, etc.:
    "HOME": str(Path.home()),
    "LANG": "C.UTF-8",
}


def _write_fake_gcloud(
    tmp_path: Path, exit_code: int
) -> Path:
    """Create an executable shim at ``tmp_path/bin/gcloud`` that
    swallows all args and exits with *exit_code*. The directory
    returned is what the test prepends to ``PATH`` for the
    subprocess invocation -- the real ``gcloud`` (if any) never
    runs.
    """
    bindir = tmp_path / "bin"
    bindir.mkdir(parents=True, exist_ok=True)
    shim = bindir / "gcloud"
    shim.write_text(f"#!/bin/sh\nexit {exit_code}\n")
    shim.chmod(
        shim.stat().st_mode | stat.S_IXUSR | stat.S_IXGRP | stat.S_IXOTH
    )
    return bindir


def _run(env: dict[str, str]) -> subprocess.CompletedProcess[str]:
    """Invoke the prereq script with a hermetic env -- nothing
    leaks in from the test runner's own environment."""
    assert _SCRIPT.is_file(), (
        f"missing pre-flight script {_SCRIPT}"
    )
    # Belt-and-braces: the script may rely on a few non-listed
    # PATH entries (/bin, /usr/bin) for awk/cut. The caller
    # prepends a fake-gcloud dir to whatever PATH we pass.
    return subprocess.run(
        ["bash", str(_SCRIPT)],
        env=env,
        capture_output=True,
        text=True,
        check=False,
    )


# --------------------------------------------------------------- #
# Happy path
# --------------------------------------------------------------- #

def test_all_required_set_and_adc_ok_exits_zero(
    tmp_path: Path,
) -> None:
    fake_bin = _write_fake_gcloud(tmp_path, 0)
    env = dict(_BASE_OK_ENV)
    env["PATH"] = f"{fake_bin}:/usr/bin:/bin"
    result = _run(env)
    assert result.returncode == 0, (
        f"expected exit 0 with all prereqs OK; "
        f"got {result.returncode}\nstdout:\n{result.stdout}"
        f"\nstderr:\n{result.stderr}"
    )
    # Every required var should produce its own line.
    for var in ("APIHUB_PROJECT", "APIHUB_LOCATION", "APIGEE_ORG"):
        assert var in result.stdout, (
            f"missing [prereq] line for {var}"
        )
    assert "[prereq] OK" in result.stdout, (
        "expected at least one explicit OK marker"
    )
    assert "[prereq] PASS" in result.stdout, (
        "expected final PASS summary line"
    )


# --------------------------------------------------------------- #
# Required vars: unset / empty -> FAILED + exit 1
# --------------------------------------------------------------- #

@pytest.mark.parametrize(
    "missing_var",
    ["APIHUB_PROJECT", "APIHUB_LOCATION", "APIGEE_ORG"],
)
def test_required_var_unset_fails(
    tmp_path: Path, missing_var: str
) -> None:
    fake_bin = _write_fake_gcloud(tmp_path, 0)
    env = dict(_BASE_OK_ENV)
    env["PATH"] = f"{fake_bin}:/usr/bin:/bin"
    env.pop(missing_var, None)
    result = _run(env)
    assert result.returncode == 1, (
        f"expected exit 1 when {missing_var} unset; "
        f"got {result.returncode}\nstdout:\n{result.stdout}"
    )
    assert "FAILED" in result.stdout, (
        f"expected a FAILED line when {missing_var} unset"
    )
    assert missing_var in result.stdout, (
        f"FAILED line must name {missing_var} verbatim"
    )


@pytest.mark.parametrize(
    "empty_var",
    ["APIHUB_PROJECT", "APIHUB_LOCATION", "APIGEE_ORG"],
)
def test_required_var_empty_string_fails(
    tmp_path: Path, empty_var: str
) -> None:
    """An empty string is just as bad as unset: §2.9 contract
    rejects both with the same FAILED line."""
    fake_bin = _write_fake_gcloud(tmp_path, 0)
    env = dict(_BASE_OK_ENV)
    env["PATH"] = f"{fake_bin}:/usr/bin:/bin"
    env[empty_var] = ""
    result = _run(env)
    assert result.returncode == 1
    assert "FAILED" in result.stdout
    assert empty_var in result.stdout


# --------------------------------------------------------------- #
# APIGEE_SKILLS_MIN_KEYWORD_OVERLAP (advisory)
# --------------------------------------------------------------- #

def test_keyword_overlap_unset_no_warning(tmp_path: Path) -> None:
    """Unset is fine -- runtime defaults to 1 silently. No
    advisory line should mention it."""
    fake_bin = _write_fake_gcloud(tmp_path, 0)
    env = dict(_BASE_OK_ENV)
    env["PATH"] = f"{fake_bin}:/usr/bin:/bin"
    env.pop("APIGEE_SKILLS_MIN_KEYWORD_OVERLAP", None)
    result = _run(env)
    assert result.returncode == 0
    assert "WARNING" not in result.stdout or (
        "APIGEE_SKILLS_MIN_KEYWORD_OVERLAP" not in
        " ".join(
            line for line in result.stdout.splitlines()
            if "WARNING" in line
        )
    ), (
        "unset APIGEE_SKILLS_MIN_KEYWORD_OVERLAP must not produce "
        "a WARNING line"
    )


def test_keyword_overlap_malformed_warns_but_does_not_fail(
    tmp_path: Path,
) -> None:
    """Bad value -> advisory WARNING line, but exit still 0
    because the fallback is silent at runtime."""
    fake_bin = _write_fake_gcloud(tmp_path, 0)
    env = dict(_BASE_OK_ENV)
    env["PATH"] = f"{fake_bin}:/usr/bin:/bin"
    env["APIGEE_SKILLS_MIN_KEYWORD_OVERLAP"] = "not-an-int"
    result = _run(env)
    assert result.returncode == 0, (
        f"malformed APIGEE_SKILLS_MIN_KEYWORD_OVERLAP must not "
        f"fail the script; got exit {result.returncode}\n"
        f"stdout:\n{result.stdout}"
    )
    assert "WARNING" in result.stdout
    assert "APIGEE_SKILLS_MIN_KEYWORD_OVERLAP" in result.stdout
    assert "not-an-int" in result.stdout, (
        "WARNING line should echo the raw bad value"
    )


def test_keyword_overlap_zero_is_malformed(tmp_path: Path) -> None:
    """0 is not a positive int: §2.9 says positive."""
    fake_bin = _write_fake_gcloud(tmp_path, 0)
    env = dict(_BASE_OK_ENV)
    env["PATH"] = f"{fake_bin}:/usr/bin:/bin"
    env["APIGEE_SKILLS_MIN_KEYWORD_OVERLAP"] = "0"
    result = _run(env)
    assert result.returncode == 0
    assert "WARNING" in result.stdout
    assert "APIGEE_SKILLS_MIN_KEYWORD_OVERLAP" in result.stdout


def test_keyword_overlap_positive_int_ok(tmp_path: Path) -> None:
    fake_bin = _write_fake_gcloud(tmp_path, 0)
    env = dict(_BASE_OK_ENV)
    env["PATH"] = f"{fake_bin}:/usr/bin:/bin"
    env["APIGEE_SKILLS_MIN_KEYWORD_OVERLAP"] = "2"
    result = _run(env)
    assert result.returncode == 0
    # Either no warning at all about this var, or only OK/INFO:
    bad_lines = [
        line for line in result.stdout.splitlines()
        if "WARNING" in line
        and "APIGEE_SKILLS_MIN_KEYWORD_OVERLAP" in line
    ]
    assert not bad_lines, (
        f"positive-int value must not warn; got: {bad_lines}"
    )


# --------------------------------------------------------------- #
# ADC
# --------------------------------------------------------------- #

def test_adc_unavailable_fails(tmp_path: Path) -> None:
    """Fake gcloud exits 1 -> ADC token unobtainable -> FAILED."""
    fake_bin = _write_fake_gcloud(tmp_path, 1)
    env = dict(_BASE_OK_ENV)
    env["PATH"] = f"{fake_bin}:/usr/bin:/bin"
    result = _run(env)
    assert result.returncode == 1, (
        f"expected exit 1 when ADC unavailable; "
        f"got {result.returncode}\nstdout:\n{result.stdout}"
    )
    assert "ADC" in result.stdout
    assert "FAILED" in result.stdout
    # Operator-facing remediation hint should appear:
    assert "gcloud auth application-default" in result.stdout.lower() \
        or "gcloud auth application-default" in result.stdout, (
        "ADC FAILED line should hint at the remediation command"
    )


# --------------------------------------------------------------- #
# Watcher + framework advisory vars
# --------------------------------------------------------------- #

def test_watcher_overrides_absent_never_fail(tmp_path: Path) -> None:
    """The two watcher override vars are optional; their absence
    must never affect the exit code."""
    fake_bin = _write_fake_gcloud(tmp_path, 0)
    env = dict(_BASE_OK_ENV)
    env["PATH"] = f"{fake_bin}:/usr/bin:/bin"
    env.pop("OPENCODE_EXPERIMENTAL_FILEWATCHER", None)
    env.pop("OPENCODE_EXPERIMENTAL_DISABLE_FILEWATCHER", None)
    result = _run(env)
    assert result.returncode == 0


def test_framework_vars_absent_emit_info(tmp_path: Path) -> None:
    """``ARGUMENTS`` and ``SKILL_DIR`` are set by OpenCode at
    injection time. Pre-flight cannot verify them but should
    report them so the operator knows they're known-deferred."""
    fake_bin = _write_fake_gcloud(tmp_path, 0)
    env = dict(_BASE_OK_ENV)
    env["PATH"] = f"{fake_bin}:/usr/bin:/bin"
    env.pop("ARGUMENTS", None)
    env.pop("SKILL_DIR", None)
    result = _run(env)
    assert result.returncode == 0
    assert "ARGUMENTS" in result.stdout
    assert "SKILL_DIR" in result.stdout
    # We don't lock the exact verb (INFO / NOTE / DEFERRED) -- the
    # key invariant is "mentioned and didn't fail":
    info_lines = [
        line for line in result.stdout.splitlines()
        if "ARGUMENTS" in line or "SKILL_DIR" in line
    ]
    assert info_lines, "framework vars must produce visible lines"
    assert not any("FAILED" in l for l in info_lines), (
        f"framework vars must not produce FAILED lines: {info_lines}"
    )


# --------------------------------------------------------------- #
# Idempotency / stable output
# --------------------------------------------------------------- #

def test_output_is_stable_across_invocations(
    tmp_path: Path,
) -> None:
    """The script MUST be idempotent and produce stable output.
    Two back-to-back invocations with identical env produce
    identical stdout."""
    fake_bin = _write_fake_gcloud(tmp_path, 0)
    env = dict(_BASE_OK_ENV)
    env["PATH"] = f"{fake_bin}:/usr/bin:/bin"
    a = _run(env).stdout
    b = _run(env).stdout
    assert a == b, (
        "pre-flight output must be stable across invocations; "
        f"first:\n{a}\nsecond:\n{b}"
    )
