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

"""Tests for ``scripts/register_skill.py``.

Coverage targets:

  * API hub mocked: create-API on first run, no-op on second run.
  * PATCH attributes on attribute mismatch.
  * Dry-run prints intent, mutates nothing.

Per-component criterion:

  * Creates exactly one API + one Version + one Spec + four
    attribute values on a fresh project; is a no-op on second run
    with identical manifest.

API hub REST surface used:

  1. POST .../apis                          create API
  2. POST .../apis/{api}/versions           create Version
  3. POST .../apis/{api}/versions/{v}/specs create Spec
  4. PATCH .../apis/{api}                   set attributes
  5. GET   .../apis/{api}/versions/{v}/specs/{s}:contents
                                            fetch existing Spec

We mock ``requests`` and ``google.auth.default`` at the module
boundary. The fixture below builds a *stateful* mock that emulates
the API hub's resource model just well enough that the idempotency
test can drive a real second-run-is-no-op path.
"""
from __future__ import annotations

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
# Fake API hub
# ---------------------------------------------------------------------------

class FakeApiHub:
    """In-memory model of the slice of API hub the registration
    script touches. Drives both the create-then-noop test and
    the PATCH-on-mismatch test from a single stateful mock so
    the assertions about call counts remain meaningful.

    Resource model (one project + location implied by the fake):

      apis[name] -> {
          "name":       <full resource path>,
          "attributes": {<attr-key>: <attr-value-dict>, ...},
          "versions":   {ver_id: {"specs": {spec_id: {"contents": <b>}}}}
      }
    """

    def __init__(self) -> None:
        self.apis: dict[str, dict[str, Any]] = {}
        # Call ledger: each entry is (METHOD, path-suffix). Lets
        # the test assert exact counts per endpoint.
        self.calls: list[tuple[str, str]] = []

    # ------------------------------------------------------------------
    # The ``requests`` HTTP verb stubs.
    # ------------------------------------------------------------------

    def request(self, method: str, url: str, **kwargs: Any):
        # Strip the host + version + project + location prefix.
        prefix_marker = "/locations/"
        idx = url.find(prefix_marker)
        suffix = url[idx + len(prefix_marker):] if idx >= 0 else url
        # Drop the location segment itself, keep the rest.
        if "/" in suffix:
            suffix = "/" + suffix.split("/", 1)[1]
        self.calls.append((method, suffix))
        body = kwargs.get("json")
        params = kwargs.get("params", {}) or {}

        if method == "POST" and suffix == "/apis":
            api_id = params.get("apiId") or (body or {}).get("name")
            if api_id in self.apis:
                return _resp(409, {"error": "already exists"})
            self.apis[api_id] = {
                "name": f"projects/p/locations/l/apis/{api_id}",
                "attributes": (body or {}).get("attributes", {}),
                "versions": {},
            }
            return _resp(200, self.apis[api_id])

        if method == "GET" and suffix.startswith("/apis/"):
            parts = suffix.strip("/").split("/")
            # /apis/{id}/versions/{v}/specs/{s}:contents (6 parts)
            if suffix.endswith(":contents") and len(parts) == 6:
                api_id, ver_id, spec_id = parts[1], parts[3], parts[5]
                spec_id = spec_id.split(":")[0]
                api = self.apis.get(api_id)
                if not api:
                    return _resp(404, {})
                spec = (
                    api["versions"]
                    .get(ver_id, {})
                    .get("specs", {})
                    .get(spec_id)
                )
                if not spec:
                    return _resp(404, {})
                return _resp(200, {
                    "contents": spec["contents_b64"],
                    "mimeType": "application/yaml",
                })
            # /apis/{id}/versions/{v} (4 parts)
            if len(parts) == 4 and parts[2] == "versions":
                api_id, ver_id = parts[1], parts[3]
                api = self.apis.get(api_id)
                if not api or ver_id not in api["versions"]:
                    return _resp(404, {})
                return _resp(200, {
                    "name": f"{api['name']}/versions/{ver_id}",
                })
            # Bare GET .../apis/{id} (2 parts)
            if len(parts) == 2:
                api_id = parts[1]
                api = self.apis.get(api_id)
                if not api:
                    return _resp(404, {})
                return _resp(200, api)
            return _resp(404, {"error": f"unmocked GET {suffix}"})

        if method == "POST" and "/versions" in suffix \
                and not suffix.endswith("/specs"):
            api_id = suffix.strip("/").split("/")[1]
            ver_id = params.get("versionId") or (body or {}).get("name")
            api = self.apis[api_id]
            if ver_id in api["versions"]:
                return _resp(409, {"error": "already exists"})
            api["versions"][ver_id] = {"specs": {}}
            return _resp(200, {"name": f"{api['name']}/versions/{ver_id}"})

        if method == "POST" and suffix.endswith("/specs"):
            parts = suffix.strip("/").split("/")
            api_id, ver_id = parts[1], parts[3]
            spec_id = params.get("specId") or (body or {}).get("name")
            api = self.apis[api_id]
            ver = api["versions"][ver_id]
            # API hub's Spec body wraps the base64-encoded payload
            # inside a NESTED `contents` object alongside `mimeType`
            # and `specType`:
            #   {contents: {contents: <b64>, mimeType: "..."},
            #    specType: {...}}
            # The old fake assumed a flat `contents: <b64>` field
            # (the v0 surface before specType was made required).
            # Extract the inner b64 string so the second-run-noop
            # path (which GETs and byte-compares the stored spec)
            # finds an equal value instead of a serialized dict.
            raw_contents = (body or {}).get("contents", "")
            if isinstance(raw_contents, dict):
                raw_b64 = raw_contents.get("contents", "")
            else:
                # Backstop for any caller still using the flat shape.
                raw_b64 = raw_contents
            ver["specs"][spec_id] = {"contents_b64": raw_b64}
            return _resp(200, {"name": f"spec/{spec_id}"})

        if method == "PATCH" and suffix.startswith("/apis/"):
            api_id = suffix.strip("/").split("/")[1]
            api = self.apis.get(api_id)
            if not api:
                return _resp(404, {})
            # Replace attributes wholesale (the test cares about
            # the final state, not the merge semantics).
            api["attributes"] = (body or {}).get("attributes", {})
            return _resp(200, api)

        return _resp(404, {"error": f"unmocked {method} {suffix}"})


