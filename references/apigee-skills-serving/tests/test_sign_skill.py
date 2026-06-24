"""Tests for ``scripts/sign_skill.py``.

Coverage targets:

  * Idempotency: re-signing produces byte-identical output.
  * Exit codes: 0 success, 1 user error, 2 system error, 3 crypto
    error.
  * In-place vs out-of-place writes.
  * Missing priv key → exit 3 (crypto error).
  * Unparseable manifest → exit 1 (user error).

Per-component criterion:

  * sign-skill.py writes a manifest that round-trips through
    validate_manifest().
  * Idempotency: diff between two sequential runs is empty.

Tests drive the script via ``scripts.sign_skill.main(argv)`` with
an argv list so that we don't need to fork subprocesses (faster
and lets us assert exit codes via SystemExit). Real ed25519
keys are generated in the fixture; canonicalize() is the real
module function. No network, no fakes.
"""
from __future__ import annotations

import hashlib
from pathlib import Path

import pytest
import yaml
from cryptography.hazmat.primitives import serialization
from cryptography.hazmat.primitives.asymmetric.ed25519 import (
    Ed25519PrivateKey,
)

from scripts.common.canonical import canonicalize
from scripts.common.manifest_schema import validate_manifest

# Defer module import: importing the script at module collection
# time would crash if it ever grows side-effects, so we import via
# helper inside each test. Cheap, and keeps failure messages local.


def _import_sign_main():
    from scripts.sign_skill import main as _main
    return _main


# ---------------------------------------------------------------------------
# Fixtures
# ---------------------------------------------------------------------------

@pytest.fixture
def priv_key_path(tmp_path: Path) -> Path:
    """Generate a real ed25519 private key on disk in raw 32-byte
    format. We use the real cryptography library, not a mock;
    ed25519 keygen is fast (sub-millisecond) and using the real
    codepath avoids a class of mock-disagrees-with-reality bugs."""
    key = Ed25519PrivateKey.generate()
    raw = key.private_bytes(
        encoding=serialization.Encoding.Raw,
        format=serialization.PrivateFormat.Raw,
        encryption_algorithm=serialization.NoEncryption(),
    )
    p = tmp_path / "priv.key"
    p.write_bytes(raw)
    return p


@pytest.fixture
def skill_zip(tmp_path: Path) -> Path:
    """A stand-in for a real ``.skill`` zip — the signer only needs
    the bytes to sha256, so any bytes will do. We avoid making a
    real zip file here to keep the test focused on the sign path."""
    p = tmp_path / "demo-skill-1.0.0.skill"
    p.write_bytes(b"PK\x03\x04this-is-a-fake-zip-blob")
    return p


@pytest.fixture
def manifest_path(tmp_path: Path) -> Path:
    """An unsigned manifest YAML missing ``signature``, ``zip_sha256``,
    and ``signing_key_id`` — those are computed by the signer."""
    m = {
        "manifest_schema_version": "1",
        "name": "demo-skill",
        "version": "1.0.0",
        "description": "Demonstration skill.",
        "keywords": ["demo"],
        "author": "demo-test-suite",
        "license": "Apache-2.0",
        "gs_uri": "gs://demo-bucket/demo-skill-1.0.0.skill",
        "runtime_iam": ["apigee.proxies.list"],
    }
    p = tmp_path / "manifest.yaml"
    p.write_text(yaml.safe_dump(m, sort_keys=False))
    return p


# ---------------------------------------------------------------------------
# Happy path
# ---------------------------------------------------------------------------

