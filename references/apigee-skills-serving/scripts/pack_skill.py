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

"""Pack a ``skills/<name>/`` directory into a signed-ready
``.skill`` zip.

CLI grammar:

    pack-skill.py --src skills/<name>
                  --out <name>-<version>.skill
                  [--repo-root <path>]
                  [--quiet]

Pipeline:

  1. Validate that ``src`` is a directory and contains at least
     ``SKILL.md``.
  2. Scan ``src/scripts/`` (if present) for any Python file that
     contains an import from ``common.*``. If at least one is
     found, the build MUST embed the five canonical
     ``scripts/common/*`` files alongside the skill's own scripts.
  3. When embedding, assert that the source repo's
     ``scripts/common/`` directory contains exactly the five
     expected files (``__init__.py``, ``canonical.py``,
     ``permission_resolver.py``, ``watcher_probe.py``,
     ``manifest_schema.py``). A missing file is a build error
     (we'd ship a half-vendored module). An extra file is also
     a build error (we'd ship something the runtime hasn't been
     audited for — the public surface of ``common/`` is locked).
  4. Write the zip in a deterministic order (sorted paths) so
     ``sha256(zip)`` is stable across builds — this is what the
     ``zip_sha256`` field in the manifest commits to.

Exit codes:
  0 success
  1 user error
  2 system error (FS write failure)
  3 packaging-policy violation (missing/extra files in
    ``scripts/common/``, missing SKILL.md, etc.)
"""
from __future__ import annotations

import argparse
import re
import sys
import zipfile
from pathlib import Path
from typing import Iterable, Sequence

EXIT_OK = 0
EXIT_USER = 1
EXIT_SYSTEM = 2
EXIT_POLICY = 3

# The eight files locked as the public surface of common/.
# http_retry.py and iam_preflight.py are pure-API helpers
# consumed by the loader. config.py decouples env-var resolution
# from the agent runtime's process lifecycle (resolves env →
# ~/.config/apigee-skills-demo/config.env). Any drift (added,
# removed, renamed) is a build-time failure.
_COMMON_FILES: frozenset[str] = frozenset({
    "__init__.py",
    "canonical.py",
    "permission_resolver.py",
    "watcher_probe.py",
    "manifest_schema.py",
    "http_retry.py",
    "iam_preflight.py",
    "config.py",
})

# Matches ``from common.foo import bar``, ``import common.foo``,
# ``from common import foo``, and the dev/test variants
# ``from scripts.common.foo import bar`` / ``import scripts.common.foo``.
# The loader uses a dual try/except import block where the
# production form references ``common.*`` and the fallback
# references ``scripts.common.*``; both forms count as a common
# dependency for packaging purposes (we still embed the same
# scripts/common/ subtree either way).
#
# Anchored so a substring match inside a string literal doesn't
# trigger a false positive (e.g. log messages that happen to
# contain ``common.``).
_COMMON_IMPORT_RE = re.compile(
    r"^\s*(?:"
    r"from\s+(?:scripts\.)?common(?:\.\w+)?\s+import\s+|"
    r"import\s+(?:scripts\.)?common(?:\.\w+)?\b"
    r")",
    re.MULTILINE,
)


def _err(quiet: bool, msg: str) -> None:
    if not quiet:
        print(msg, file=sys.stderr)


def _say(quiet: bool, msg: str) -> None:
    if not quiet:
        print(msg)


def _parse_args(argv: Sequence[str]) -> argparse.Namespace:
    p = argparse.ArgumentParser(
        prog="pack-skill.py",
        description="Pack a skill directory into a .skill zip.",
    )
    p.add_argument("--src", required=True,
                   help="Path to skills/<name>/ source directory.")
    p.add_argument("--out", required=True,
                   help="Output .skill zip path.")
    p.add_argument(
        "--repo-root", default=None,
        help=(
            "Repository root containing scripts/common/. "
            "Defaults to the parent of this script's directory "
            "so the build is self-locating in the normal layout."
        ),
    )
    p.add_argument("--quiet", action="store_true")
    return p.parse_args(list(argv))


def _scripts_imports_common(src: Path) -> bool:
    """Return True iff any .py file under ``src/scripts/`` has an
    import from the ``common`` package. Static analysis is enough
    here -- detected via static grep at build time."""
    scripts_dir = src / "scripts"
    if not scripts_dir.is_dir():
        return False
    for py in sorted(scripts_dir.rglob("*.py")):
        try:
            text = py.read_text(encoding="utf-8", errors="ignore")
        except OSError:
            continue
        if _COMMON_IMPORT_RE.search(text):
            return True
    return False


