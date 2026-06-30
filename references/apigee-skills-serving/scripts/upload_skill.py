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

"""Upload a signed .skill zip to GCS.

CLI grammar:

    upload-skill.py --zip <path>
                    --bucket <name>
                    [--object-name <key>]
                    [--quiet]

We deliberately do NOT depend on ``google-cloud-storage`` (we
keep ``requirements.txt`` to four runtime packages). Instead we
issue a single POST against the GCS JSON upload API with an ADC
bearer token from ``google.auth.default()``. The endpoint shape
is:

    POST https://storage.googleapis.com/upload/storage/v1/b/
         <bucket>/o?uploadType=media&name=<object-name>

with the zip bytes as the request body. The response is a JSON
object whose ``name`` field echoes back the object name; we don't
introspect it beyond status-code handling.

Exit codes:
  0 success
  1 user error (bad CLI args, file not found)
  2 system error (GCS API error or 404)
  3 IAM error (403 — insufficient permissions)
"""
from __future__ import annotations

import argparse
import sys
from pathlib import Path
from typing import Sequence

import requests

EXIT_OK = 0
EXIT_USER = 1
EXIT_SYSTEM = 2
EXIT_IAM = 3

_UPLOAD_BASE = (
    "https://storage.googleapis.com/upload/storage/v1/b/{bucket}/o"
)


def _err(quiet: bool, msg: str) -> None:
    if not quiet:
        print(msg, file=sys.stderr)


def _credentials():
    """Centralised ADC fetch. Wrapped so tests can monkeypatch
    this module attribute rather than ``google.auth.default``
    globally, which keeps the test surface narrow.

    Scope matches the other call sites in this repo. The GCS
    upload endpoint accepts the cloud-platform scope; using a
    narrower devstorage scope here would diverge from the other
    Google call sites and add a scope-mismatch failure mode for
    no benefit."""
    import google.auth
    import google.auth.transport.requests

    creds, project = google.auth.default(
        scopes=["https://www.googleapis.com/auth/cloud-platform"]
    )
    creds.refresh(google.auth.transport.requests.Request())
    return creds, project


def _parse_args(argv: Sequence[str]) -> argparse.Namespace:
    p = argparse.ArgumentParser(
        prog="upload-skill.py",
        description="Upload a .skill zip to GCS via the JSON API.",
    )
    p.add_argument("--zip", required=True, dest="zip_path")
    p.add_argument("--bucket", required=True)
    p.add_argument("--object-name", default=None, dest="object_name")
    p.add_argument("--quiet", action="store_true")
    return p.parse_args(list(argv))


def main(argv: Sequence[str] | None = None) -> int:
    if argv is None:
        argv = sys.argv[1:]
    try:
        ns = _parse_args(argv)
    except SystemExit:
        return EXIT_USER

    quiet = ns.quiet
    zip_path = Path(ns.zip_path)
    if not zip_path.is_file():
        _err(quiet, f"error: zip not found: {zip_path}")
        return EXIT_USER

    object_name = ns.object_name or zip_path.name

    # Bearer token. Any failure here is a user-environment issue
    # (no ADC, bad credentials file) — we surface it but classify
    # as user error so the caller knows to fix their environment.
    try:
        creds, _ = _credentials()
    except Exception as exc:  # pragma: no cover - covered via mock
        _err(quiet, f"error: ADC credentials unavailable: {exc}")
        return EXIT_USER

    url = _UPLOAD_BASE.format(bucket=ns.bucket)
    headers = {
        "Authorization": f"Bearer {creds.token}",
        "Content-Type": "application/zip",
    }
    params = {"uploadType": "media", "name": object_name}

    try:
        resp = requests.post(
            url,
            headers=headers,
            params=params,
            data=zip_path.read_bytes(),
            timeout=60,
        )
    except requests.RequestException as exc:
        _err(quiet, f"error: GCS upload network failure: {exc}")
        return EXIT_SYSTEM

    if resp.status_code == 403:
        _err(quiet, "error: GCS upload denied (403): "
                    "check bucket IAM permissions")
        return EXIT_IAM
    if resp.status_code == 404:
        _err(quiet, f"error: bucket not found (404): {ns.bucket}")
        return EXIT_SYSTEM
    if resp.status_code >= 400:
        _err(
            quiet,
            f"error: GCS upload failed ({resp.status_code}): "
            f"{getattr(resp, 'text', '')}",
        )
        return EXIT_SYSTEM

    uri = f"gs://{ns.bucket}/{object_name}"
    if not quiet:
        print(uri)
    return EXIT_OK


if __name__ == "__main__":  # pragma: no cover
    raise SystemExit(main())
