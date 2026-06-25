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

"""OpenCode file-watcher state detector.

Returns one of three states:

    WATCHER_ENABLED      -- the watcher is on and the probe
                            directory survived the settle window
    WATCHER_DISABLED     -- env var unset or explicitly disabled
    WATCHER_UNDETECTABLE -- env var on but the probe could not
                            run (read-only skills dir, etc.);
                            caller falls back to /reload-skills

Honest disclosure: the current ENABLED check is degenerate --
the probe directory always survives because the probe itself
created it. The real value of this function today is (a) the
env-var presence signal and (b) the OSError catch that makes
UNDETECTABLE reachable for the failure-line surface. A future
improvement (out of scope for the demo) would replace the
directory-presence check with a real watcher-response check
(e.g., wait for an OpenCode reload signal).
"""
from __future__ import annotations

import os
import shutil
import time
import uuid
from enum import Enum
from pathlib import Path

SKILLS_DIR = Path.home() / ".config" / "opencode" / "skills"
PROBE_SETTLE_SECONDS = 2.0

MINIMAL_PROBE_FRONTMATTER = """---
name: __probe__
description: Internal probe written by the loader. Safe to delete.
compatibility: opencode
---
# Internal probe
"""


class WatcherState(str, Enum):
    """Three-state outcome of the file-watcher detection.

    The string values (``"watcher_enabled"`` etc.) are observable
    via ``.value`` and appear in operator log lines. Treat them
    as part of the contract surface even though the values
    themselves don't appear in the failure-line family -- a
    future log line that prints ``state.value`` would lock
    these strings."""

    WATCHER_ENABLED = "watcher_enabled"
    WATCHER_DISABLED = "watcher_disabled"
    WATCHER_UNDETECTABLE = "watcher_undetectable"


def _env_disabled() -> bool:
    """The operator's explicit-off override.
    ``OPENCODE_EXPERIMENTAL_DISABLE_FILEWATCHER=1`` forces
    DISABLED regardless of the enable variable. Used in
    environments where the watcher misbehaves (NFS-mounted
    skills dirs, container layers without inotify, etc.)."""
    return (
        os.environ.get(
            "OPENCODE_EXPERIMENTAL_DISABLE_FILEWATCHER", ""
        )
        == "1"
    )


def _env_enabled() -> bool:
    """The watcher is opt-in via
    ``OPENCODE_EXPERIMENTAL_FILEWATCHER=1``. Absence (the
    default) means DISABLED."""
    return (
        os.environ.get("OPENCODE_EXPERIMENTAL_FILEWATCHER", "")
        == "1"
    )


def detect_watcher(
    skills_dir: Path = SKILLS_DIR,
    settle_seconds: float = PROBE_SETTLE_SECONDS,
) -> WatcherState:
    """Run the three-state probe and return the result.

    Algorithm:

        1. If the explicit-disable env var is set, return DISABLED
           without writing anything.
        2. If the enable env var is unset, return DISABLED without
           writing anything (default).
        3. Otherwise, mkdir a ``.probe-<uuid>`` directory under
           ``skills_dir``, write a minimal SKILL.md inside, sleep
           ``settle_seconds`` to let any watcher react, and check
           whether the directory still appears in
           ``skills_dir.iterdir()``.
        4. On any OSError (mkdir failure, write failure, etc.)
           return UNDETECTABLE.
        5. Cleanup runs in a ``finally`` so the probe directory
           never leaks even on the error path.

    Step 3's directory-existence check is degenerate by
    construction (we created the directory; of course it
    survives). See module docstring for the honest disclosure
    on why we keep it anyway.
    """
    if _env_disabled():
        return WatcherState.WATCHER_DISABLED
    if not _env_enabled():
        return WatcherState.WATCHER_DISABLED

    probe_name = f".probe-{uuid.uuid4().hex}"
    probe_dir = skills_dir / probe_name
    probe_skill = probe_dir / "SKILL.md"
    try:
        skills_dir.mkdir(parents=True, exist_ok=True)
        probe_dir.mkdir(exist_ok=False)
        probe_skill.write_text(MINIMAL_PROBE_FRONTMATTER)
        time.sleep(settle_seconds)
        listed = {p.name for p in skills_dir.iterdir()}
        if probe_dir.name in listed:
            return WatcherState.WATCHER_ENABLED
        return WatcherState.WATCHER_UNDETECTABLE
    except OSError:
        return WatcherState.WATCHER_UNDETECTABLE
    finally:
        shutil.rmtree(probe_dir, ignore_errors=True)