def _resp(status: int, body: dict):
    """Build a minimal Response-shaped object for the fake."""
    class _R:
        status_code = status
        text = json.dumps(body)

        def json(self) -> dict:
            return body

        def raise_for_status(self) -> None:
            if status >= 400:
                import requests
                raise requests.HTTPError(
                    f"HTTP {status}", response=self,  # type: ignore[arg-type]
                )
    return _R()


# ---------------------------------------------------------------------------
# Fixtures
# ---------------------------------------------------------------------------

@pytest.fixture
def fake_hub(monkeypatch: pytest.MonkeyPatch) -> FakeApiHub:
    import scripts.register_skill as rs

    hub = FakeApiHub()
    creds = MagicMock()
    creds.token = "fake-bearer"
    creds.refresh = MagicMock(return_value=None)
    monkeypatch.setattr(rs, "_credentials", lambda: (creds, "demo-project"))

    def request_router(method: str, url: str, **kwargs: Any):
        return hub.request(method, url, **kwargs)

    # We route all verbs through a single entry point so the fake
    # remains the single source of truth.
    monkeypatch.setattr(
        rs.requests, "request",
        lambda method, url, **kw: request_router(method, url, **kw),
    )
    return hub


@pytest.fixture
def signed_manifest_file(tmp_path: Path) -> Path:
    """A signed manifest YAML on disk. The signature itself is a
    sentinel string — the registration script does NOT verify
    signatures (that is the consumer's job at install time);
    register_skill only validates the schema and ships the
    manifest as the Spec body. So a sentinel sig is fine."""
    m = {
        "manifest_schema_version": "1",
        "name": "demo-skill",
        "version": "1.0.0",
        "description": "Demo.",
        "keywords": ["demo"],
        "author": "tests",
        "license": "Apache-2.0",
        "gs_uri": "gs://demo-bucket/demo-skill-1.0.0.skill",
        "zip_sha256": "0" * 64,
        "signature": "AAAA",
        "signing_key_id": "sha256:" + "a" * 64,
        "runtime_iam": ["apigee.proxies.list"],
    }
    p = tmp_path / "manifest.signed.yaml"
    p.write_text(yaml.safe_dump(m, sort_keys=True))
    return p


# ---------------------------------------------------------------------------
# Happy path: create on first run, no-op on second
# ---------------------------------------------------------------------------

def test_first_run_creates_api_version_spec_and_attrs(
    fake_hub: FakeApiHub,
    signed_manifest_file: Path,
) -> None:
    """Exactly one API + one Version + one Spec + four attribute
    values."""
    main = _import_register_main()
    rc = main([
        "--manifest", str(signed_manifest_file),
        "--project", "demo-project",
        "--location", "us-central1",
        "--quiet",
    ])
    assert rc == 0
    # The fake's call ledger tells us what was attempted.
    posts = [c for c in fake_hub.calls if c[0] == "POST"]
    patches = [c for c in fake_hub.calls if c[0] == "PATCH"]
    # Exactly one POST per resource type: api, version, spec.
    assert sum(1 for m, s in posts if s == "/apis") == 1
    assert sum(
        1 for m, s in posts if s.endswith("/versions")
    ) == 1
    assert sum(
        1 for m, s in posts if s.endswith("/specs")
    ) == 1
    # Exactly one PATCH for the attributes.
    assert len(patches) == 1
    # The four attribute values land on the API resource. API hub
    # keys the AttributeValues map by FULLY-QUALIFIED attribute
    # resource name (`projects/<p>/locations/<l>/attributes/<id>`),
    # not by bare id. The script emits the FQ form when project +
    # location are passed (see `register_skill._attributes_from_manifest`
    # lines 100-127).
    attrs = fake_hub.apis["demo-skill"]["attributes"]
    expected_attr_keys = {
        f"projects/demo-project/locations/us-central1/attributes/{a}"
        for a in (
            "agentic_skill", "keywords", "gs_uri", "signing_key_id"
        )
    }
    assert set(attrs.keys()) >= expected_attr_keys


