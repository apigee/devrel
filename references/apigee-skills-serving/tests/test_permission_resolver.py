"""Tests for ``scripts/common/permission_resolver.py``.

The resolver reads OpenCode's documented permission chain: global
``~/.config/opencode/opencode.json``, project ``./opencode.json``,
per-agent ``permission.skill.*`` overrides, and the absolute-deny
escape hatch ``agent.<name>.tools.skill: false``. The acceptance
criteria are: "default allow, tools.skill=false override, pattern
precedence, agent override".

The implementation in IMPL_DETAILS resolves
``GLOBAL_OPENCODE_JSON`` and ``PROJECT_OPENCODE_JSON`` at import
time, which makes tests that need to redirect them tricky. We
test the public behavior by monkeypatching the module-level
constants in each test that needs an isolated config tree.
"""
from __future__ import annotations

import json
from pathlib import Path

import pytest

from scripts.common import permission_resolver as pr
from scripts.common.permission_resolver import (
    Resolution,
    Verdict,
    detect_active_agent,
    resolve_skill_permission,
)


@pytest.fixture
def isolated_config_paths(
    tmp_path: Path, monkeypatch: pytest.MonkeyPatch
) -> tuple[Path, Path]:
    """Redirect ``GLOBAL_OPENCODE_JSON`` and
    ``PROJECT_OPENCODE_JSON`` into ``tmp_path`` for the duration
    of the test. Returns ``(global_path, project_path)`` so the
    test can write config files at known locations without
    touching the user's real ``~/.config``."""
    global_path = tmp_path / "global" / "opencode.json"
    project_path = tmp_path / "project" / "opencode.json"
    global_path.parent.mkdir(parents=True, exist_ok=True)
    project_path.parent.mkdir(parents=True, exist_ok=True)
    monkeypatch.setattr(pr, "GLOBAL_OPENCODE_JSON", global_path)
    monkeypatch.setattr(pr, "PROJECT_OPENCODE_JSON", project_path)
    return global_path, project_path


def _write(path: Path, cfg: dict) -> None:
    path.write_text(json.dumps(cfg))


# ----- Default + empty-config behaviour -----


def test_default_allow_when_no_config_files(
    isolated_config_paths: tuple[Path, Path],
) -> None:
    """Both opencode.json files absent: OpenCode's documented
    default for the build agent is ALLOW. Source is 'default' so
    operators can grep for unconfigured installs."""
    r = resolve_skill_permission("apigee-policy-top10")
    assert r == Resolution(
        verdict=Verdict.ALLOW, matched_pattern=None, source="default"
    )


def test_default_allow_when_configs_are_empty_dicts(
    isolated_config_paths: tuple[Path, Path],
) -> None:
    """Empty ``{}`` files MUST behave identically to absent
    files. Otherwise an operator who creates the file to make a
    single tweak and then deletes the tweak gets a different
    verdict than before they ever touched it."""
    global_path, project_path = isolated_config_paths
    _write(global_path, {})
    _write(project_path, {})
    r = resolve_skill_permission("any-skill")
    assert r.verdict == Verdict.ALLOW
    assert r.source == "default"


# ----- Global vs project precedence -----


def test_global_pattern_allow_matches(
    isolated_config_paths: tuple[Path, Path],
) -> None:
    global_path, _ = isolated_config_paths
    _write(global_path, {"permission": {"skill": {"*": "allow"}}})
    r = resolve_skill_permission("anything")
    assert r.verdict == Verdict.ALLOW
    assert r.matched_pattern == "*"
    assert r.source == "pattern:*"


def test_global_pattern_deny_matches(
    isolated_config_paths: tuple[Path, Path],
) -> None:
    global_path, _ = isolated_config_paths
    _write(global_path, {"permission": {"skill": {"*": "deny"}}})
    r = resolve_skill_permission("anything")
    assert r.verdict == Verdict.DENY
    assert r.matched_pattern == "*"


def test_project_pattern_overrides_global(
    isolated_config_paths: tuple[Path, Path],
) -> None:
    """Per §2.3 project config overlays onto global. A
    project-level ``apigee-*: allow`` MUST beat a global ``*:
    deny`` for skills matching ``apigee-*``. This is the canonical
    'team unlocks a specific skill family' workflow."""
    global_path, project_path = isolated_config_paths
    _write(global_path, {"permission": {"skill": {"*": "deny"}}})
    _write(
        project_path,
        {"permission": {"skill": {"apigee-*": "allow"}}},
    )
    r = resolve_skill_permission("apigee-policy-top10")
    assert r.verdict == Verdict.ALLOW
    assert r.matched_pattern == "apigee-*"


