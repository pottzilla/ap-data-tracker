---
name: make-scenario
description: Reference spec for the Make.com enrichment scenario built in Phase 4. Phase 4 is complete. One scenario was built -- Scenario 1 (real-time enrichment). Three modules: SharePoint Watch Items -> Anthropic Claude -> SharePoint Update. No HTTP module, no JSON parse modules. Full guide in make.com/PHASE4_GUIDE.md.
tools: Read
---

# Make Scenario — AP Tracker

**Phase 4 is complete as of 2026-04-28.** This skill is retained as a reference spec for the built scenario.

---

## What was built

Scenario 1 -- Real-time Record Enrichment. Three-module scenario running every 15 minutes.

Scenario 2 (weekly summary) was descoped and not built.

---

## Scenario 1 — Real-time Record Enrichment

### Module sequence

```
[Module 1]    SharePoint Online — Watch Items (new items only, every 15 min)
    |
[Module 2]    Anthropic Claude — Create a Message
    |
[Module 3]    SharePoint Online — Update an Item
```

### Module 1 — SharePoint Online: Watch Items

| Field | Value |
|---|---|
| Connection | `APdatademo SP` |
| Site URL | `https://APdatademo.sharepoint.com/sites/aptrackerdem` |
| List | `Approval Tracker` |
| Watch | New items only |
| Limit | `10` |

### Module 2 — Anthropic Claude: Create a Message

| Field | Value |
|---|---|
| Connection | `Anthropic AP Tracker` |
| Model | `claude-opus-4-7` |
| Max Tokens | `500` |
| Role | `User` |

**Prompt:**

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

### Module 3 — SharePoint Online: Update an Item

Item ID: `{{1.id}}` (from the Watch trigger)

| SharePoint field | Expression |
|---|---|
| `ComplianceStatus` | `{{parseJSON(2.content[].text).compliance_status}}` |
| `SupplierRisk` | `{{parseJSON(2.content[].text).supplier_risk}}` |
| `AnomalyReason` | `{{ifempty(parseJSON(2.content[].text).anomaly_reason; "")}}` |

No separate JSON parse module. `parseJSON()` extracts fields inline from `2.content[].text` (the native Claude module output).

### Schedule

Every 15 minutes.

---

## Full documentation

- Step-by-step build guide: `make.com/PHASE4_GUIDE.md`
- Claude module configuration reference: `make.com/claude_api_modules.md`
