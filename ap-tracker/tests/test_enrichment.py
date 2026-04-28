"""One-off smoke test for src/claude_enrichment.classify_invoice."""

from __future__ import annotations

import json
import logging

from src.claude_enrichment import classify_invoice, SAFE_DEFAULT

logging.basicConfig(level=logging.INFO, format="%(levelname)s %(name)s: %(message)s")


SAMPLES = [
    {
        "label": "standard PO invoice",
        "subject": "Invoice #INV-2456 - PO 78910 - Acme Consulting March services",
        "sender": "accounts@acme-consulting.com.au",
        "body_preview": (
            "Hi George, please find attached invoice INV-2456 for work delivered "
            "against PO 78910 for March. Net 30. Approved by Sarah Chen. "
            "Total $4,250 excl GST."
        ),
    },
    {
        "label": "no-PO anomaly",
        "subject": "URGENT payment needed today - wire transfer",
        "sender": "billing@unknown-vendor-xyz.net",
        "body_preview": (
            "Send $18,500 immediately to updated bank details below. "
            "No PO. Do not delay. Details attached."
        ),
    },
]


def main() -> None:
    print(f"Safe default shape: {sorted(SAFE_DEFAULT.keys())}\n")
    for sample in SAMPLES:
        print(f"--- {sample['label']} ---")
        result = classify_invoice(
            subject=sample["subject"],
            sender=sample["sender"],
            body_preview=sample["body_preview"],
        )
        print(json.dumps(result, indent=2))
        assert set(result.keys()) == set(SAFE_DEFAULT.keys()), "schema drift"
        print()


if __name__ == "__main__":
    main()
