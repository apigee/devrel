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

"""Shared HTTP retry helper.

Provides ``http_get_retry`` and ``http_post_retry`` -- both wrap
``requests.{get,post}`` with this policy:

* ONE retry on any 5xx response.
* Jittered backoff drawn from ``random.uniform(0.2, 0.4)``
  seconds (200-400 ms inclusive).
* 4xx responses raise immediately via
  ``response.raise_for_status()`` -- no retry.
* On 2xx responses, the ``requests.Response`` is returned as-is.

This module is a PURE library: it emits NOTHING to stdout. The
caller-owned contract line

    [apigee-skills] transient failure (HTTP <code>); retry 1/1 after <N>ms

is owned by the caller. To let the caller log retries without
polling, both verbs accept an optional
``on_retry: Callable[[int, float], None]`` callback that is
invoked with ``(status_code, sleep_seconds)`` BEFORE the retry
attempt. If ``on_retry`` is ``None`` (the default), the retry
happens silently and the caller is responsible for any logging
it wants to do after the fact.

The two verbs share a single private worker
``_request_with_retry`` so the backoff/retry/jitter logic lives
in exactly one place; the public functions are thin verb-binding
shells over it -- they differ only in HTTP verb.

All ``requests`` and ``time``/``random`` imports are referenced
through this module's namespace so tests can monkeypatch them
without touching the global package state.
"""
from __future__ import annotations

import random
import time
from typing import Any, Callable, Optional

import requests


def _request_with_retry(
    fn: Callable[..., requests.Response],
    url: str,
    *,
    on_retry: Optional[Callable[[int, float], None]] = None,
    **kwargs: Any,
) -> requests.Response:
    """Issue ``fn(url, **kwargs)``; retry once on 5xx with
    jittered 200-400 ms backoff.

    The first response that is 2xx is returned. The first
    response that is 4xx raises immediately. A 5xx triggers
    exactly one retry; the second response (whatever its
    status) is the terminal one -- raised on 4xx/5xx, returned
    on 2xx.

    When ``on_retry`` is provided, it is invoked exactly once
    with ``(status_code, sleep_seconds)`` BEFORE the
    ``time.sleep`` and retry attempt -- so the caller can log
    the retry decision with the SAME sleep value the helper is
    about to wait. ``on_retry`` is NEVER called on a first-try
    success or on a 4xx (no retry occurs in those cases).
    """
    resp = fn(url, **kwargs)
    if 500 <= resp.status_code < 600:
        sleep_seconds = random.uniform(0.2, 0.4)
        # Hand the retry decision to the caller BEFORE sleeping
        # so the caller's log line carries the same backoff value
        # we are about to wait. Library itself stays silent --
        # the contract line lives in the caller.
        if on_retry is not None:
            on_retry(resp.status_code, sleep_seconds)
        time.sleep(sleep_seconds)
        resp = fn(url, **kwargs)
    # 2xx -> return; 4xx or 5xx -> raise via raise_for_status.
    resp.raise_for_status()
    return resp


def http_get_retry(
    url: str,
    *,
    on_retry: Optional[Callable[[int, float], None]] = None,
    **kwargs: Any,
) -> requests.Response:
    """GET ``url`` with the module-level retry policy. See module doc.

    Extra ``**kwargs`` (e.g. ``headers``, ``params``, ``timeout``)
    are passed through to ``requests.get`` unchanged so callers
    can configure the request as they would any other ``requests``
    call. ``on_retry`` is consumed by the retry layer and is NOT
    forwarded.
    """
    return _request_with_retry(
        requests.get, url, on_retry=on_retry, **kwargs
    )


def http_post_retry(
    url: str,
    *,
    on_retry: Optional[Callable[[int, float], None]] = None,
    **kwargs: Any,
) -> requests.Response:
    """POST ``url`` with the module-level retry policy. Used by
    ``iam_preflight``. See module doc.

    Extra ``**kwargs`` (e.g. ``json``, ``headers``, ``timeout``)
    are passed through to ``requests.post`` unchanged.
    ``on_retry`` is consumed by the retry layer and is NOT
    forwarded.
    """
    return _request_with_retry(
        requests.post, url, on_retry=on_retry, **kwargs
    )
