"""Tests for ``scripts/common/http_retry.py``.

The helper:

* Retries exactly once on 5xx with a jittered 200-400 ms backoff.
* Invokes an optional ``on_retry`` callback with
  ``(status_code, sleep_seconds)`` BEFORE the retry attempt so the
  caller can log retries however it wants. The library itself
  emits NOTHING to stdout -- the transient-failure contract line
  is owned by the caller.
* Does NOT retry on 4xx -- 4xx responses raise immediately.
* On 2xx, returns the ``requests.Response`` directly.

The POST variant sits alongside the original GET; both share the
backoff/retry/jitter logic and differ only in HTTP verb.

All ``requests`` and ``time.sleep`` calls are stubbed; no test
makes a real HTTP call.
"""
from __future__ import annotations

from typing import Any
from unittest import mock

import pytest
import requests

from scripts.common import http_retry


# ----- Test helpers -----


class _FakeResponse:
    """Minimal ``requests.Response`` stand-in.

    Real ``requests.Response`` is heavy to construct; the helper
    only needs ``status_code``, ``reason``, ``raise_for_status``,
    and (for the IAM caller) ``json()``. ``raise_for_status``
    must raise ``requests.HTTPError`` on 4xx/5xx, matching the
    real library's contract.
    """

    def __init__(
        self,
        status_code: int,
        json_data: Any = None,
        reason: str = "",
    ) -> None:
        self.status_code = status_code
        self.reason = reason
        self._json_data = json_data

    def raise_for_status(self) -> None:
        if 400 <= self.status_code < 600:
            err = requests.HTTPError(
                f"{self.status_code} {self.reason}"
            )
            err.response = self  # type: ignore[attr-defined]
            raise err

    def json(self) -> Any:
        return self._json_data


@pytest.fixture
def captured_sleeps(monkeypatch: pytest.MonkeyPatch) -> list[float]:
    """Replace ``time.sleep`` in the module under test with a
    capture list so tests can assert on jitter bounds without
    actually sleeping."""
    calls: list[float] = []
    monkeypatch.setattr(
        http_retry.time, "sleep", lambda s: calls.append(s)
    )
    return calls


# ----- GET: success on first try -----


def test_get_success_first_try_returns_response(
    captured_sleeps: list[float],
    capsys: pytest.CaptureFixture[str],
) -> None:
    """First-try success: response returned, no sleep, no stdout,
    and on_retry callback is NOT invoked (no retry happened)."""
    ok = _FakeResponse(200, json_data={"x": 1})
    retry_calls: list[tuple[int, float]] = []
    with mock.patch.object(
        http_retry.requests, "get", return_value=ok
    ) as mocked_get:
        resp = http_retry.http_get_retry(
            "https://example/foo",
            on_retry=lambda code, sleep: retry_calls.append(
                (code, sleep)
            ),
        )
    assert resp is ok
    mocked_get.assert_called_once_with("https://example/foo")
    assert captured_sleeps == []  # No backoff on success.
    assert capsys.readouterr().out == ""  # Library is silent.
    assert retry_calls == []  # Callback not invoked on success.


# ----- GET: 5xx then 2xx -----


def test_get_retries_once_on_5xx_then_succeeds(
    captured_sleeps: list[float],
    capsys: pytest.CaptureFixture[str],
) -> None:
    """503 then 200: response returned from second call, one
    sleep recorded, on_retry callback invoked exactly once with
    (503, sleep_seconds) where 0.2 <= sleep_seconds <= 0.4."""
    bad = _FakeResponse(503, reason="Service Unavailable")
    ok = _FakeResponse(200, json_data={"ok": True})
    retry_calls: list[tuple[int, float]] = []
    with mock.patch.object(
        http_retry.requests, "get", side_effect=[bad, ok]
    ) as mocked_get:
        resp = http_retry.http_get_retry(
            "https://example/foo",
            on_retry=lambda code, sleep: retry_calls.append(
                (code, sleep)
            ),
        )
    assert resp is ok
    assert mocked_get.call_count == 2
    assert len(captured_sleeps) == 1
    assert 0.2 <= captured_sleeps[0] <= 0.4
    # Library MUST NOT print anything; the caller owns the §2.8
    # transient-failure contract line.
    assert capsys.readouterr().out == ""
    # on_retry invoked exactly once with the 5xx status and the
    # same sleep value that was passed to time.sleep.
    assert len(retry_calls) == 1
    assert retry_calls[0][0] == 503
    assert retry_calls[0][1] == captured_sleeps[0]
    assert 0.2 <= retry_calls[0][1] <= 0.4


