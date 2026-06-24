"""Tests for ``scripts/common/iam_preflight.py``.

The pre-flight library:

* Posts the dot-form ``runtime_iam`` permissions verbatim to
  Apigee/Cloud ``testIamPermissions`` (no slash-form translation).
* Reads the returned ``permissions[]`` list -- any input
  permission not echoed back is considered NOT granted.
* On empty input, skips the call entirely.
* Hardening: routes the POST through ``http_post_retry`` (1
  retry on 5xx); uses a centralized ``_creds()`` helper with
  uniform ``cloud-platform`` scope; calls ``raise_for_status()``
  and catches ``json.JSONDecodeError`` BEFORE extracting
  ``permissions[]``.

This module is a PURE API: it emits NOTHING to stdout. The
contract lines (``[apigee-skills] IAM pre-flight: ...``) are
owned by the loader, which reads the returned
``IamPreflightResult`` and formats the contract line. Tests
therefore assert on the dataclass fields, not on captured stdout.

All ``requests``, ``google.auth.default``, and ``time.sleep``
calls are stubbed; no test hits the network.
"""
from __future__ import annotations

import json
from typing import Any
from unittest import mock

import pytest
import requests

from scripts.common import http_retry, iam_preflight


# ----- Fakes -----


class _FakeResponse:
    """Minimal stand-in for ``requests.Response``.

    Mirrors the helper used in ``test_http_retry.py`` so the two
    test files exercise the same interface. ``raise_for_status``
    raises ``requests.HTTPError`` on 4xx/5xx; ``json()`` returns
    the configured payload or raises ``json.JSONDecodeError`` if
    constructed with ``json_decode_error=True``.
    """

    def __init__(
        self,
        status_code: int,
        json_data: Any = None,
        reason: str = "",
        json_decode_error: bool = False,
    ) -> None:
        self.status_code = status_code
        self.reason = reason
        self._json_data = json_data
        self._json_decode_error = json_decode_error

    def raise_for_status(self) -> None:
        if 400 <= self.status_code < 600:
            err = requests.HTTPError(
                f"{self.status_code} {self.reason}"
            )
            err.response = self  # type: ignore[attr-defined]
            raise err

    def json(self) -> Any:
        if self._json_decode_error:
            raise json.JSONDecodeError("expecting value", "<html>", 0)
        return self._json_data


class _FakeCreds:
    """Stand-in for ``google.auth.credentials.Credentials``.

    The pre-flight library never reads token values in tests --
    only that the object exposes a ``token`` attribute the
    Authorization header can be built from. ``refresh`` is a
    no-op so the centralized ``_creds()`` helper can call it
    without exploding.
    """

    def __init__(self, token: str = "fake-token") -> None:
        self.token = token

    def refresh(self, _request: Any) -> None:  # pragma: no cover
        return None


@pytest.fixture
def patched_auth(monkeypatch: pytest.MonkeyPatch) -> mock.MagicMock:
    """Replace ``google.auth.default`` in ``iam_preflight`` with a
    mock that returns ``(_FakeCreds, "test-project")``. Tests
    that need to assert on the scopes passed to it can read
    ``call_args`` from the returned mock."""
    fake = mock.MagicMock(
        return_value=(_FakeCreds(), "test-project")
    )
    monkeypatch.setattr(iam_preflight.google_auth, "default", fake)
    return fake


@pytest.fixture
def no_sleep(monkeypatch: pytest.MonkeyPatch) -> None:
    """Stub ``time.sleep`` inside the shared retry helper so the
    retry tests in this file never actually pause."""
    monkeypatch.setattr(http_retry.time, "sleep", lambda _s: None)


# ----- Empty runtime_iam -> skip path -----


def test_empty_runtime_iam_returns_skipped_result(
    patched_auth: mock.MagicMock,
    capsys: pytest.CaptureFixture[str],
) -> None:
    """Empty input: status=SKIPPED, no network call, no auth
    lookup, and -- because this is a pure API -- no stdout."""
    with mock.patch.object(
        http_retry.requests, "post"
    ) as mocked_post:
        result = iam_preflight.iam_preflight(
            project="proj-1", runtime_iam=[]
        )
    assert result.status == "SKIPPED"
    assert result.requested == ()
    assert result.granted == ()
    assert result.missing == ()
    # Skip path MUST NOT call testIamPermissions or even ask for
    # credentials -- there is nothing to validate.
    mocked_post.assert_not_called()
    patched_auth.assert_not_called()
    # Pure API: no stdout, ever.
    assert capsys.readouterr().out == ""


