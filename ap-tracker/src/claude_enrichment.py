"""Claude-powered enrichment of invoice email metadata.

Uses the Anthropic Python SDK with adaptive thinking (Claude Opus 4.7) to
classify invoice emails and flag anomalies. The classifier returns a fixed
JSON shape; malformed or failed responses fall back to a safe default so
a single enrichment hiccup never stalls the pipeline.
"""

from __future__ import annotations

import json
import logging
from typing import Any, Optional

import anthropic

from config import settings

logger = logging.getLogger(__name__)

MODEL = "claude-opus-4-7"
MAX_TOKENS = 500

CLASSIFICATION_PROMPT = """\
You are an accounts payable analyst. Analyse this invoice email and return
a JSON object with exactly these fields:
- has_po: boolean -- true if a PO or work order reference is present
- supplier_risk: "low" / "medium" / "high" -- based on subject and sender
- anomaly_reason: string or null -- describe anything unusual; null if nothing unusual
- compliance_status: "compliant" / "non_compliant" / "unclear"

Email subject: {subject}
Sender: {sender}
Body preview: {body_preview}

Return JSON only. No preamble. No markdown formatting. No explanation.
"""

SAFE_DEFAULT: dict[str, Any] = {
    "has_po": False,
    "supplier_risk": None,
    "anomaly_reason": None,
    "compliance_status": "unclear",
}

_ALLOWED_RISK = {"low", "medium", "high"}
_ALLOWED_COMPLIANCE = {"compliant", "non_compliant", "unclear"}

_client: Optional[anthropic.Anthropic] = None


def _get_client() -> anthropic.Anthropic:
    global _client
    if _client is None:
        _client = anthropic.Anthropic(api_key=settings.ANTHROPIC_API_KEY)
    return _client


def classify_invoice(
    subject: str,
    sender: str,
    body_preview: str,
) -> dict[str, Any]:
    """Classify an invoice email via Claude Opus 4.7 with adaptive thinking.

    Returns the parsed JSON on success, or a safe default dict with all
    fields set to null/false on any failure (network, parse, schema).
    """
    prompt = CLASSIFICATION_PROMPT.format(
        subject=subject or "",
        sender=sender or "",
        body_preview=body_preview or "",
    )

    try:
        response = _get_client().messages.create(
            model=MODEL,
            max_tokens=MAX_TOKENS,
            thinking={"type": "adaptive"},
            messages=[{"role": "user", "content": prompt}],
        )
    except anthropic.APIError as exc:
        logger.error("Claude API call failed: %s", exc)
        return dict(SAFE_DEFAULT)
    except Exception as exc:  # noqa: BLE001 -- never let enrichment stall the pipeline
        logger.exception("Unexpected error calling Claude: %s", exc)
        return dict(SAFE_DEFAULT)

    text = _extract_text(response)
    if not text:
        logger.warning("Claude response contained no text block; using default")
        return dict(SAFE_DEFAULT)

    try:
        parsed = json.loads(text)
    except json.JSONDecodeError as exc:
        logger.warning("Failed to parse Claude JSON (%s); raw=%r", exc, text[:200])
        return dict(SAFE_DEFAULT)

    if not isinstance(parsed, dict):
        logger.warning("Claude returned non-object JSON; using default")
        return dict(SAFE_DEFAULT)

    return _normalise(parsed)


def _extract_text(response: Any) -> str:
    """Concatenate text blocks from the response, skipping thinking blocks."""
    parts: list[str] = []
    for block in getattr(response, "content", []):
        if getattr(block, "type", None) == "text":
            parts.append(getattr(block, "text", ""))
    return "".join(parts).strip()


def _normalise(parsed: dict[str, Any]) -> dict[str, Any]:
    """Merge parsed fields over the safe default, coercing known enums."""
    merged = dict(SAFE_DEFAULT)

    for key in SAFE_DEFAULT:
        if key in parsed:
            merged[key] = parsed[key]

    risk = merged.get("supplier_risk")
    if isinstance(risk, str) and risk.lower() in _ALLOWED_RISK:
        merged["supplier_risk"] = risk.lower()
    elif risk is not None:
        merged["supplier_risk"] = None

    compliance = merged.get("compliance_status")
    if isinstance(compliance, str) and compliance.lower() in _ALLOWED_COMPLIANCE:
        merged["compliance_status"] = compliance.lower()
    else:
        merged["compliance_status"] = "unclear"

    merged["has_po"] = bool(merged.get("has_po"))

    return merged
