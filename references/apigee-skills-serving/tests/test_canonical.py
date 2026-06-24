"""Tests for ``scripts/common/canonical.py``.

The canonical transform is:

    1. Read manifest YAML into Python dict.
    2. Remove the ``signature`` field (it is what we sign).
    3. ``json.dumps(d, sort_keys=True, separators=(",", ":"),
       ensure_ascii=False).encode("utf-8")``

The sign side and verify side MUST produce byte-identical output
for the same input dict. This file covers the acceptance
("sign-side and verify-side produce byte-identical output for the
same dict; signature field removal; key ordering determinism;
non-ASCII escape correctness") plus three edge cases (empty
dict, nested dict ordering, return type).
"""
from __future__ import annotations

import pytest

from scripts.common.canonical import canonicalize


@pytest.fixture
def signed_manifest() -> dict:
    """A manifest dict shaped like a post-sign payload, with a
    ``signature`` field that the canonicalizer must strip."""
    return {
        "name": "demo-skill",
        "manifest_schema_version": "1",
        "gs_uri": "gs://demo-bucket/demo-skill-1.skill",
        "zip_sha256": "0" * 64,
        "signing_key_id": "sha256:" + "a" * 64,
        "signature": "base64-encoded-bytes-go-here==",
        "runtime_iam": ["apigee.proxies.list"],
    }


def test_returns_bytes_not_str(signed_manifest: dict) -> None:
    result = canonicalize(signed_manifest)
    assert isinstance(result, bytes), (
        "canonicalize must return bytes so the signer can pass it "
        "directly to ed25519 sign; str would force the caller to "
        "guess an encoding."
    )


def test_signature_field_removed(signed_manifest: dict) -> None:
    """The signature is the output of signing the canonical bytes;
    if it were included in those bytes we would have a chicken-and-egg
    problem. Verify it is stripped before serialization."""
    result = canonicalize(signed_manifest)
    assert b"signature" not in result
    assert b"base64-encoded-bytes-go-here" not in result


def test_signature_field_removal_does_not_mutate_input(
    signed_manifest: dict,
) -> None:
    """The caller may need the signed manifest for other purposes
    after canonicalization (e.g., the signer writes it back to disk).
    Stripping ``signature`` in place would be a surprising
    side-effect; the function must leave the input dict unchanged."""
    before = dict(signed_manifest)
    canonicalize(signed_manifest)
    assert signed_manifest == before


def test_byte_identical_for_same_dict(signed_manifest: dict) -> None:
    """The whole point of canonicalization: two calls on the same
    input must yield the same bytes. If this fails, signatures
    will randomly mismatch between sign and verify."""
    a = canonicalize(signed_manifest)
    b = canonicalize(signed_manifest)
    assert a == b


def test_key_ordering_is_deterministic() -> None:
    """Dicts constructed in different key orders must canonicalize
    identically. Python preserves insertion order; ``sort_keys=True``
    is what makes the output stable."""
    d1 = {"alpha": 1, "beta": 2, "gamma": 3}
    d2 = {"gamma": 3, "alpha": 1, "beta": 2}
    assert canonicalize(d1) == canonicalize(d2)


def test_nested_dict_keys_also_sorted() -> None:
    """``sort_keys=True`` sorts at every nesting level, not just
    the root. A nested dict with permuted keys must canonicalize
    the same as the same dict with sorted keys."""
    d1 = {"outer": {"a": 1, "b": 2}}
    d2 = {"outer": {"b": 2, "a": 1}}
    assert canonicalize(d1) == canonicalize(d2)


def test_separators_are_compact() -> None:
    """Per §2.2 ``separators=(",", ":")``. The default
    ``json.dumps`` adds whitespace (``", "`` and ``": "``); the
    canonical form must not, because whitespace is a hidden
    variation between Python versions and serialization libraries."""
    d = {"a": 1, "b": 2}
    result = canonicalize(d)
    assert b", " not in result
    assert b": " not in result
    # Exact-shape sanity check.
    assert result == b'{"a":1,"b":2}'


def test_non_ascii_preserved_not_escaped() -> None:
    """Per §2.2 ``ensure_ascii=False``. The default ``json.dumps``
    escapes non-ASCII as ``\\u00e9``; that would make the canonical
    output dependent on the source-code encoding (since YAML loaders
    may return either form). Keeping ``ensure_ascii=False`` yields
    raw UTF-8 bytes, which are stable."""
    d = {"description": "café"}
    result = canonicalize(d)
    assert "café".encode("utf-8") in result
    assert b"\\u00e9" not in result


def test_empty_dict() -> None:
    """Edge case: ``{}`` → ``b"{}"``. Not an error; an empty
    manifest is a degenerate but valid input."""
    assert canonicalize({}) == b"{}"


def test_signature_field_only_stripped_at_top_level() -> None:
    """Defensive: the strip happens at the top level. A nested
    ``signature`` key under, say, ``metadata.signature`` is part of
    the schema and must NOT be removed."""
    d = {
        "name": "x",
        "signature": "TOP_LEVEL_GONE",
        "metadata": {"signature": "NESTED_KEPT"},
    }
    result = canonicalize(d)
    assert b"TOP_LEVEL_GONE" not in result
    assert b"NESTED_KEPT" in result
