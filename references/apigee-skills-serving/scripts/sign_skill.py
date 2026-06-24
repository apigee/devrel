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

"""Sign a skill manifest with an ed25519 private key.

CLI grammar:

    sign-skill.py --manifest <path>
                  --zip <path>
                  --priv-key <path>
                  [--in-place | --out <path>]
                  [--quiet]

Pipeline:

  1. Load the manifest YAML.
  2. Compute sha256(zip-bytes), set ``zip_sha256``.
  3. Load the raw 32-byte ed25519 private key, derive the public
     key, compute ``signing_key_id = sha256:<hex(sha256(pub_raw))>``.
  4. Set ``signing_key_id`` and DROP any pre-existing ``signature``
     (so re-signing is byte-identical to a fresh sign).
  5. Canonicalise the manifest with ``scripts.common.canonical``
     and sign those bytes with ed25519. Base64-encode and set
     ``signature``.
  6. Validate the resulting dict with ``validate_manifest``
     (refuse to write an invalid signed manifest).
  7. Write the YAML to ``--out`` or ``--in-place``.

Idempotency: ed25519 is deterministic (RFC 8032), so re-running
with identical inputs produces byte-identical output. We rely on
``yaml.safe_dump(..., sort_keys=True)`` + the validator to keep
the on-disk form stable too.

Exit codes:
  0 success
  1 user error (bad CLI args, missing file, bad YAML)
  2 system error (FS write failure)
  3 cryptographic error (priv key unreadable, invalid)
"""
from __future__ import annotations

import argparse
import base64
import hashlib
import sys
from pathlib import Path
from typing import Sequence

import yaml
from cryptography.exceptions import InvalidKey
from cryptography.hazmat.primitives import serialization
from cryptography.hazmat.primitives.asymmetric.ed25519 import (
    Ed25519PrivateKey,
)

from scripts.common.canonical import canonicalize
from scripts.common.manifest_schema import (
    ManifestValidationError,
    validate_manifest,
)

EXIT_OK = 0
EXIT_USER = 1
EXIT_SYSTEM = 2
EXIT_CRYPTO = 3


def _err(quiet: bool, msg: str) -> None:
    """Write an error line to stderr unless ``--quiet``. We never
    swallow the message in non-quiet mode; the CLI is the only
    user-visible surface."""
    if not quiet:
        print(msg, file=sys.stderr)


def _parse_args(argv: Sequence[str]) -> argparse.Namespace:
    p = argparse.ArgumentParser(
        prog="sign-skill.py",
        description="Sign a skill manifest with ed25519.",
    )
    p.add_argument("--manifest", required=True)
    p.add_argument("--zip", required=True, dest="zip_path")
    p.add_argument("--priv-key", required=True, dest="priv_key")
    p.add_argument("--in-place", action="store_true")
    p.add_argument("--out", default=None)
    p.add_argument("--quiet", action="store_true")
    return p.parse_args(list(argv))


def _load_priv_key(path: Path) -> Ed25519PrivateKey:
    """Load the raw 32-byte ed25519 private key. We use Raw
    encoding + PrivateFormat.Raw + NoEncryption -- no PEM, no
    PKCS8."""
    raw = path.read_bytes()
    # ``from_private_bytes`` enforces the 32-byte length itself
    # and raises ValueError (or InvalidKey on some versions) on
    # any other length. We catch both so the caller's exit code
    # is deterministic.
    return Ed25519PrivateKey.from_private_bytes(raw)


def _signing_key_id(priv: Ed25519PrivateKey) -> str:
    """sha256:<hex> fingerprint of the raw 32-byte public key.

    Matches the ``signing_key_id`` regex in the schema and is
    what the consumer cross-checks against the trusted pubkey
    at verify time."""
    pub_raw = priv.public_key().public_bytes(
        encoding=serialization.Encoding.Raw,
        format=serialization.PublicFormat.Raw,
    )
    return "sha256:" + hashlib.sha256(pub_raw).hexdigest()


