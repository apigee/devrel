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

"""Unit tests for scripts/common/config.py.

The helper has 3 concerns we want to nail down:
  1. Resolution order (env beats file beats default).
  2. Parser tolerance (comments, blank lines, `export` prefix,
    quoted values, unknown keys).
  3. `get_or_die` contract (calls die_fn with a message that
    references BOTH env var AND config file path).

Each test isolates the config-file path via the
APIGEE_SKILLS_CONFIG_FILE env override and clears the cache so
back-to-back tests don't poison each other.
"""
from __future__ import annotations

import sys
from pathlib import Path

import pytest

# Make scripts/common importable as a package.
_REPO_ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(_REPO_ROOT))

from scripts.common import config  # noqa: E402


@pytest.fixture(autouse=True)
def _clear_cache_and_env(monkeypatch):
    """Every test starts with a clean cache + scrubbed env so
    we test what the test sets, not what the host shell leaks."""
    config.clear_cache()
    for k in (
        "APIHUB_PROJECT",
        "APIHUB_LOCATION",
        "APIGEE_ORG",
        "APIGEE_SKILLS_MIN_KEYWORD_OVERLAP",
        "APIGEE_SKILLS_CONFIG_FILE",
    ):
        monkeypatch.delenv(k, raising=False)
    yield
    config.clear_cache()


def _point_to_config(tmp_path: Path, contents: str, monkeypatch) -> Path:
    """Write `contents` to tmp_path/config.env and point the
    helper at it via APIGEE_SKILLS_CONFIG_FILE."""
    path = tmp_path / "config.env"
    path.write_text(contents)
    monkeypatch.setenv("APIGEE_SKILLS_CONFIG_FILE", str(path))
    config.clear_cache()
    return path


# --------------------------------------------------------------
# 1. Resolution order
# --------------------------------------------------------------


class TestResolutionOrder:

    def test_env_beats_file(self, tmp_path, monkeypatch):
        _point_to_config(
            tmp_path,
            "APIHUB_PROJECT=from-file\n",
            monkeypatch,
        )
        monkeypatch.setenv("APIHUB_PROJECT", "from-env")
        assert config.get("APIHUB_PROJECT") == "from-env"
        assert config.source("APIHUB_PROJECT") == (
            "from-env", "env"
        )

    def test_file_used_when_env_unset(
        self, tmp_path, monkeypatch
    ):
        _point_to_config(
            tmp_path,
            "APIHUB_PROJECT=from-file\n",
            monkeypatch,
        )
        assert config.get("APIHUB_PROJECT") == "from-file"
        assert config.source("APIHUB_PROJECT") == (
            "from-file", "config-file"
        )

    def test_file_used_when_env_is_whitespace(
        self, tmp_path, monkeypatch
    ):
        """An env var set to a whitespace string is functionally
        unset for our purposes. We strip and treat empty as
        missing."""
        _point_to_config(
            tmp_path,
            "APIHUB_PROJECT=from-file\n",
            monkeypatch,
        )
        monkeypatch.setenv("APIHUB_PROJECT", "   ")
        assert config.get("APIHUB_PROJECT") == "from-file"

    def test_default_returned_when_nothing_set(
        self, tmp_path, monkeypatch
    ):
        # Point at a non-existent file so the file path also
        # contributes nothing.
        nonexistent = tmp_path / "nope.env"
        monkeypatch.setenv(
            "APIGEE_SKILLS_CONFIG_FILE", str(nonexistent)
        )
        config.clear_cache()
        assert config.get("APIHUB_PROJECT", "fallback") == "fallback"
        assert config.source("APIHUB_PROJECT") == ("", "missing")

    def test_empty_string_default_is_returned(
        self, tmp_path, monkeypatch
    ):
        nonexistent = tmp_path / "nope.env"
        monkeypatch.setenv(
            "APIGEE_SKILLS_CONFIG_FILE", str(nonexistent)
        )
        config.clear_cache()
        assert config.get("APIHUB_PROJECT") == ""


# --------------------------------------------------------------
# 2. Parser tolerance
# --------------------------------------------------------------


