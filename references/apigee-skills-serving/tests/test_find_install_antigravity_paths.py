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
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or
# implied. See the License for the specific language governing
# permissions and limitations under the License.

"""Regression tests for the Antigravity dual-path detection in
``find_install.py``.

skill-finder must recognise BOTH Antigravity install layouts:

  * ``~/.gemini/antigravity/skills/`` — the layout that
    ``bin/install-skill-finder.sh`` and ``bin/provision.sh``
    install into (canonical / preferred).
  * ``~/.gemini/config/skills/`` — an older layout observed on
    some Antigravity builds.

Historically ``find_install.py`` only knew about the ``config``
path, so a skill-finder installed via the shipped installer
silently fell back to the OpenCode layout in
``_detect_skills_root`` and also lost its "agentic runtime"
classification in the reload-hint trailer.

These tests pin both invariants:

  1. ``_detect_skills_root`` returns the matched Antigravity root
     when the invocation lives under either path.
  2. ``_ANTIGRAVITY_ROOTS`` contains both paths, and the singular
     ``_ANTIGRAVITY_ROOT`` alias equals the canonical (first) entry.
"""

from __future__ import annotations

import importlib
import importlib.util
import sys
from pathlib import Path

import pytest


# Same import pattern as tests/test_find_install_multikey.py: load
# find_install.py by file path rather than package import, because
# it lives under skills/skill-finder/scripts/ which is not on
# sys.path by default.
_SCRIPTS_DIR = (
    Path(__file__).resolve().parent.parent
    / "skills" / "skill-finder" / "scripts"
)
_FIND_INSTALL_PY = _SCRIPTS_DIR / "find_install.py"


def _reload_find_install(monkeypatch: pytest.MonkeyPatch, fake_home: Path):
    """Load a fresh copy of find_install.py with HOME pointing at
    ``fake_home``.

    ``_ANTIGRAVITY_ROOTS`` and friends are computed at import time
    from ``Path.home()``, so each test that needs a distinct HOME
    layout must reload the module.
    """
    monkeypatch.setenv("HOME", str(fake_home))
    monkeypatch.delenv("APIGEE_SKILLS_INSTALL_ROOT", raising=False)
    # Force a completely fresh import so the module-level
    # `_ANTIGRAVITY_ROOTS = Path.home() / ...` expressions
    # re-evaluate against the freshly-set HOME.
    sys.modules.pop("find_install", None)
    spec = importlib.util.spec_from_file_location(
        "find_install", _FIND_INSTALL_PY
    )
    assert spec is not None and spec.loader is not None
    module = importlib.util.module_from_spec(spec)
    sys.modules["find_install"] = module
    spec.loader.exec_module(module)
    return module


@pytest.mark.parametrize(
    "relative_install_path",
    [
        # Canonical layout — matches install-skill-finder.sh +
        # provision.sh.
        ".gemini/antigravity/skills",
        # Legacy layout — must still be detected.
        ".gemini/config/skills",
    ],
    ids=["canonical", "legacy"],
)
def test_detect_skills_root_matches_both_antigravity_layouts(
    tmp_path: Path,
    monkeypatch: pytest.MonkeyPatch,
    relative_install_path: str,
) -> None:
    fake_home = tmp_path / "home"
    fake_home.mkdir()
    install_root = fake_home / relative_install_path
    install_root.mkdir(parents=True)
    skill_finder_dir = install_root / "skill-finder"
    (skill_finder_dir / "scripts").mkdir(parents=True)

    fi = _reload_find_install(monkeypatch, fake_home)

    # Simulate an invocation from inside the freshly-created
    # antigravity tree by pointing SKILL_DIR at skill_finder_dir
    # and re-running _detect_skills_root.
    monkeypatch.setattr(fi, "SKILL_DIR", skill_finder_dir)

    detected = fi._detect_skills_root()

    assert detected == install_root, (
        f"expected {install_root!r} for layout "
        f"{relative_install_path!r}, got {detected!r}"
    )


def test_antigravity_roots_contains_both_layouts(
    tmp_path: Path,
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    """``_ANTIGRAVITY_ROOTS`` must list both the canonical and
    the legacy Antigravity install paths.

    This is the invariant that the reload-hint trailer's
    ``is_agentic_runtime`` check in ``main`` relies on.
    """
    fake_home = tmp_path / "home"
    fake_home.mkdir()
    fi = _reload_find_install(monkeypatch, fake_home)

    canonical = fake_home / ".gemini" / "antigravity" / "skills"
    legacy = fake_home / ".gemini" / "config" / "skills"

    assert canonical in fi._ANTIGRAVITY_ROOTS
    assert legacy in fi._ANTIGRAVITY_ROOTS


def test_antigravity_root_alias_is_canonical(
    tmp_path: Path,
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    """The singular ``_ANTIGRAVITY_ROOT`` alias must equal the
    first (canonical) entry of ``_ANTIGRAVITY_ROOTS``.

    Callers that want the single canonical install path (e.g.
    dry-run reporting) rely on this alias. If the tuple ordering
    ever flips such that the legacy path comes first, we would
    silently start reporting the wrong path to operators.
    """
    fake_home = tmp_path / "home"
    fake_home.mkdir()
    fi = _reload_find_install(monkeypatch, fake_home)

    assert fi._ANTIGRAVITY_ROOT == fi._ANTIGRAVITY_ROOTS[0]
    assert fi._ANTIGRAVITY_ROOT == (
        fake_home / ".gemini" / "antigravity" / "skills"
    )
