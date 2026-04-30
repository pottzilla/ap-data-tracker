<div align="center">

# AP Invoice Tracker

**A solo-engineered analytics pipeline built to close a metrics gap in an AP workflow improvement.**

[![Python](https://img.shields.io/badge/Python-3.12-3776AB?logo=python&logoColor=white)](https://python.org)
[![PowerShell](https://img.shields.io/badge/PowerShell-7.x-5391FE?logo=powershell&logoColor=white)](https://microsoft.com/powershell)
[![Power Automate](https://img.shields.io/badge/Power%20Automate-Live-0066FF?logo=microsoft&logoColor=white)](https://powerautomate.microsoft.com)
[![Graph API](https://img.shields.io/badge/Microsoft%20Graph%20API-v1.0-00BCF2?logo=microsoft&logoColor=white)](https://learn.microsoft.com/graph)
[![SharePoint](https://img.shields.io/badge/SharePoint-Online-0078D4?logo=microsoft&logoColor=white)](https://microsoft.com/sharepoint)
[![Claude API](https://img.shields.io/badge/Claude%20API-claude--opus--4--7-D97757)](https://anthropic.com)
[![Claude Code](https://img.shields.io/badge/Claude%20Code-CLI-000000)](https://claude.ai/code)
[![VS Code](https://img.shields.io/badge/VS%20Code-007ACC?logo=visualstudiocode&logoColor=white)](https://code.visualstudio.com)
[![Antigravity](https://img.shields.io/badge/Google%20Antigravity-IDE-4285F4?logo=google&logoColor=white)](https://antigravity.im)
[![Status](https://img.shields.io/badge/Phase%203-Complete-brightgreen)]()
[![Environment](https://img.shields.io/badge/Environment-M365%20Trial%20Tenant-8A2BE2)]()

</div>

---

## The Story

### The Broken Process

I joined Senversa — a Melbourne-based infrastructure consultancy — as an AP Officer on a contract basis. The invoice approval workflow I inherited was almost entirely email-dependent, and it was slow.

The process worked like this: a supplier invoice would arrive without a purchase order, but with a job number and a contact name. AP would forward it to the listed contact requesting a PO. The contact would reply with one. AP would manually process the invoice in Deltek PiMS and self-approve based on the PO provided.

In practice, it broke constantly.

- If the contact listed on the invoice was incorrect, AP had to locate the right project manager manually — sometimes only discovering the error after waiting days for a reply that never came
- Field-based contacts were rarely near their inboxes; emails sat unread for days and required multiple chase-ups, eventually escalating to a project director
- Some contacts were chronically unresponsive; invoices went overdue, aggravating suppliers and damaging relationships
- Email chains of 5–6 messages per invoice were routine before a single invoice could move
- Emails got buried in busy project managers' inboxes and were simply missed

The process was inefficient by design. It asked the wrong people to do the wrong things at the wrong time.

---

### The Fix

A redesign was implemented to eliminate the email dependency entirely.

Project managers were instructed to issue purchase orders to suppliers upfront, before invoicing began. Suppliers were briefed to include PO references on all invoices and to flag if they had not received a work order. Invoices arriving with a valid PO were processed immediately by AP in Deltek PiMS — no email chain required. AP attached the work order and invoice but did not self-approve. The project manager received a PiMS notification of pending documents and reviewed AP's input against the invoice and work order before approving or rejecting with a reason.

The results were felt immediately:

- Email back-and-forth was almost entirely eliminated
- Processing moved out of Outlook and into the system of record
- Project managers approved their own invoices — increasing accuracy and accountability
- Invoice processing speed increased significantly
- Month-end backlogs reduced
- Supplier statements of accounts became cleaner with fewer outstanding items
- AP could focus on genuinely problematic invoices rather than routine processing

**The process was better. It could not be proved.**

There were no metrics. No data on cycle time reduction, email chain length per invoice, which suppliers were still non-compliant, which approvers were bottlenecks, what the old system had cost in hours, or what dollar value the redesign had saved. The improvement existed only as a feeling shared by the team.

---

### What I Built — Without Being Asked

Nobody asked for a dataset. Nobody asked for a pipeline. I identified the gap independently, designed a schema that could answer the questions the business had never thought to ask, and built the flow in my own time.

A scheduled Power Automate cloud flow, firing every 15 minutes, polling the shared AP mailbox at `supplieraccounts@senversa.com.au`. Subject-line filtered for invoice emails using `contains(toLower(subject), 'invoice')`. Each qualifying email triggered a second call to retrieve full `receivedDateTime` precision from `Get_email_(V2)`. A ticks-based expression calculated hours elapsed since receipt, divided by 24 for days. A message ID deduplication check prevented the 15-minute schedule from writing duplicate records. A structured SharePoint write captured each qualifying, non-duplicate email as a performance record.

The schema was designed for the complete vision — not just what the connector could immediately deliver. Three fields were stubbed and waiting:

| Field | Purpose | Status |
|---|---|---|
| `ThreadMessageCount` | Quantify email chain length per invoice — the core waste metric | Pending Graph API via App Registration |
| `ApproverCategory` | Identify which Outlook category (approver) each email was assigned to | Pending Graph API via App Registration |
| `ApproverName` | Surface which contacts were bottlenecks in the approval chain | Pending Graph API via App Registration |

All three required an Azure App Registration provisioned by IT admin. The request was submitted. It was never completed before my contract ended.

---

### The Choice

The original environment was gone. The App Registration was never provisioned. The three fields were still blank. 

However, I could not leave such a rewarding project incomplete.

Instead, I provisioned a complete Microsoft 365 Business Premium trial tenant from scratch. I scripted the entire infrastructure across eight sequential PowerShell scripts: user accounts, shared mailbox, Azure App Registration with four application permissions, SharePoint site and 17-column list schema, 40 synthetic supplier emails sent via Graph API, full environment verification. I rebuilt the Power Automate flow action-by-action in the browser, extending it with the Graph API HTTP actions that were never provisioned at Senversa. I wrote a Python pipeline on top of it to close every remaining gap. I added an AI enrichment layer using the Anthropic Claude API to classify compliance, supplier risk, and anomalies.

Nobody asked for this. The data supposedly didn't exist. This repository is the answer to both of those claims.

---

## What Was Built

### The Original Flow — Production (Senversa)

A scheduled Power Automate cloud flow polling a shared AP mailbox every 15 minutes. Subject-line filter for invoice emails. Ticks-based cycle time calculation. Message ID deduplication. SharePoint write. Three schema fields pending IT provisioning — not delivered before contract end.

### The Sandbox Build — This Repository

A complete reconstruction and extension in a controlled M365 environment. Every gap from the original is closed. Every external dependency is now owned end-to-end.

| Capability | Original Build | Sandbox Build |
|---|---|---|
| Email monitoring | Standard Office 365 connector | Microsoft Graph API direct |
| Cycle time calculation | Ticks expression (Power Automate) | Python datetime + ticks (both) |
| Duplicate prevention | Message ID check | Message ID check (Graph HTTP, no connector cache) |
| Thread message count | **Pending — IT never provisioned** | Fully populated via Graph API |
| Approver categories | **Shared mailbox limitation** | Fully populated via Graph API |
| Conversation ID tracking | **Not available** | Fully populated via Graph API |
| Supplier email simulation | Manual | Automated — PowerShell + Graph API sendMail |
| AI enrichment layer | Not built | Claude API — compliance, risk, anomaly classification |
| Infrastructure provisioning | GUI / manual | PowerShell scripted — 8 core scripts, 7 helpers |
| Version control | None | Full GitHub repository |

---

## Architecture

```
Supplier Sandbox Accounts (x4)
        │  Graph API sendMail — automated via PowerShell
        ▼
Shared AP Inbox  (sharedinbox@APdatademo.onmicrosoft.com)
        │
        ▼
Power Automate  [recurrence every 15 minutes]
  ├─ Condition 1: contains(toLower(subject), 'invoice') AND NOT RE:/FW:
  ├─ Get email (V2): full receivedDateTime precision
  ├─ Graph HTTP: flag + categories  (connector cannot expose these)
  ├─ Graph HTTP: ThreadMessageCount across all folders
  ├─ Graph HTTP: Dedup check  (direct — bypasses connector cache)
  └─ SharePoint write: 12 fields per qualifying email
        │
        ▼
SharePoint Approval Tracker
        │
        ▼
Python Pipeline  (src/)
  ├─ Graph API email monitor with pagination
  ├─ Thread count retrieval         <- gap closed
  ├─ Category metadata retrieval    <- gap closed
  ├─ ConversationID tracking        <- new capability
  ├─ Cycle time via Python datetime
  ├─ Duplicate check (Message ID)
  ├─ Claude API enrichment per email
  └─ SharePoint write via Graph API
        │
        ▼
Make.com Enrichment Layer  [every 15 minutes]
  ├─ SharePoint: Watch Items (new rows only)
  ├─ Anthropic Claude: Create a Message — classifies subject + sender
  │     returns: has_po, supplier_risk, anomaly_reason, compliance_status
  └─ SharePoint: Update an Item — writes 3 enrichment fields via parseJSON()
        │
        ▼
Enriched Dataset
  ├─ 15-column SharePoint schema including AI-classified fields
  └─ Synthetic 100-record historical dataset (--sandbox mode)
```

---

## Tech Stack

**Languages**
- Python 3.12 — pipeline, enrichment, sandbox dataset generation
- PowerShell 7 — full M365 tenant provisioning, Graph API auth, email simulation

**APIs and Services**
- Microsoft Graph API v1.0 — email, SharePoint, Exchange, user management
- Microsoft 365 Business Premium trial tenant — full sandbox environment
- Power Automate cloud flows — scheduled processing, Graph HTTP actions
- SharePoint Online — structured data store, 17-column AP tracker schema
- Exchange Online — shared mailbox, supplier account provisioning
- Anthropic Claude API (`claude-opus-4-7`) — invoice classification, weekly summaries
- Azure App Registration — OAuth2 client credentials flow, four application permissions

**Development Environment**
- [Google Antigravity](https://antigravity.im) — agent-first AI IDE; the project lives here with the integrated terminal and flow tree
- VS Code with Claude Code CLI — code generation, agent-directed edits, custom rules/skills architecture (see section below)
- Both environments used in parallel — Antigravity for project execution and navigation, Claude Code for constrained agent engineering

**Python Libraries**
- `anthropic` — Claude SDK with adaptive thinking
- `requests` — all Graph API HTTP calls
- `python-dotenv` — environment variable management
- `schedule` — 15-minute pipeline scheduling

---

## Power Automate — Live Evidence

The flow runs against the sandbox shared mailbox. 36 of 40 inbox emails pass Condition 1 — the 4 excluded are RE:/FW: reply chains, correctly filtered out to prevent duplicate records.

### Run History — Emails Entering the If Yes Branch
![Run history showing the Apply to each loop with emails entering the If yes branch](Screenshots/Run%20history%20-%20If%20yes.png)

### Graph HTTP — Thread Message Count
The connector cannot return thread counts. Direct Graph API call across all folders — includes sent replies in Sent Items, not just Inbox.

![HTTP Get thread count action returning @odata.count](Screenshots/HTTP%20-%20Get%20thread%20count.png)

### Graph HTTP — Flag and Category Metadata
The Office 365 connector does not expose `flag` or `categories` for shared mailboxes. Retrieved via `GET /messages/{id}?$select=flag,categories`.

![HTTP Get message details action returning flag and categories](Screenshots/HTTP%20-%20Get%20message%20details.png)

### Graph HTTP — Duplicate Check (No Connector Cache)
The SharePoint connector's `Get items` action returns `x-ms-apihub-cached-response: true` with no override. Replaced entirely with a direct Graph API call.

![HTTP Check duplicate action with encodeUriComponent applied to EmailID](Screenshots/HTTP%20-%20Check%20dupes.png)

### SharePoint Row — All Fields Populated
All 12 fields written on first pass including ThreadMessageCount, ConversationID, ApproverCategory, and ApprovalStatus.

![SharePoint Approval Tracker row showing all fields populated](Screenshots/AP%20tracker%20sharepoint%20list.png)

---

## Key Technical Problems Solved

Eight significant issues were encountered and resolved during the build. The ones below demonstrate the depth of investigation required when building against a real environment rather than a tutorial.

---

**SharePoint connector cache causing false-positive duplicate detection**

The `Get items` SharePoint connector action returned `x-ms-apihub-cached-response: true` regardless of how the request was varied — different filter encoding, redundant OData clauses, varying `Top Count`. There is no per-action setting to disable it at the platform level.

Resolution: replaced the connector action entirely with `HTTP - Check duplicate` — a direct Graph API GET. No connector-level caching applies to HTTP actions.

---

**Email ID URL encoding mismatch breaking dedup on every run**

Exchange message IDs contain Base64 padding (`=`), stored in SharePoint as `%3D`. When the dedup filter URI was built with `concat()`, the HTTP layer decoded `%3D` back to `=` before the OData filter evaluated — so the stored value never matched. Indexing the EmailID column had no effect on this.

Resolution: wrapped the email ID with `encodeUriComponent()` in the URI. This double-encodes `%3D` to `%253D`. The HTTP layer decodes to `%3D`. OData matches the stored value. 36 rows written correctly on first pass; 0 duplicates on subsequent runs.

---

**`Sites.ReadWrite.All` insufficient for list creation on a group-backed site**

Script 06 returned a 403 despite `Sites.ReadWrite.All` with admin consent granted. M365 group-backed team sites treat list creation as a group operation — the app service principal must be a group member, not just a sites permission holder.

Resolution: `create_list_delegated.ps1` — delegated auth as the global admin bypasses the group membership requirement. All subsequent list operations function correctly under application auth once the list exists.

---

**ThreadMessageCount undercounting — sent replies not in Inbox**

The thread count URI was scoped to `mailFolders/inbox/messages`. Replies sent from the shared mailbox land in Sent Items. A 3-message conversation registered as 1.

Resolution: URI changed to `/messages` — all-mailbox scope. True thread count regardless of folder.

---

**Device code auth cannot send mail across user boundaries**

Early scripts used `Connect-MgGraph -UseDeviceCode` (delegated auth as the global admin). `sendMail` on supplier accounts requires either explicit `Send As` grants per mailbox or application-level `Mail.Send` permissions.

Resolution: all cross-user operations switched to client credentials flow — `Invoke-RestMethod` against the token endpoint, `grant_type=client_credentials`. Application `Mail.Send` covers all tenant mailboxes without per-mailbox grants.

---

Full issue log with root cause analysis for all 8 issues: [`.claude/docs/issues_log.md`](.claude/docs/issues_log.md)

---

## AI Agent Engineering

This project was built across two AI-native development environments: **Google Antigravity** (Google's agent-first IDE, where the project lives with its integrated terminal and flow tree) and **Claude Code** (Anthropic's CLI) within **VS Code**. Both were used in parallel throughout the build.

The Claude Code environment was extended with a custom `rules/` and `skills/` architecture engineered to control agent behaviour and reduce per-prompt token consumption. This is not a passive use of AI tooling. The agent's context window was actively managed, its behaviours were constrained by custom rules, and specific capabilities were packaged as on-demand slash commands.

### Custom Rules (`/.claude/rules/`)

Injected automatically into every prompt context:

- **`token_efficiency.md`** — enforces diff-only code output, prohibits filler responses, mandates targeted file reads via grep rather than full file loads, bans multi-paragraph docstrings. Reduced baseline token consumption by approximately 25,000 tokens per prompt compared to default context loading.
- **`constraints.md`** — non-negotiable engineering standards applied across the entire codebase: no hardcoded credentials, exponential backoff on all Graph API calls, Claude prompts stored as module-level constants, safe fallback defaults on all AI parse failures, all logging via Python logging module.
- **`context.md`** — AP domain background and business context, loaded on demand rather than always-on to keep baseline consumption minimal.

Heavy reference documents (`issues_log.md`, `status.md`, `build_guide.md`) are isolated in `docs/` rather than `rules/` so they are never loaded unless explicitly requested. This separation was an active architectural decision.

### Custom Skills (`/.claude/skills/`)

On-demand behaviours triggered as slash commands during development:

| Skill | Trigger | Behaviour |
|---|---|---|
| `/security-review` | Pre-commit | Full security audit of pending branch changes — credential exposure, injection risks, OWASP checks |
| `/organise` | As needed | Restructures and deduplicates project documentation across `docs/` and `rules/` |
| `/compact` | High-throughput sessions | Forces zero-filler mode — no preamble, no summary, code and diffs only |
| `/status` | Any point in build | Parses `status.md` and outputs a 20-second project snapshot with phase completion |
| `/commit` | Pre-commit | Enforces commit message standards and pre-commit validation |
| `/update-status` | Post-milestone | Updates `status.md` after each phase is completed |

The result: a development environment where the AI agent operates within explicit constraints, produces minimal-token outputs, and can be directed at specific tasks without reloading full project context each time.

---

## Project Structure

```
ap-tracker/
├── config/
│   └── settings.py                   # Env var validation — raises on startup if any missing
├── src/
│   ├── auth.py                       # OAuth2 client credentials + token caching
│   ├── graph_client.py               # Graph HTTP helpers — retry, 401 refresh, pagination
│   ├── email_monitor.py              # Graph API email retrieval with pagination + RE:/FW: exclusion
│   ├── cycle_time.py                 # Python datetime cycle time — replaces ticks expression
│   ├── sharepoint.py                 # Duplicate check + SharePoint write via Graph API
│   ├── claude_enrichment.py          # Anthropic SDK — compliance, risk, anomaly classification
│   ├── weekly_summary.py             # Weekly AP performance summary via Claude
│   └── pipeline.py                   # Orchestrator — token, emails, enrichment, SharePoint
├── powershell/
│   ├── core/                         # 01-08: full tenant provisioning sequence
│   ├── helpers/                      # Licence assignment, delegated auth, resend failed
│   └── runners/                      # Composite scripts — licence + emails, fix + verify, etc.
├── sandbox/
│   └── generate_dataset.py           # 100 synthetic records across 4 suppliers + 60-day window
├── power_automate/
│   ├── PHASE3_GUIDE.md               # Full action-by-action build guide
│   └── graph_http_actions.md         # Graph HTTP action specifications
├── make.com/
│   ├── PHASE4_GUIDE.md               # Step-by-step Make.com scenario build guide
│   └── claude_api_modules.md         # Anthropic Claude module configuration reference
├── Screenshots/                      # Live evidence — Power Automate + Make.com (7 screenshots)
├── .claude/
│   ├── rules/                        # Agent constraints — token efficiency, coding standards, context
│   ├── skills/                       # On-demand slash commands — security-review, organise, etc.
│   └── docs/                         # Reference docs loaded on demand — status, issues, specs
├── requirements.txt
└── main.py                           # --run | --schedule | --sandbox | --summary
```

---

## SharePoint Schema

17-column Approval Tracker list capturing the full invoice lifecycle from receipt to approval decision:

| Column | Type | Source | Notes |
|---|---|---|---|
| Title / EmailSubject | Single line | Power Automate | Original schema |
| SenderEmail | Single line | Power Automate | Original schema |
| ReceivedDate / ApprovalDate | Date/time | Power Automate | Original schema |
| DaysToApprove / HoursToApprove | Number | Ticks + Python | Original schema |
| ThreadMessageCount | Number | Graph API | **Gap closed in sandbox** |
| ApproverCategory | Single line | Graph API | **Gap closed in sandbox** |
| EmailID | Single line | Dedup key | Original schema — hidden from list view |
| ConversationID | Single line | Graph API | New in sandbox — hidden from list view |
| ApprovalStatus | Choice | Power Automate | Unopened / flagged / complete |
| ComplianceStatus | Choice | Claude API | compliant / non_compliant / unclear |
| SupplierRisk | Choice | Claude API | low / medium / high |
| AnomalyReason | Single line | Claude API | Populated on ~10% of records; null if none |

---

## Build Status

| Phase | Description | Status |
|---|---|---|
| 1 | M365 tenant provisioning — 42 verification checks, all pass | ✅ Complete |
| 2 | Python pipeline — Graph API, Claude enrichment, sandbox dataset | ✅ Complete |
| 3 | Power Automate cloud flow — 36 rows live, all fields populated | ✅ Complete |
| 4 | Make.com enrichment — 3-module scenario, AI-enriched SharePoint rows live | ✅ Complete |
| 5 | GitHub publish and LinkedIn portfolio | 🔄 In progress |

---

## Setup

> This project runs against a live M365 environment. The PowerShell scripts in `powershell/core/` provision the full tenant from scratch. All credentials are managed via `.env` — never committed.

**Prerequisites**
- Microsoft 365 Business Premium trial tenant
- Azure App Registration with application permissions: `Mail.Read`, `Mail.Send`, `Sites.ReadWrite.All`, `MailboxSettings.Read` — admin consent required
- Anthropic API key
- Python 3.12, PowerShell 7

**Environment Variables** (`.env`)
```
AZURE_CLIENT_ID=
AZURE_TENANT_ID=
AZURE_CLIENT_SECRET=
SHAREPOINT_SITE_ID=
SHAREPOINT_LIST_ID=
AP_MAILBOX_ADDRESS=
ANTHROPIC_API_KEY=
SUPPLIER_1=
SUPPLIER_2=
SUPPLIER_3=
SUPPLIER_4=
```

**Provision from scratch**
```powershell
# Run in order from powershell/core/
01_install_modules.ps1
02_connect_services.ps1
03_create_users.ps1
04_create_shared_mailbox.ps1
05_create_app_registration.ps1
06_create_sharepoint_list.ps1
07_send_test_emails.ps1
08_verify_environment.ps1
```

**Run the pipeline**
```bash
python main.py --run        # Single pipeline execution
python main.py --schedule   # 15-minute recurring execution
python main.py --sandbox    # Generate 100-record synthetic dataset
python main.py --summary    # Generate weekly AP performance summary
```

---

## What This Demonstrates

This is not a tutorial project or a portfolio exercise built to spec. It replicates and extends a Power Automate flow that was live in a production AP environment at a Melbourne infrastructure consultancy, built independently without a brief or a request.

The gap it closes — thread message counts, category metadata, AI classification — was blocked by an IT provisioning dependency that never resolved. When the contract ended, the straightforward path was to claim it had been done.

Building the sandbox from scratch was the answer to that.

**Capabilities demonstrated:**
- **AP domain expertise** — the business problem, the schema, and the metrics are operationally accurate, not invented for demonstration
- **Independent technical initiative** — no brief, no support, no existing environment to work from
- **Microsoft Graph API depth** — direct HTTP calls, OAuth2 client credentials flow, pagination, dedup, SharePoint writes, cross-user mail operations
- **Cross-platform orchestration** — PowerShell, Python, Power Automate, SharePoint, Exchange Online, Azure, all integrated end-to-end
- **AI integration** — Anthropic Claude SDK, classification prompt engineering, safe fallback design, weekly summary generation
- **AI agent engineering** — custom Claude Code rules and skills architecture, token optimisation at the context level, agent behaviour constraints; parallel use of Google Antigravity as the project execution environment
- **Infrastructure as code** — full M365 tenant provisioned via 8 sequential PowerShell scripts, reproducible from zero

---

*Built by George Potter — Accounts Payable Officer, Melbourne.*
*Career pivot target: AI workflow automation consulting.*
