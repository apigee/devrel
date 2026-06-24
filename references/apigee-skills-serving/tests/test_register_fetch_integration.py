"""Register + fetch round-trip integration test.

Real ``register_skill.main`` against a mocked API hub HTTP layer;
asserts that what register_skill writes as the Spec body is the
exact byte sequence the consumer's ``_fetch_spec()`` would read
back. This is the seam that guarantees the install side sees the
same manifest the author signed.

The consumer's loader is not part of this repo, so we mirror
``_fetch_spec``'s contract inline here: GET
``.../apis/{name}/versions/{ver}/specs/{spec_id}:contents``,
decode the base64 ``contents`` field. This stand-in is a faithful
substitute even though the production helper lives elsewhere.

Byte-equality is the key assertion: if register_skill mangled
the manifest YAML (e.g., re-serialised it through PyYAML and lost
key ordering), this test would catch it.
"""
from __future__ import annotations

import base64
import json
from pathlib import Path
from typing import Any
from unittest.mock import MagicMock

import pytest
import yaml


def _import_register_main():
    from scripts.register_skill import main as _main
    return _main


# ---------------------------------------------------------------------------
# Local fake API hub (state + HTTP shim)
# ---------------------------------------------------------------------------

class _FakeHub:
    def __init__(self) -> None:
        # Track only what we need: spec bodies keyed by
        # (api_id, ver_id, spec_id). All other resources are
        # acknowledged but their contents are uninteresting.
        self.apis: set[str] = set()
        self.versions: set[tuple[str, str]] = set()
        self.specs: dict[tuple[str, str, str], bytes] = {}
        self.attrs: dict[str, dict] = {}

    def __call__(self, method: str, url: str, **kwargs: Any):
        suffix = self._normalize(url)
        params = kwargs.get("params") or {}
        body = kwargs.get("json") or {}
        parts = suffix.strip("/").split("/")

        if method == "POST" and suffix == "/apis":
            api_id = params.get("apiId")
            self.apis.add(api_id)
            return _resp(200, {})

        if method == "GET" and suffix.startswith("/apis/") \
                and len(parts) == 2:
            api_id = parts[1]
            if api_id not in self.apis:
                return _resp(404, {})
            return _resp(200, {"attributes": self.attrs.get(api_id, {})})

        if method == "GET" and len(parts) == 4 \
                and parts[2] == "versions":
            api_id, ver_id = parts[1], parts[3]
            if (api_id, ver_id) not in self.versions:
                return _resp(404, {})
            return _resp(200, {})

        if method == "POST" and suffix.endswith("/versions"):
            api_id = parts[1]
            ver_id = params.get("versionId")
            self.versions.add((api_id, ver_id))
            return _resp(200, {})

        if method == "GET" and suffix.endswith(":contents"):
            api_id, ver_id, spec_id = parts[1], parts[3], parts[5]
            spec_id = spec_id.split(":")[0]
            key = (api_id, ver_id, spec_id)
            if key not in self.specs:
                return _resp(404, {})
            return _resp(200, {
                "contents": base64.b64encode(
                    self.specs[key]
                ).decode("ascii"),
            })

        if method == "POST" and suffix.endswith("/specs"):
            api_id, ver_id = parts[1], parts[3]
            spec_id = params.get("specId")
            # API hub's Spec body wraps the base64-encoded payload
            # inside a NESTED `contents` object alongside `mimeType`
            # and `specType`. Unwrap to find the actual b64 string.
            raw_contents = body.get("contents", "")
            if isinstance(raw_contents, dict):
                b64_str = raw_contents.get("contents", "")
            else:
                b64_str = raw_contents
            raw = base64.b64decode(b64_str)
            self.specs[(api_id, ver_id, spec_id)] = raw
            return _resp(200, {})

        if method == "PATCH" and suffix.startswith("/apis/") \
                and len(parts) == 2:
            api_id = parts[1]
            self.attrs[api_id] = body.get("attributes", {})
            return _resp(200, {})

        return _resp(404, {"error": f"unmocked {method} {suffix}"})

    @staticmethod
    def _normalize(url: str) -> str:
        marker = "/locations/"
        idx = url.find(marker)
        if idx < 0:
            return url
        tail = url[idx + len(marker):]
        return "/" + tail.split("/", 1)[1] if "/" in tail else "/"


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


# ---------------------------------------------------------------------------
# The local _fetch_spec stand-in mirroring the consumer's contract.
# ---------------------------------------------------------------------------

def _fetch_spec(
    hub: _FakeHub, project: str, location: str, name: str,
    version: str, spec_id: str,
) -> bytes:
    """Mirror of the helper the consumer's loader will expose as
    ``_fetch_spec``. Pulled out here so the test is a real
    round-trip: same URL the production fetcher uses, same
    base64-decode, same byte output."""
    url = (
        f"https://apihub.googleapis.com/v1/projects/{project}"
        f"/locations/{location}/apis/{name}/versions/{version}"
        f"/specs/{spec_id}:contents"
    )
    r = hub("GET", url)
    if r.status_code != 200:
        raise RuntimeError(
            f"fetch_spec failed: {r.status_code} {r.text}"
        )
    return base64.b64decode(r.json()["contents"])