def main(argv: Sequence[str] | None = None) -> int:
    """Entry point. Returns an int exit code; never raises on the
    success path. Designed to be call-able from tests via
    ``main(argv_list)`` without subprocesses."""
    if argv is None:
        argv = sys.argv[1:]

    try:
        ns = _parse_args(argv)
    except SystemExit:
        # argparse already wrote the usage to stderr.
        return EXIT_USER

    quiet = ns.quiet

    # --in-place and --out are mutually exclusive. argparse can
    # express this via a mutually-exclusive group, but using the
    # group also blocks the "neither was given" check below, so
    # we enforce both invariants by hand.
    if ns.in_place and ns.out:
        _err(quiet, "error: --in-place and --out are mutually exclusive")
        return EXIT_USER
    if not ns.in_place and not ns.out:
        _err(quiet, "error: exactly one of --in-place or --out is required")
        return EXIT_USER

    manifest_path = Path(ns.manifest)
    zip_path = Path(ns.zip_path)
    priv_path = Path(ns.priv_key)

    if not manifest_path.is_file():
        _err(quiet, f"error: manifest not found: {manifest_path}")
        return EXIT_USER
    if not zip_path.is_file():
        _err(quiet, f"error: zip not found: {zip_path}")
        return EXIT_USER

    # Load the manifest. YAML parse errors are user errors.
    try:
        manifest_text = manifest_path.read_text(encoding="utf-8")
        manifest = yaml.safe_load(manifest_text)
    except (yaml.YAMLError, UnicodeDecodeError) as exc:
        _err(quiet, f"error: manifest parse failed: {exc}")
        return EXIT_USER
    if not isinstance(manifest, dict):
        _err(quiet, "error: manifest YAML must be a mapping")
        return EXIT_USER

    # Load the priv key. A missing file or any decode failure maps
    # to the cryptographic-error class.
    if not priv_path.is_file():
        _err(quiet, f"error: priv-key not found: {priv_path}")
        return EXIT_CRYPTO
    try:
        priv = _load_priv_key(priv_path)
    except (ValueError, InvalidKey, OSError) as exc:
        _err(quiet, f"error: priv-key load failed: {exc}")
        return EXIT_CRYPTO

    # Compute the integrity fields. We blank out any pre-existing
    # ``signature`` so re-signing is byte-identical (idempotency).
    zip_bytes = zip_path.read_bytes()
    manifest["zip_sha256"] = hashlib.sha256(zip_bytes).hexdigest()
    manifest["signing_key_id"] = _signing_key_id(priv)
    manifest.pop("signature", None)

    # Canonicalise + sign. canonicalize() strips ``signature``
    # itself; we drop it above so the in-memory dict is the
    # canonical input either way.
    canonical = canonicalize(manifest)
    sig_bytes = priv.sign(canonical)
    manifest["signature"] = base64.b64encode(sig_bytes).decode("ascii")

    # Validate the signed manifest before writing. A schema failure
    # here would mean we just produced an unloadable artifact.
    try:
        validate_manifest(manifest)
    except ManifestValidationError as exc:
        _err(quiet, f"error: signed manifest is invalid: {exc}")
        return EXIT_USER

    # Write. ``sort_keys=True`` keeps the on-disk YAML stable
    # across runs (idempotency property surfaces on disk, not
    # just in memory).
    out_path = manifest_path if ns.in_place else Path(ns.out)
    try:
        out_path.write_text(
            yaml.safe_dump(manifest, sort_keys=True),
            encoding="utf-8",
        )
    except OSError as exc:
        _err(quiet, f"error: failed to write {out_path}: {exc}")
        return EXIT_SYSTEM

    if not quiet:
        print(f"signed: {out_path}")
    return EXIT_OK


if __name__ == "__main__":  # pragma: no cover - thin wrapper
    raise SystemExit(main())
