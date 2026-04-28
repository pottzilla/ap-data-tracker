"""Environment configuration for the AP Invoice Tracker pipeline.

Loads required values from `.env` at import time and exposes them as module
constants. Missing or empty values raise `EnvironmentError` immediately so the
pipeline never runs with incomplete credentials.
"""

from __future__ import annotations

import os
from pathlib import Path

from dotenv import load_dotenv

PROJECT_ROOT = Path(__file__).resolve().parent.parent
ENV_PATH = PROJECT_ROOT / ".env"

load_dotenv(dotenv_path=ENV_PATH, override=False)


REQUIRED_VARS = (
    "AZURE_CLIENT_ID",
    "AZURE_TENANT_ID",
    "AZURE_CLIENT_SECRET",
    "SHAREPOINT_SITE_ID",
    "SHAREPOINT_LIST_ID",
    "AP_MAILBOX_ADDRESS",
    "ANTHROPIC_API_KEY",
    "SUPPLIER_1",
    "SUPPLIER_2",
    "SUPPLIER_3",
    "SUPPLIER_4",
)


def _require(name: str) -> str:
    value = os.getenv(name, "").strip()
    if not value:
        raise EnvironmentError(
            f"Required environment variable {name!r} is missing or empty. "
            f"Check {ENV_PATH} and ensure the value is set."
        )
    return value


def _validate_all() -> None:
    missing = [n for n in REQUIRED_VARS if not os.getenv(n, "").strip()]
    if missing:
        raise EnvironmentError(
            "Missing required environment variables: "
            + ", ".join(missing)
            + f". Check {ENV_PATH}."
        )


_validate_all()


AZURE_CLIENT_ID = _require("AZURE_CLIENT_ID")
AZURE_TENANT_ID = _require("AZURE_TENANT_ID")
AZURE_CLIENT_SECRET = _require("AZURE_CLIENT_SECRET")

SHAREPOINT_SITE_ID = _require("SHAREPOINT_SITE_ID")
SHAREPOINT_LIST_ID = _require("SHAREPOINT_LIST_ID")
SHAREPOINT_SITE_URL = os.getenv("SHAREPOINT_SITE_URL", "").strip()

AP_MAILBOX_ADDRESS = _require("AP_MAILBOX_ADDRESS")

ANTHROPIC_API_KEY = _require("ANTHROPIC_API_KEY")

SUPPLIER_ACCOUNTS = (
    _require("SUPPLIER_1"),
    _require("SUPPLIER_2"),
    _require("SUPPLIER_3"),
    _require("SUPPLIER_4"),
)

GRAPH_BASE_URL = "https://graph.microsoft.com/v1.0"
GRAPH_SCOPE = "https://graph.microsoft.com/.default"
TOKEN_ENDPOINT = (
    f"https://login.microsoftonline.com/{AZURE_TENANT_ID}/oauth2/v2.0/token"
)
