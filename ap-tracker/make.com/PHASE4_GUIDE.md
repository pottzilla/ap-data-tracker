# Phase 4 -- Make.com Enrichment Layer

One scenario that runs after the Power Automate pipeline (Phase 3) has written rows to the SharePoint Approval Tracker list. Phase 3 leaves three columns unpopulated -- `ComplianceStatus`, `SupplierRisk`, `AnomalyReason` -- because they require AI inference, not flow logic. This scenario closes that gap using Make.com's native Anthropic Claude module.

Sign in at https://www.make.com. Use the account connected to the same Anthropic API key referenced in `src/claude_enrichment.py`.

**Phase 4 is complete as of 2026-04-28.**

---

## Note on EmailID and ConversationID columns

`EmailID` and `ConversationID` have been removed from the default SharePoint list view to keep the list display clean. They have not been deleted from the list schema -- Power Automate continues to write both fields on every Create item action, and all pipeline references (`src/sharepoint.py`, `src/pipeline.py`, the Power Automate flow) remain valid and unchanged. They are simply hidden from the UI view.

---

## What the scenario does

| Scenario | Trigger | What it does |
| --- | --- | --- |
| Scenario 1 -- Real-time Enrichment | SharePoint: Watch Items (every 15 min) | For each new row, calls Claude API to classify the invoice and writes the enriched fields back to the same row |

---

## Reference IDs

| Thing | Value |
| --- | --- |
| Make.com workspace | your personal/team workspace |
| SharePoint site URL | `https://APdatademo.sharepoint.com/sites/aptrackerdem` |
| SharePoint list name | `Approval Tracker` |
| SharePoint list ID | see `.env` (SHAREPOINT_LIST_ID) |
| Anthropic API key | see `.env` (ANTHROPIC_API_KEY) |
| Claude model | `claude-opus-4-7` |

---

## SharePoint columns Make.com writes

These three columns are left blank by Power Automate. Scenario 1 populates them.

| Column | Type | Source | Notes |
| --- | --- | --- | --- |
| ComplianceStatus | Choice | Claude API | `compliant` / `non_compliant` / `unclear` |
| SupplierRisk | Choice | Claude API | `low` / `medium` / `high` |
| AnomalyReason | Single line | Claude API | Describes the anomaly if present; null if none |

The `ComplianceStatus` and `SupplierRisk` columns are Choice type in SharePoint. The Claude API returns lowercase strings (`compliant`, `low`, etc.) -- confirm these match your choice option values exactly or updates will fail silently.

---

## Connections required before building

Two connections are required before adding any module.

**SharePoint connection:**
1. Left nav -- Connections -- Create a connection
2. Search `SharePoint` -- select **Microsoft SharePoint**
3. Sign in as `gp@APdatademo.onmicrosoft.com`
4. Grant the requested permissions
5. Name it `APdatademo SP` -- this name is used throughout this guide

**Anthropic Claude connection:**
1. Left nav -- Connections -- Create a connection
2. Search `Anthropic` -- select **Anthropic Claude**
3. Paste the `ANTHROPIC_API_KEY` value from `.env` into the API key field
4. Name it `Anthropic AP Tracker`

See `claude_api_modules.md` for full Claude module configuration reference.

---

## Scenario 1 -- Real-time Record Enrichment

### Scenario 1 structure

```
Module 1 -- SharePoint Online: Watch Items (every 15 min)
  |
Module 2 -- Anthropic Claude: Create a Message
  |
Module 3 -- SharePoint Online: Update an Item
```

### Step 1 -- Create Scenario 1

1. Make.com dashboard -- **+ Create a new scenario**
2. Leave the trigger blank for now -- click the empty trigger circle
3. Search `SharePoint` -- select **Microsoft SharePoint**
4. Select the **Watch Items** module
5. Name the scenario `AP Invoice Enrichment -- Real-time`

### Step 2 -- Configure the trigger: SharePoint Watch Items

| Field | Value |
| --- | --- |
| Connection | `APdatademo SP` |
| Site URL | `https://APdatademo.sharepoint.com/sites/aptrackerdem` |
| List | `Approval Tracker` |
| Watch items | `New Items Only` |
| Limit | `10` |

**Note on polling vs webhook:** Make.com's SharePoint Watch Items module polls on the scenario's schedule -- it does not receive a real-time push. Set the scenario schedule to **every 15 minutes** to match the Power Automate pipeline cadence so enrichment arrives within one polling cycle of the row being written.