def test_get_retry_callback_not_invoked_when_none(
    captured_sleeps: list[float],
    capsys: pytest.CaptureFixture[str],
) -> None:
    """on_retry defaults to None; retry still happens silently
    and the library still produces no stdout."""
    bad = _FakeResponse(503, reason="Service Unavailable")
    ok = _FakeResponse(200, json_data={"ok": True})
    with mock.patch.object(
        http_retry.requests, "get", side_effect=[bad, ok]
    ) as mocked_get:
        resp = http_retry.http_get_retry("https://example/foo")
    assert resp is ok
    assert mocked_get.call_count == 2
    assert capsys.readouterr().out == ""


# ----- GET: 5xx then 5xx -> raise after one retry -----


def test_get_5xx_then_5xx_raises_after_single_retry(
    captured_sleeps: list[float],
    capsys: pytest.CaptureFixture[str],
) -> None:
    """Two consecutive 5xx: HTTPError raised after one retry;
    on_retry invoked exactly once for the FIRST 5xx (the retry
    boundary), not again for the terminal 5xx."""
    bad1 = _FakeResponse(500, reason="Internal Server Error")
    bad2 = _FakeResponse(502, reason="Bad Gateway")
    retry_calls: list[tuple[int, float]] = []
    with mock.patch.object(
        http_retry.requests, "get", side_effect=[bad1, bad2]
    ) as mocked_get:
        with pytest.raises(requests.HTTPError):
            http_retry.http_get_retry(
                "https://example/foo",
                on_retry=lambda code, sleep: retry_calls.append(
                    (code, sleep)
                ),
            )
    # Exactly two attempts: original + one retry.
    assert mocked_get.call_count == 2
    assert len(captured_sleeps) == 1
    assert capsys.readouterr().out == ""
    # Callback fired once for the first 5xx (status=500).
    assert len(retry_calls) == 1
    assert retry_calls[0][0] == 500


# ----- GET: 4xx -> raise immediately, no retry, no callback -----


def test_get_4xx_raises_immediately_no_retry(
    captured_sleeps: list[float],
    capsys: pytest.CaptureFixture[str],
) -> None:
    """4xx is terminal: no retry, no sleep, no callback, no
    stdout. The caller's responsibility to surface the error."""
    bad = _FakeResponse(404, reason="Not Found")
    retry_calls: list[tuple[int, float]] = []
    with mock.patch.object(
        http_retry.requests, "get", side_effect=[bad]
    ) as mocked_get:
        with pytest.raises(requests.HTTPError):
            http_retry.http_get_retry(
                "https://example/foo",
                on_retry=lambda code, sleep: retry_calls.append(
                    (code, sleep)
                ),
            )
    mocked_get.assert_called_once()
    assert captured_sleeps == []
    assert capsys.readouterr().out == ""
    assert retry_calls == []  # No retry happened, no callback.


# ----- POST: success on first try -----


def test_post_success_first_try_returns_response(
    captured_sleeps: list[float],
    capsys: pytest.CaptureFixture[str],
) -> None:
    ok = _FakeResponse(200, json_data={"y": 2})
    retry_calls: list[tuple[int, float]] = []
    with mock.patch.object(
        http_retry.requests, "post", return_value=ok
    ) as mocked_post:
        resp = http_retry.http_post_retry(
            "https://example/bar",
            json={"a": 1},
            on_retry=lambda code, sleep: retry_calls.append(
                (code, sleep)
            ),
        )
    assert resp is ok
    mocked_post.assert_called_once_with(
        "https://example/bar", json={"a": 1}
    )
    assert captured_sleeps == []
    assert capsys.readouterr().out == ""
    assert retry_calls == []


# ----- POST: 5xx then 2xx -----