# ----- All perms granted -> GRANTED -----


def test_all_perms_granted_returns_granted_status(
    patched_auth: mock.MagicMock,
    no_sleep: None,
    capsys: pytest.CaptureFixture[str],
) -> None:
    """All permissions echoed back: status=GRANTED, granted is
    the full input in INPUT ORDER, missing is empty.

    Input order is preserved in the dataclass; if the caller
    wants a sorted contract line it can sort the tuple itself.
    """
    perms = [
        "apigee.proxies.list",
        "apigee.deployments.list",
        "apigee.proxyrevisions.get",
    ]
    granted = list(perms)  # All granted.
    ok = _FakeResponse(200, json_data={"permissions": granted})
    with mock.patch.object(
        http_retry.requests, "post", return_value=ok
    ) as mocked_post:
        result = iam_preflight.iam_preflight(
            project="proj-1", runtime_iam=perms
        )
    assert result.status == "GRANTED"
    assert result.requested == tuple(perms)
    assert result.granted == tuple(perms)  # Input order preserved.
    assert result.missing == ()
    assert result.http_status is None
    assert result.http_reason is None
    assert result.error_class is None
    # Exactly one POST -- no retry, no extra call.
    assert mocked_post.call_count == 1
    # Pure API.
    assert capsys.readouterr().out == ""


# ----- Some perms missing -> DENIED, input-order missing list -----


def test_partial_grant_returns_denied_with_input_order_missing(
    patched_auth: mock.MagicMock,
    no_sleep: None,
) -> None:
    """One of three granted: status=DENIED. ``granted`` lists
    the subset in input order; ``missing`` is the input-order
    set difference."""
    requested = [
        "apigee.proxies.list",
        "apigee.deployments.list",
        "apigee.proxyrevisions.get",
    ]
    granted_back = ["apigee.proxies.list"]  # The other two missing.
    ok = _FakeResponse(200, json_data={"permissions": granted_back})
    with mock.patch.object(
        http_retry.requests, "post", return_value=ok
    ):
        result = iam_preflight.iam_preflight(
            project="proj-1", runtime_iam=requested
        )
    assert result.status == "DENIED"
    assert result.requested == tuple(requested)
    assert result.granted == ("apigee.proxies.list",)
    # Missing list MUST preserve input order so the caller can
    # surface it directly to the operator.
    assert result.missing == (
        "apigee.deployments.list",
        "apigee.proxyrevisions.get",
    )


def test_zero_perms_granted_reports_all_as_missing_in_input_order(
    patched_auth: mock.MagicMock,
    no_sleep: None,
) -> None:
    """testIamPermissions returning an empty list (or omitting
    the key entirely) means every input permission is missing.
    Input order is preserved verbatim."""
    requested = ["b.read", "a.write", "c.list"]
    ok = _FakeResponse(200, json_data={"permissions": []})
    with mock.patch.object(
        http_retry.requests, "post", return_value=ok
    ):
        result = iam_preflight.iam_preflight(
            project="proj-1", runtime_iam=requested
        )
    assert result.status == "DENIED"
    assert result.requested == tuple(requested)
    assert result.granted == ()
    assert result.missing == tuple(requested)  # Input order.


def test_403_response_treated_as_denied_all_missing(
    patched_auth: mock.MagicMock,
    no_sleep: None,
) -> None:
    """testIamPermissions returning 403 means the caller has no
    relevant perms (lacks the broader role to even call
    testIamPermissions). Map to status=DENIED with the full
    input list reported missing -- the user's situation is the
    same as if they had been granted zero perms."""
    requested = ["apigee.proxies.list", "apigee.deployments.list"]
    forbidden = _FakeResponse(403, reason="Forbidden", json_data={})
    with mock.patch.object(
        http_retry.requests, "post", return_value=forbidden
    ):
        result = iam_preflight.iam_preflight(
            project="proj-1", runtime_iam=requested
        )
    assert result.status == "DENIED"
    assert result.requested == tuple(requested)
    assert result.granted == ()
    assert result.missing == tuple(requested)


