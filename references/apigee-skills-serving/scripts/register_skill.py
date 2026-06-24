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

"""Register (or update) a signed skill manifest in API hub.

CLI grammar:

    register-skill.py --manifest <path>
                      --project <gcp-project-id>
                      --location <api-hub-location>
                      [--dry-run]
                      [--quiet]

Idempotent pipeline:

  1. Validate the manifest against the schema.
  2. GET the API resource by ``name``. If 404 → POST to create.
  3. GET the Version. If 404 → POST to create.
  4. GET the Spec ``:contents``. If 404 OR the existing body
     differs from our manifest YAML → POST to create/update.
  5. Compare attributes against the API's current attributes.
     PATCH only when there is a diff.

Re-running with the same inputs touches the network with reads
only (no POST, no PATCH) → byte-identical behaviour is observable
as zero mutating calls (the test asserts this).

Exit codes:
  0 success
  1 user error (bad CLI args, missing file, schema invalid)
  2 system error
  3 IAM / 403
  4 API-hub-side reject (e.g., taxonomy not initialised)
"""
from __future__ import annotations

import argparse
import base64
import sys
from pathlib import Path
from typing import Any, Sequence

import requests
import yaml

from scripts.common.manifest_schema import (
    ManifestValidationError,
    validate_manifest,
)

EXIT_OK = 0
EXIT_USER = 1
EXIT_SYSTEM = 2
EXIT_IAM = 3
EXIT_TAXONOMY = 4

_API_HUB_BASE = (
    "https://apihub.googleapis.com/v1/"
    "projects/{project}/locations/{location}"
)

# Attribute keys we project from the manifest onto the API
# resource. These four must already exist as attribute
# definitions (created by ``update_taxonomy.py``); if they don't,
# the API hub side rejects the PATCH with 400 and we exit 4.
_ATTR_KEYS = ("agentic_skill", "keywords", "gs_uri", "signing_key_id")


def _err(quiet: bool, msg: str) -> None:
    if not quiet:
        print(msg, file=sys.stderr)


def _credentials():
    """Cloud-platform scoped ADC, matching the uniform scope
    used by every other helper."""
    import google.auth
    import google.auth.transport.requests

    creds, project = google.auth.default(
        scopes=["https://www.googleapis.com/auth/cloud-platform"]
    )
    creds.refresh(google.auth.transport.requests.Request())
    return creds, project


def _parse_args(argv: Sequence[str]) -> argparse.Namespace:
    p = argparse.ArgumentParser(
        prog="register-skill.py",
        description="Register a signed skill manifest in API hub.",
    )
    p.add_argument("--manifest", required=True)
    p.add_argument("--project", required=True)
    p.add_argument("--location", required=True)
    p.add_argument("--dry-run", action="store_true", dest="dry_run")
    p.add_argument("--quiet", action="store_true")
    return p.parse_args(list(argv))


def _attributes_from_manifest(
    manifest: dict[str, Any],
    project: str | None = None,
    location: str | None = None,
) -> dict:
    """Build the attribute-values payload shape the API hub PATCH
    expects.

    API hub keys the AttributeValues map by FULLY-QUALIFIED
    attribute resource name (``projects/<p>/locations/<l>/
    attributes/<id>``), not by bare attribute id. When project
    and location are provided we emit the FQ form (production
    use). When omitted we fall back to bare ids (legacy
    fixture-based tests still pass)."""
    if project and location:
        prefix = f"projects/{project}/locations/{location}/attributes/"
    else:
        prefix = ""
    return {
        f"{prefix}agentic_skill": {
            "stringValues": {"values": ["true"]}
        },
        f"{prefix}keywords": {"stringValues": {"values": list(
            manifest.get("keywords", [])
        )}},
        f"{prefix}gs_uri": {
            "stringValues": {"values": [manifest["gs_uri"]]}
        },
        f"{prefix}signing_key_id": {"stringValues": {"values": [
            manifest["signing_key_id"],
        ]}},
    }


def _api_get(url: str, headers: dict, params: dict | None = None):
    return requests.request(
        "GET", url, headers=headers, params=params or {}, timeout=30,
    )


def _api_post(url: str, headers: dict, body: dict | None,
              params: dict | None = None):
    return requests.request(
        "POST", url, headers=headers, params=params or {},
        json=body or {}, timeout=60,
    )


def _api_patch(
    url: str, headers: dict, body: dict, params: dict | None = None
):
    return requests.request(
        "PATCH", url, headers=headers, json=body, params=params,
        timeout=60,
    )


