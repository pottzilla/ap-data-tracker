"""End-to-end orchestrator for the AP Invoice Tracker pipeline.

``run_pipeline`` authenticates against Microsoft Graph, pulls invoice emails
from the shared AP mailbox, deduplicates against the SharePoint Approval
Tracker list, enriches each email via Claude, and writes a complete record.
The function is idempotent across runs -- the EmailID dedup guarantees that
the 15-minute scheduler never writes the same message twice.
"""

from __future__ import annotations

import logging
from dataclasses import dataclass, field
from datetime import datetime, timezone
from typing import Any, Optional

from config import settings
from src.auth import get_access_token
from src.claude_enrichment import classify_invoice
from src.cycle_time import calculate_cycle_time
from src.email_monitor import get_invoice_emails, get_thread_message_count
from src.sharepoint import check_duplicate, write_record

logger = logging.getLogger(__name__)


@dataclass
class PipelineStats:
    """Aggregate counters returned from a single pipeline run."""

    fetched: int = 0
    written: int = 0
    skipped_duplicate: int = 0
    errors: int = 0
    error_details: list[str] = field(default_factory=list)

    def as_dict(self) -> dict[str, Any]:
        return {
            "fetched": self.fetched,
            "written": self.written,
            "skipped_duplicate": self.skipped_duplicate,
            "errors": self.errors,
            "error_details": list(self.error_details),
        }


def run_pipeline() -> PipelineStats:
    """Execute one end-to-end pipeline pass.

    Safe to call repeatedly -- dedup on EmailID prevents double writes.
    Per-email failures are logged and counted but do not abort the run.
    """
    stats = PipelineStats()

    access_token = get_access_token()
    site_id = settings.SHAREPOINT_SITE_ID
    list_id = settings.SHAREPOINT_LIST_ID
    mailbox = settings.AP_MAILBOX_ADDRESS

    messages = get_invoice_emails(access_token, mailbox)
    stats.fetched = len(messages)
    logger.info("Pipeline fetched %s candidate invoice emails.", stats.fetched)

    for message in messages:
        email_id = message.get("id") or ""
        subject = message.get("subject") or ""

        try:
            if not email_id:
                raise ValueError("message missing 'id' field")

            if check_duplicate(access_token, site_id, list_id, email_id):
                stats.skipped_duplicate += 1
                logger.info("Skipping duplicate EmailID=%s (%s)", email_id, subject)
                continue

            record = _build_record(access_token, mailbox, message)
            write_record(access_token, site_id, list_id, record)
            stats.written += 1
            logger.info("Wrote record for EmailID=%s subject=%r", email_id, subject)

        except Exception as exc:  # noqa: BLE001 -- never let one email halt the batch
            stats.errors += 1
            detail = f"EmailID={email_id or '<missing>'}: {exc}"
            stats.error_details.append(detail)
            logger.exception("Pipeline error on message %s", detail)

    logger.info("Pipeline complete: %s", stats.as_dict())
    return stats


def _build_record(
    access_token: str, mailbox: str, message: dict
) -> dict[str, Any]:
    """Assemble a SharePoint record dict from a Graph message payload."""
    email_id = message["id"]
    subject = message.get("subject") or ""
    sender = _sender_email(message)
    received = message.get("receivedDateTime") or ""
    conversation_id = message.get("conversationId") or ""
    body_preview = message.get("bodyPreview") or ""

    hours_elapsed, days_elapsed = calculate_cycle_time(received)

    try:
        thread_count = get_thread_message_count(
            access_token, mailbox, conversation_id
        )
    except Exception as exc:  # noqa: BLE001 -- thread count is nice-to-have
        logger.warning(
            "Thread count lookup failed for conversationId=%s: %s",
            conversation_id,
            exc,
        )
        thread_count = 0

    enrichment = classify_invoice(
        subject=subject, sender=sender, body_preview=body_preview
    )

    return {
        "Title": subject,
        "EmailSubject": subject,
        "SenderEmail": sender,
        "ReceivedDate": received,
        "ApprovalDate": _now_iso_utc(),
        "DaysToApprove": days_elapsed,
        "HoursToApprove": hours_elapsed,
        "ThreadMessageCount": thread_count,
        "ApproverCategory": _stringify_categories(message.get("categories")),
        "EmailID": email_id,
        "ConversationID": conversation_id,
        "ApprovalStatus": "Pending",
        "ComplianceStatus": enrichment.get("compliance_status"),
        "SupplierRisk": enrichment.get("supplier_risk"),
        "AnomalyReason": enrichment.get("anomaly_reason"),
    }


def _sender_email(message: dict) -> str:
    sender_block = message.get("from") or {}
    email_address = sender_block.get("emailAddress") or {}
    return email_address.get("address") or ""


def _stringify_categories(categories: Optional[list]) -> str:
    """Match the original Power Automate expression string(categories)."""
    if not categories:
        return ""
    return ", ".join(str(c) for c in categories)


def _now_iso_utc() -> str:
    return datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")