def test_success_writes_signed_manifest(
    manifest_path: Path,
    skill_zip: Path,
    priv_key_path: Path,
    tmp_path: Path,
) -> None:
    """End-to-end: argv → exit 0 → signed manifest on disk that
    passes validate_manifest()."""
    out = tmp_path / "manifest.signed.yaml"
    main = _import_sign_main()
    rc = main([
        "--manifest", str(manifest_path),
        "--zip", str(skill_zip),
        "--priv-key", str(priv_key_path),
        "--out", str(out),
        "--quiet",
    ])
    assert rc == 0
    assert out.exists()
    signed = yaml.safe_load(out.read_text())
    validate_manifest(signed)
    # zip_sha256 must equal the actual zip sha256 (not a placeholder).
    assert signed["zip_sha256"] == hashlib.sha256(
        skill_zip.read_bytes()
    ).hexdigest()
    # signing_key_id is sha256:<hex(sha256(raw_pubkey))>.
    priv = Ed25519PrivateKey.from_private_bytes(
        priv_key_path.read_bytes()
    )
    pub_raw = priv.public_key().public_bytes(
        encoding=serialization.Encoding.Raw,
        format=serialization.PublicFormat.Raw,
    )
    expected_kid = "sha256:" + hashlib.sha256(pub_raw).hexdigest()
    assert signed["signing_key_id"] == expected_kid


def test_idempotent_byte_identical_on_resign(
    manifest_path: Path,
    skill_zip: Path,
    priv_key_path: Path,
    tmp_path: Path,
) -> None:
    """The diff between two sequential runs is empty. We sign
    twice (same priv key, same inputs) and assert the output
    bytes are identical. Ed25519 is deterministic (RFC 8032), so
    this is a hard requirement, not a soft one."""
    out_a = tmp_path / "a.yaml"
    out_b = tmp_path / "b.yaml"
    main = _import_sign_main()
    assert main([
        "--manifest", str(manifest_path),
        "--zip", str(skill_zip),
        "--priv-key", str(priv_key_path),
        "--out", str(out_a),
        "--quiet",
    ]) == 0
    assert main([
        "--manifest", str(manifest_path),
        "--zip", str(skill_zip),
        "--priv-key", str(priv_key_path),
        "--out", str(out_b),
        "--quiet",
    ]) == 0
    assert out_a.read_bytes() == out_b.read_bytes()


def test_in_place_write_mutates_manifest_file(
    manifest_path: Path,
    skill_zip: Path,
    priv_key_path: Path,
) -> None:
    """``--in-place`` overwrites the manifest path. Verifies the
    flag does what the §3.1 grammar promises."""
    before = manifest_path.read_text()
    main = _import_sign_main()
    rc = main([
        "--manifest", str(manifest_path),
        "--zip", str(skill_zip),
        "--priv-key", str(priv_key_path),
        "--in-place",
        "--quiet",
    ])
    assert rc == 0
    after = manifest_path.read_text()
    assert before != after
    signed = yaml.safe_load(after)
    validate_manifest(signed)


def test_signature_verifies_with_pubkey(
    manifest_path: Path,
    skill_zip: Path,
    priv_key_path: Path,
    tmp_path: Path,
) -> None:
    """Cross-check: extract the signature, recompute canonical
    bytes the verify side would compute, and confirm the real
    ed25519 public key accepts the signature. This is the unit
    half of the §8.2 sign+verify integration."""
    import base64

    from cryptography.hazmat.primitives.asymmetric.ed25519 import (
        Ed25519PublicKey,
    )

    out = tmp_path / "m.signed.yaml"
    main = _import_sign_main()
    assert main([
        "--manifest", str(manifest_path),
        "--zip", str(skill_zip),
        "--priv-key", str(priv_key_path),
        "--out", str(out),
        "--quiet",
    ]) == 0
    signed = yaml.safe_load(out.read_text())
    priv = Ed25519PrivateKey.from_private_bytes(
        priv_key_path.read_bytes()
    )
    pub = priv.public_key()
    sig = base64.b64decode(signed["signature"])
    pub.verify(sig, canonicalize(signed))  # raises on mismatch


# ---------------------------------------------------------------------------
# Error paths and exit codes
# ---------------------------------------------------------------------------