class TestParser:

    def test_blank_lines_and_comments_ignored(
        self, tmp_path, monkeypatch
    ):
        _point_to_config(
            tmp_path,
            (
                "# This is a comment line.\n"
                "\n"
                "   # indented comment\n"
                "APIHUB_PROJECT=p\n"
                "\n"
                "APIHUB_LOCATION=l\n"
            ),
            monkeypatch,
        )
        assert config.get("APIHUB_PROJECT") == "p"
        assert config.get("APIHUB_LOCATION") == "l"

    def test_export_prefix_tolerated(self, tmp_path, monkeypatch):
        """Operators may copy-paste the demo-setup `export`
        block straight into the file. That should work without
        making them edit out the `export` keyword."""
        _point_to_config(
            tmp_path,
            (
                "export APIHUB_PROJECT=p\n"
                "  export APIHUB_LOCATION=l\n"
            ),
            monkeypatch,
        )
        assert config.get("APIHUB_PROJECT") == "p"
        assert config.get("APIHUB_LOCATION") == "l"

    def test_double_quoted_value_stripped(
        self, tmp_path, monkeypatch
    ):
        _point_to_config(
            tmp_path,
            'APIHUB_PROJECT="quoted-value"\n',
            monkeypatch,
        )
        assert config.get("APIHUB_PROJECT") == "quoted-value"

    def test_single_quoted_value_stripped(
        self, tmp_path, monkeypatch
    ):
        _point_to_config(
            tmp_path,
            "APIHUB_PROJECT='quoted-value'\n",
            monkeypatch,
        )
        assert config.get("APIHUB_PROJECT") == "quoted-value"

    def test_unknown_keys_dropped_silently(
        self, tmp_path, monkeypatch
    ):
        _point_to_config(
            tmp_path,
            (
                "RANDOM_GARBAGE=ignored\n"
                "APIHUB_PROJECT=p\n"
                "ALSO_GARBAGE=ignored\n"
            ),
            monkeypatch,
        )
        assert config.get("APIHUB_PROJECT") == "p"
        # Unknown keys are not exposed by any helper.

    def test_malformed_lines_skipped(
        self, tmp_path, monkeypatch
    ):
        _point_to_config(
            tmp_path,
            (
                "this is not a valid line\n"
                "APIHUB_PROJECT=p\n"
                "=value-with-no-key\n"
            ),
            monkeypatch,
        )
        assert config.get("APIHUB_PROJECT") == "p"

    def test_missing_file_yields_empty(
        self, tmp_path, monkeypatch
    ):
        nonexistent = tmp_path / "nope.env"
        monkeypatch.setenv(
            "APIGEE_SKILLS_CONFIG_FILE", str(nonexistent)
        )
        config.clear_cache()
        assert config.get("APIHUB_PROJECT") == ""

    def test_unreadable_file_yields_empty(
        self, tmp_path, monkeypatch
    ):
        path = tmp_path / "config.env"
        path.write_text("APIHUB_PROJECT=p\n")
        path.chmod(0o000)
        monkeypatch.setenv(
            "APIGEE_SKILLS_CONFIG_FILE", str(path)
        )
        config.clear_cache()
        try:
            # Either the read fails (returns "") or, on some
            # filesystems, root-equivalent access is allowed.
            # Both are acceptable as long as nothing raises.
            v = config.get("APIHUB_PROJECT", "fallback")
            assert v in ("p", "fallback", "")
        finally:
            # Restore so pytest can clean up.
            path.chmod(0o600)


# --------------------------------------------------------------
# 3. get_or_die contract
# --------------------------------------------------------------


class TestGetOrDie:

    def test_returns_value_when_present(
        self, tmp_path, monkeypatch
    ):
        _point_to_config(
            tmp_path,
            "APIHUB_PROJECT=p\n",
            monkeypatch,
        )
        called: list[str] = []

        def fake_die(msg):
            called.append(msg)
            raise SystemExit(2)

        v = config.get_or_die("APIHUB_PROJECT", die_fn=fake_die)
        assert v == "p"
        assert called == []  # die_fn was not invoked

    def test_calls_die_with_helpful_message(
        self, tmp_path, monkeypatch
    ):
        nonexistent = tmp_path / "nope.env"
        monkeypatch.setenv(
            "APIGEE_SKILLS_CONFIG_FILE", str(nonexistent)
        )
        config.clear_cache()
        captured: list[str] = []

        def fake_die(msg):
            captured.append(msg)
            raise SystemExit(2)

        with pytest.raises(SystemExit) as exc:
            config.get_or_die("APIHUB_PROJECT", die_fn=fake_die)
        assert exc.value.code == 2
        assert len(captured) == 1
        msg = captured[0]
        # The message MUST mention both the env var and the
        # config file path so the operator can fix either route.
        assert "APIHUB_PROJECT" in msg
        assert "export" in msg
        assert str(nonexistent) in msg
        assert "demo-setup.sh" in msg
        assert msg.startswith("config: FAILED")


