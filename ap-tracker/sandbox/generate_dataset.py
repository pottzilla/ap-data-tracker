"""Synthetic dataset generator for the AP Invoice Tracker portfolio demo.

Produces 100 SharePoint records across 60 days of simulated history so the
Power BI dashboards and the weekly summary have realistic data to chew on
before real invoices start flowing. Records can be emitted to CSV and/or
written directly to the SharePoint Approval Tracker list.
"""

from __future__ import annotations

import argparse
import csv
import logging
import random
import uuid
from datetime import datetime, timedelta, timezone
from pathlib import Path
from typing import Any

from config import settings
from src.auth import get_access_token
from src.sharepoint import SCHEMA_COLUMNS, write_record

logger = logging.getLogger(__name__)


SUPPLIERS: list[dict[str, Any]] = [
    {
        "name": "Apex Site Works Pty Ltd",
        "email": "apexsiteworks@APdatademo.onmicrosoft.com",
        "compliance_rate": 0.80,
        "risk": "low",
    },
    {
        "name": "Clearwater Environmental Services",
        "email": "clearwaterenv@APdatademo.onmicrosoft.com",
        "compliance_rate": 0.60,
        "risk": "medium",
    },
    {
        "name": "Bridgepoint Civil Contractors",
        "email": "bridgepointcivil@APdatademo.onmicrosoft.com",
        "compliance_rate": 0.90,
        "risk": "low",
    },
    {
        "name": "Halcyon Electrical Group",
        "email": "halcyonelectrical@APdatademo.onmicrosoft.com",
        "compliance_rate": 0.40,
        "risk": "high",
    },
]

APPROVAL_STATUS_WEIGHTS = [
    ("Approved", 0.60),
    ("Pending", 0.30),
    ("Rejected", 0.10),
]

ANOMALY_REASONS = [
    "Duplicate invoice number already seen this quarter",
    "Amount significantly above historical average for this supplier",
    "Bank details differ from the supplier's last three invoices",
    "Invoice received outside normal business hours",
    "Missing or malformed PO reference",
    "Payment terms shortened from Net 30 to Net 7 without approval",
]

SUBJECT_TEMPLATES = {
    "compliant": [
        "Invoice #{inv} - PO {po} - {supplier} {month} services",
        "{supplier} invoice #{inv} - work order {po}",
        "Invoice INV-{inv} against PO {po} ({supplier})",
    ],
    "non_compliant": [
        "Invoice {inv} - URGENT - {supplier}",
        "{supplier} - payment required - ref {inv}",
        "Outstanding invoice {inv} from {supplier}",
    ],
    "unclear": [
        "Invoice {inv} - {supplier}",
        "{supplier} monthly invoice {inv}",
    ],
}

DEFAULT_COUNT = 100
DEFAULT_HISTORY_DAYS = 60
DEFAULT_CSV_PATH = Path(__file__).resolve().parent / "synthetic_dataset.csv"


def generate_records(
    count: int = DEFAULT_COUNT,
    history_days: int = DEFAULT_HISTORY_DAYS,
    seed: int | None = None,
) -> list[dict[str, Any]]:
    """Return ``count`` synthetic SharePoint records across ``history_days``."""
    rng = random.Random(seed)
    now = datetime.now(timezone.utc)
    records: list[dict[str, Any]] = []

    for _ in range(count):
        supplier = rng.choice(SUPPLIERS)
        compliant = rng.random() < supplier["compliance_rate"]
        compliance_status = "compliant" if compliant else "non_compliant"

        received = _random_received(now, history_days, rng)
        hours_to_approve = _realistic_cycle_hours(rng)
        approved_at = received + timedelta(hours=hours_to_approve)

        approval_status = _weighted_choice(APPROVAL_STATUS_WEIGHTS, rng)
        anomaly_reason = rng.choice(ANOMALY_REASONS) if rng.random() < 0.10 else None

        invoice_no = rng.randint(1000, 99999)
        po_no = rng.randint(10000, 99999)
        subject = _build_subject(
            supplier["name"], invoice_no, po_no, compliance_status, received, rng
        )

        record = {
            "Title": subject,
            "EmailSubject": subject,
            "SenderEmail": supplier["email"],
            "ReceivedDate": _iso(received),
            "ApprovalDate": _iso(approved_at),
            "DaysToApprove": round(hours_to_approve / 24.0, 2),
            "HoursToApprove": round(hours_to_approve, 2),
            "ThreadMessageCount": rng.randint(1, 6),
            "ApproverCategory": "",
            "EmailID": f"synthetic-{uuid.uuid4().hex}",
            "ConversationID": f"conv-{uuid.uuid4().hex[:16]}",
            "ApprovalStatus": approval_status,
            "ComplianceStatus": compliance_status,
            "SupplierRisk": supplier["risk"],
            "AnomalyReason": anomaly_reason,
        }
        records.append(record)

    records.sort(key=lambda r: r["ReceivedDate"])
    return records


