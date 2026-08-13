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
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or
# implied. See the License for the specific language governing
# permissions and limitations under the License.

"""Unit tests for skill-finder's multi-key trust root loading and
signature verification.

These tests exercise the two functions that changed when we moved
skill-finder from a single-key (keys/trusted_pubkey.pem) to a
multi-key (keys/*.pem) trust model:

  * ``_load_pubkeys``  -- reads every PEM under ``KEYS_DIR`` and
                          returns ``dict[fingerprint -> Ed25519PublicKey]``.
  * ``_verify_signature`` -- accepts a manifest and the dict from
                             ``_load_pubkeys``, matches
                             ``signing_key_id`` against ANY installed
                             fingerprint, verifies ed25519.

The tests deliberately do NOT touch the network. Every fixture is
in-memory or in ``tmp_path``. We patch ``find_install.KEYS_DIR``
via monkeypatch so the module reads test-owned key directories
without needing to munge the install layout.

Coverage matrix:

  * empty keys/ dir  -> "trust root: FAILED" + non-zero exit
  * missing keys/    -> "trust root: FAILED" + non-zero exit
  * single valid key -> loads OK, verifies OK
  * two valid keys, manifest matches key A -> verifies via key A
  * two valid keys, manifest matches key B -> verifies via key B
    (both keys usable, ordering independent)
  * key-id mismatch  -> "key-id check: FAILED" + trusted list in message
  * unreadable / non-PEM file under keys/ -> warned + skipped
  * duplicate keys under different filenames -> deduped, no error
  * dotfile (``.gitkeep``) under keys/ -> ignored silently
  * README.md under keys/ -> ignored silently (not a .pem / .raw)
  * signature-field-absent   -> "manifest signature: FAILED" (absent)
  * signature-malformed-b64  -> "manifest signature: FAILED" (malformed)
  * signature-doesnt-verify  -> "manifest signature: FAILED" (rejected)
"""
from __future__ import annotations

import base64
import hashlib
import importlib.util
import sys
from pathlib import Path

import pytest
import yaml
from cryptography.hazmat.primitives import serialization
from cryptography.hazmat.primitives.asymmetric.ed25519 import Ed25519PrivateKey


# The skill-finder scripts dir isn't on sys.path by default (tests
# live at the repo root); load find_install.py explicitly. We do
# this once per session so all tests share the module object.
_SCRIPTS_DIR = (
    Path(__file__).resolve().parent.parent
    / "skills" / "skill-finder" / "scripts"
)
_FIND_INSTALL_PY = _SCRIPTS_DIR / "find_install.py"


@pytest.fixture(scope="module")
def find_install():
    """Load skill-finder's find_install.py as a module.

    We use importlib rather than a top-level `import find_install`
    because the script lives under `skills/skill-finder/scripts/`
    and pytest doesn't put that on sys.path automatically. The
    sys.path.insert in find_install.py itself handles the
    `from common.X` production imports; the module's ImportError
    fallback to `from scripts.common.X` is what actually resolves
    when tests run (because conftest.py adds the repo root).
    """
    spec = importlib.util.spec_from_file_location(
        "find_install", _FIND_INSTALL_PY
    )
    module = importlib.util.module_from_spec(spec)
    sys.modules["find_install"] = module
    spec.loader.exec_module(module)
    return module


# --------- key generation helpers -------------------------------


def _mk_keypair():
    """Generate a fresh ed25519 keypair; return
    (private_bytes_raw, public_bytes_raw, fingerprint_str)."""
    priv = Ed25519PrivateKey.generate()
    priv_raw = priv.private_bytes(
        encoding=serialization.Encoding.Raw,
        format=serialization.PrivateFormat.Raw,
        encryption_algorithm=serialization.NoEncryption(),
    )
    pub = priv.public_key()
    pub_raw = pub.public_bytes(
        encoding=serialization.Encoding.Raw,
        format=serialization.PublicFormat.Raw,
    )
    fp = "sha256:" + hashlib.sha256(pub_raw).hexdigest()
    return priv, priv_raw, pub, pub_raw, fp


def _write_pem(keys_dir: Path, pub, name: str) -> Path:
    """Write a PEM public key file into keys_dir. Returns the
    full path. The filename shape is arbitrary here (tests exercise
    both fingerprint-named and human-named files)."""
    pem = pub.public_bytes(
        encoding=serialization.Encoding.PEM,
        format=serialization.PublicFormat.SubjectPublicKeyInfo,
    )
    p = keys_dir / name
    p.write_bytes(pem)
    return p


