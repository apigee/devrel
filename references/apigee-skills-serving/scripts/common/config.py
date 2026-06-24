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

"""scripts/common/config.py — demo configuration loader.

Single source of truth for `APIHUB_PROJECT`, `APIHUB_LOCATION`,
`APIGEE_ORG`, and `APIGEE_SKILLS_MIN_KEYWORD_OVERLAP`.

Resolution order (first match wins):

  1. The matching environment variable in the current process.
  2. The matching key in `~/.config/apigee-skills-demo/config.env`
     (file format: one `KEY=value` per line, `#` comments OK).
  3. Empty string (caller's responsibility to handle).

The config file path can be overridden with the env var
`APIGEE_SKILLS_CONFIG_FILE` for testing. The file is read lazily
on first lookup and cached for the rest of the process.

Why a config file at all: a long-running agent runtime inherits
its env vars from the shell that launched it. If the operator
launches the runtime before sourcing the demo env, the agent's
bash subprocesses see no demo env -- even if demo-setup.sh has
been run later. Writing a persistent config file once breaks
that coupling: any process can read the config regardless of
when or where the runtime was launched.

Why plain `KEY=value` lines (not JSON/TOML): the file is also
useful as something the operator can `source` from a shell, AND
as a copy-paste source for the `export` lines. Stdlib parsers
only.
"""
from __future__ import annotations

import os
from pathlib import Path

# Public API: the four resolvable keys + the config-file
# discovery override.
_RESOLVABLE_KEYS = (
    "APIHUB_PROJECT",
    "APIHUB_LOCATION",
    "APIGEE_ORG",
    "APIGEE_SKILLS_MIN_KEYWORD_OVERLAP",
)
_CONFIG_FILE_OVERRIDE = "APIGEE_SKILLS_CONFIG_FILE"
_DEFAULT_CONFIG_PATH = (
    Path.home() / ".config" / "apigee-skills-demo" / "config.env"
)

# Cache of parsed config (populated on first lookup). The cache
# key is the resolved path; if the operator points
# APIGEE_SKILLS_CONFIG_FILE at a different file mid-process, the
# new file is read fresh.
_cache: dict[Path, dict[str, str]] = {}


def _resolve_config_path() -> Path:
    """Return the config file path; honors
    APIGEE_SKILLS_CONFIG_FILE override."""
    override = os.environ.get(_CONFIG_FILE_OVERRIDE, "").strip()
    if override:
        return Path(override).expanduser()
    return _DEFAULT_CONFIG_PATH


def _parse_config_file(path: Path) -> dict[str, str]:
    """Parse a `KEY=value` config file into a dict. Ignores
    blank lines and `#` comments. Quotes around values are
    stripped. Unknown keys are silently dropped (only the four
    resolvable keys make it into the result).

    Errors during read return an empty dict -- a missing or
    unreadable config file is equivalent to "no config".
    Resolution then falls through to defaults.
    """
    if not path.is_file():
        return {}
    try:
        text = path.read_text(encoding="utf-8")
    except OSError:
        return {}
    out: dict[str, str] = {}
    for line in text.splitlines():
        stripped = line.strip()
        if not stripped or stripped.startswith("#"):
            continue
        # Tolerate "export KEY=value" form (some operators
        # source the file as a shell script).
        if stripped.startswith("export "):
            stripped = stripped[len("export "):]
        if "=" not in stripped:
            continue
        key, _, val = stripped.partition("=")
        key = key.strip()
        val = val.strip()
        # Strip surrounding quotes.
        if len(val) >= 2 and val[0] == val[-1] and val[0] in ("'", '"'):
            val = val[1:-1]
        if key in _RESOLVABLE_KEYS:
            out[key] = val
    return out


def _load_config() -> dict[str, str]:
    """Load and cache the config file. Cache is keyed by resolved
    path so an override change takes effect."""
    path = _resolve_config_path()
    cached = _cache.get(path)
    if cached is not None:
        return cached
    parsed = _parse_config_file(path)
    _cache[path] = parsed
    return parsed


def get(key: str, default: str = "") -> str:
    """Resolve one demo config value.

    Resolution: env var → config file → `default`. The default
    is returned ONLY when neither env nor file supplies the
    value; callers that need to know whether the value came
    from the environment vs the config file should call
    `source(key)` instead.
    """
    env_val = os.environ.get(key, "").strip()
    if env_val:
        return env_val
    return _load_config().get(key, default)


def source(key: str) -> tuple[str, str]:
    """Return `(value, source)` for `key`.

    `source` is one of:
      - `"env"`: came from the process environment
      - `"config-file"`: came from the persistent config file
      - `"missing"`: not set anywhere; `value` is the empty string

    Useful for diagnostic output ("APIHUB_PROJECT loaded from
    ~/.config/apigee-skills-demo/config.env").
    """
    env_val = os.environ.get(key, "").strip()
    if env_val:
        return env_val, "env"
    file_val = _load_config().get(key, "")
    if file_val:
        return file_val, "config-file"
    return "", "missing"


def get_or_die(key: str, *, die_fn) -> str:
    """Resolve `key`; on missing, call `die_fn(msg)` with a
    contract-line-style failure message.

    Callers pass their own die function so the message respects
    each script's emission style (find_install._die, top10's
    sys.stderr, etc.). The message references both the env var
    AND the config file path so the operator can fix either.
    """
    val, src = source(key)
    if src == "missing":
        path = _resolve_config_path()
        die_fn(
            f"config: FAILED — {key} is empty. Set it via "
            f"`export {key}=...` OR add the line `{key}=...` "
            f"to {path}. Run `./bin/demo-setup.sh` to write "
            f"the config file automatically."
        )
    return val


def clear_cache() -> None:
    """Drop the cached parse. Primarily for tests."""
    _cache.clear()


def config_path() -> Path:
    """Public accessor for the resolved config-file path
    (honors `APIGEE_SKILLS_CONFIG_FILE`). Useful for messages
    that tell the operator where to look."""
    return _resolve_config_path()


# Convenience getters for the four resolvable keys, all callable
# without parens for grep-friendliness in production code.

def apihub_project() -> str:
    return get("APIHUB_PROJECT")


def apihub_location() -> str:
    return get("APIHUB_LOCATION")


def apigee_org() -> str:
    return get("APIGEE_ORG")


def keyword_overlap_threshold(default: int = 1) -> int:
    """Special case: the threshold is an integer with a default.
    Parsing errors fall through to `default`."""
    raw = get("APIGEE_SKILLS_MIN_KEYWORD_OVERLAP", str(default))
    try:
        v = int(raw)
        return v if v >= 0 else default
    except (TypeError, ValueError):
        return default