# --------------------------------------------------------------
# 4. Convenience getters
# --------------------------------------------------------------


class TestConvenienceGetters:

    def test_apihub_project_reads_env(self, monkeypatch):
        monkeypatch.setenv("APIHUB_PROJECT", "p")
        assert config.apihub_project() == "p"

    def test_keyword_overlap_default(self, tmp_path, monkeypatch):
        nonexistent = tmp_path / "nope.env"
        monkeypatch.setenv(
            "APIGEE_SKILLS_CONFIG_FILE", str(nonexistent)
        )
        config.clear_cache()
        assert config.keyword_overlap_threshold() == 1

    def test_keyword_overlap_explicit_via_env(
        self, monkeypatch
    ):
        monkeypatch.setenv(
            "APIGEE_SKILLS_MIN_KEYWORD_OVERLAP", "3"
        )
        assert config.keyword_overlap_threshold() == 3

    def test_keyword_overlap_explicit_via_file(
        self, tmp_path, monkeypatch
    ):
        _point_to_config(
            tmp_path,
            "APIGEE_SKILLS_MIN_KEYWORD_OVERLAP=2\n",
            monkeypatch,
        )
        assert config.keyword_overlap_threshold() == 2

    def test_keyword_overlap_malformed_falls_back(
        self, monkeypatch
    ):
        monkeypatch.setenv(
            "APIGEE_SKILLS_MIN_KEYWORD_OVERLAP", "not-a-number"
        )
        assert config.keyword_overlap_threshold(default=5) == 5

    def test_keyword_overlap_negative_falls_back(
        self, monkeypatch
    ):
        monkeypatch.setenv(
            "APIGEE_SKILLS_MIN_KEYWORD_OVERLAP", "-1"
        )
        assert config.keyword_overlap_threshold() == 1


# --------------------------------------------------------------
# 5. Cache behavior
# --------------------------------------------------------------


class TestCacheBehavior:

    def test_repeated_reads_hit_cache(
        self, tmp_path, monkeypatch
    ):
        path = _point_to_config(
            tmp_path,
            "APIHUB_PROJECT=p\n",
            monkeypatch,
        )
        assert config.get("APIHUB_PROJECT") == "p"
        # Mutate file; the cache should hold.
        path.write_text("APIHUB_PROJECT=changed\n")
        assert config.get("APIHUB_PROJECT") == "p"

    def test_clear_cache_picks_up_changes(
        self, tmp_path, monkeypatch
    ):
        path = _point_to_config(
            tmp_path,
            "APIHUB_PROJECT=p\n",
            monkeypatch,
        )
        assert config.get("APIHUB_PROJECT") == "p"
        path.write_text("APIHUB_PROJECT=changed\n")
        config.clear_cache()
        assert config.get("APIHUB_PROJECT") == "changed"

    def test_override_swap_invalidates_cache(
        self, tmp_path, monkeypatch
    ):
        """Pointing APIGEE_SKILLS_CONFIG_FILE at a different
        file should give that file's values, not the cached
        prior file's."""
        path1 = tmp_path / "a.env"
        path1.write_text("APIHUB_PROJECT=from-a\n")
        path2 = tmp_path / "b.env"
        path2.write_text("APIHUB_PROJECT=from-b\n")

        monkeypatch.setenv("APIGEE_SKILLS_CONFIG_FILE", str(path1))
        config.clear_cache()
        assert config.get("APIHUB_PROJECT") == "from-a"

        # Swap to b; should pick up b without manual clear
        # because the cache key includes the path.
        monkeypatch.setenv("APIGEE_SKILLS_CONFIG_FILE", str(path2))
        assert config.get("APIHUB_PROJECT") == "from-b"
