"""AP Invoice Tracker entry point.

Four execution modes:

    python main.py --run        Execute the pipeline once immediately.
    python main.py --schedule   Run the pipeline every 15 minutes.
    python main.py --sandbox    Generate and push synthetic historical data.
    python main.py --summary    Print the Claude weekly performance summary.

Exactly one mode flag must be passed per invocation.
"""

from __future__ import annotations

import argparse
import logging
import sys
import time
from typing import Callable

import schedule

from config import settings
from sandbox.generate_dataset import (
    generate_records,
    push_to_sharepoint,
    write_csv,
    DEFAULT_CSV_PATH,
)
from src.auth import get_access_token
from src.pipeline import run_pipeline
from src.weekly_summary import generate_weekly_summary

logger = logging.getLogger(__name__)

SCHEDULE_INTERVAL_MINUTES = 15


def _configure_logging() -> None:
    logging.basicConfig(
        level=logging.INFO,
        format="%(asctime)s %(levelname)s %(name)s: %(message)s",
    )


def cmd_run() -> int:
    logger.info("Starting one-shot pipeline run.")
    stats = run_pipeline()
    logger.info("Run finished: %s", stats.as_dict())
    return 0


def cmd_schedule() -> int:
    logger.info(
        "Starting scheduled pipeline -- every %s minutes. Ctrl+C to stop.",
        SCHEDULE_INTERVAL_MINUTES,
    )

    def _safe_run() -> None:
        try:
            run_pipeline()
        except Exception as exc:  # noqa: BLE001 -- keep the scheduler alive
            logger.exception("Scheduled pipeline run failed: %s", exc)

    _safe_run()  # run immediately on start-up, then on the schedule
    schedule.every(SCHEDULE_INTERVAL_MINUTES).minutes.do(_safe_run)

    try:
        while True:
            schedule.run_pending()
            time.sleep(1)
    except KeyboardInterrupt:
        logger.info("Scheduler interrupted by user -- exiting cleanly.")
        return 0


def cmd_sandbox() -> int:
    logger.info("Generating synthetic dataset (100 records across 60 days).")
    records = generate_records()
    write_csv(records, DEFAULT_CSV_PATH)
    written, errors = push_to_sharepoint(records)
    logger.info(
        "Sandbox complete: %s pushed, %s errors, csv=%s",
        written,
        errors,
        DEFAULT_CSV_PATH,
    )
    return 0 if errors == 0 else 1


def cmd_summary() -> int:
    logger.info("Generating weekly AP performance summary.")
    token = get_access_token()
    summary = generate_weekly_summary(
        token, settings.SHAREPOINT_SITE_ID, settings.SHAREPOINT_LIST_ID
    )
    print("\n=== Weekly AP Performance Summary ===\n")
    print(summary)
    print()
    return 0


COMMANDS: dict[str, Callable[[], int]] = {
    "run": cmd_run,
    "schedule": cmd_schedule,
    "sandbox": cmd_sandbox,
    "summary": cmd_summary,
}


def _parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    group = parser.add_mutually_exclusive_group(required=True)
    group.add_argument("--run", action="store_true", help="Execute the pipeline once")
    group.add_argument(
        "--schedule",
        action="store_true",
        help=f"Run the pipeline every {SCHEDULE_INTERVAL_MINUTES} minutes",
    )
    group.add_argument(
        "--sandbox",
        action="store_true",
        help="Generate and push synthetic historical data",
    )
    group.add_argument(
        "--summary",
        action="store_true",
        help="Print the Claude weekly performance summary",
    )
    return parser.parse_args()


def main() -> int:
    _configure_logging()
    args = _parse_args()

    for flag, command in COMMANDS.items():
        if getattr(args, flag):
            return command()

    logger.error("No mode flag selected; this should not happen.")
    return 2


if __name__ == "__main__":
    sys.exit(main())