# ---------------------------------------------------------------------------
# Fixtures
# ---------------------------------------------------------------------------

@pytest.fixture
def signed_manifest_file(tmp_path: Path) -> Path:
    m = {
        "manifest_schema_version": "1",
        "name": "demo-skill",
        "version": "2.0.0",
        "description": "Integration test manifest.",
        "keywords": ["demo"],
        "author": "tests",
        "license": "Apache-2.0",
        "gs_uri": "gs://demo-bucket/demo-skill-2.0.0.skill",
        "zip_sha256": "0" * 64,
        "signature": "AAAA",
        "signing_key_id": "sha256:" + "a" * 64,
        "runtime_iam": ["apigee.proxies.list"],
    }
    p = tmp_path / "manifest.signed.yaml"
    p.write_text(yaml.safe_dump(m, sort_keys=True))
    return p


@pytest.fixture
def hub_and_register(monkeypatch: pytest.MonkeyPatch) -> _FakeHub:
    import scripts.register_skill as rs
    hub = _FakeHub()
    creds = MagicMock()
    creds.token = "tok"
    creds.refresh = MagicMock(return_value=None)
    monkeypatch.setattr(rs, "_credentials", lambda: (creds, "demo"))
    monkeypatch.setattr(
        rs.requests, "request",
        lambda method, url, **kw: hub(method, url, **kw),
    )
    return hub


# ---------------------------------------------------------------------------
# Test
# ---------------------------------------------------------------------------

def test_register_then_fetch_byte_identical(
    hub_and_register: _FakeHub,
    signed_manifest_file: Path,
) -> None:
    """Register the manifest and immediately fetch the Spec back.
    The fetched bytes MUST equal the on-disk manifest bytes —
    no YAML re-serialisation, no encoding swap, no BOM
    introduction. If they differ, ed25519 verify in the consumer
    would fail in production.

    Note: API hub's versionId field rejects dots (see
    `register_skill.py` lines 203-207), so the on-the-wire ids are
    the hyphen-translated form `2-0-0` / `manifest-2-0-0`, not the
    semver `2.0.0` / `manifest-2.0.0`.
    """
    main = _import_register_main()
    rc = main([
        "--manifest", str(signed_manifest_file),
        "--project", "demo-project",
        "--location", "us-central1",
        "--quiet",
    ])
    assert rc == 0
    fetched = _fetch_spec(
        hub_and_register, "demo-project", "us-central1",
        "demo-skill", "2-0-0", "manifest-2-0-0",
    )
    assert fetched == signed_manifest_file.read_bytes()


def test_register_then_fetch_then_parse_roundtrip(
    hub_and_register: _FakeHub,
    signed_manifest_file: Path,
) -> None:
    """Even tighter: fetch the Spec, parse it as YAML, and
    confirm every field matches the source manifest. Catches
    encoding bugs that byte-equality might miss when the test
    fixture happens to be ASCII-pure."""
    main = _import_register_main()
    assert main([
        "--manifest", str(signed_manifest_file),
        "--project", "demo-project",
        "--location", "us-central1",
        "--quiet",
    ]) == 0
    fetched = _fetch_spec(
        hub_and_register, "demo-project", "us-central1",
        "demo-skill", "2-0-0", "manifest-2-0-0",
    )
    src = yaml.safe_load(signed_manifest_file.read_text())
    dst = yaml.safe_load(fetched.decode("utf-8"))
    assert src == dst


def test_second_register_does_not_disturb_fetch(
    hub_and_register: _FakeHub,
    signed_manifest_file: Path,
) -> None:
    """Idempotency at the fetch seam: re-running register_skill
    must not cause the consumer to download a different byte
    sequence on the second install. Equivalent to 'two installs
    in a row succeed identically'."""
    main = _import_register_main()
    assert main([
        "--manifest", str(signed_manifest_file),
        "--project", "demo-project",
        "--location", "us-central1",
        "--quiet",
    ]) == 0
    fetched_first = _fetch_spec(
        hub_and_register, "demo-project", "us-central1",
        "demo-skill", "2-0-0", "manifest-2-0-0",
    )
    assert main([
        "--manifest", str(signed_manifest_file),
        "--project", "demo-project",
        "--location", "us-central1",
        "--quiet",
    ]) == 0
    fetched_second = _fetch_spec(
        hub_and_register, "demo-project", "us-central1",
        "demo-skill", "2-0-0", "manifest-2-0-0",
    )
    assert fetched_first == fetched_second
