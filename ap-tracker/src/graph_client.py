"""Shared Microsoft Graph HTTP helpers.

Centralises auth header injection, 401 token refresh, and exponential
backoff retry on 429/5xx for every Graph call in the pipeline.
"""

from __future__ import annotations

import logging
import time
from typing import Any, Iterable, Optional

import requests

from src import auth

logger = logging.getLogger(__name__)

REQUEST_TIMEOUT_SECONDS = 30
MAX_RETRIES = 5
INITIAL_BACKOFF_SECONDS = 1.0
MAX_BACKOFF_SECONDS = 30.0


def _auth_headers(token: str, extra: Optional[dict] = None) -> dict:
    headers = {
        "Authorization": f"Bearer {token}",
        "Accept": "application/json",
    }
    if extra:
        headers.update(extra)
    return headers


def _request(
    method: str,
    url: str,
    access_token: str,
    *,
    params: Optional[dict] = None,
    json_body: Optional[dict] = None,
    extra_headers: Optional[dict] = None,
) -> tuple[requests.Response, str]:
    """Perform a Graph HTTP request with retry, backoff, and 401 refresh.

    Returns ``(response, current_token)`` so the caller can keep using a
    refreshed token on subsequent calls.
    """
    backoff = INITIAL_BACKOFF_SECONDS
    token = access_token

    for attempt in range(1, MAX_RETRIES + 1):
        headers = _auth_headers(token, extra_headers)
        if json_body is not None and "Content-Type" not in headers:
            headers["Content-Type"] = "application/json"

        response = requests.request(
            method,
            url,
            headers=headers,
            params=params,
            json=json_body,
            timeout=REQUEST_TIMEOUT_SECONDS,
        )

        if response.status_code == 401 and attempt < MAX_RETRIES:
            logger.warning(
                "Graph %s %s returned 401; forcing token refresh and retrying.",
                method,
                url,
            )
            token = auth.get_access_token(force_refresh=True)
            continue

        if response.status_code == 429 or 500 <= response.status_code < 600:
            if attempt >= MAX_RETRIES:
                return response, token
            retry_after = response.headers.get("Retry-After")
            sleep_for = float(retry_after) if retry_after else backoff
            logger.warning(
                "Graph %s on %s %s; retry %s/%s in %.2fs",
                response.status_code,
                method,
                url,
                attempt,
                MAX_RETRIES,
                sleep_for,
            )
            time.sleep(sleep_for)
            backoff = min(backoff * 2, MAX_BACKOFF_SECONDS)
            continue

        return response, token

    raise RuntimeError(f"Graph {method} {url} exhausted retries.")


def graph_get(
    url: str,
    access_token: str,
    params: Optional[dict] = None,
    extra_headers: Optional[dict] = None,
) -> tuple[dict, str]:
    """GET against Graph; returns ``(json_payload, current_token)``."""
    response, token = _request(
        "GET",
        url,
        access_token,
        params=params,
        extra_headers=extra_headers,
    )
    if not response.ok:
        raise RuntimeError(
            f"Graph GET {url} failed: HTTP {response.status_code} -- {response.text}"
        )
    return response.json(), token


def graph_post(
    url: str,
    access_token: str,
    json_body: dict,
    extra_headers: Optional[dict] = None,
) -> tuple[dict, str]:
    """POST against Graph; returns ``(json_payload, current_token)``."""
    response, token = _request(
        "POST",
        url,
        access_token,
        json_body=json_body,
        extra_headers=extra_headers,
    )
    if not response.ok:
        raise RuntimeError(
            f"Graph POST {url} failed: HTTP {response.status_code} -- {response.text}"
        )
    return response.json(), token


def graph_delete(
    url: str,
    access_token: str,
    extra_headers: Optional[dict] = None,
) -> str:
    """DELETE against Graph; returns the current token. Raises on non-2xx."""
    response, token = _request(
        "DELETE",
        url,
        access_token,
        extra_headers=extra_headers,
    )
    if not response.ok:
        raise RuntimeError(
            f"Graph DELETE {url} failed: HTTP {response.status_code} -- {response.text}"
        )
    return token


def iter_pages(
    initial_url: str,
    access_token: str,
    params: Optional[dict] = None,
    extra_headers: Optional[dict] = None,
) -> Iterable[dict]:
    """Yield Graph result pages following ``@odata.nextLink``."""
    url = initial_url
    current_params = params
    token = access_token

    while url:
        payload, token = graph_get(
            url,
            token,
            params=current_params,
            extra_headers=extra_headers,
        )
        yield payload
        url = payload.get("@odata.nextLink")
        current_params = None  # nextLink already encodes the original query