**Note on `New Items Only`:** Set this to `New Items Only` (not `All Items` / `Updated Items`). `Updated Items` will re-trigger enrichment every time Power Automate's Update item action refreshes a row's `ThreadMessageCount`, `ApproverCategory`, or `ApprovalStatus` -- causing redundant Claude API calls on every 15-minute run for every existing row.

**Important:** On first run, Make.com will ask which item to start from. Choose the most recent item or `From now on` to avoid batch-enriching all 36 existing rows at once and exhausting API quota.

Click **OK**.

### Step 3 -- Add Anthropic Claude module: Create a Message

Click **+** after the trigger -- search **Anthropic** -- select **Anthropic Claude: Create a Message**.

| Field | Value |
| --- | --- |
| Connection | `Anthropic AP Tracker` |
| Model | `claude-opus-4-7` |
| Max Tokens | `500` |
| Role | `User` |
| Message Content | see prompt below |

**Message Content** -- click the content field and use the variable picker to build the prompt. Insert `EmailSubject` and `SenderEmail` from Module 1 at the indicated positions:

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

**Note on body_preview:** The Python pipeline (`src/claude_enrichment.py`) passes `body_preview` to Claude because it retrieves it directly from the Graph API. At the SharePoint layer, `bodyPreview` is not stored as a column -- only the fields written by Power Automate are available. The classification is effective on subject and sender alone for the compliance, risk, and anomaly fields.

Click **OK**.

### Step 4 -- Add SharePoint module: Update an Item

Click **+** -- search **SharePoint** -- select **SharePoint Online: Update an Item**.

| Field | Value |
| --- | --- |
| Connection | `APdatademo SP` |
| Site URL | `https://APdatademo.sharepoint.com/sites/aptrackerdem` |
| List | `Approval Tracker` |
| Item ID | Map `ID` from Module 1 (the SharePoint trigger) |

Map the three enrichment columns using `parseJSON()` inline on the Claude module output. In each field, click the variable picker, select the text output from Module 2, then wrap it with the `parseJSON` function and the relevant key:

| SharePoint column | Expression |
| --- | --- |
| ComplianceStatus | `{{parseJSON(2.content[].text).compliance_status}}` |
| SupplierRisk | `{{parseJSON(2.content[].text).supplier_risk}}` |
| AnomalyReason | `{{parseJSON(2.content[].text).anomaly_reason}}` |

The native Claude module exposes the response text directly as `2.content[].text`. The `parseJSON()` function extracts individual field values inline -- no separate JSON parse module required.

**Note on null values:** Use `ifempty(parseJSON(2.content[].text).anomaly_reason; "")` for the AnomalyReason field to convert JSON null to an empty string rather than the literal string `"null"`.

Click **OK**.

### Step 5 -- Set scenario schedule

Click the **clock icon** on the scenario -- set to **Every 15 minutes**.

### Step 6 -- Test Scenario 1

1. Turn on the Power Automate flow, clear the SharePoint list, and run the flow manually -- confirm 36 rows are written.
2. Return to Make.com. Click **Run once** on Scenario 1.
3. The scenario should pick up the most recently created row, call the Claude module, and write the three enrichment fields back to that row.
4. Open the SharePoint list -- click the row -- confirm `ComplianceStatus`, `SupplierRisk`, and `AnomalyReason` are populated.
5. If the scenario processes 0 items, click the trigger module -- check the `Choose where to start` position. Adjust to `All` for testing, then reset to `From now on` for live operation.
6. Enable the scenario for scheduled runs.

---

## Issues encountered

No issues to log -- Scenario 1 ran successfully on first test.

---

## Common errors

| Error | Likely cause | Fix |
| --- | --- | --- |
| Anthropic Claude module returns connection error | API key in the connection is wrong or has zero credit balance | Edit the `Anthropic AP Tracker` connection -- re-enter the key; confirm credits at console.anthropic.com |
| Claude module returns text but `parseJSON()` fails in SharePoint update | Claude prefaced the JSON with a sentence, or used markdown fences | Add `Return JSON only. No preamble. No markdown.` to the prompt (already included); check the Module 2 output text in run history to confirm raw JSON |
| SharePoint update fails with `400` on ComplianceStatus / SupplierRisk | Choice column values don't match exactly -- case sensitive | Open the Approval Tracker list -- column settings -- confirm choices are exactly `compliant`, `non_compliant`, `unclear` and `low`, `medium`, `high` (lowercase, matching Claude output) |
| AnomalyReason column contains string `"null"` | `parseJSON()` returns JSON null which Make.com passes as literal `"null"` to SharePoint | Use `ifempty(parseJSON(2.content[].text).anomaly_reason; "")` in the AnomalyReason field mapping |
| Scenario 1 re-enriches already-enriched rows | Trigger set to `Updated Items` instead of `New Items Only` | Change Watch Items trigger to `New Items Only` |
| Scenario 1 picks up 0 items on first run | Trigger `Choose where to start` position is set past all existing items | Edit the trigger -- reset the position to `All` for one test run, then set back to `From now on` |

