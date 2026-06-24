"""Tests for ``scripts/update_taxonomy.py``.

Coverage targets:

  * All four attributes created on fresh instance.
  * Idempotent on second run.
  * Permission-denied error path.

Per-component criterion: creates exactly four attribute
definitions on a fresh project; no-op on second run. The four
attribute keys are fixed:

    agentic_skill, keywords, gs_uri, signing_key_id

These mirror the four ``_ATTR_KEYS`` consumed by
``register_skill.py``; the constants are duplicated rather than
shared so a future change to one script forces the test author
to think about the other.
"""
from __future__ import annotations

import json
from typing import Any
from unittest.mock import MagicMock

import pytest


def _import_taxonomy_main():
    from scripts.update_taxonomy import main as _main
    return _main


class FakeAttrSurface:
    """Tiny stateful fake for the attribute-definition CRUD
    endpoints. Tracks created attribute IDs so the idempotency
    test can assert second-run is a pure-GET pass."""

    def __init__(self) -> None:
        self.attrs: set[str] = set()
        self.calls: list[tuple[str, str]] = []

    def request(self, method: str, url: str, **kwargs: Any):
        prefix = "/locations/"
        idx = url.find(prefix)
        suffix = url[idx + len(prefix):] if idx >= 0 else url
        if "/" in suffix:
            suffix = "/" + suffix.split("/", 1)[1]
        self.calls.append((method, suffix))
        params = kwargs.get("params", {}) or {}
        body = kwargs.get("json") or {}

        if method == "GET" and suffix.startswith("/attributes/"):
            attr_id = suffix.strip("/").split("/")[1]
            if attr_id in self.attrs:
                return _resp(200, {"name": attr_id})
            return _resp(404, {})

        if method == "POST" and suffix == "/attributes":
            attr_id = params.get("attributeId") or body.get("name")
            if attr_id in self.attrs:
                return _resp(409, {"error": "exists"})
            self.attrs.add(attr_id)
            return _resp(200, {"name": attr_id})

        return _resp(404, {"error": f"unmocked {method} {suffix}"})


def _resp(status: int, body: dict):
    class _R:
        status_code = status
        text = json.dumps(body)

        def json(self) -> dict:
            return body

        def raise_for_status(self) -> None:
            if status >= 400:
                import requests
                raise requests.HTTPError(
                    f"HTTP {status}",
                    response=self,  # type: ignore[arg-type]
                )
    return _R()


@pytest.fixture
def fake_surface(monkeypatch: pytest.MonkeyPatch) -> FakeAttrSurface:
    import scripts.update_taxonomy as ut

    surface = FakeAttrSurface()
    creds = MagicMock()
    creds.token = "fake"
    creds.refresh = MagicMock(return_value=None)
    monkeypatch.setattr(ut, "_credentials", lambda: (creds, "demo"))
    monkeypatch.setattr(
        ut.requests, "request",
        lambda method, url, **kw: surface.request(method, url, **kw),
    )
    return surface


# ---------------------------------------------------------------------------
# Happy path
# ---------------------------------------------------------------------------

def test_fresh_project_creates_four_attributes(
    fake_surface: FakeAttrSurface,
) -> None:
    """Exactly four attribute defs on a fresh instance."""
    main = _import_taxonomy_main()
    rc = main([
        "--project", "demo-project",
        "--location", "us-central1",
        "--quiet",
    ])
    assert rc == 0
    posts = [c for c in fake_surface.calls if c[0] == "POST"]
    assert len(posts) == 4
    assert fake_surface.attrs == {
        "agentic_skill", "keywords", "gs_uri", "signing_key_id"
    }


def test_second_run_is_noop(
    fake_surface: FakeAttrSurface,
) -> None:
    """Second run is no-op (no POSTs)."""
    main = _import_taxonomy_main()
    main([
        "--project", "demo-project",
        "--location", "us-central1",
        "--quiet",
    ])
    fake_surface.calls.clear()
    rc = main([
        "--project", "demo-project",
        "--location", "us-central1",
        "--quiet",
    ])
    assert rc == 0
    posts = [c for c in fake_surface.calls if c[0] == "POST"]
    assert posts == []


def test_partial_existing_creates_only_missing(
    fake_surface: FakeAttrSurface,
) -> None:
    """If some attributes already exist (e.g. created by a
    previous partial run that crashed), the script must create
    only the missing ones — not re-POST existing ones."""
    fake_surface.attrs.add("agentic_skill")
    fake_surface.attrs.add("keywords")
    main = _import_taxonomy_main()
    rc = main([
        "--project", "demo-project",
        "--location", "us-central1",
        "--quiet",
    ])
    assert rc == 0
    posts = [c for c in fake_surface.calls if c[0] == "POST"]
    assert len(posts) == 2
    assert fake_surface.attrs == {
        "agentic_skill", "keywords", "gs_uri", "signing_key_id"
    }


# ---------------------------------------------------------------------------
# Error paths
# ---------------------------------------------------------------------------

def test_permission_denied_exits_3(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    """403 → exit 3 (IAM error class). §3.4 spec says 'fails
    loudly on permission denied (exit 3)'."""
    import scripts.update_taxonomy as ut

    creds = MagicMock()
    creds.token = "fake"
    creds.refresh = MagicMock(return_value=None)
    monkeypatch.setattr(ut, "_credentials", lambda: (creds, "demo"))
    monkeypatch.setattr(
        ut.requests, "request",
        lambda method, url, **kw: _resp(403, {"error": "denied"}),
    )
    main = _import_taxonomy_main()
    rc = main([
        "--project", "demo-project",
        "--location", "us-central1",
        "--quiet",
    ])
    assert rc == 3


def test_5xx_exits_2(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    """Generic server-side failures classify as system error."""
    import scripts.update_taxonomy as ut

    creds = MagicMock()
    creds.token = "fake"
    creds.refresh = MagicMock(return_value=None)
    monkeypatch.setattr(ut, "_credentials", lambda: (creds, "demo"))
    monkeypatch.setattr(
        ut.requests, "request",
        lambda method, url, **kw: _resp(500, {"error": "boom"}),
    )
    main = _import_taxonomy_main()
    rc = main([
        "--project", "demo-project",
        "--location", "us-central1",
        "--quiet",
    ])
    assert rc == 2
