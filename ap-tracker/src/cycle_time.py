"""Cycle time calculation for invoice emails.

Replaces the ticks-based Power Automate expression
``div(sub(ticks(now), ticks(receivedDateTime)), 36000000000)`` with clean
Python datetime arithmetic. Output matches the original flow's hours and
days fields exactly.
"""

from __future__ import annotations

from datetime import datetime, timezone
from typing import Optional


def _parse_iso(received_datetime_str: str) -> datetime:
    """Parse a Graph receivedDateTime ISO 8601 string into a tz-aware datetime.

    Graph returns values like ``2026-04-15T11:25:19Z``. ``datetime.fromisoformat``
    accepts the trailing ``Z`` from Python 3.11+, but we normalise it to
    ``+00:00`` to keep behaviour identical across patch releases.
    """
    if not received_datetime_str:
        raise ValueError("received_datetime_str is empty")

    cleaned = received_datetime_str.strip()
    if cleaned.endswith("Z"):
        cleaned = cleaned[:-1] + "+00:00"

    parsed = datetime.fromisoformat(cleaned)
    if parsed.tzinfo is None:
        parsed = parsed.replace(tzinfo=timezone.utc)
    return parsed


def calculate_cycle_time(
    received_datetime_str: str,
    now: Optional[datetime] = None,
) -> tuple[float, float]:
    """Return ``(hours_elapsed, days_elapsed)`` between received time and now.

    Both values are floats rounded to 2 decimal places. ``now`` defaults to
    the current UTC time and is exposed only so tests can pin a reference
    instant.
    """
    received = _parse_iso(received_datetime_str)
    reference = now if now is not None else datetime.now(timezone.utc)

    if reference.tzinfo is None:
        reference = reference.replace(tzinfo=timezone.utc)

    delta_seconds = (reference - received).total_seconds()
    hours_elapsed = round(delta_seconds / 3600.0, 2)
    days_elapsed = round(hours_elapsed / 24.0, 2)
    return hours_elapsed, days_elapsed