def write_csv(records: list[dict[str, Any]], path: Path) -> None:
    """Write records to CSV using SCHEMA_COLUMNS as the header order."""
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("w", newline="", encoding="utf-8") as fh:
        writer = csv.DictWriter(fh, fieldnames=list(SCHEMA_COLUMNS))
        writer.writeheader()
        for record in records:
            writer.writerow({k: record.get(k, "") for k in SCHEMA_COLUMNS})
    logger.info("Wrote %s records to %s", len(records), path)


def push_to_sharepoint(records: list[dict[str, Any]]) -> tuple[int, int]:
    """POST every record to SharePoint. Returns ``(written, errors)``."""
    token = get_access_token()
    written = 0
    errors = 0
    for record in records:
        try:
            write_record(
                token,
                settings.SHAREPOINT_SITE_ID,
                settings.SHAREPOINT_LIST_ID,
                record,
            )
            written += 1
        except Exception as exc:  # noqa: BLE001 -- keep pushing the rest on failure
            errors += 1
            logger.exception(
                "Failed to write synthetic record EmailID=%s: %s",
                record.get("EmailID"),
                exc,
            )
    logger.info(
        "SharePoint push complete: %s written, %s errors.", written, errors
    )
    return written, errors


def _random_received(
    now: datetime, history_days: int, rng: random.Random
) -> datetime:
    day_offset = rng.randint(0, history_days - 1)
    hour = rng.randint(7, 18)
    minute = rng.randint(0, 59)
    base = now - timedelta(days=day_offset)
    return base.replace(hour=hour, minute=minute, second=0, microsecond=0)


def _realistic_cycle_hours(rng: random.Random) -> float:
    """Bias towards sub-48h with a long tail up to 96h -- matches real AP flow."""
    roll = rng.random()
    if roll < 0.55:
        return rng.uniform(0.5, 24.0)
    if roll < 0.85:
        return rng.uniform(24.0, 48.0)
    return rng.uniform(48.0, 96.0)


def _weighted_choice(
    weighted: list[tuple[str, float]], rng: random.Random
) -> str:
    roll = rng.random()
    cumulative = 0.0
    for value, weight in weighted:
        cumulative += weight
        if roll <= cumulative:
            return value
    return weighted[-1][0]


def _build_subject(
    supplier: str,
    invoice_no: int,
    po_no: int,
    compliance: str,
    received: datetime,
    rng: random.Random,
) -> str:
    template = rng.choice(SUBJECT_TEMPLATES.get(compliance, SUBJECT_TEMPLATES["unclear"]))
    return template.format(
        inv=invoice_no,
        po=po_no,
        supplier=supplier,
        month=received.strftime("%B"),
    )


def _iso(dt: datetime) -> str:
    return dt.astimezone(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--count", type=int, default=DEFAULT_COUNT, help="Number of records to generate"
    )
    parser.add_argument(
        "--history-days",
        type=int,
        default=DEFAULT_HISTORY_DAYS,
        help="Spread of received dates across the past N days",
    )
    parser.add_argument(
        "--csv",
        type=Path,
        default=DEFAULT_CSV_PATH,
        help="CSV output path (pass empty string to skip)",
    )
    parser.add_argument(
        "--push",
        action="store_true",
        help="Also write the records to SharePoint",
    )
    parser.add_argument("--seed", type=int, default=None, help="Deterministic seed")
    args = parser.parse_args()

    logging.basicConfig(
        level=logging.INFO, format="%(asctime)s %(levelname)s %(name)s: %(message)s"
    )

    records = generate_records(
        count=args.count, history_days=args.history_days, seed=args.seed
    )
    logger.info("Generated %s synthetic records.", len(records))

    if args.csv and str(args.csv):
        write_csv(records, args.csv)

    if args.push:
        push_to_sharepoint(records)


if __name__ == "__main__":
    main()
