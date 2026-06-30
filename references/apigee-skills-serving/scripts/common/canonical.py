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

"""Canonical manifest serialization.

The sign side (``sign_skill.py``) and the verify side (the
consumer's install-time verifier) both call ``canonicalize`` to
derive the byte string that the ed25519 signature covers.
Byte-identical output across both call sites is a correctness
pre-requisite: any drift causes every install to fail signature
verification.

The canonical transform is exactly:

    1. Shallow-copy the manifest dict.
    2. Remove the top-level ``signature`` field (it is what we
       sign; including it would create a chicken-and-egg loop).
    3. ``json.dumps(d, sort_keys=True, separators=(",", ":"),
       ensure_ascii=False).encode("utf-8")``

We deliberately use ``json``, not ``yaml``, for the canonical form.
PyYAML's serializer differs between major versions (scalar quoting,
flow vs block style, sort behavior); ``json.dumps`` semantics are
RFC-locked.
"""
from __future__ import annotations

import json
from typing import Any


def canonicalize(manifest: dict[str, Any]) -> bytes:
    """Return the canonical UTF-8 byte form of *manifest*.

    The input dict is not mutated. The output is suitable as the
    payload to ed25519 sign/verify.
    """
    # Shallow copy so we can drop ``signature`` without mutating
    # the caller's dict. A deep copy would be wasteful here -- the
    # only mutation we perform is the top-level ``del``.
    stripped = {k: v for k, v in manifest.items() if k != "signature"}
    return json.dumps(
        stripped,
        sort_keys=True,
        separators=(",", ":"),
        ensure_ascii=False,
    ).encode("utf-8")