def test_404_response_treated_as_denied_all_missing(
    patched_auth: mock.MagicMock,
    no_sleep: None,
) -> None:
    """Same semantics as 403: 404 from testIamPermissions maps
    to DENIED with the full input list reported missing."""
    requested = ["apigee.proxies.list"]
    notfound = _FakeResponse(404, reason="Not Found", json_data={})
    with mock.patch.object(
        http_retry.requests, "post", return_value=notfound
    ):
        result = iam_preflight.iam_preflight(
            project="proj-1", runtime_iam=requested
        )
    assert result.status == "DENIED"
    assert result.requested == tuple(requested)
    assert result.granted == ()
    assert result.missing == tuple(requested)


# ----- Dot-form pass-through (no slash-form translation) -----


def test_dot_form_permissions_posted_verbatim(
    patched_auth: mock.MagicMock,
    no_sleep: None,
) -> None:
    """The POST body MUST contain the EXACT dot-form strings,
    not slash-form translations. Verified by inspecting the
    ``json=`` kwarg passed to ``requests.post``."""
    requested = [
        "apigee.proxies.list",
        "apigee.deployments.list",
        "secretmanager.versions.access",
    ]
    ok = _FakeResponse(200, json_data={"permissions": requested})
    with mock.patch.object(
        http_retry.requests, "post", return_value=ok
    ) as mocked_post:
        iam_preflight.iam_preflight(
            project="proj-1", runtime_iam=requested
        )
    # Single call; inspect the json= kwarg.
    assert mocked_post.call_count == 1
    _, kwargs = mocked_post.call_args
    body = kwargs.get("json")
    assert body is not None, "POST body must be JSON-encoded"
    posted_perms = body.get("permissions")
    assert posted_perms == requested  # Verbatim, in order.
    # Defensive: no slash-form leaked anywhere in the POSTed body.
    for p in posted_perms:
        assert "/" not in p
        assert "googleapis.com" not in p


# ----- 5xx retry via http_post_retry -----


def test_5xx_triggers_retry_via_http_post_retry(
    patched_auth: mock.MagicMock,
    no_sleep: None,
    capsys: pytest.CaptureFixture[str],
) -> None:
    """503 then 200: exactly two POST calls (original + 1 retry).
    Result is GRANTED. Library still emits nothing to stdout --
    the transient line belongs to the caller."""
    requested = ["apigee.proxies.list"]
    bad = _FakeResponse(503, reason="Service Unavailable")
    ok = _FakeResponse(200, json_data={"permissions": requested})
    with mock.patch.object(
        http_retry.requests, "post", side_effect=[bad, ok]
    ) as mocked_post:
        result = iam_preflight.iam_preflight(
            project="proj-1", runtime_iam=requested
        )
    assert result.status == "GRANTED"
    assert mocked_post.call_count == 2
    # Pure API: no stdout from the library on retry either.
    assert capsys.readouterr().out == ""


def test_persistent_5xx_returns_http_error_status(
    patched_auth: mock.MagicMock,
    no_sleep: None,
) -> None:
    """Two consecutive 5xx: result.status == 'HTTP_ERROR' with
    http_status/http_reason populated. The library DOES NOT
    raise -- the caller reads the result and prints the
    'HTTP <code> <reason>' contract line."""
    requested = ["apigee.proxies.list"]
    bad1 = _FakeResponse(500, reason="Internal Server Error")
    bad2 = _FakeResponse(502, reason="Bad Gateway")
    with mock.patch.object(
        http_retry.requests, "post", side_effect=[bad1, bad2]
    ) as mocked_post:
        result = iam_preflight.iam_preflight(
            project="proj-1", runtime_iam=requested
        )
    assert mocked_post.call_count == 2
    assert result.status == "HTTP_ERROR"
    assert result.requested == tuple(requested)
    assert result.granted == ()
    assert result.missing == ()
    # The terminal status is what raise_for_status raised on:
    # the SECOND response (502). That matches the contract --
    # 'HTTP <code>' refers to the response actually received.
    assert result.http_status == 502
    assert result.http_reason == "Bad Gateway"
    assert result.error_class is None


