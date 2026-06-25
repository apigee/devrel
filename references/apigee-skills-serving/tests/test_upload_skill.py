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

"""Tests for ``scripts/upload_skill.py``.

Coverage targets:

  * GCS mocked: success path returns URI on stdout.
  * Bucket-not-found error path.
  * Permission-denied path.

The implementation uses ``requests`` against the GCS JSON upload
endpoint (no ``google-cloud-storage`` dependency). ADC provides
the bearer token via ``google.auth.default()``. Both boundaries
are mocked at module-attribute level (``monkeypatch.setattr``) so
the tests never hit the network.
"""
from __future__ import annotations

from pathlib import Path
from typing import Any
from unittest.mock import MagicMock

import pytest


def _import_upload_main():
    from scripts.upload_skill import main as _main
    return _main


# ---------------------------------------------------------------------------
# Boundary mocks
# ---------------------------------------------------------------------------

class FakeResponse:
    """Minimal ``requests.Response`` stand-in. Carries a status
    and a json body; ``raise_for_status`` mirrors the real
    behaviour. Used in place of the network layer."""

    def __init__(self, status: int, body: dict | None = None,
                 text: str = "") -> None:
        self.status_code = status
        self._body = body or {}
        self.text = text

    def json(self) -> dict:
        return self._body

    def raise_for_status(self) -> None:
        if self.status_code >= 400:
            import requests
            raise requests.HTTPError(
                f"HTTP {self.status_code}: {self.text}",
                response=self,  # type: ignore[arg-type]
            )


@pytest.fixture
def fake_creds(monkeypatch: pytest.MonkeyPatch) -> MagicMock:
    """Replace ``google.auth.default`` with a stub that returns a
    pre-built credentials object whose ``refresh`` is a no-op and
    whose ``token`` is a sentinel string. The upload script uses
    the token only as a bearer header; the string contents are
    not interpreted by the script."""
    import scripts.upload_skill as us

    creds = MagicMock()
    creds.token = "fake-bearer-token"
    creds.refresh = MagicMock(return_value=None)
    monkeypatch.setattr(
        us, "_credentials", lambda: (creds, "demo-project")
    )
    return creds


@pytest.fixture
def skill_zip(tmp_path: Path) -> Path:
    p = tmp_path / "demo-skill-1.0.0.skill"
    p.write_bytes(b"PK\x03\x04fake-zip-payload")
    return p


# ---------------------------------------------------------------------------
# Happy path
# ---------------------------------------------------------------------------

def test_success_uploads_and_prints_uri(
    fake_creds: MagicMock,
    skill_zip: Path,
    monkeypatch: pytest.MonkeyPatch,
    capsys: pytest.CaptureFixture[str],
) -> None:
    """Success path: 200 from GCS → exit 0 → final stdout line is
    the gs:// URI."""
    import scripts.upload_skill as us

    captured: dict[str, Any] = {}

    def fake_post(url: str, **kwargs: Any) -> FakeResponse:
        captured["url"] = url
        captured["headers"] = kwargs.get("headers", {})
        captured["data"] = kwargs.get("data")
        captured["params"] = kwargs.get("params", {})
        return FakeResponse(200, {"name": "demo-skill-1.0.0.skill"})

    monkeypatch.setattr(us.requests, "post", fake_post)

    main = _import_upload_main()
    rc = main([
        "--zip", str(skill_zip),
        "--bucket", "demo-bucket",
    ])
    assert rc == 0
    out = capsys.readouterr().out
    assert "gs://demo-bucket/demo-skill-1.0.0.skill" in out
    # Authorization header threaded through from the fake creds.
    assert captured["headers"].get("Authorization") == (
        "Bearer fake-bearer-token"
    )


def test_object_name_override(
    fake_creds: MagicMock,
    skill_zip: Path,
    monkeypatch: pytest.MonkeyPatch,
    capsys: pytest.CaptureFixture[str],
) -> None:
    """``--object-name`` replaces the default basename in both
    the request and the printed URI."""
    import scripts.upload_skill as us

    captured: dict[str, Any] = {}

    def fake_post(url: str, **kwargs: Any) -> FakeResponse:
        captured["params"] = kwargs.get("params", {})
        return FakeResponse(200, {})

    monkeypatch.setattr(us.requests, "post", fake_post)

    main = _import_upload_main()
    rc = main([
        "--zip", str(skill_zip),
        "--bucket", "demo-bucket",
        "--object-name", "custom/path/my.skill",
    ])
    assert rc == 0
    out = capsys.readouterr().out
    assert "gs://demo-bucket/custom/path/my.skill" in out
    assert captured["params"].get("name") == "custom/path/my.skill"


# ---------------------------------------------------------------------------
# Error paths
# ---------------------------------------------------------------------------

def test_bucket_not_found_exits_2(
    fake_creds: MagicMock,
    skill_zip: Path,
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    """A 404 from GCS → system error (exit 2)."""
    import scripts.upload_skill as us
    monkeypatch.setattr(
        us.requests, "post",
        lambda url, **kw: FakeResponse(404, text="bucket not found"),
    )
    main = _import_upload_main()
    rc = main([
        "--zip", str(skill_zip),
        "--bucket", "missing-bucket",
        "--quiet",
    ])
    assert rc == 2


def test_permission_denied_exits_3(
    fake_creds: MagicMock,
    skill_zip: Path,
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    """A 403 from GCS is IAM, not transport — §3.2 reserves exit 3."""
    import scripts.upload_skill as us
    monkeypatch.setattr(
        us.requests, "post",
        lambda url, **kw: FakeResponse(403, text="forbidden"),
    )
    main = _import_upload_main()
    rc = main([
        "--zip", str(skill_zip),
        "--bucket", "denied-bucket",
        "--quiet",
    ])
    assert rc == 3


def test_other_5xx_exits_2(
    fake_creds: MagicMock,
    skill_zip: Path,
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    """Server error → system error. (The retry policy lives in
    the consumer's install pipeline; upload is one-shot.)"""
    import scripts.upload_skill as us
    monkeypatch.setattr(
        us.requests, "post",
        lambda url, **kw: FakeResponse(500, text="boom"),
    )
    main = _import_upload_main()
    rc = main([
        "--zip", str(skill_zip),
        "--bucket", "demo-bucket",
        "--quiet",
    ])
    assert rc == 2


def test_missing_zip_exits_1(
    fake_creds: MagicMock,
    tmp_path: Path,
) -> None:
    """`--zip` points at nothing → user error per §3.2."""
    main = _import_upload_main()
    rc = main([
        "--zip", str(tmp_path / "missing.skill"),
        "--bucket", "demo-bucket",
        "--quiet",
    ])
    assert rc == 1


def test_quiet_suppresses_stdout(
    fake_creds: MagicMock,
    skill_zip: Path,
    monkeypatch: pytest.MonkeyPatch,
    capsys: pytest.CaptureFixture[str],
) -> None:
    """Even on success, ``--quiet`` keeps stdout empty. The §3.2
    contract says the URI is the only stdout line — quiet kills
    everything except it; we drop it entirely under --quiet so the
    script is safe in shell pipelines that capture stdout."""
    import scripts.upload_skill as us
    monkeypatch.setattr(
        us.requests, "post",
        lambda url, **kw: FakeResponse(200, {}),
    )
    main = _import_upload_main()
    rc = main([
        "--zip", str(skill_zip),
        "--bucket", "demo-bucket",
        "--quiet",
    ])
    assert rc == 0
    assert capsys.readouterr().out == ""
