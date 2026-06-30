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

"""IAM pre-flight library for the install pipeline.

runtime_iam values are GCP permissions in dot-form (e.g.
``apigee.proxies.list``). The loader calls this library after
manifest signature + schema + attribute cross-check pass and
BEFORE the zip download. The purpose is to fail fast: if the
caller does not hold the permissions the skill needs at runtime,
the install is aborted before any bytes hit disk.

PURE API contract (NO stdout):

This library NEVER prints to stdout. It returns an
``IamPreflightResult`` dataclass describing what happened. The
caller (the loader) is the SOLE producer of the contract lines

    [apigee-skills] IAM pre-flight: OK (<perms>: granted)
    [apigee-skills] IAM pre-flight: FAILED — <perm> not granted ...
    [apigee-skills] IAM pre-flight: FAILED — HTTP <code> <reason> ...
    [apigee-skills] IAM pre-flight: FAILED — HTTP <code> non-JSON body ...
    [apigee-skills] IAM pre-flight: skipped (no runtime_iam declared)

so that the ``[apigee-skills]`` prefix and the exact wording of
the contract are owned by one module. This library produces
structured data; the loader produces strings.

Hardening:

* The POST is routed through ``http_retry.http_post_retry`` so
  the 5xx-with-jittered-backoff policy is identical to every
  other HTTP call in the pipeline.
* Credentials come from a centralized ``_creds()`` helper that
  calls ``google.auth.default`` with the same ``cloud-platform``
  scope every other helper uses -- no per-call scope drift.
* ``raise_for_status()`` runs before the JSON decode, and the
  JSON decode is guarded so an HTML proxy error page does not
  produce a confusing ``KeyError: 'permissions'`` deep in the
  call stack. The result is mapped to ``status="NON_JSON"``
  with ``error_class="JSONDecodeError"``.

403/404 from ``testIamPermissions`` are treated as "no permissions
granted" (the caller lacks the broader role needed to even ask),
so every input permission is reported missing -- the result is
``status="DENIED"`` with ``granted=()`` and ``missing=requested``.
Other 4xx/5xx after the single retry exhausts are surfaced as
``status="HTTP_ERROR"`` with ``http_status`` / ``http_reason``
populated; the library does NOT raise on HTTP errors -- it
returns a status. The caller decides exit code.
"""
from __future__ import annotations

from dataclasses import dataclass
from typing import Iterable, Optional

import google.auth as google_auth
import requests

# Dual import: production .skill zip layout has no `scripts/`
# parent package; bare `common.*` resolves via sys.path.insert
# at module load. Dev/test layout uses `scripts.common.*` via
# tests/conftest.py.
try:
    from common import http_retry  # production .skill zip layout
except ImportError:
    from scripts.common import http_retry  # dev/test layout

# Uniform OAuth scope. Every google.auth.default call in this
# codebase requests exactly this scope so there is no silent
# per-helper drift.
CLOUD_PLATFORM_SCOPE = (
    "https://www.googleapis.com/auth/cloud-platform"
)

# Apigee/Cloud Resource Manager endpoint template for
# testIamPermissions. The project resource form is sufficient
# for Apigee org-level permissions; the headline skill never
# needs to probe per-environment or per-proxy permissions.
_TEST_IAM_URL = (
    "https://cloudresourcemanager.googleapis.com/v1/"
    "projects/{project}:testIamPermissions"
)


@dataclass(frozen=True)
class IamPreflightResult:
    """Result of an IAM pre-flight check. Pure data; no stdout.

    Status values:

    * ``"SKIPPED"`` -- ``runtime_iam`` was empty; no network
      call was made and no credentials were fetched.
    * ``"GRANTED"`` -- every requested permission was granted
      by ``testIamPermissions``.
    * ``"DENIED"`` -- ``testIamPermissions`` returned a strict
      subset of requested permissions OR returned 403/404
      (mapped to "no permissions granted"). The ``missing``
      tuple lists everything the caller does NOT hold, in
      input order.
    * ``"HTTP_ERROR"`` -- ``testIamPermissions`` returned a
      4xx/5xx (excluding the 403/404 case) after the single
      retry exhausted. ``http_status`` and ``http_reason`` are
      populated. The reported status is the TERMINAL response
      that ``raise_for_status`` raised on (e.g. for "500 then
      502" the result reports 502, not 500).
    * ``"NON_JSON"`` -- the response body was not valid JSON
      (typically an HTML proxy error page returned with a 200).
      ``error_class`` is populated (e.g. ``"JSONDecodeError"``).

    All sequence fields are tuples (frozen dataclass) so the
    result is hashable and safe to share across threads. Input
    order is preserved in every field that is a subset of the
    input -- this matches the caller's contract wording that
    lists missing permissions in the order the operator declared
    them in the manifest's ``runtime_iam`` list.
    """

    status: str  # SKIPPED | GRANTED | DENIED | HTTP_ERROR | NON_JSON
    requested: tuple[str, ...] = ()
    granted: tuple[str, ...] = ()
    missing: tuple[str, ...] = ()
    http_status: Optional[int] = None
    http_reason: Optional[str] = None
    error_class: Optional[str] = None


