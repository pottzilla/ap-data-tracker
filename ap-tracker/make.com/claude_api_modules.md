# Claude Module Specs -- Make.com

Configuration reference for the Anthropic Claude module used in Phase 4 Scenario 1. Uses Make.com's native **Anthropic Claude: Create a Message** module -- no HTTP module or JSON parse modules required.

---

## Prerequisites

- `ANTHROPIC_API_KEY` from `.env` -- must have a positive credit balance at console.anthropic.com
- Connection set up in Make.com as `Anthropic AP Tracker` (Left nav -- Connections -- Anthropic Claude -- paste API key)
- Model: `claude-opus-4-7`

---

## Module 2 -- Anthropic Claude: Create a Message

Used in Scenario 1, Step 3. Fires once per new SharePoint row. Classifies the invoice email and returns a JSON object with four fields.

### Module configuration

| Field | Value |
| --- | --- |
| Connection | `Anthropic AP Tracker` |
| Model | `claude-opus-4-7` |
| Max Tokens | `500` |
| Role | `User` |
| Message Content | see prompt below |

### Prompt

```
You are an accounts payable analyst. Analyse this invoice email and return a JSON object with exactly these fields:
- has_po: boolean -- true if a PO or work order reference is present
- supplier_risk: "low" / "medium" / "high" -- based on subject and sender
- anomaly_reason: string or null -- describe anything unusual; null if nothing unusual
- compliance_status: "compliant" / "non_compliant" / "unclear"

Email subject: [EmailSubject from Module 1]
Sender: [SenderEmail from Module 1]

Return JSON only. No preamble. No markdown formatting. No explanation.
```

`[EmailSubject from Module 1]` and `[SenderEmail from Module 1]` are Make.com dynamic content tokens inserted via the variable picker -- they resolve to the SharePoint trigger's `EmailSubject` and `SenderEmail` field values at runtime.

### Expected module output

The native Claude module exposes the response text directly. The key output variable is:

| Variable | Path | Contains |
| --- | --- | --- |
| Response text | `2.content[].text` | The classification JSON as a string |

Example value of `2.content[].text`:

```json
{"has_po": true, "supplier_risk": "low", "anomaly_reason": null, "compliance_status": "compliant"}
```

---

## Field mapping in Module 3 (SharePoint Update)

No separate JSON parse module is needed. The `parseJSON()` function extracts classification fields inline within the SharePoint Update module's field mapping.

| SharePoint column | Expression in field mapping |
| --- | --- |
| ComplianceStatus | `{{parseJSON(2.content[].text).compliance_status}}` |
| SupplierRisk | `{{parseJSON(2.content[].text).supplier_risk}}` |
| AnomalyReason | `{{ifempty(parseJSON(2.content[].text).anomaly_reason; "")}}` |

`has_po` is returned by Claude and available via `parseJSON(2.content[].text).has_po` but is not written to SharePoint -- it is used internally by the compliance_status classification.

---

## Prompt equivalence -- Python vs Make.com

The Python module (`src/claude_enrichment.py`) and the Make.com Claude module use the same underlying classification prompt. The Python version stores it as a module-level constant (`CLASSIFICATION_PROMPT`) and interpolates `{subject}`, `{sender}`, `{body_preview}` at call time. The Make.com version maps `EmailSubject` and `SenderEmail` from the SharePoint trigger.

The key difference is `body_preview` -- the Python pipeline retrieves this directly from Graph API. At the SharePoint layer, `bodyPreview` is not stored as a column. The Make.com module classifies on subject and sender only, which is sufficient for the four output fields.

---

## Token cost estimates

| Call | Approximate input tokens | Approximate output tokens |
| --- | --- | --- |
| Per record | ~105 | ~32 |

For the sandbox with a static 36-row dataset, cost is negligible. Monitor via console.anthropic.com usage dashboard.
