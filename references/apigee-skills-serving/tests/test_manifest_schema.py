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

"""Tests for ``scripts/common/manifest_schema.py``.

The manifest schema is LOCKED. Every required field is enforced;
every regex has a positive and a negative case. ``runtime_iam``
must use the GCP IAM dot-form (e.g., ``apigee.proxies.list``),
NOT the service-host prefix form
(``apigee.googleapis.com/proxies``) -- so the negative regex case
for that field is the bug we are explicitly defending against.

Acceptance: "every required field rejected when absent; every
regex enforced on a positive and a negative (including dot-form
``runtime_iam``); unknown top-level keys accepted; schema version
``\"1\"``".
"""
from __future__ import annotations

from typing import Any

import pytest

from scripts.common.manifest_schema import (ManifestValidationError,
                                            validate_manifest)


@pytest.fixture
def valid_manifest() -> dict[str, Any]:
    """A minimal-but-complete manifest that MUST validate cleanly.
    Tests mutate copies to exercise edge cases; the fixture itself
    is the baseline 'this should pass' shape."""
    return {
        "manifest_schema_version": "1",
        "name": "demo-skill",
        "version": "1.0.0",
        "description": "Demonstration skill for integration tests.",
        "keywords": ["demo", "test"],
        "author": "demo-test-suite",
        "license": "Apache-2.0",
        "gs_uri": "gs://demo-bucket/demo-skill-1.0.0.skill",
        "zip_sha256": "0" * 64,
        "signature": "AAAA",  # base64 sentinel; sig length not
                              # gated by the schema
        "signing_key_id": "sha256:" + "a" * 64,
        "runtime_iam": ["apigee.proxies.list"],
    }


def test_valid_minimal_manifest_passes(
    valid_manifest: dict[str, Any],
) -> None:
    """The fixture itself MUST validate; this is the canary that
    catches accidental over-strict regexes in the implementation."""
    validate_manifest(valid_manifest)  # no exception


REQUIRED_FIELDS = (
    "manifest_schema_version",
    "name",
    "version",
    "description",
    "keywords",
    "author",
    "license",
    "gs_uri",
    "zip_sha256",
    "signature",
    "signing_key_id",
)


@pytest.mark.parametrize("field", REQUIRED_FIELDS)
def test_required_field_rejected_when_absent(
    valid_manifest: dict[str, Any], field: str
) -> None:
    """Each of the 11 required fields, removed in turn, must
    cause validation to raise. Parameterized so a future schema
    addition only needs a new entry in REQUIRED_FIELDS, not a new
    test function."""
    del valid_manifest[field]
    with pytest.raises(ManifestValidationError):
        validate_manifest(valid_manifest)


def test_manifest_schema_version_must_be_string_one(
    valid_manifest: dict[str, Any],
) -> None:
    """Per §2.6 the field is the *string* ``"1"``, not the int
    ``1`` and not ``"2"`` (which would advertise a future
    incompatible schema)."""
    for bad in ["2", "1.0", 1, None]:
        valid_manifest["manifest_schema_version"] = bad
        with pytest.raises(ManifestValidationError):
            validate_manifest(valid_manifest)


@pytest.mark.parametrize(
    "name", ["a", "demo-skill", "1-2-3", "abc-def-ghi", "a" * 64]
)
def test_name_regex_positive(
    valid_manifest: dict[str, Any], name: str
) -> None:
    valid_manifest["name"] = name
    validate_manifest(valid_manifest)


@pytest.mark.parametrize(
    "name",
    [
        "",
        "My-Skill",  # uppercase
        "my_skill",  # underscore
        "my skill",  # space
        "-leading-dash",
        "trailing-dash-",
        "a" * 65,  # too long
        "double--dash",  # consecutive dashes not in regex
    ],
)
def test_name_regex_negative(
    valid_manifest: dict[str, Any], name: str
) -> None:
    valid_manifest["name"] = name
    with pytest.raises(ManifestValidationError):
        validate_manifest(valid_manifest)


@pytest.mark.parametrize(
    "version", ["1.0.0", "0.0.0", "10.20.30", "999.999.999"]
)
def test_version_semver_positive(
    valid_manifest: dict[str, Any], version: str
) -> None:
    valid_manifest["version"] = version
    validate_manifest(valid_manifest)


@pytest.mark.parametrize(
    "version", ["1.0", "v1.0.0", "1.0.0-beta", "1.0.0.0", ""]
)
def test_version_semver_negative(
    valid_manifest: dict[str, Any], version: str
) -> None:
    valid_manifest["version"] = version
    with pytest.raises(ManifestValidationError):
        validate_manifest(valid_manifest)


def test_description_length_bounds(
    valid_manifest: dict[str, Any],
) -> None:
    """Per §2.6 length 1-1024. Boundary checks both ends."""
    valid_manifest["description"] = "a"  # 1 ok
    validate_manifest(valid_manifest)
    valid_manifest["description"] = "a" * 1024  # 1024 ok
    validate_manifest(valid_manifest)
    valid_manifest["description"] = ""  # 0 bad
    with pytest.raises(ManifestValidationError):
        validate_manifest(valid_manifest)
    valid_manifest["description"] = "a" * 1025  # 1025 bad
    with pytest.raises(ManifestValidationError):
        validate_manifest(valid_manifest)


def test_keywords_count_bounds(
    valid_manifest: dict[str, Any],
) -> None:
    """Per §2.6 1-20 items."""
    valid_manifest["keywords"] = ["a"]
    validate_manifest(valid_manifest)
    valid_manifest["keywords"] = [f"k{i}" for i in range(20)]
    validate_manifest(valid_manifest)
    valid_manifest["keywords"] = []
    with pytest.raises(ManifestValidationError):
        validate_manifest(valid_manifest)
    valid_manifest["keywords"] = [f"k{i}" for i in range(21)]
    with pytest.raises(ManifestValidationError):
        validate_manifest(valid_manifest)