---

## Phase 4 checklist

- [x] Connections created (SharePoint -- `APdatademo SP`, Anthropic -- `Anthropic AP Tracker`)
- [x] Scenario 1 created -- `AP Invoice Enrichment -- Real-time`
- [x] Scenario 1 trigger: SharePoint Online Watch Items -- New Items Only, every 15 min
- [x] Scenario 1 Module 2: Anthropic Claude -- Create a Message configured with model, max tokens, and prompt
- [x] Scenario 1 Module 3: SharePoint Online Update an Item -- ComplianceStatus, SupplierRisk, AnomalyReason mapped via parseJSON()
- [x] Scenario 1 test run: one row enriched with ComplianceStatus, SupplierRisk, AnomalyReason populated
- [x] Scenario 1 enabled on 15-minute schedule
- [x] Portfolio screenshots captured (see below)

**Phase 4 complete -- proceed to Phase 5 (synthetic dataset, live pipeline run, GitHub publish).**

---

## Portfolio screenshots -- what to capture and how

Four screenshots cover Phase 4 fully for the portfolio.

---

### Screenshot 1 -- Scenario canvas (all three modules visible)

**What it shows:** The full Scenario 1 flow in a single frame -- SharePoint Watch Items connected to Anthropic Claude connected to SharePoint Update. Three modules, two connections. This is the primary evidence that the Make.com enrichment layer exists and is wired correctly.

**How to get it:**
1. Open the scenario in Make.com
2. Click the **zoom out** control (bottom-left, or use scroll wheel) until all three modules are visible in one frame with the connecting lines between them
3. Do not open any module panel -- the canvas should be the full view
4. Screenshot the full browser window

---

### Screenshot 2 -- Successful run history (all modules green)

**What it shows:** Evidence that the scenario executed end-to-end without errors -- every module shows a green tick and a bundle count.

**How to get it:**
1. After a successful run, click the **clock / history icon** in the bottom toolbar of the scenario designer (or go to the scenario detail page and click **History**)
2. Click the most recent successful run
3. The run detail opens showing each module with a green indicator and the number of bundles processed
4. Screenshot this view -- ideally showing Module 2 (Anthropic Claude) with `1 bundle` and Module 3 (SharePoint) with `1 bundle`

---

### Screenshot 3 -- Anthropic Claude module: configuration and output

**What it shows:** The Claude module configuration (model, max tokens, prompt with mapped EmailSubject and SenderEmail) and/or the output from a live run showing the classification JSON returned by the model. This is the technical evidence of AI integration.

**How to get it (configuration):**
1. Click **Module 2 (Anthropic Claude)** on the scenario canvas
2. The module configuration panel opens showing the Connection, Model, Max Tokens, and Message Content fields
3. Screenshot the panel showing the model set to `claude-opus-4-7` and the prompt with the SharePoint variables mapped

**How to get it (live output):**
1. Open run history -- click the most recent run -- click Module 2
2. The output panel shows the Claude response including `content[].text` with the classification JSON
3. Screenshot the output showing the JSON string with `compliance_status`, `supplier_risk`, `anomaly_reason`, `has_po`

---

### Screenshot 4 -- SharePoint row with enriched fields populated

**What it shows:** A live SharePoint row where `ComplianceStatus`, `SupplierRisk`, and `AnomalyReason` have been written by Make.com -- the end-to-end evidence that the enrichment pipeline reached the dataset.

**How to get it:**
1. Open the Approval Tracker list at `https://APdatademo.sharepoint.com/sites/aptrackerdem`
2. Click any row that was processed after Make.com ran
3. The item detail panel opens on the right showing all columns
4. Scroll to show `ComplianceStatus`, `SupplierRisk`, and `AnomalyReason` with values populated
5. Screenshot the item detail panel -- or edit the list view to show these three columns alongside `EmailSubject` and `SenderEmail` so the evidence is readable in a single grid view