def test_post_retries_once_on_5xx_then_succeeds(
    captured_sleeps: list[float],
    capsys: pytest.CaptureFixture[str],
) -> None:
    bad = _FakeResponse(503, reason="Service Unavailable")
    ok = _FakeResponse(200, json_data={"ok": True})
    retry_calls: list[tuple[int, float]] = []
    with mock.patch.object(
        http_retry.requests, "post", side_effect=[bad, ok]
    ) as mocked_post:
        resp = http_retry.http_post_retry(
            "https://example/bar",
            json={"k": "v"},
            on_retry=lambda code, sleep: retry_calls.append(
                (code, sleep)
            ),
        )
    assert resp is ok
    assert mocked_post.call_count == 2
    assert len(captured_sleeps) == 1
    assert 0.2 <= captured_sleeps[0] <= 0.4
    assert capsys.readouterr().out == ""
    assert len(retry_calls) == 1
    assert retry_calls[0][0] == 503
    assert retry_calls[0][1] == captured_sleeps[0]


# ----- POST: 5xx then 5xx -> raise -----


def test_post_5xx_then_5xx_raises_after_single_retry(
    captured_sleeps: list[float],
    capsys: pytest.CaptureFixture[str],
) -> None:
    bad1 = _FakeResponse(500, reason="Internal Server Error")
    bad2 = _FakeResponse(504, reason="Gateway Timeout")
    retry_calls: list[tuple[int, float]] = []
    with mock.patch.object(
        http_retry.requests, "post", side_effect=[bad1, bad2]
    ) as mocked_post:
        with pytest.raises(requests.HTTPError):
            http_retry.http_post_retry(
                "https://example/bar",
                json={},
                on_retry=lambda code, sleep: retry_calls.append(
                    (code, sleep)
                ),
            )
    assert mocked_post.call_count == 2
    assert len(captured_sleeps) == 1
    assert len(retry_calls) == 1
    assert retry_calls[0][0] == 500


# ----- POST: 4xx -> raise immediately, no callback -----


def test_post_4xx_raises_immediately_no_retry(
    captured_sleeps: list[float],
    capsys: pytest.CaptureFixture[str],
) -> None:
    bad = _FakeResponse(403, reason="Forbidden")
    retry_calls: list[tuple[int, float]] = []
    with mock.patch.object(
        http_retry.requests, "post", side_effect=[bad]
    ) as mocked_post:
        with pytest.raises(requests.HTTPError):
            http_retry.http_post_retry(
                "https://example/bar",
                json={},
                on_retry=lambda code, sleep: retry_calls.append(
                    (code, sleep)
                ),
            )
    mocked_post.assert_called_once()
    assert captured_sleeps == []
    assert capsys.readouterr().out == ""
    assert retry_calls == []


# ----- Jitter: many runs all land in [0.2, 0.4] -----


def test_jitter_always_within_200_400_ms(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    """Sample many retries; every sleep must land in
    ``[0.2, 0.4]`` seconds. Asserts the jitter bound, not any
    specific value (the implementation uses
    ``random.uniform(0.2, 0.4)`` which is closed on both ends)."""
    sleeps: list[float] = []
    monkeypatch.setattr(
        http_retry.time, "sleep", lambda s: sleeps.append(s)
    )
    for _ in range(50):
        bad = _FakeResponse(503, reason="Service Unavailable")
        ok = _FakeResponse(200)
        with mock.patch.object(
            http_retry.requests, "get", side_effect=[bad, ok]
        ):
            http_retry.http_get_retry("https://example/x")
    assert len(sleeps) == 50
    for s in sleeps:
        assert 0.2 <= s <= 0.4, f"sleep {s} outside [0.2, 0.4]"


# ----- Header / kwarg pass-through (used by IAM caller) -----


def test_get_passes_kwargs_through(
    captured_sleeps: list[float],
) -> None:
    ok = _FakeResponse(200)
    with mock.patch.object(
        http_retry.requests, "get", return_value=ok
    ) as mocked_get:
        http_retry.http_get_retry(
            "https://example/foo",
            headers={"Authorization": "Bearer x"},
            timeout=5,
        )
    mocked_get.assert_called_once_with(
        "https://example/foo",
        headers={"Authorization": "Bearer x"},
        timeout=5,
    )


def test_post_passes_kwargs_through(
    captured_sleeps: list[float],
) -> None:
    ok = _FakeResponse(200)
    with mock.patch.object(
        http_retry.requests, "post", return_value=ok
    ) as mocked_post:
        http_retry.http_post_retry(
            "https://example/bar",
            json={"q": 1},
            headers={"Authorization": "Bearer x"},
            timeout=5,
        )
    mocked_post.assert_called_once_with(
        "https://example/bar",
        json={"q": 1},
        headers={"Authorization": "Bearer x"},
        timeout=5,
    )