def test_second_run_is_noop(
    fake_hub: FakeApiHub,
    signed_manifest_file: Path,
) -> None:
    """Second run with identical manifest is a no-op (compares
    Spec contents byte-for-byte; only updates on mismatch). The
    exact noop-detection mechanism is left to the implementation,
    but the observable contract is: no additional POSTs to /apis,
    /versions, /specs and no PATCH on the API."""
    main = _import_register_main()
    main([
        "--manifest", str(signed_manifest_file),
        "--project", "demo-project",
        "--location", "us-central1",
        "--quiet",
    ])
    fake_hub.calls.clear()
    rc = main([
        "--manifest", str(signed_manifest_file),
        "--project", "demo-project",
        "--location", "us-central1",
        "--quiet",
    ])
    assert rc == 0
    posts = [c for c in fake_hub.calls if c[0] == "POST"]
    patches = [c for c in fake_hub.calls if c[0] == "PATCH"]
    # Zero writes on the second run.
    assert posts == []
    assert patches == []


def test_attribute_mismatch_triggers_patch(
    fake_hub: FakeApiHub,
    signed_manifest_file: Path,
    tmp_path: Path,
) -> None:
    """If the second-run manifest changes an attribute (here,
    keywords), the script must PATCH the API resource. Spec
    content is unchanged so no Spec POST; only the attribute
    delta is written."""
    main = _import_register_main()
    main([
        "--manifest", str(signed_manifest_file),
        "--project", "demo-project",
        "--location", "us-central1",
        "--quiet",
    ])
    fake_hub.calls.clear()

    # Mutate the manifest in a way that ONLY changes the attribute
    # set (different keywords) but leaves the Spec body byte-for-
    # byte equal once attributes are stripped. The simplest way is
    # to load, mutate, and write back.
    signed = yaml.safe_load(signed_manifest_file.read_text())
    signed["keywords"] = ["demo", "new-keyword"]
    signed_manifest_file.write_text(yaml.safe_dump(signed, sort_keys=True))

    rc = main([
        "--manifest", str(signed_manifest_file),
        "--project", "demo-project",
        "--location", "us-central1",
        "--quiet",
    ])
    assert rc == 0
    patches = [c for c in fake_hub.calls if c[0] == "PATCH"]
    assert len(patches) >= 1


def test_dry_run_mutates_nothing(
    fake_hub: FakeApiHub,
    signed_manifest_file: Path,
    capsys: pytest.CaptureFixture[str],
) -> None:
    """``--dry-run``: prints intent (so the operator can audit),
    issues only GETs (to discover state), and makes zero writes."""
    main = _import_register_main()
    rc = main([
        "--manifest", str(signed_manifest_file),
        "--project", "demo-project",
        "--location", "us-central1",
        "--dry-run",
    ])
    assert rc == 0
    out = capsys.readouterr().out
    assert "dry-run" in out.lower() or "would" in out.lower()
    # No POSTs and no PATCHes.
    writes = [c for c in fake_hub.calls if c[0] in ("POST", "PATCH")]
    assert writes == []


# ---------------------------------------------------------------------------
# Validation paths
# ---------------------------------------------------------------------------

def test_invalid_manifest_exits_1(
    fake_hub: FakeApiHub,
    tmp_path: Path,
) -> None:
    """The script must validate before talking to API hub. A
    schema-invalid manifest is user error."""
    bad = tmp_path / "bad.yaml"
    bad.write_text("manifest_schema_version: '2'\nname: ohno\n")
    main = _import_register_main()
    rc = main([
        "--manifest", str(bad),
        "--project", "demo-project",
        "--location", "us-central1",
        "--quiet",
    ])
    assert rc == 1


def test_missing_manifest_exits_1(
    fake_hub: FakeApiHub,
    tmp_path: Path,
) -> None:
    main = _import_register_main()
    rc = main([
        "--manifest", str(tmp_path / "missing.yaml"),
        "--project", "demo-project",
        "--location", "us-central1",
        "--quiet",
    ])
    assert rc == 1