def _assert_common_surface(common_dir: Path) -> None:
    """Refuse to build if scripts/common/ contains anything
    other than the locked file set. Raises a ValueError with a
    message describing the exact drift so a maintainer can
    diagnose without re-reading the spec."""
    if not common_dir.is_dir():
        raise ValueError(
            f"scripts/common/ not found at {common_dir}"
        )
    present = frozenset(
        p.name for p in common_dir.iterdir() if p.is_file()
    )
    missing = _COMMON_FILES - present
    extra = present - _COMMON_FILES
    if missing or extra:
        raise ValueError(
            f"scripts/common/ surface mismatch: "
            f"missing={sorted(missing)}, extra={sorted(extra)}"
        )


def _iter_files(root: Path) -> Iterable[Path]:
    """Yield every regular file under ``root``, recursively,
    skipping bytecode caches. Order is determined by the caller
    sorting the result; we just enumerate."""
    for p in root.rglob("*"):
        if not p.is_file():
            continue
        # __pycache__ contents are build-local; never ship them.
        if "__pycache__" in p.parts:
            continue
        if p.name.endswith(".pyc"):
            continue
        yield p


def _write_zip(out_path: Path, entries: list[tuple[Path, str]]) -> None:
    """Write a zip containing ``entries = [(on_disk, arcname), ...]``.

    Members are written in arcname-sorted order with a fixed
    mtime so ``sha256(zip)`` is byte-stable across builds. This
    is necessary for the ``zip_sha256`` manifest field to mean
    the same thing across CI runs and developer machines."""
    fixed_date = (1980, 1, 1, 0, 0, 0)  # earliest representable
    entries_sorted = sorted(entries, key=lambda e: e[1])
    out_path.parent.mkdir(parents=True, exist_ok=True)
    with zipfile.ZipFile(
        out_path, "w", compression=zipfile.ZIP_DEFLATED,
    ) as zf:
        for on_disk, arcname in entries_sorted:
            info = zipfile.ZipInfo(filename=arcname, date_time=fixed_date)
            info.compress_type = zipfile.ZIP_DEFLATED
            info.external_attr = 0o644 << 16
            zf.writestr(info, on_disk.read_bytes())


def main(argv: Sequence[str] | None = None) -> int:
    if argv is None:
        argv = sys.argv[1:]
    try:
        ns = _parse_args(argv)
    except SystemExit:
        return EXIT_USER

    quiet = ns.quiet
    src = Path(ns.src).resolve()
    out_path = Path(ns.out).resolve()
    if not src.is_dir():
        _err(quiet, f"error: --src is not a directory: {src}")
        return EXIT_USER
    if not (src / "SKILL.md").is_file():
        _err(quiet, f"error: SKILL.md missing from {src}")
        return EXIT_POLICY

    # Resolve the repo root that owns scripts/common/. The default
    # is two levels up from this file (scripts/ → repo root). The
    # CLI flag exists for tests and out-of-tree builds.
    if ns.repo_root:
        repo_root = Path(ns.repo_root).resolve()
    else:
        repo_root = Path(__file__).resolve().parent.parent

    # The skill's name is the source directory's name; the zip's
    # internal layout puts everything under that name so the
    # extracted tree looks exactly like the source layout.
    skill_name = src.name

    # Collect the skill's own files.
    entries: list[tuple[Path, str]] = []
    for p in _iter_files(src):
        rel = p.relative_to(src).as_posix()
        arcname = f"{skill_name}/{rel}"
        entries.append((p, arcname))

    # Conditionally embed scripts/common/.
    needs_common = _scripts_imports_common(src)
    if needs_common:
        common_dir = repo_root / "scripts" / "common"
        try:
            _assert_common_surface(common_dir)
        except ValueError as exc:
            _err(quiet, f"error: {exc}")
            return EXIT_POLICY
        for fname in sorted(_COMMON_FILES):
            on_disk = common_dir / fname
            arcname = f"{skill_name}/scripts/common/{fname}"
            entries.append((on_disk, arcname))
        _say(quiet, f"embedding scripts/common/ ({len(_COMMON_FILES)} files)")
    else:
        _say(quiet, "scripts/common/ not needed for this skill")

    try:
        _write_zip(out_path, entries)
    except OSError as exc:
        _err(quiet, f"error: zip write failed: {exc}")
        return EXIT_SYSTEM

    _say(quiet, f"packed: {out_path} ({len(entries)} files)")
    return EXIT_OK


if __name__ == "__main__":  # pragma: no cover
    raise SystemExit(main())