def test_first_pattern_in_dict_order_wins(
    isolated_config_paths: tuple[Path, Path],
) -> None:
    """Python 3.7+ preserves dict insertion order. The resolver
    documents 'first match wins iterating in dict insertion
    order' so operators can reason about precedence by reading
    the JSON top-to-bottom."""
    global_path, _ = isolated_config_paths
    _write(
        global_path,
        {
            "permission": {
                "skill": {"apigee-*": "allow", "*": "deny"}
            }
        },
    )
    r = resolve_skill_permission("apigee-x")
    assert r.verdict == Verdict.ALLOW
    # And a skill that doesn't match apigee-* falls to the
    # second pattern.
    r2 = resolve_skill_permission("other-skill")
    assert r2.verdict == Verdict.DENY


# ----- Per-agent overrides -----


def test_agent_override_overrides_global_skill(
    isolated_config_paths: tuple[Path, Path],
) -> None:
    """A global ``permission.skill.*: allow`` can be tightened
    by an agent-specific ``agent.plan.permission.skill.*: deny``.
    Lets a careful operator opt the 'plan' agent out of skills
    that are fine for 'build'."""
    global_path, _ = isolated_config_paths
    _write(
        global_path,
        {
            "permission": {"skill": {"*": "allow"}},
            "agent": {
                "plan": {
                    "permission": {"skill": {"*": "deny"}}
                }
            },
        },
    )
    # Default agent ('build') still sees ALLOW.
    assert (
        resolve_skill_permission("anything").verdict == Verdict.ALLOW
    )
    # 'plan' agent sees DENY.
    assert (
        resolve_skill_permission(
            "anything", active_agent="plan"
        ).verdict
        == Verdict.DENY
    )


def test_tools_skill_false_overrides_everything(
    isolated_config_paths: tuple[Path, Path],
) -> None:
    """The absolute-deny escape hatch. Even with a sweeping
    ``permission.skill.*: allow``, ``tools.skill: false`` for an
    agent removes the skill tool entirely. Source MUST be
    'tools.skill=false' so the failure message is unambiguous."""
    global_path, _ = isolated_config_paths
    _write(
        global_path,
        {
            "permission": {"skill": {"*": "allow"}},
            "agent": {"plan": {"tools": {"skill": False}}},
        },
    )
    r = resolve_skill_permission(
        "apigee-policy-top10", active_agent="plan"
    )
    assert r.verdict == Verdict.DENY
    assert r.source == "tools.skill=false"
    assert r.matched_pattern is None


def test_ask_verdict_is_supported(
    isolated_config_paths: tuple[Path, Path],
) -> None:
    """OpenCode permission actions include 'ask'. The resolver
    must not collapse it to allow or deny silently."""
    global_path, _ = isolated_config_paths
    _write(
        global_path,
        {"permission": {"skill": {"experimental-*": "ask"}}},
    )
    r = resolve_skill_permission("experimental-foo")
    assert r.verdict == Verdict.ASK


# ----- Error paths -----


def test_unknown_action_raises_runtimeerror(
    isolated_config_paths: tuple[Path, Path],
) -> None:
    global_path, _ = isolated_config_paths
    _write(
        global_path,
        {"permission": {"skill": {"*": "maybe"}}},
    )
    with pytest.raises(RuntimeError, match="Unknown permission action"):
        resolve_skill_permission("x")


def test_corrupt_json_raises_runtimeerror(
    isolated_config_paths: tuple[Path, Path],
) -> None:
    global_path, _ = isolated_config_paths
    global_path.write_text("{not: valid json,}")
    with pytest.raises(RuntimeError, match="is not valid JSON"):
        resolve_skill_permission("x")


# ----- detect_active_agent helper -----


def test_detect_active_agent_from_env(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    monkeypatch.setenv("OPENCODE_AGENT", "plan")
    assert detect_active_agent() == "plan"


def test_detect_active_agent_default_build(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    """Per §2.3 the default is 'build' when unset. This matches
    OpenCode's default agent identity so detection failure
    degrades safely."""
    monkeypatch.delenv("OPENCODE_AGENT", raising=False)
    assert detect_active_agent() == "build"
