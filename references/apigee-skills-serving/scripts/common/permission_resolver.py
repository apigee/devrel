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

"""Resolve effective ``skill`` tool permission for a given skill
name and active OpenCode agent.

Reads the documented OpenCode permission chain:

    global  ~/.config/opencode/opencode.json
    project ./opencode.json
    agent.<name>.permission.skill.*   (overrides)
    agent.<name>.tools.skill: false   (absolute deny)

Project overlays onto global; per-agent overrides overlay onto
the merged config. ``tools.skill: false`` is the absolute-deny
escape hatch and beats every pattern. Pattern matching uses
``fnmatch`` (glob-style); first match in dict insertion order
wins.

Public surface:
    Verdict (enum)
    Resolution (dataclass)
    resolve_skill_permission(skill_name, active_agent="build")
    detect_active_agent()

Module-level constants ``GLOBAL_OPENCODE_JSON`` and
``PROJECT_OPENCODE_JSON`` capture the paths at import time. Tests
that need to redirect them monkeypatch the constants -- the
resolver re-reads them on every call so the patches take effect
without reloading the module.
"""
from __future__ import annotations

import fnmatch
import json
import os
from dataclasses import dataclass
from enum import Enum
from pathlib import Path
from typing import Any


GLOBAL_OPENCODE_JSON = (
    Path.home() / ".config" / "opencode" / "opencode.json"
)
PROJECT_OPENCODE_JSON = Path.cwd() / "opencode.json"


class Verdict(str, Enum):
    """Possible permission outcomes. Mirrors OpenCode's
    documented permission actions for the ``skill`` tool."""

    ALLOW = "allow"
    DENY = "deny"
    ASK = "ask"


@dataclass(frozen=True)
class Resolution:
    r"""The resolved verdict plus enough provenance for the
    failure-line ``[apigee-skills] agent \`skill\` tool: …``
    family to be self-explanatory.

    ``source`` is one of:
        "default"               -- no rule matched; fell to the
                                   OpenCode default ALLOW
        "tools.skill=false"     -- agent absolute-deny hatch fired
        f"pattern:{pattern}"    -- a pattern matched; ``pattern``
                                   is the glob-style key
    """

    verdict: Verdict
    matched_pattern: str | None
    source: str


def _read_json(path: Path) -> dict[str, Any]:
    """Read a JSON config file. Absent file returns ``{}``;
    malformed file raises RuntimeError with the path embedded so
    the operator knows which file to fix."""
    try:
        return json.loads(path.read_text())
    except FileNotFoundError:
        return {}
    except json.JSONDecodeError as e:
        raise RuntimeError(
            f"opencode.json at {path} is not valid JSON: {e}"
        ) from e


def _deep_merge(base: dict, overlay: dict) -> dict:
    """Recursive dict merge: overlay's keys win, except when
    both sides carry a dict at the same key, in which case the
    merge recurses. Lists are replaced wholesale, not appended.

    Caller passes ``global_cfg`` as base and ``project_cfg`` as
    overlay so project settings take precedence."""
    result = dict(base)
    for key, val in overlay.items():
        if (
            key in result
            and isinstance(result[key], dict)
            and isinstance(val, dict)
        ):
            result[key] = _deep_merge(result[key], val)
        else:
            result[key] = val
    return result


def _match_pattern(
    patterns: dict[str, str], skill_name: str
) -> Resolution | None:
    """Match ``skill_name`` against the pattern map. First match
    wins, iterating in dict insertion order (Python 3.7+ guaranteed
    stable). Returns ``None`` if no pattern matched."""
    for pattern, action in patterns.items():
        if fnmatch.fnmatchcase(skill_name, pattern):
            try:
                v = Verdict(action)
            except ValueError as e:
                raise RuntimeError(
                    f"Unknown permission action '{action}' "
                    f"for pattern '{pattern}'"
                ) from e
            return Resolution(
                verdict=v,
                matched_pattern=pattern,
                source=f"pattern:{pattern}",
            )
    return None


def resolve_skill_permission(
    skill_name: str,
    active_agent: str = "build",
) -> Resolution:
    """Resolve the effective ``skill`` tool permission for
    *skill_name* under *active_agent*.

    Order of evaluation:
        1. Load global and project configs separately; also
           compute their deep-merged view for the agent-config
           lookup.
        2. Collect three pattern sources separately, each from its
           own ``permission.skill.*`` map:
             - per-agent (from the merged agent config)
             - project-level
             - global-level
        3. Build a single pattern map by inserting agent patterns
           first, then ``setdefault``-ing project patterns, then
           ``setdefault``-ing global patterns. This preserves the
           precedence ``agent > project > global`` (because
           ``setdefault`` is a no-op when the key already exists)
           AND preserves dict insertion order so the
           ``_match_pattern`` first-match-wins iteration walks
           higher-precedence rules first.
        4. If ``agent.<name>.tools.skill`` is ``False``, return
           DENY with source ``tools.skill=false``. The escape
           hatch beats any matching pattern.
        5. Iterate the assembled pattern map (first-match wins).
        6. If nothing matched, return ALLOW with source
           ``default`` -- OpenCode's documented behavior for
           the build agent.

    Implementation note: the original deep-merge approach
    collapsed global and project pattern maps into one dict,
    which lost per-source precedence at the pattern level (a
    global ``*: deny`` inserted before a project ``apigee-*:
    allow`` would beat it on dict iteration order). The
    setdefault cascade above keeps the three sources distinct.
    """
    global_cfg = _read_json(GLOBAL_OPENCODE_JSON)
    project_cfg = _read_json(PROJECT_OPENCODE_JSON)
    merged = _deep_merge(global_cfg, project_cfg)

    # Per-agent overrides take the highest precedence among
    # pattern sources. The override map (per active agent) is
    # tried first, then the project-level patterns (which beat
    # global), then the global patterns. Because `_match_pattern`
    # is first-match-wins by dict insertion order, we insert in
    # that order without overwriting later-insertion (earlier
    # precedence) entries.
    agent_cfg = merged.get("agent", {}).get(active_agent, {})
    agent_patterns: dict[str, str] = dict(
        agent_cfg.get("permission", {}).get("skill", {})
    )
    project_patterns: dict[str, str] = dict(
        project_cfg.get("permission", {}).get("skill", {})
    )
    global_patterns: dict[str, str] = dict(
        global_cfg.get("permission", {}).get("skill", {})
    )

    patterns: dict[str, str] = dict(agent_patterns)
    for pat, action in project_patterns.items():
        patterns.setdefault(pat, action)
    for pat, action in global_patterns.items():
        patterns.setdefault(pat, action)

    # Absolute deny via tools.skill: false. Checked AFTER
    # patterns are assembled so the source string is correct,
    # but BEFORE any pattern is evaluated so the escape hatch
    # wins.
    if agent_cfg.get("tools", {}).get("skill") is False:
        return Resolution(
            verdict=Verdict.DENY,
            matched_pattern=None,
            source="tools.skill=false",
        )

    match = _match_pattern(patterns, skill_name)
    if match is not None:
        return match

    # OpenCode's documented default for the build agent is ALLOW.
    return Resolution(
        verdict=Verdict.ALLOW,
        matched_pattern=None,
        source="default",
    )


def detect_active_agent() -> str:
    """Best-effort active-agent detection. OpenCode sets
    ``OPENCODE_AGENT`` in the subprocess environment for tool
    calls. Falls back to ``"build"`` (OpenCode's default agent)
    so a missing env var degrades safely rather than crashing."""
    return os.environ.get("OPENCODE_AGENT", "build")