def test_500_then_503_returns_http_error_with_terminal_status(
    patched_auth: mock.MagicMock,
    no_sleep: None,
) -> None:
    """Locks the property that the HTTP_ERROR result reports the
    TERMINAL HTTP status (the one raise_for_status raised on),
    not the initial one. Defensive sibling to the previous test."""
    requested = ["x.y"]
    bad = _FakeResponse(
        500, reason="Internal Server Error", json_data={"x": 1}
    )
    bad2 = _FakeResponse(
        503, reason="Service Unavailable", json_data={"x": 2}
    )
    with mock.patch.object(
        http_retry.requests, "post", side_effect=[bad, bad2]
    ):
        result = iam_preflight.iam_preflight(
            project="proj-1", runtime_iam=requested
        )
    assert result.status == "HTTP_ERROR"
    assert result.http_status == 503
    assert result.http_reason == "Service Unavailable"


# ----- JSON decode failure -> NON_JSON status -----


def test_non_json_body_returns_non_json_status(
    patched_auth: mock.MagicMock,
    no_sleep: None,
) -> None:
    """An HTML proxy error page returned with a 200 status maps
    to status=NON_JSON with error_class='JSONDecodeError'. The
    library DOES NOT raise -- the caller reads the result and
    prints the 'non-JSON body' contract line."""
    requested = ["apigee.proxies.list"]
    html_resp = _FakeResponse(
        200, reason="OK", json_decode_error=True
    )
    with mock.patch.object(
        http_retry.requests, "post", return_value=html_resp
    ):
        result = iam_preflight.iam_preflight(
            project="proj-1", runtime_iam=requested
        )
    assert result.status == "NON_JSON"
    assert result.requested == tuple(requested)
    assert result.granted == ()
    assert result.missing == ()
    assert result.error_class == "JSONDecodeError"


# ----- Uniform cloud-platform scope -----


def test_creds_helper_requests_cloud_platform_scope(
    patched_auth: mock.MagicMock,
    no_sleep: None,
) -> None:
    """The centralized ``_creds()`` helper MUST call
    ``google.auth.default(scopes=[...cloud-platform])`` so every
    HTTP path uses the same auth scope."""
    requested = ["apigee.proxies.list"]
    ok = _FakeResponse(200, json_data={"permissions": requested})
    with mock.patch.object(
        http_retry.requests, "post", return_value=ok
    ):
        iam_preflight.iam_preflight(
            project="proj-1", runtime_iam=requested
        )
    patched_auth.assert_called_once()
    _, kwargs = patched_auth.call_args
    assert kwargs.get("scopes") == [
        "https://www.googleapis.com/auth/cloud-platform"
    ]


def test_creds_helper_is_a_separate_function(
    patched_auth: mock.MagicMock,
    no_sleep: None,
) -> None:
    """The helper is named ``_creds`` so other callers can
    import and reuse it without duplicating the scope literal."""
    assert hasattr(iam_preflight, "_creds")
    assert callable(iam_preflight._creds)
    creds, project = iam_preflight._creds()
    assert creds is not None
    assert project == "test-project"


# ----- Public API surface: dataclass + iam_preflight function -----


def test_public_api_exports_iam_preflight_result_dataclass() -> None:
    """The library exports ``IamPreflightResult`` as the
    consumer-facing data type so any caller can import it for
    type hints without duplicating the field layout."""
    assert hasattr(iam_preflight, "IamPreflightResult")
    cls = iam_preflight.IamPreflightResult
    # Frozen dataclass -- field assignment must raise.
    instance = cls(status="SKIPPED")
    with pytest.raises(Exception):
        instance.status = "GRANTED"  # type: ignore[misc]


def test_public_function_name_has_no_leading_underscore() -> None:
    """The function was previously exposed as ``_iam_preflight``
    as if it were module-private, but it is the cross-module
    public API. Callers import ``iam_preflight`` (no underscore).
    Lock the surface so a future rename does not silently break
    callers."""
    assert hasattr(iam_preflight, "iam_preflight")
    assert callable(iam_preflight.iam_preflight)