def _creds() -> tuple[object, object]:
    """Return ``(credentials, project_id)`` from ADC with the
    uniform cloud-platform scope. Credentials are REFRESHED before
    return so ``creds.token`` is immediately populated.

    Centralized so every HTTP path in the pipeline asks for the
    same OAuth scope; per-call scope overrides are explicitly
    forbidden. The refresh-before-return invariant was added
    after the real-infra demo run discovered that a fresh
    ``google.auth.default()`` returns ``creds.token = None`` until
    the first explicit ``creds.refresh()`` call, producing silent
    HTTP 401 responses on the first call.
    """
    from google.auth.transport.requests import Request
    credentials, project_id = google_auth.default(
        scopes=[CLOUD_PLATFORM_SCOPE]
    )
    credentials.refresh(Request())
    return credentials, project_id


def iam_preflight(
    project: str, runtime_iam: Iterable[str]
) -> IamPreflightResult:
    """Probe ``testIamPermissions`` for every entry in
    ``runtime_iam`` and return an ``IamPreflightResult``.

    PURE API: this function NEVER prints to stdout and NEVER
    raises on HTTP errors. Every outcome -- success, partial
    grant, 403/404, 5xx-after-retry, non-JSON body -- maps to
    an ``IamPreflightResult`` status. The caller (the loader)
    reads the result and emits the contract line.

    Outcomes:

    * Empty ``runtime_iam`` -> ``status="SKIPPED"``,
      ``requested=()``. No network call, no auth lookup.
    * Every requested permission echoed back ->
      ``status="GRANTED"``, ``granted=requested`` (input order),
      ``missing=()``.
    * Subset echoed back -> ``status="DENIED"``,
      ``granted=<input-order subset>``,
      ``missing=<input-order difference>``.
    * 403 or 404 from ``testIamPermissions`` ->
      ``status="DENIED"``, ``granted=()``,
      ``missing=requested``. The caller lacks even the broader
      resource-manager role; from the user's perspective this
      is indistinguishable from "you have none of these
      permissions" and produces an actionable message.
    * Other 4xx or 5xx after the single retry exhausts ->
      ``status="HTTP_ERROR"`` with ``http_status`` and
      ``http_reason`` set to the TERMINAL response (the one
      ``raise_for_status`` raised on).
    * Response body is not valid JSON ->
      ``status="NON_JSON"`` with
      ``error_class="JSONDecodeError"``.

    ``raise_for_status`` runs inside ``http_post_retry`` before
    we reach the JSON decode, so a 200 with an HTML body is the
    only path into the ``NON_JSON`` branch -- any 4xx/5xx body
    is already handled by the ``HTTPError`` catch.
    """
    requested = tuple(runtime_iam)

    # Skip path -- no network call, no credentials touched, no
    # stdout. The caller decides whether to log "skipped".
    if not requested:
        return IamPreflightResult(
            status="SKIPPED", requested=()
        )

    # Resolve credentials through the centralized helper so the
    # OAuth scope matches every other HTTP call.
    creds, _project_id = _creds()
    # The Authorization header is built defensively: if the
    # credentials object exposes a ``token`` attribute we use
    # it. Tests stub the credentials object; production code
    # gets a real ``Credentials`` instance whose token is
    # populated by ``google.auth.transport.requests.Request``.
    token = getattr(creds, "token", None) or ""
    headers = {
        "Authorization": f"Bearer {token}",
        "Content-Type": "application/json",
    }
    url = _TEST_IAM_URL.format(project=project)
    body = {"permissions": list(requested)}

    # POST through the shared retry helper -- one retry on 5xx
    # with jittered 200-400 ms backoff. We do not pass on_retry:
    # the transient-failure contract line is the caller's
    # responsibility, and we are a pure data API.
    try:
        resp = http_retry.http_post_retry(
            url, json=body, headers=headers
        )
    except requests.HTTPError as exc:
        # 403/404 are treated as "no perms granted" -- map to
        # DENIED with everything missing. Other 4xx/5xx surface
        # as HTTP_ERROR (the caller prints the 'HTTP <code>
        # <reason>' line and exits).
        status_code = getattr(exc.response, "status_code", None)
        reason = getattr(exc.response, "reason", None)
        if status_code in (403, 404):
            return IamPreflightResult(
                status="DENIED",
                requested=requested,
                granted=(),
                missing=requested,
            )
        return IamPreflightResult(
            status="HTTP_ERROR",
            requested=requested,
            granted=(),
            missing=(),
            http_status=status_code,
            http_reason=reason,
        )

    # 200 OK with a body we still need to decode. An HTML proxy
    # error page returned with a 200 status is the documented
    # NON_JSON case (the response is "OK" enough for
    # raise_for_status but not valid JSON). Map to NON_JSON
    # with the exception class name so the caller can include
    # it in the contract line.
    try:
        payload = resp.json()
    except ValueError as exc:
        # json.JSONDecodeError inherits from ValueError so we
        # catch the broader type and report the actual class.
        return IamPreflightResult(
            status="NON_JSON",
            requested=requested,
            granted=(),
            missing=(),
            error_class=type(exc).__name__,
        )

    # testIamPermissions returns the SUBSET of requested
    # permissions that the caller holds. ``granted`` and
    # ``missing`` are both computed in input order so the
    # contract line the caller eventually prints can be
    # correlated directly against the manifest's runtime_iam
    # list.
    granted_set = set(payload.get("permissions") or [])
    granted_in_order = tuple(
        p for p in requested if p in granted_set
    )
    missing_in_order = tuple(
        p for p in requested if p not in granted_set
    )

    if missing_in_order:
        return IamPreflightResult(
            status="DENIED",
            requested=requested,
            granted=granted_in_order,
            missing=missing_in_order,
        )

    return IamPreflightResult(
        status="GRANTED",
        requested=requested,
        granted=requested,
        missing=(),
    )
