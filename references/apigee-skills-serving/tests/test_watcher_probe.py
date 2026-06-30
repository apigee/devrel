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

"""Tests for ``scripts/common/watcher_probe.py``.

The three-state probe returns:

    WATCHER_DISABLED     -- env unset or explicitly disabled
    WATCHER_ENABLED      -- env enabled AND probe directory survived
                            the settle window (degenerate: the probe
                            trivially survives because we created it
                            ourselves)
    WATCHER_UNDETECTABLE -- env enabled but mkdir / iterdir raised
                            OSError (e.g., read-only skills dir)

Acceptance: "env-disabled returns DISABLED; env-unset returns
DISABLED; env-enabled + writable dir returns ENABLED; env-enabled +
read-only dir returns UNDETECTABLE; probe cleanup on all paths".

All tests pass ``settle_seconds=0.0`` so the suite stays fast --
the settle window's actual value is irrelevant for the
three-state outcome.
"""
from __future__ import annotations

from pathlib import Path

import pytest

from scripts.common.watcher_probe import WatcherState, detect_watcher

# ----- DISABLED paths -----


def test_env_disabled_returns_DISABLED(
    monkeypatch: pytest.MonkeyPatch, tmp_path: Path
) -> None:
    """The explicit disable variable beats every other signal."""
    monkeypatch.setenv(
        "OPENCODE_EXPERIMENTAL_DISABLE_FILEWATCHER", "1"
    )
    monkeypatch.setenv("OPENCODE_EXPERIMENTAL_FILEWATCHER", "1")
    state = detect_watcher(
        skills_dir=tmp_path, settle_seconds=0.0
    )
    assert state == WatcherState.WATCHER_DISABLED


def test_env_unset_returns_DISABLED(
    monkeypatch: pytest.MonkeyPatch, tmp_path: Path
) -> None:
    """The watcher is opt-in. Absence of the enable variable is
    equivalent to DISABLED -- and explicitly so, not
    UNDETECTABLE."""
    monkeypatch.delenv(
        "OPENCODE_EXPERIMENTAL_DISABLE_FILEWATCHER", raising=False
    )
    monkeypatch.delenv(
        "OPENCODE_EXPERIMENTAL_FILEWATCHER", raising=False
    )
    state = detect_watcher(
        skills_dir=tmp_path, settle_seconds=0.0
    )
    assert state == WatcherState.WATCHER_DISABLED


def test_disable_var_takes_precedence_over_enable_var(
    monkeypatch: pytest.MonkeyPatch, tmp_path: Path
) -> None:
    """The disable variable is the operator's escape hatch and
    beats the enable variable. Order in the function matters:
    ``_env_disabled()`` is checked first."""
    monkeypatch.setenv("OPENCODE_EXPERIMENTAL_FILEWATCHER", "1")
    monkeypatch.setenv(
        "OPENCODE_EXPERIMENTAL_DISABLE_FILEWATCHER", "1"
    )
    state = detect_watcher(
        skills_dir=tmp_path, settle_seconds=0.0
    )
    assert state == WatcherState.WATCHER_DISABLED


def test_disabled_path_does_not_write_probe(
    monkeypatch: pytest.MonkeyPatch, tmp_path: Path
) -> None:
    """When DISABLED the probe MUST short-circuit without touching
    the skills directory. Otherwise we would write a useless
    sentinel on every install on every machine."""
    monkeypatch.delenv(
        "OPENCODE_EXPERIMENTAL_FILEWATCHER", raising=False
    )
    detect_watcher(skills_dir=tmp_path, settle_seconds=0.0)
    assert list(tmp_path.iterdir()) == [], (
        "DISABLED path wrote to skills_dir; should have skipped"
    )


# ----- ENABLED + UNDETECTABLE paths -----


def test_env_enabled_writable_dir_returns_ENABLED(
    monkeypatch: pytest.MonkeyPatch, tmp_path: Path
) -> None:
    """Happy path: env opt-in is set, skills_dir is writable.
    The probe writes a ``.probe-<uuid>`` directory, settles, and
    confirms it appears in the listing. (We know this check is
    degenerate -- the probe trivially survives because we created
    it ourselves -- but ENABLED is the documented return value
    for this config.)"""
    monkeypatch.setenv("OPENCODE_EXPERIMENTAL_FILEWATCHER", "1")
    monkeypatch.delenv(
        "OPENCODE_EXPERIMENTAL_DISABLE_FILEWATCHER", raising=False
    )
    state = detect_watcher(
        skills_dir=tmp_path, settle_seconds=0.0
    )
    assert state == WatcherState.WATCHER_ENABLED