def _sign_manifest(priv, manifest: dict, canonicalize) -> dict:
    """Return a signed copy of the manifest. Uses find_install's
    canonicalize function (aliased through the module fixture)
    so signature bytes are identical to production."""
    pub = priv.public_key()
    pub_raw = pub.public_bytes(
        encoding=serialization.Encoding.Raw,
        format=serialization.PublicFormat.Raw,
    )
    fp = "sha256:" + hashlib.sha256(pub_raw).hexdigest()
    m = dict(manifest)
    m["signing_key_id"] = fp
    # canonicalize excludes 'signature' itself; safe to leave it
    # out and let canonicalize compute over the rest.
    m.pop("signature", None)
    canonical = canonicalize(m)
    sig = priv.sign(canonical)
    m["signature"] = base64.b64encode(sig).decode("ascii")
    return m


@pytest.fixture
def valid_manifest_dict():
    """A minimally-valid manifest that passes the schema (used as
    the input to _sign_manifest). Signature/zip_sha256/gs_uri
    values are placeholders for the sign step."""
    return {
        "manifest_schema_version": "1",
        "name": "test-skill",
        "version": "1.0.0",
        "description": "A test skill for multi-key trust root tests.",
        "keywords": ["test"],
        "author": "test-author",
        "license": "Apache-2.0",
        "gs_uri": "gs://demo-bucket/test-skill-1.0.0.skill",
        "zip_sha256": "0" * 64,
    }


# ===================================================================
# _load_pubkeys tests
# ===================================================================


class TestLoadPubkeys:
    """Cover the trust-root loading behaviour."""

    def test_missing_keys_dir_fails(
        self, find_install, tmp_path, monkeypatch
    ):
        """No keys/ directory at all -> hard fail, non-zero exit."""
        monkeypatch.setattr(
            find_install, "KEYS_DIR", tmp_path / "does-not-exist"
        )
        with pytest.raises(SystemExit) as excinfo:
            find_install._load_pubkeys()
        assert excinfo.value.code != 0

    def test_empty_keys_dir_fails(
        self, find_install, tmp_path, monkeypatch
    ):
        """Empty keys/ directory -> hard fail."""
        keys = tmp_path / "keys"
        keys.mkdir()
        monkeypatch.setattr(find_install, "KEYS_DIR", keys)
        with pytest.raises(SystemExit) as excinfo:
            find_install._load_pubkeys()
        assert excinfo.value.code != 0

    def test_keys_dir_with_only_dotfiles_fails(
        self, find_install, tmp_path, monkeypatch
    ):
        """.gitkeep and .anything-else are ignored -> empty ->
        hard fail. Verifies that the dotfile skip works AND that
        it doesn't fall through to a false-positive load."""
        keys = tmp_path / "keys"
        keys.mkdir()
        (keys / ".gitkeep").write_bytes(b"")
        (keys / ".hidden.pem").write_bytes(b"not real")
        monkeypatch.setattr(find_install, "KEYS_DIR", keys)
        with pytest.raises(SystemExit):
            find_install._load_pubkeys()

    def test_keys_dir_with_only_readme_fails(
        self, find_install, tmp_path, monkeypatch
    ):
        """README.md exists but no .pem -> hard fail. Verifies the
        suffix filter."""
        keys = tmp_path / "keys"
        keys.mkdir()
        (keys / "README.md").write_text("just docs")
        monkeypatch.setattr(find_install, "KEYS_DIR", keys)
        with pytest.raises(SystemExit):
            find_install._load_pubkeys()

    def test_single_valid_key_loads(
        self, find_install, tmp_path, monkeypatch
    ):
        """One PEM under keys/ -> loads OK, returns dict of size 1."""
        keys = tmp_path / "keys"
        keys.mkdir()
        _, _, pub, _, fp = _mk_keypair()
        _write_pem(keys, pub, "test.pem")
        monkeypatch.setattr(find_install, "KEYS_DIR", keys)
        trusted = find_install._load_pubkeys()
        assert len(trusted) == 1
        assert fp in trusted

    def test_two_valid_keys_load(
        self, find_install, tmp_path, monkeypatch
    ):
        """Two distinct PEMs -> both loaded under their own
        fingerprints. Verifies multi-publisher / rotation
        support at load time."""
        keys = tmp_path / "keys"
        keys.mkdir()
        _, _, pub_a, _, fp_a = _mk_keypair()
        _, _, pub_b, _, fp_b = _mk_keypair()
        _write_pem(keys, pub_a, "publisher-a.pem")
        _write_pem(keys, pub_b, "publisher-b.pem")
        monkeypatch.setattr(find_install, "KEYS_DIR", keys)
        trusted = find_install._load_pubkeys()
        assert len(trusted) == 2
        assert fp_a in trusted
        assert fp_b in trusted
        assert fp_a != fp_b  # sanity

    def test_duplicate_key_material_deduped(
        self, find_install, tmp_path, monkeypatch, capsys
    ):
        """Same key material under two filenames -> one entry in
        the trusted dict. Warning is emitted (via _say to stdout)
        but the load succeeds."""
        keys = tmp_path / "keys"
        keys.mkdir()
        _, _, pub, _, fp = _mk_keypair()
        _write_pem(keys, pub, "first.pem")
        _write_pem(keys, pub, "second.pem")
        monkeypatch.setattr(find_install, "KEYS_DIR", keys)
        trusted = find_install._load_pubkeys()
        assert len(trusted) == 1
        captured = capsys.readouterr()
        # The warning goes to stdout via _say(), which prefixes
        # with "[skill-finder]".
        assert "duplicate" in captured.out.lower()

    def test_unparseable_pem_skipped(
        self, find_install, tmp_path, monkeypatch, capsys
    ):
        """Garbage file under keys/*.pem is skipped with a warning
        but doesn't abort the load. Real keys still load."""
        keys = tmp_path / "keys"
        keys.mkdir()
        (keys / "garbage.pem").write_bytes(b"not a valid PEM")
        _, _, pub, _, fp = _mk_keypair()
        _write_pem(keys, pub, "real.pem")
        monkeypatch.setattr(find_install, "KEYS_DIR", keys)
        trusted = find_install._load_pubkeys()
        assert fp in trusted
        assert len(trusted) == 1  # garbage.pem was skipped
        captured = capsys.readouterr()
        assert "skipped" in captured.out.lower()

    def test_raw_key_supported_alongside_pem(
        self, find_install, tmp_path, monkeypatch
    ):
        """Legacy 32-byte raw key files under keys/*.raw are
        loaded alongside PEMs."""
        keys = tmp_path / "keys"
        keys.mkdir()
        _, _, pub, pub_raw, fp = _mk_keypair()
        (keys / "raw-key.raw").write_bytes(pub_raw)
        monkeypatch.setattr(find_install, "KEYS_DIR", keys)
        trusted = find_install._load_pubkeys()
        assert fp in trusted


