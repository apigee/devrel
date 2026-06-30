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

"""Sign + verify round-trip integration test.

Real ed25519 keypair, real ``canonicalize()``, real
``sign_skill.main``. No mocks, no network. This is the integration
half of the byte-exactness contract: the bytes the signer feeds
to ``Ed25519PrivateKey.sign`` MUST equal the bytes the verifier
feeds to ``Ed25519PublicKey.verify``. If they drift the
signature mismatches in production.

The test deliberately reaches outside the script boundary — it
does what the consumer will do at install time, in miniature:

  1. Generate a real ed25519 keypair on disk.
  2. Run ``sign_skill.main(...)`` against a real manifest +
     ``.skill`` zip.
  3. Re-load the signed manifest.
  4. Recompute ``canonicalize(signed)`` and verify with the real
     public key.
  5. As a bonus, mutate one byte in the manifest and confirm
     verification FAILS — the test is only meaningful if the
     signature is actually distinguishing real vs tampered.
"""
from __future__ import annotations

import base64
from pathlib import Path

import pytest
import yaml
from cryptography.exceptions import InvalidSignature
from cryptography.hazmat.primitives import serialization
from cryptography.hazmat.primitives.asymmetric.ed25519 import Ed25519PrivateKey

from scripts.common.canonical import canonicalize
from scripts.common.manifest_schema import validate_manifest
from scripts.sign_skill import main as sign_main


def _make_keypair(tmp_path: Path) -> Path:
    key = Ed25519PrivateKey.generate()
    raw = key.private_bytes(
        encoding=serialization.Encoding.Raw,
        format=serialization.PrivateFormat.Raw,
        encryption_algorithm=serialization.NoEncryption(),
    )
    p = tmp_path / "priv.key"
    p.write_bytes(raw)
    return p


def _make_manifest(tmp_path: Path) -> Path:
    m = {
        "manifest_schema_version": "1",
        "name": "demo-skill",
        "version": "1.2.3",
        "description": "Round-trip integration test.",
        "keywords": ["demo", "integration"],
        "author": "demo-test-suite",
        "license": "Apache-2.0",
        "gs_uri": "gs://demo-bucket/demo-skill-1.2.3.skill",
        "runtime_iam": ["apigee.proxies.list"],
    }
    p = tmp_path / "manifest.yaml"
    p.write_text(yaml.safe_dump(m, sort_keys=False))
    return p


def _make_zip(tmp_path: Path) -> Path:
    p = tmp_path / "demo-skill-1.2.3.skill"
    p.write_bytes(b"PK\x03\x04integration-test-zip-payload")
    return p


@pytest.fixture
def signed_manifest(tmp_path: Path) -> tuple[Path, Path]:
    priv = _make_keypair(tmp_path)
    manifest = _make_manifest(tmp_path)
    skill = _make_zip(tmp_path)
    out = tmp_path / "manifest.signed.yaml"
    rc = sign_main([
        "--manifest", str(manifest),
        "--zip", str(skill),
        "--priv-key", str(priv),
        "--out", str(out),
        "--quiet",
    ])
    assert rc == 0
    return out, priv


# ---------------------------------------------------------------------------
# Positive: sign + verify is byte-identical end-to-end
# ---------------------------------------------------------------------------

def test_signed_manifest_validates(
    signed_manifest: tuple[Path, Path]
) -> None:
    out, _ = signed_manifest
    signed = yaml.safe_load(out.read_text())
    validate_manifest(signed)


def test_signed_manifest_verifies_with_real_pubkey(
    signed_manifest: tuple[Path, Path],
) -> None:
    """The whole point: real verify-side bytes accepted by real
    ed25519 public key. Drift in canonicalize() between sign and
    verify would surface as InvalidSignature here."""
    out, priv_path = signed_manifest
    signed = yaml.safe_load(out.read_text())
    priv = Ed25519PrivateKey.from_private_bytes(
        priv_path.read_bytes()
    )
    pub = priv.public_key()
    sig = base64.b64decode(signed["signature"])
    pub.verify(sig, canonicalize(signed))  # raises on mismatch


def test_resign_is_byte_identical(
    signed_manifest: tuple[Path, Path],
    tmp_path: Path,
) -> None:
    """Cross-check: re-signing the *original* unsigned manifest
    with the same priv-key produces an identical YAML file on
    disk. RFC 8032 ed25519 is deterministic, so this is a
    correctness — not a flakiness — assertion."""
    out_a, priv_path = signed_manifest
    out_b = tmp_path / "manifest.b.yaml"
    redo_dir = tmp_path / "redo"
    redo_dir.mkdir()
    manifest_path = _make_manifest(redo_dir)
    skill = _make_zip(redo_dir)
    rc = sign_main([
        "--manifest", str(manifest_path),
        "--zip", str(skill),
        "--priv-key", str(priv_path),
        "--out", str(out_b),
        "--quiet",
    ])
    assert rc == 0
    assert out_a.read_bytes() == out_b.read_bytes()


# ---------------------------------------------------------------------------
# Negative: tampered manifest fails verification
# ---------------------------------------------------------------------------

def test_tampered_manifest_fails_verify(
    signed_manifest: tuple[Path, Path],
) -> None:
    """Mutate one field (description) after signing and confirm
    the signature no longer verifies. Without this assertion the
    other tests could pass with a no-op signer."""
    out, priv_path = signed_manifest
    signed = yaml.safe_load(out.read_text())
    signed["description"] = "tampered after signing"
    priv = Ed25519PrivateKey.from_private_bytes(
        priv_path.read_bytes()
    )
    pub = priv.public_key()
    sig = base64.b64decode(signed["signature"])
    with pytest.raises(InvalidSignature):
        pub.verify(sig, canonicalize(signed))


def test_wrong_pubkey_fails_verify(
    signed_manifest: tuple[Path, Path],
    tmp_path: Path,
) -> None:
    """A different ed25519 keypair MUST NOT validate the signature.
    Defends against the 'we accidentally accept any signature'
    failure mode."""
    out, _ = signed_manifest
    signed = yaml.safe_load(out.read_text())
    other_priv = Ed25519PrivateKey.generate()
    other_pub = other_priv.public_key()
    sig = base64.b64decode(signed["signature"])
    with pytest.raises(InvalidSignature):
        other_pub.verify(sig, canonicalize(signed))