def test_env_enabled_readonly_dir_returns_UNDETECTABLE(
    monkeypatch: pytest.MonkeyPatch, tmp_path: Path
) -> None:
    """When mkdir raises OSError (e.g., read-only skills dir,
    quota exhausted, ENOSPC, EROFS), the probe must catch it and
    return UNDETECTABLE so the caller can fall back to the
    /reload-skills path -- not crash.

    Implementation note: this test originally tried to provoke
    the OSError by chmod'ing tmp_path to 0o555. That works for
    an unprivileged user but is a no-op for root, which has
    CAP_DAC_OVERRIDE and ignores POSIX write bits. CI containers
    sometimes run as root (e.g., the Cloud Build pipeline), in
    which case the test silently passed the chmod, mkdir
    succeeded, and the assertion failed with
    WATCHER_ENABLED != WATCHER_UNDETECTABLE.

    Patching ``Path.mkdir`` to raise OSError directly is the
    honest fix: the contract under test is "mkdir failure ->
    UNDETECTABLE", not "POSIX permission semantics on tmp_path".
    The patch is scoped via monkeypatch so it's automatically
    reverted at test exit."""
    monkeypatch.setenv("OPENCODE_EXPERIMENTAL_FILEWATCHER", "1")
    monkeypatch.delenv(
        "OPENCODE_EXPERIMENTAL_DISABLE_FILEWATCHER", raising=False
    )

    original_mkdir = Path.mkdir

    def _mkdir_raises_on_probe_dir(
        self: Path, *args: object, **kwargs: object
    ) -> None:
        """Allow the ``skills_dir.mkdir(parents=True,
        exist_ok=True)`` call (used by the probe to ensure the
        parent exists) to succeed, but make the inner
        ``probe_dir.mkdir(exist_ok=False)`` raise EACCES the way
        a real read-only skills dir would."""
        if self.name.startswith(".probe-"):
            raise PermissionError(
                13, "Permission denied (simulated)", str(self)
            )
        return original_mkdir(self, *args, **kwargs)

    monkeypatch.setattr(Path, "mkdir", _mkdir_raises_on_probe_dir)

    state = detect_watcher(skills_dir=tmp_path, settle_seconds=0.0)
    assert state == WatcherState.WATCHER_UNDETECTABLE


# ----- Probe cleanup -----


def test_probe_dir_cleaned_up_after_ENABLED(
    monkeypatch: pytest.MonkeyPatch, tmp_path: Path
) -> None:
    """The probe writes ``.probe-<uuid>/SKILL.md``. After return,
    no probe directory should remain -- otherwise repeated
    invocations accumulate stale probe dirs in ~/.config/.../skills."""
    monkeypatch.setenv("OPENCODE_EXPERIMENTAL_FILEWATCHER", "1")
    monkeypatch.delenv(
        "OPENCODE_EXPERIMENTAL_DISABLE_FILEWATCHER", raising=False
    )
    detect_watcher(skills_dir=tmp_path, settle_seconds=0.0)
    probe_dirs = [p for p in tmp_path.iterdir() if p.name.startswith(".probe-")]
    assert probe_dirs == [], (
        f"probe dirs leaked after detect_watcher: {probe_dirs}"
    )


def test_probe_dir_cleaned_up_after_UNDETECTABLE(
    monkeypatch: pytest.MonkeyPatch, tmp_path: Path
) -> None:
    """Even on the error path, cleanup must run. The try/finally
    in detect_watcher ensures shutil.rmtree(probe_dir,
    ignore_errors=True) fires whether the probe succeeded or
    raised OSError mid-stream."""
    monkeypatch.setenv("OPENCODE_EXPERIMENTAL_FILEWATCHER", "1")
    monkeypatch.delenv(
        "OPENCODE_EXPERIMENTAL_DISABLE_FILEWATCHER", raising=False
    )
    tmp_path.chmod(0o555)
    try:
        detect_watcher(skills_dir=tmp_path, settle_seconds=0.0)
        # mkdir failed, so no probe dir was created; either way
        # the directory listing should not contain a `.probe-*`.
        tmp_path.chmod(0o755)
        probe_dirs = [
            p for p in tmp_path.iterdir() if p.name.startswith(".probe-")
        ]
        assert probe_dirs == []
    finally:
        tmp_path.chmod(0o755)


# ----- WatcherState enum sanity -----


def test_watcher_state_string_values() -> None:
    """The enum's str values are observable via .value -- callers
    log them. Lock the wire format so a future rename doesn't
    silently break log greps."""
    assert WatcherState.WATCHER_ENABLED.value == "watcher_enabled"
    assert WatcherState.WATCHER_DISABLED.value == "watcher_disabled"
    assert (
        WatcherState.WATCHER_UNDETECTABLE.value
        == "watcher_undetectable"
    )