def test_missing_priv_key_exits_3(
    manifest_path: Path,
    skill_zip: Path,
    tmp_path: Path,
) -> None:
    """A non-existent priv-key path is a cryptographic-prerequisite
    error; §3.1 reserves exit 3 for this class."""
    main = _import_sign_main()
    rc = main([
        "--manifest", str(manifest_path),
        "--zip", str(skill_zip),
        "--priv-key", str(tmp_path / "does-not-exist.key"),
        "--out", str(tmp_path / "out.yaml"),
        "--quiet",
    ])
    assert rc == 3


def test_invalid_priv_key_content_exits_3(
    manifest_path: Path,
    skill_zip: Path,
    tmp_path: Path,
) -> None:
    """The file exists but doesn't decode as a 32-byte raw ed25519
    private key. §3.1 says 'priv key unreadable, invalid' → 3."""
    bad = tmp_path / "bad.key"
    bad.write_bytes(b"this is not a valid ed25519 raw private key")
    main = _import_sign_main()
    rc = main([
        "--manifest", str(manifest_path),
        "--zip", str(skill_zip),
        "--priv-key", str(bad),
        "--out", str(tmp_path / "out.yaml"),
        "--quiet",
    ])
    assert rc == 3


def test_unparseable_manifest_exits_1(
    skill_zip: Path,
    priv_key_path: Path,
    tmp_path: Path,
) -> None:
    """A YAML parse failure is user error per §3.1 (bad inputs)."""
    bad = tmp_path / "bad.yaml"
    bad.write_text("this: is: invalid: yaml: ::: [\n")
    main = _import_sign_main()
    rc = main([
        "--manifest", str(bad),
        "--zip", str(skill_zip),
        "--priv-key", str(priv_key_path),
        "--out", str(tmp_path / "out.yaml"),
        "--quiet",
    ])
    assert rc == 1


def test_missing_manifest_file_exits_1(
    skill_zip: Path,
    priv_key_path: Path,
    tmp_path: Path,
) -> None:
    """`--manifest` points at a nonexistent file → user error."""
    main = _import_sign_main()
    rc = main([
        "--manifest", str(tmp_path / "nope.yaml"),
        "--zip", str(skill_zip),
        "--priv-key", str(priv_key_path),
        "--out", str(tmp_path / "out.yaml"),
        "--quiet",
    ])
    assert rc == 1


def test_missing_zip_file_exits_1(
    manifest_path: Path,
    priv_key_path: Path,
    tmp_path: Path,
) -> None:
    """`--zip` points at a nonexistent file → user error."""
    main = _import_sign_main()
    rc = main([
        "--manifest", str(manifest_path),
        "--zip", str(tmp_path / "nope.skill"),
        "--priv-key", str(priv_key_path),
        "--out", str(tmp_path / "out.yaml"),
        "--quiet",
    ])
    assert rc == 1


def test_both_in_place_and_out_is_error(
    manifest_path: Path,
    skill_zip: Path,
    priv_key_path: Path,
    tmp_path: Path,
) -> None:
    """The §3.1 grammar marks `--in-place` and `--out` as mutually
    exclusive; supplying both is user error."""
    main = _import_sign_main()
    rc = main([
        "--manifest", str(manifest_path),
        "--zip", str(skill_zip),
        "--priv-key", str(priv_key_path),
        "--in-place",
        "--out", str(tmp_path / "out.yaml"),
        "--quiet",
    ])
    assert rc == 1


def test_neither_in_place_nor_out_is_error(
    manifest_path: Path,
    skill_zip: Path,
    priv_key_path: Path,
) -> None:
    """If the caller specifies neither, we cannot know where to
    write — refuse rather than guess (silent in-place would be
    surprising). User error."""
    main = _import_sign_main()
    rc = main([
        "--manifest", str(manifest_path),
        "--zip", str(skill_zip),
        "--priv-key", str(priv_key_path),
        "--quiet",
    ])
    assert rc == 1
