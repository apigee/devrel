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

"""Manifest schema validator.

Validates a parsed manifest dict against the LOCKED v1 schema.
Used by ``sign_skill.py`` (before signing -- refuses to sign an
invalid manifest), by ``register_skill.py`` (before posting to
API hub), and by the consumer's install-time verifier (after
ed25519 verify, before any side-effecting work).

Unknown top-level keys are accepted (forward compatibility); a
newer signer can add fields a current verifier hasn't learned
about yet without breaking the install.

The validator is hand-rolled regexes + length checks instead of
jsonschema/pydantic for two reasons:

1. **Dependency surface.** Adding jsonschema or pydantic would
   inflate ``requirements.txt``; both have larger transitive
   trees than the four current deps combined.
2. **Error messages.** A hand-rolled validator produces stable
   failure messages naturally; jsonschema's default
   ValidationError messages are noisier than the contract
   surface allows.

``runtime_iam`` MUST use dot-form (``apigee.proxies.list``),
NOT the service-host prefix form
(``apigee.googleapis.com/proxies``) -- ``testIamPermissions``
rejects the prefix form, so a manifest carrying the wrong form
would fail every install. The regex below enforces dot-form.
"""
from __future__ import annotations

import re
from typing import Any

# Field regexes. Compiled once at import time.
_NAME_RE = re.compile(r"^[a-z0-9]+(-[a-z0-9]+)*$")
_VERSION_RE = re.compile(r"^\d+\.\d+\.\d+$")
_KEYWORD_RE = re.compile(r"^[a-z0-9-]+$")
_GS_URI_RE = re.compile(r"^gs://[a-z0-9._-]+/.+\.skill$")
_ZIP_SHA256_RE = re.compile(r"^[0-9a-f]{64}$")
_SIGNING_KEY_ID_RE = re.compile(r"^sha256:[0-9a-f]{64}$")
# Dot-form GCP IAM permission. The leading lowercase service id,
# then one or more dot-separated lowercase-alphanumeric segments.
# Rejects the service-host-prefix form by construction (no slashes,
# no dots in the leading segment).
_IAM_PERM_RE = re.compile(r"^[a-z]+\.[a-z0-9.]+$")


class ManifestValidationError(ValueError):
    """Raised when a manifest dict fails the schema."""


def _require(cond: bool, msg: str) -> None:
    """Assert *cond* or raise ManifestValidationError(msg)."""
    if not cond:
        raise ManifestValidationError(msg)


def _check_string_length(
    field: str, value: Any, min_len: int, max_len: int
) -> None:
    _require(
        isinstance(value, str),
        f"field {field!r} must be a string, got {type(value).__name__}",
    )
    _require(
        min_len <= len(value) <= max_len,
        f"field {field!r} length {len(value)} out of bounds "
        f"[{min_len}, {max_len}]",
    )


def _check_regex(field: str, value: Any, pattern: re.Pattern[str]) -> None:
    _require(
        isinstance(value, str),
        f"field {field!r} must be a string, got {type(value).__name__}",
    )
    _require(
        pattern.fullmatch(value) is not None,
        f"field {field!r} value {value!r} does not match "
        f"required pattern {pattern.pattern}",
    )


def _check_list_of_strings(
    field: str, value: Any, min_items: int, max_items: int
) -> None:
    _require(
        isinstance(value, list),
        f"field {field!r} must be a list, got {type(value).__name__}",
    )
    _require(
        min_items <= len(value) <= max_items,
        f"field {field!r} length {len(value)} out of bounds "
        f"[{min_items}, {max_items}]",
    )
    for i, item in enumerate(value):
        _require(
            isinstance(item, str),
            f"field {field!r}[{i}] must be a string, "
            f"got {type(item).__name__}",
        )


def validate_manifest(manifest: dict[str, Any]) -> None:
    """Validate *manifest* against the schema.

    Raises ManifestValidationError on the first violation. Does
    not mutate *manifest*. Returns ``None`` on success so the
    caller can chain ``validate_manifest(m); use(m)``.
    """
    _require(
        isinstance(manifest, dict),
        f"manifest must be a dict, got {type(manifest).__name__}",
    )

    # manifest_schema_version: exact "1".
    _require(
        manifest.get("manifest_schema_version") == "1",
        "manifest_schema_version must be the string \"1\"",
    )

    # name: regex + length 1..64.
    _require("name" in manifest, "missing required field 'name'")
    _check_string_length("name", manifest["name"], 1, 64)
    _check_regex("name", manifest["name"], _NAME_RE)

    # version: semver.
    _require("version" in manifest, "missing required field 'version'")
    _check_regex("version", manifest["version"], _VERSION_RE)

    # description: length 1..1024.
    _require(
        "description" in manifest,
        "missing required field 'description'",
    )
    _check_string_length("description", manifest["description"], 1, 1024)

    # keywords: 1..20 items, each matches _KEYWORD_RE.
    _require(
        "keywords" in manifest, "missing required field 'keywords'"
    )
    _check_list_of_strings("keywords", manifest["keywords"], 1, 20)
    for kw in manifest["keywords"]:
        _check_regex("keywords[*]", kw, _KEYWORD_RE)

    # author: length 1..256.
    _require("author" in manifest, "missing required field 'author'")
    _check_string_length("author", manifest["author"], 1, 256)

    # license: SPDX identifier; we accept any non-empty string
    # rather than maintain the SPDX list. This is a soft check.
    _require("license" in manifest, "missing required field 'license'")
    _check_string_length("license", manifest["license"], 1, 64)

    # gs_uri.
    _require("gs_uri" in manifest, "missing required field 'gs_uri'")
    _check_regex("gs_uri", manifest["gs_uri"], _GS_URI_RE)

    # zip_sha256: exactly 64 lowercase hex chars.
    _require(
        "zip_sha256" in manifest,
        "missing required field 'zip_sha256'",
    )
    _check_regex("zip_sha256", manifest["zip_sha256"], _ZIP_SHA256_RE)

    # signature: base64 string. Length is not gated by the schema;
    # the actual base64 decode + ed25519 verify happens later.
    _require(
        "signature" in manifest,
        "missing required field 'signature'",
    )
    _require(
        isinstance(manifest["signature"], str)
        and len(manifest["signature"]) > 0,
        "field 'signature' must be a non-empty string (base64)",
    )

    # signing_key_id.
    _require(
        "signing_key_id" in manifest,
        "missing required field 'signing_key_id'",
    )
    _check_regex(
        "signing_key_id",
        manifest["signing_key_id"],
        _SIGNING_KEY_ID_RE,
    )

    # runtime_iam: optional; if present, list of dot-form strings.
    # The 100-item cap is a defensive upper bound: an adversarial
    # manifest with 10k IAM strings would force the install-time
    # pre-flight to make 10k testIamPermissions calls. 100 is
    # generously above the legitimate ceiling
    # (apigee-policy-top10 uses 3 permissions; a hypothetical
    # full-Apigee management skill might need 30-40).
    if "runtime_iam" in manifest:
        _check_list_of_strings(
            "runtime_iam", manifest["runtime_iam"], 0, 100
        )
        for perm in manifest["runtime_iam"]:
            _check_regex("runtime_iam[*]", perm, _IAM_PERM_RE)

    # capabilities: optional, free-form, not enforced.
    if "capabilities" in manifest:
        _require(
            isinstance(manifest["capabilities"], list),
            "field 'capabilities' must be a list when present",
        )
