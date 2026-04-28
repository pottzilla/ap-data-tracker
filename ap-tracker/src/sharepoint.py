"""SharePoint Approval Tracker reads and writes via Microsoft Graph.

Two responsibilities:
1. ``check_duplicate`` -- query the list filtered on the ``EmailID`` column
   so the pipeline never writes the same message twice.
2. ``write_record`` -- POST a new list item with all schema fields mapped
   exactly to the column internal names verified during Phase 1.
"""

from __future__ import annotations

import logging
from typing import Iterable, Optional

from config import settings
from src.graph_client import graph_get, graph_post, graph_delete

logger = logging.getLogger(__name__)


SCHEMA_COLUMNS: tuple[str, ...] = (
    "Title",
    "EmailSubject",
    "SenderEmail",
    "ReceivedDate",
    "ApprovalDate",
    "DaysToApprove",
    "HoursToApprove",
    "ThreadMessageCount",
    "ApproverCategory",
    "EmailID",
    "ConversationID",
    "ApprovalStatus",
    "ComplianceStatus",
    "SupplierRisk",
    "AnomalyReason",
)


def _items_url(site_id: str, list_id: str, item_id: Optional[str] = None) -> str:
    base = f"{settings.GRAPH_BASE_URL}/sites/{site_id}/lists/{list_id}/items"
    return f"{base}/{item_id}" if item_id else base


def _escape_filter_literal(value: str) -> str:
    """Escape single quotes for an OData filter string literal."""
    return value.replace("'", "''")


def check_duplicate(
    access_token: str,
    site_id: str,
    list_id: str,
    email_id: str,
) -> bool:
    """Return True if a list item already exists with the given EmailID."""
    if not email_id:
        raise ValueError("email_id is required for duplicate check")

    safe_id = _escape_filter_literal(email_id)
    params = {
        "$expand": "fields($select=EmailID)",
        "$filter": f"fields/EmailID eq '{safe_id}'",
        "$top": 1,
    }
    headers = {
        "Prefer": "HonorNonIndexedQueriesWarningMayFailRandomly",
    }

    payload, _ = graph_get(
        _items_url(site_id, list_id),
        access_token,
        params=params,
        extra_headers=headers,
    )
    items = payload.get("value", [])
    exists = len(items) > 0
    logger.debug("Duplicate check for EmailID=%s -> %s", email_id, exists)
    return exists


def write_record(
    access_token: str,
    site_id: str,
    list_id: str,
    record: dict,
) -> dict:
    """POST a new item to the SharePoint Approval Tracker list.

    ``record`` keys must match the SharePoint column internal names listed
    in ``SCHEMA_COLUMNS``. Unknown keys are dropped with a warning so a
    schema drift doesn't quietly poison the dataset.
    """
    fields, ignored = _project_fields(record)
    if ignored:
        logger.warning("Dropping unknown field keys from record: %s", sorted(ignored))

    if not fields:
        raise ValueError("record contained no recognised SharePoint columns")

    body = {"fields": fields}
    try:
        payload, _ = graph_post(_items_url(site_id, list_id), access_token, body)
    except RuntimeError as exc:
        message = str(exc)
        if " 400 " in message or "HTTP 400" in message:
            raise RuntimeError(
                f"SharePoint write rejected (400 -- bad request). "
                f"Likely a column name mismatch or invalid value type. Body: {body}. "
                f"Underlying: {exc}"
            ) from exc
        if " 403 " in message or "HTTP 403" in message:
            raise RuntimeError(
                f"SharePoint write forbidden (403). Confirm Sites.ReadWrite.All "
                f"is granted to the App Registration and admin-consented. "
                f"Underlying: {exc}"
            ) from exc
        raise

    logger.info(
        "Wrote SharePoint item id=%s for EmailID=%s",
        payload.get("id"),
        fields.get("EmailID"),
    )
    return payload


def delete_item(
    access_token: str,
    site_id: str,
    list_id: str,
    item_id: str,
) -> None:
    """Delete a list item by id. Used by tests to clean up after writes."""
    graph_delete(_items_url(site_id, list_id, item_id), access_token)
    logger.info("Deleted SharePoint item id=%s", item_id)


def _project_fields(record: dict) -> tuple[dict, set[str]]:
    """Project a record dict to recognised columns; return (fields, ignored)."""
    schema_set = set(SCHEMA_COLUMNS)
    fields = {k: v for k, v in record.items() if k in schema_set}
    ignored = set(record.keys()) - schema_set
    return fields, ignored