@pytest.mark.parametrize(
    "keyword", ["abc", "abc-def", "123", "abc-123"]
)
def test_keywords_regex_positive(
    valid_manifest: dict[str, Any], keyword: str
) -> None:
    valid_manifest["keywords"] = [keyword]
    validate_manifest(valid_manifest)


@pytest.mark.parametrize(
    "keyword", ["ABC", "abc_def", "abc def", "abc.def", ""]
)
def test_keywords_regex_negative(
    valid_manifest: dict[str, Any], keyword: str
) -> None:
    valid_manifest["keywords"] = [keyword]
    with pytest.raises(ManifestValidationError):
        validate_manifest(valid_manifest)


@pytest.mark.parametrize(
    "uri",
    [
        "gs://my-bucket/my-skill.skill",
        "gs://b/a.skill",
        "gs://a.b.c/deep/path/to.skill",
    ],
)
def test_gs_uri_regex_positive(
    valid_manifest: dict[str, Any], uri: str
) -> None:
    valid_manifest["gs_uri"] = uri
    validate_manifest(valid_manifest)


@pytest.mark.parametrize(
    "uri",
    [
        "https://example.com/x.skill",
        "gs://Bucket/x.skill",  # uppercase
        "gs://bucket/x.zip",  # wrong extension
        "gs://bucket/",  # empty object
        "",
    ],
)
def test_gs_uri_regex_negative(
    valid_manifest: dict[str, Any], uri: str
) -> None:
    valid_manifest["gs_uri"] = uri
    with pytest.raises(ManifestValidationError):
        validate_manifest(valid_manifest)


def test_zip_sha256_regex(valid_manifest: dict[str, Any]) -> None:
    """Per §2.6 exactly 64 lowercase hex chars."""
    valid_manifest["zip_sha256"] = "a" * 64
    validate_manifest(valid_manifest)
    valid_manifest["zip_sha256"] = "0123456789abcdef" * 4
    validate_manifest(valid_manifest)
    valid_manifest["zip_sha256"] = "a" * 63  # too short
    with pytest.raises(ManifestValidationError):
        validate_manifest(valid_manifest)
    valid_manifest["zip_sha256"] = "A" * 64  # uppercase
    with pytest.raises(ManifestValidationError):
        validate_manifest(valid_manifest)
    valid_manifest["zip_sha256"] = "g" * 64  # non-hex
    with pytest.raises(ManifestValidationError):
        validate_manifest(valid_manifest)


def test_signing_key_id_regex(valid_manifest: dict[str, Any]) -> None:
    valid_manifest["signing_key_id"] = "sha256:" + "f" * 64
    validate_manifest(valid_manifest)
    # Wrong prefix.
    valid_manifest["signing_key_id"] = "sha1:" + "f" * 40
    with pytest.raises(ManifestValidationError):
        validate_manifest(valid_manifest)
    # Missing colon.
    valid_manifest["signing_key_id"] = "sha256" + "f" * 64
    with pytest.raises(ManifestValidationError):
        validate_manifest(valid_manifest)


def test_runtime_iam_is_optional(valid_manifest: dict[str, Any]) -> None:
    """Per §2.6 runtime_iam is the only optional field besides
    capabilities. Absent and empty-list MUST both validate."""
    del valid_manifest["runtime_iam"]
    validate_manifest(valid_manifest)
    valid_manifest["runtime_iam"] = []
    validate_manifest(valid_manifest)


@pytest.mark.parametrize(
    "perm",
    [
        "apigee.proxies.list",
        "apigee.deployments.list",
        "apigee.proxyrevisions.get",
        "apigee.organizations.apis.list",
        "iam.serviceaccounts.actas",
    ],
)
def test_runtime_iam_dot_form_positive(
    valid_manifest: dict[str, Any], perm: str
) -> None:
    """The §2.4 IAM list MUST validate; these are exactly the
    permissions the apigee-policy-top10 skill declares."""
    valid_manifest["runtime_iam"] = [perm]
    validate_manifest(valid_manifest)


@pytest.mark.parametrize(
    "bad_perm",
    [
        # The §10.1 explicit-rejection case: service-host-prefixed
        # form. testIamPermissions rejects this.
        "apigee.googleapis.com/proxies.list",
        # Slash form (REST-style).
        "apigee/proxies/list",
        # Uppercase.
        "Apigee.Proxies.List",
        # Empty string.
        "",
        # Single segment (no dots).
        "apigee",
    ],
)
def test_runtime_iam_dot_form_negative(
    valid_manifest: dict[str, Any], bad_perm: str
) -> None:
    valid_manifest["runtime_iam"] = [bad_perm]
    with pytest.raises(ManifestValidationError):
        validate_manifest(valid_manifest)


def test_unknown_top_level_keys_accepted(
    valid_manifest: dict[str, Any],
) -> None:
    """Per §2.6: unknown top-level keys accepted. Forward
    compatibility -- a future schema field can be added by a
    newer signer without breaking older verifiers."""
    valid_manifest["future_field"] = "ignored"
    valid_manifest["another_one"] = {"nested": True}
    validate_manifest(valid_manifest)


def test_capabilities_is_optional(valid_manifest: dict[str, Any]) -> None:
    """Per §2.6 capabilities is documented as optional and
    free-form (not enforced)."""
    valid_manifest["capabilities"] = ["a", "b", "c"]
    validate_manifest(valid_manifest)
    valid_manifest["capabilities"] = []
    validate_manifest(valid_manifest)