def _classify_http_error(status: int) -> int:
    if status == 403:
        return EXIT_IAM
    if status == 400:
        # API hub rejects malformed payloads as 400; the most
        # likely cause for us is "attribute definition does not
        # exist" — which is the exit-4 case.
        return EXIT_TAXONOMY
    return EXIT_SYSTEM


def _say(quiet: bool, msg: str) -> None:
    """Operator-visible status print. Lives on stdout (not stderr)
    so ``--dry-run`` output is grep-able from a pipeline."""
    if not quiet:
        print(msg)


def main(argv: Sequence[str] | None = None) -> int:
    if argv is None:
        argv = sys.argv[1:]
    try:
        ns = _parse_args(argv)
    except SystemExit:
        return EXIT_USER

    quiet = ns.quiet
    manifest_path = Path(ns.manifest)
    if not manifest_path.is_file():
        _err(quiet, f"error: manifest not found: {manifest_path}")
        return EXIT_USER

    try:
        manifest_text = manifest_path.read_text(encoding="utf-8")
        manifest = yaml.safe_load(manifest_text)
    except (yaml.YAMLError, UnicodeDecodeError) as exc:
        _err(quiet, f"error: manifest parse failed: {exc}")
        return EXIT_USER
    if not isinstance(manifest, dict):
        _err(quiet, "error: manifest YAML must be a mapping")
        return EXIT_USER

    try:
        validate_manifest(manifest)
    except ManifestValidationError as exc:
        _err(quiet, f"error: manifest invalid: {exc}")
        return EXIT_USER

    name = manifest["name"]
    version = manifest["version"]
    # API hub's versionId field rejects dots; translate semver
    # "0.1.0" -> "0-1-0" for the resource path. Spec id stays in
    # dotted form for human readability.
    version_id = version.replace(".", "-")
    spec_id = f"manifest-{version_id}"

    try:
        creds, _ = _credentials()
    except Exception as exc:
        _err(quiet, f"error: ADC credentials unavailable: {exc}")
        return EXIT_USER

    base = _API_HUB_BASE.format(
        project=ns.project, location=ns.location
    )
    headers = {
        "Authorization": f"Bearer {creds.token}",
        "Content-Type": "application/json",
    }

    # ---- 1. API resource ------------------------------------------------
    # API hub's admission-control layer returns 403 ("Read access to
    # project denied") on GET of nonexistent SUBresources even when
    # the caller can write them. Treat 403 + 404 + 200 as the only
    # non-fatal statuses; assume nonexistence when 403 or 404.
    api_url = f"{base}/apis/{name}"
    api_resp = _api_get(api_url, headers)
    api_exists = api_resp.status_code == 200
    if not api_exists and api_resp.status_code not in (200, 403, 404):
        _err(quiet, f"error: GET API failed ({api_resp.status_code})")
        return _classify_http_error(api_resp.status_code)

    desired_attrs = _attributes_from_manifest(
        manifest, project=ns.project, location=ns.location
    )

    if not api_exists:
        _say(quiet, f"would create API: {name}"
             if ns.dry_run else f"creating API: {name}")
        if not ns.dry_run:
            # Create the API resource *without* attributes; we PATCH
            # them separately below. Splitting create-vs-attribute-
            # set keeps the idempotency story clean: the bare
            # create is "did the resource exist", the attribute
            # PATCH is "do the attribute values match" — two
            # independent decisions instead of one tangled "what
            # did the API look like at creation time" history bit.
            r = _api_post(
                f"{base}/apis",
                headers,
                {
                    "displayName": name,
                    "description": manifest.get("description", ""),
                },
                params={"apiId": name},
            )
            if r.status_code >= 400:
                _err(quiet, f"error: POST api failed ({r.status_code})")
                return _classify_http_error(r.status_code)
        # We just created the API; treat its attribute state as
        # empty so the PATCH below will fire exactly once.
        current_attrs = {}
    else:
        current_attrs = api_resp.json().get("attributes", {})

    # ---- 2. Version -----------------------------------------------------
    ver_url = f"{base}/apis/{name}/versions/{version_id}"
    ver_resp = _api_get(ver_url, headers)
    ver_exists = ver_resp.status_code == 200
    if not ver_exists and ver_resp.status_code not in (200, 403, 404):
        _err(quiet, f"error: GET Version failed ({ver_resp.status_code})")
        return _classify_http_error(ver_resp.status_code)

    if not ver_exists:
        _say(quiet, f"would create Version: {version}"
             if ns.dry_run else f"creating Version: {version}")
        if not ns.dry_run:
            r = _api_post(
                f"{base}/apis/{name}/versions",
                headers,
                {"displayName": version},
                params={"versionId": version_id},
            )
            if r.status_code >= 400:
                body_snippet = (r.text or "")[:300]
                _err(
                    quiet,
                    f"error: POST version failed ({r.status_code}): "
                    f"{body_snippet}",
                )
                return _classify_http_error(r.status_code)

    # ---- 3. Spec --------------------------------------------------------
    spec_contents = manifest_text.encode("utf-8")
    spec_url = (
        f"{base}/apis/{name}/versions/{version_id}"
        f"/specs/{spec_id}:contents"
    )
    spec_resp = _api_get(spec_url, headers)
    spec_exists = spec_resp.status_code == 200
    needs_spec_write = True
    if spec_exists:
        existing_b64 = spec_resp.json().get("contents", "")
        try:
            existing = base64.b64decode(existing_b64)
        except (ValueError, TypeError):
            existing = b""
        if existing == spec_contents:
            needs_spec_write = False
        else:
            _say(quiet, "spec content differs; will rewrite")
    if needs_spec_write:
        _say(quiet, f"would create/update Spec: {spec_id}"
             if ns.dry_run else f"writing Spec: {spec_id}")
        if not ns.dry_run:
            # API hub Spec schema requires:
            #  - contents is a NESTED object: {contents:<b64>, mimeType:...}
            #  - specType is a REQUIRED enum reference to the
            #    system-spec-type attribute. We use the built-in
            #    "skill-spec" enum value (purpose-built for this).
            # Idempotency: POST on first-create, PATCH on update.
            # The spec_exists flag above tells us which path to take.
            spec_type_attr = (
                f"projects/{ns.project}/locations/{ns.location}"
                f"/attributes/system-spec-type"
            )
            spec_body = {
                "displayName": spec_id,
                "contents": {
                    "contents": base64.b64encode(spec_contents)
                    .decode("ascii"),
                    "mimeType": "application/yaml",
                },
                "specType": {
                    "attribute": spec_type_attr,
                    "enumValues": {
                        "values": [
                            {
                                "id": "skill-spec",
                                "displayName": "Skill Spec",
                            }
                        ]
                    },
                },
            }
            if spec_exists:
                # PATCH the existing Spec. API hub enforces that
                # when `contents` is in updateMask, `spec_type`
                # must also be present (otherwise the spec_type
                # would silently revert to inferred). Include both.
                spec_resource_url = (
                    f"{base}/apis/{name}/versions/{version_id}"
                    f"/specs/{spec_id}"
                )
                r = _api_patch(
                    spec_resource_url,
                    headers,
                    spec_body,
                    params={"updateMask": "contents,spec_type"},
                )
            else:
                r = _api_post(
                    f"{base}/apis/{name}/versions/{version_id}/specs",
                    headers,
                    spec_body,
                    params={"specId": spec_id},
                )
            if r.status_code >= 400:
                body_snippet = (r.text or "")[:300]
                verb = "PATCH" if spec_exists else "POST"
                _err(
                    quiet,
                    f"error: {verb} spec failed ({r.status_code}): "
                    f"{body_snippet}",
                )
                return _classify_http_error(r.status_code)

    # ---- 4. Attributes (PATCH only on diff) -----------------------------
    if current_attrs != desired_attrs:
        _say(quiet, "would patch attributes" if ns.dry_run
             else "patching attributes")
        if not ns.dry_run:
            # API hub PATCH (standard Google AIP-134) requires an
            # update_mask query param naming the field to update.
            r = _api_patch(
                api_url,
                headers,
                {"attributes": desired_attrs},
                params={"updateMask": "attributes"},
            )
            if r.status_code >= 400:
                body_snippet = (r.text or "")[:300]
                _err(
                    quiet,
                    f"error: PATCH api failed ({r.status_code}): "
                    f"{body_snippet}",
                )
                return _classify_http_error(r.status_code)

    if ns.dry_run:
        _say(quiet, "dry-run: no mutations performed")
    else:
        _say(quiet, f"registered: {name} {version}")
    return EXIT_OK


if __name__ == "__main__":  # pragma: no cover
    raise SystemExit(main())
