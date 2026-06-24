"""Shared pytest configuration.

Adds the repository root to ``sys.path`` so test files can do
``from scripts.common.canonical import canonicalize`` regardless
of how pytest is invoked. The source tree is rooted at
``scripts/`` and tests live in ``tests/`` at the same level.
"""
from __future__ import annotations

import sys
from pathlib import Path

_REPO_ROOT = Path(__file__).resolve().parent.parent
if str(_REPO_ROOT) not in sys.path:
    sys.path.insert(0, str(_REPO_ROOT))
