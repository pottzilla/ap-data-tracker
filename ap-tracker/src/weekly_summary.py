"""Weekly AP performance summary via Claude.

Pulls the past 7 days of SharePoint records, hands them to Claude Opus 4.7
with adaptive thinking, and returns a plain-English summary covering
cycle time, compliance, top offenders, and recommended actions.
"""

from __future__ import annotations

import json
import logging
from datetime import datetime, timedelta, timezone
from typing import Any

import anthropic

from config import settings
from src.graph_client import iter_pages
from src.sharepoint import SCHEMA_COLUMNS

logger = logging.getLogger(__name__)

MODEL = "claude-opus-4-7"
MAX_TOKENS = 2000
LOOKBACK_DAYS = 7
PAGE_SIZE = 100

SUMMARY_PROMPT = """\
You are an accounts payable analyst writing a weekly performance summary for
a finance manager. You will be given a JSON array of invoice records captured
over the past {lookback} days. Each record includes cycle time, supplier,
compliance status, risk, and any anomaly flags.

Produce a concise plain-English summary covering:
1. Average cycle time in hours and days (across all approved records).
2. Worst performing suppliers by cycle time and by compliance rate.
3. Overall compliance rate for the week (percentage compliant).
4. Anomaly count and a one-line description of each flagged anomaly.
5. Two or three recommended actions based on what the data shows.

Records ({count} total):
{records_json}

Write the summary only. No preamble. No markdown headers. Short paragraphs
and bullet lists are fine.
"""

SUMMARY_FIELDS = (
    "EmailSubject",
    "SenderEmail",
    "ReceivedDate",
    "ApprovalDate",
    "HoursToApprove",
    "DaysToApprove",
    "ApprovalStatus",
    "ComplianceStatus",
    "SupplierRisk",
    "AnomalyReason",
)


_client: anthropic.Anthropic | None = None


def _get_client() -> anthropic.Anthropic:
    global _client
    if _client is None:
        _client = anthropic.Anthropic(api_key=settings.ANTHROPIC_API_KEY)
    return _client


def generate_weekly_summary(
    access_token: str,
    site_id: str,
    list_id: str,
) -> str:
    """Fetch the past ``LOOKBACK_DAYS`` of records and return a Claude summary.

    Returns an empty-state message if no records were captured in the window.
    """
    records = _fetch_recent_records(
        access_token, site_id, list_id, days=LOOKBACK_DAYS
    )
    logger.info(
        "Weekly summary: %s records from the past %s days.",
        len(records),
        LOOKBACK_DAYS,
    )

    if not records:
        return (
            f"No invoice records were captured in the past {LOOKBACK_DAYS} days. "
            f"Confirm the pipeline is running on schedule."
        )

    prompt = SUMMARY_PROMPT.format(
        lookback=LOOKBACK_DAYS,
        count=len(records),
        records_json=json.dumps(records, default=str, indent=2),
    )

    try:
        response = _get_client().messages.create(
            model=MODEL,
            max_tokens=MAX_TOKENS,
            thinking={"type": "adaptive"},
            messages=[{"role": "user", "content": prompt}],
        )
    except anthropic.APIError as exc:
        logger.error("Weekly summary Claude call failed: %s", exc)
        return f"Weekly summary unavailable (Claude API error): {exc}"

    summary = _extract_text(response)
    if not summary:
        logger.warning("Claude returned no text content for weekly summary.")
        return "Weekly summary unavailable (empty Claude response)."

    return summary


def _fetch_recent_records(
    access_token: str,
    site_id: str,
    list_id: str,
    days: int,
) -> list[dict[str, Any]]:
    """Return field dicts for list items received within the past ``days``."""
    cutoff = datetime.now(timezone.utc) - timedelta(days=days)
    cutoff_iso = cutoff.strftime("%Y-%m-%dT%H:%M:%SZ")

    select_fields = ",".join(SCHEMA_COLUMNS)
    url = (
        f"{settings.GRAPH_BASE_URL}/sites/{site_id}/lists/{list_id}/items"
    )
    params = {
        "$expand": f"fields($select={select_fields})",
        "$filter": f"fields/ReceivedDate ge '{cutoff_iso}'",
        "$top": PAGE_SIZE,
    }
    headers = {
        "Prefer": "HonorNonIndexedQueriesWarningMayFailRandomly",
    }

    records: list[dict[str, Any]] = []
    for page in iter_pages(url, access_token, params=params, extra_headers=headers):
        for item in page.get("value", []):
            fields = item.get("fields") or {}
            records.append({k: fields.get(k) for k in SUMMARY_FIELDS})

    return records


def _extract_text(response: Any) -> str:
    parts: list[str] = []
    for block in getattr(response, "content", []):
        if getattr(block, "type", None) == "text":
            parts.append(getattr(block, "text", ""))
    return "".join(parts).strip()
