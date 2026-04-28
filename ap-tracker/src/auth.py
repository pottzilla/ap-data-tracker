"""Microsoft Graph OAuth2 authentication with in-process token caching.

Uses the client credentials flow (application permissions) against the App
Registration provisioned for the AP Tracker tenant. Tokens are cached in the
module so that repeat calls within the lifetime of a token return the cached
value instead of hitting the identity endpoint on every pipeline run.
"""

from __future__ import annotations

import logging
import threading
import time
from dataclasses import dataclass
from typing import Optional

import requests

from config import settings

logger = logging.getLogger(__name__)

EXPIRY_SAFETY_MARGIN_SECONDS = 60
REQUEST_TIMEOUT_SECONDS = 30


@dataclass
class _CachedToken:
    access_token: str
    expires_at_epoch: float

    def is_valid(self) -> bool:
        return time.time() < (self.expires_at_epoch - EXPIRY_SAFETY_MARGIN_SECONDS)


_cache_lock = threading.Lock()
_cached: Optional[_CachedToken] = None


def get_access_token(force_refresh: bool = False) -> str:
    """Return a valid Microsoft Graph access token.

    Returns the cached token when still valid; otherwise calls the token
    endpoint and stores the new value before returning it.
    """
    global _cached

    with _cache_lock:
        if not force_refresh and _cached is not None and _cached.is_valid():
            logger.debug("Returning cached Graph access token.")
            return _cached.access_token

        logger.info("Requesting new Graph access token from %s", settings.TOKEN_ENDPOINT)
        response = requests.post(
            settings.TOKEN_ENDPOINT,
            data={
                "client_id": settings.AZURE_CLIENT_ID,
                "client_secret": settings.AZURE_CLIENT_SECRET,
                "scope": settings.GRAPH_SCOPE,
                "grant_type": "client_credentials",
            },
            timeout=REQUEST_TIMEOUT_SECONDS,
        )

        if response.status_code != 200:
            raise RuntimeError(
                f"Token request failed: HTTP {response.status_code} -- {response.text}"
            )

        payload = response.json()
        access_token = payload.get("access_token")
        expires_in = payload.get("expires_in")

        if not access_token or not isinstance(expires_in, int):
            raise RuntimeError(
                f"Token response missing access_token or expires_in: {payload}"
            )

        _cached = _CachedToken(
            access_token=access_token,
            expires_at_epoch=time.time() + expires_in,
        )
        logger.info(
            "Acquired Graph token; expires in %s seconds (cached).", expires_in
        )
        return access_token


def clear_cache() -> None:
    """Drop the cached token. Primarily for tests."""
    global _cached
    with _cache_lock:
        _cached = None
