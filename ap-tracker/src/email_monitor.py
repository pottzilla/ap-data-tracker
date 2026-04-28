"""Microsoft Graph email monitor for the shared AP inbox.

Pulls invoice emails from the configured shared mailbox and, for each one,
queries the conversation count -- the Graph capability that was blocked by
IT provisioning in the original Power Automate build.

Notes
-----
The CLAUDE.md spec calls for ``$filter=contains(tolower(subject), 'invoice')``.
Microsoft Graph's ``/users/{id}/messages`` endpoint does not list ``contains``
in its supported $filter functions for messages -- only ``startswith`` is
supported on subject. We therefore use ``$search="subject:invoice"``, which
performs the same case-insensitive substring match using KQL syntax and is
the canonical Graph approach. Any subject starting with ``RE:`` or ``FW:`` is
excluded client-side to avoid double-counting reply chains, matching the
original flow's intent.
"""

from __future__ import annotations

import logging
from typing import Optional
from urllib.parse import quote

from config import settings
from src.graph_client import graph_get, iter_pages

logger = logging.getLogger(__name__)

PAGE_SIZE = 50

EMAIL_SELECT_FIELDS = (
    "id,subject,from,receivedDateTime,conversationId,categories,bodyPreview"
)

REPLY_PREFIXES = ("re:", "fw:", "fwd:")


def _is_reply_or_forward(subject: Optional[str]) -> bool:
    if not subject:
        return False
    head = subject.lstrip().lower()
    return any(head.startswith(prefix) for prefix in REPLY_PREFIXES)


def get_invoice_emails(access_token: str, mailbox: str) -> list[dict]:
    """Return invoice emails from the shared mailbox.

    Filters subject lines for "invoice" via Graph $search, then drops
    RE:/FW:/FWD: replies client-side. Pagination is followed via
    ``@odata.nextLink``.
    """
    url = f"{settings.GRAPH_BASE_URL}/users/{quote(mailbox)}/messages"
    params = {
        "$search": '"subject:invoice"',
        "$select": EMAIL_SELECT_FIELDS,
        "$top": PAGE_SIZE,
    }
    headers = {"ConsistencyLevel": "eventual"}

    results: list[dict] = []
    for page in iter_pages(url, access_token, params=params, extra_headers=headers):
        for message in page.get("value", []):
            if _is_reply_or_forward(message.get("subject")):
                continue
            results.append(message)

    logger.info(
        "Retrieved %s invoice emails from %s (after RE:/FW: exclusion).",
        len(results),
        mailbox,
    )
    return results


def get_thread_message_count(
    access_token: str, mailbox: str, conversation_id: str
) -> int:
    """Return the count of inbox messages sharing a conversationId.

    This call was scoped but never enabled in the original Senversa build
    because the Azure App Registration was blocked by IT provisioning.
    """
    url = (
        f"{settings.GRAPH_BASE_URL}/users/{quote(mailbox)}"
        f"/mailFolders/inbox/messages"
    )
    params = {
        "$filter": f"conversationId eq '{conversation_id}'",
        "$count": "true",
        "$top": 1,
        "$select": "id",
    }
    headers = {"ConsistencyLevel": "eventual"}

    payload, _ = graph_get(url, access_token, params=params, extra_headers=headers)
    count = payload.get("@odata.count")
    if isinstance(count, int):
        return count

    total = len(payload.get("value", []))
    next_link = payload.get("@odata.nextLink")
    while next_link:
        page, _ = graph_get(next_link, access_token)
        total += len(page.get("value", []))
        next_link = page.get("@odata.nextLink")
    return total
