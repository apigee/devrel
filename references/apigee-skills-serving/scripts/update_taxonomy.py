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

"""Bootstrap the API hub attribute-definition taxonomy.

CLI grammar:

    update-taxonomy.py --project <gcp-project-id>
                       --location <api-hub-location>
                       [--quiet]

Creates the four required custom attribute definitions
(``agentic_skill``, ``keywords``, ``gs_uri``, ``signing_key_id``)
referenced by every registered skill manifest. Run once per API
hub instance. Idempotent: re-running discovers the existing defs
via GET and skips the POST.

The four definitions are minimally typed (all string-valued) so
the existing call sites in ``register_skill.py`` don't need to
know about enum allocation. A future skill catalog with a typed
enum (``skill_class: builtin | partner | user``) would extend
this script.

Exit codes:
  0 success
  1 user error (bad CLI args)
  2 system error
  3 IAM / 403 — fails loudly so the operator notices.
"""
from __future__ import annotations

import argparse
import sys
from typing import Sequence

import requests

EXIT_OK = 0
EXIT_USER = 1
EXIT_SYSTEM = 2
EXIT_IAM = 3

_API_HUB_BASE = (
    "https://apihub.googleapis.com/v1/"
    "projects/{project}/locations/{location}"
)

# (attribute_id, display_name, description) tuples. The four are
# the union of what register_skill writes and what the consumer
# reads. The order is the create order; tests assert the *set* of
# created IDs, not the order, but a stable order keeps logs
# deterministic for human reviewers.
_ATTR_DEFS: tuple[tuple[str, str, str], ...] = (
    (
        "agentic_skill",
        "Agentic skill",
        "True for skills consumable by the agent runtime.",
    ),
    (
        "keywords",
        "Keywords",
        "Discovery keywords mirrored from the manifest.",
    ),
    (
        "gs_uri",
        "GCS URI",
        "Location of the signed .skill zip in GCS.",
    ),
    (
        "signing_key_id",
        "Signing key ID",
        "sha256:<hex> fingerprint of the signing public key.",
    ),
)


def _err(quiet: bool, msg: str) -> None:
    if not quiet:
        print(msg, file=sys.stderr)


def _say(quiet: bool, msg: str) -> None:
    if not quiet:
        print(msg)


def _credentials():
    """Cloud-platform scoped ADC (uniform across all helpers)."""
    import google.auth
    import google.auth.transport.requests

    creds, project = google.auth.default(
        scopes=["https://www.googleapis.com/auth/cloud-platform"]
    )
    creds.refresh(google.auth.transport.requests.Request())
    return creds, project


def _parse_args(argv: Sequence[str]) -> argparse.Namespace:
    p = argparse.ArgumentParser(
        prog="update-taxonomy.py",
        description="Create API hub attribute defs for skills.",
    )
    p.add_argument("--project", required=True)
    p.add_argument("--location", required=True)
    p.add_argument("--quiet", action="store_true")
    return p.parse_args(list(argv))


def _classify(status: int) -> int:
    if status == 403:
        return EXIT_IAM
    return EXIT_SYSTEM


def main(argv: Sequence[str] | None = None) -> int:
    if argv is None:
        argv = sys.argv[1:]
    try:
        ns = _parse_args(argv)
    except SystemExit:
        return EXIT_USER

    quiet = ns.quiet

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

    created = 0
    for attr_id, display_name, description in _ATTR_DEFS:
        get_url = f"{base}/attributes/{attr_id}"
        try:
            r = requests.request(
                "GET", get_url, headers=headers, timeout=30,
            )
        except requests.RequestException as exc:
            _err(quiet, f"error: GET attribute network failure: {exc}")
            return EXIT_SYSTEM
        if r.status_code == 200:
            _say(quiet, f"attribute exists: {attr_id}")
            continue
        if r.status_code == 403:
            _err(quiet, f"error: GET attribute denied (403): {attr_id}")
            return EXIT_IAM
        if r.status_code not in (404,):
            _err(quiet, f"error: GET attribute failed ({r.status_code})")
            return _classify(r.status_code)

        # Not present: create.
        post_url = f"{base}/attributes"
        body = {
            "displayName": display_name,
            "description": description,
            "scope": "API",
            "dataType": "STRING",
            # API hub uses `cardinality` (max number of values).
            # `keywords` needs to hold the full keyword list per skill
            # (up to ~20 tokens); the scalar attributes are 1 each.
            "cardinality": 20 if attr_id == "keywords" else 1,
        }
        try:
            r = requests.request(
                "POST",
                post_url,
                headers=headers,
                params={"attributeId": attr_id},
                json=body,
                timeout=60,
            )
        except requests.RequestException as exc:
            _err(quiet, f"error: POST attribute network failure: {exc}")
            return EXIT_SYSTEM
        if r.status_code >= 400:
            body_snippet = (r.text or "")[:500]
            _err(
                quiet,
                f"error: POST attribute failed ({r.status_code}): "
                f"{body_snippet}",
            )
            return _classify(r.status_code)
        _say(quiet, f"created attribute: {attr_id}")
        created += 1

    if created == 0:
        _say(quiet, "taxonomy already up to date")
    else:
        _say(quiet, f"taxonomy updated: {created} attribute(s) created")
    return EXIT_OK


if __name__ == "__main__":  # pragma: no cover
    raise SystemExit(main())