# ===================================================================
# _verify_signature tests
# ===================================================================


class TestVerifySignature:
    """Cover manifest-signature verification against the multi-key
    trust root."""

    def test_matching_key_verifies(
        self, find_install, valid_manifest_dict
    ):
        """Single trust root, manifest signed by the matching key
        -> verification passes, canonicalized manifest returned."""
        priv, _, pub, _, fp = _mk_keypair()
        trusted = {fp: pub}
        signed = _sign_manifest(
            priv, valid_manifest_dict, find_install.canonicalize
        )
        result = find_install._verify_signature(
            yaml.safe_dump(signed), trusted
        )
        assert result["name"] == "test-skill"
        assert result["signing_key_id"] == fp

    def test_two_trusted_keys_first_matches(
        self, find_install, valid_manifest_dict
    ):
        """Two trust roots installed, manifest signed by key A.
        The verify loop picks key A, verifies, returns the
        parsed manifest."""
        priv_a, _, pub_a, _, fp_a = _mk_keypair()
        _, _, pub_b, _, fp_b = _mk_keypair()
        trusted = {fp_a: pub_a, fp_b: pub_b}
        signed = _sign_manifest(
            priv_a, valid_manifest_dict, find_install.canonicalize
        )
        result = find_install._verify_signature(
            yaml.safe_dump(signed), trusted
        )
        assert result["signing_key_id"] == fp_a

    def test_two_trusted_keys_second_matches(
        self, find_install, valid_manifest_dict
    ):
        """Same scenario but the manifest is signed by key B.
        Verify still passes -- confirms the trusted dict is a
        true set, not order-dependent."""
        _, _, pub_a, _, fp_a = _mk_keypair()
        priv_b, _, pub_b, _, fp_b = _mk_keypair()
        trusted = {fp_a: pub_a, fp_b: pub_b}
        signed = _sign_manifest(
            priv_b, valid_manifest_dict, find_install.canonicalize
        )
        result = find_install._verify_signature(
            yaml.safe_dump(signed), trusted
        )
        assert result["signing_key_id"] == fp_b

    def test_key_id_mismatch_fails(
        self, find_install, valid_manifest_dict
    ):
        """Manifest is signed by a key that's not in the trust
        set -> fails with 'key-id check: FAILED' and non-zero
        exit code."""
        # Two DIFFERENT keys: sign with priv_untrusted, but
        # skill-finder only trusts pub_trusted.
        _, _, pub_trusted, _, fp_trusted = _mk_keypair()
        priv_untrusted, _, _, _, _ = _mk_keypair()
        trusted = {fp_trusted: pub_trusted}
        signed = _sign_manifest(
            priv_untrusted,
            valid_manifest_dict,
            find_install.canonicalize,
        )
        with pytest.raises(SystemExit) as excinfo:
            find_install._verify_signature(
                yaml.safe_dump(signed), trusted
            )
        assert excinfo.value.code != 0

    def test_key_id_error_message_lists_trusted_fingerprints(
        self, find_install, valid_manifest_dict, capsys
    ):
        """The 'key-id check: FAILED' line should include the list
        of trusted fingerprints so an operator can diagnose which
        key is missing from keys/. Regression test against a
        vague error message."""
        _, _, pub_trusted, _, fp_trusted = _mk_keypair()
        priv_untrusted, _, _, _, fp_untrusted = _mk_keypair()
        trusted = {fp_trusted: pub_trusted}
        signed = _sign_manifest(
            priv_untrusted,
            valid_manifest_dict,
            find_install.canonicalize,
        )
        with pytest.raises(SystemExit):
            find_install._verify_signature(
                yaml.safe_dump(signed), trusted
            )
        captured = capsys.readouterr()
        # Error prints via _say() to stdout with the
        # [skill-finder] prefix. Both the manifest's declared fp
        # and the trusted set should be visible.
        combined = captured.out + captured.err
        assert fp_untrusted in combined
        assert fp_trusted in combined

    def test_signature_field_absent_fails(
        self, find_install, valid_manifest_dict
    ):
        """Manifest with a matching signing_key_id but NO
        signature field -> 'manifest signature: FAILED'."""
        _, _, pub, _, fp = _mk_keypair()
        trusted = {fp: pub}
        # Construct a manifest that has signing_key_id but no
        # signature. This tests the missing-field branch that
        # was added to distinguish 'absent' from 'malformed'
        # from 'crypto rejected'.
        m = dict(valid_manifest_dict)
        m["signing_key_id"] = fp
        assert "signature" not in m
        with pytest.raises(SystemExit) as excinfo:
            find_install._verify_signature(
                yaml.safe_dump(m), trusted
            )
        assert excinfo.value.code != 0

    def test_signature_field_malformed_base64_fails(
        self, find_install, valid_manifest_dict
    ):
        """Signature field is not valid base64 -> 'malformed
        base64' branch."""
        _, _, pub, _, fp = _mk_keypair()
        trusted = {fp: pub}
        m = dict(valid_manifest_dict)
        m["signing_key_id"] = fp
        m["signature"] = "!!! not base64 !!!"
        with pytest.raises(SystemExit) as excinfo:
            find_install._verify_signature(
                yaml.safe_dump(m), trusted
            )
        assert excinfo.value.code != 0

    def test_signature_wrong_key_fails_crypto(
        self, find_install, valid_manifest_dict
    ):
        """Signature was made by a different private key than the
        pubkey the trust root has for the same fingerprint. In
        practice this is unreachable (the fingerprint IS
        derived from the pubkey) but we test the code path
        anyway by manually crafting a mismatched manifest."""
        priv_a, _, pub_a, _, fp_a = _mk_keypair()
        priv_b, _, _, _, _ = _mk_keypair()
        trusted = {fp_a: pub_a}
        # Sign with priv_b but claim signing_key_id = fp_a
        m = dict(valid_manifest_dict)
        m["signing_key_id"] = fp_a
        m.pop("signature", None)
        canonical = find_install.canonicalize(m)
        sig = priv_b.sign(canonical)
        m["signature"] = base64.b64encode(sig).decode("ascii")
        with pytest.raises(SystemExit) as excinfo:
            find_install._verify_signature(
                yaml.safe_dump(m), trusted
            )
        assert excinfo.value.code != 0
