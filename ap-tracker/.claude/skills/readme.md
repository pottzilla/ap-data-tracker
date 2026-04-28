---
name: readme
description: Generate a professional portfolio README.md for the AP Tracker GitHub repository. Reads all project context files and produces a complete README covering the business problem, technical architecture, what it demonstrates, and how to run it. Run during Phase 5 when preparing for GitHub publish.
tools: Read, Write
---

# README — AP Tracker

Generates `README.md` at the project root from existing project context. Read all source files first, then write the document.

---

## Step 1 — Load context

Read the following files in full before writing anything:

- `.claude/rules/context.md` — business background, original problem, process redesign
- `.claude/rules/portfolio.md` — what the build demonstrates vs the original
- `.claude/rules/sandbox_spec.md` — environment, accounts, architecture, SharePoint schema
- `.claude/rules/module_specs.md` — Python module descriptions
- `.claude/rules/build_guide.md` — PowerShell scripts, Make.com scenarios, build sequence
- `.claude/rules/status.md` — current phase completion state
- `requirements.txt` — Python dependencies

---

## Step 2 — Write README.md

Write to `README.md` at the project root. If a README already exists, read it first and preserve any sections that should not be overwritten.

### Required sections in order

**1. Title and one-line description**

```
# AP Invoice Tracker
Automated AP invoice monitoring pipeline — Power Automate + Python + Microsoft Graph API + Claude AI
```

**2. Background — The Problem**

Summarise from `context.md`:
- The original broken email-dependent process at Senversa
- The process redesign that fixed it operationally
- The gap that remained: no data to prove the improvement

Keep this to 3-4 short paragraphs. This is the hook for anyone reading the portfolio — it has to make the business case clear before the technical detail.

**3. What I Built**

Two parts:
- The original Power Automate flow (built professionally, what it did, what was incomplete)
- The sandbox reconstruction (what this repo is, what it closes)

**4. Architecture**

Reproduce the architecture diagram from `sandbox_spec.md` in plain text/ASCII. Include the full data flow:

```
Supplier Sandbox Accounts (x4)
        ↓ Graph API sendMail
Shared AP Inbox
        ↓
Power Automate (every 15 min)
        ↓
SharePoint Approval Tracker List
        ↓
Python Pipeline (VS Code)
        ↓
Make.com Enrichment Layer
        ↓
Enriched SharePoint Dataset
```

**5. Tech Stack**

| Layer | Technology |
|---|---|
| Infrastructure provisioning | PowerShell + Microsoft Graph API |
| Email monitoring | Microsoft Graph API (application permissions) |
| Data pipeline | Python 3 |
| Workflow automation | Power Automate |
| AI enrichment | Claude API (Anthropic) via Make.com |
| Storage | SharePoint Online |
| Authentication | Azure App Registration — client credentials flow |

**6. SharePoint Schema**

Reproduce the schema table from `sandbox_spec.md`. Include the Source and Status columns — these show which fields were in the original build vs new in the sandbox.

**7. What This Demonstrates**

Reproduce the comparison table from `portfolio.md` (Original Build vs Sandbox Build).

Follow it with the portfolio narrative paragraph from the same file — this is the closing argument and should not be paraphrased.

**8. Project Structure**

Reproduce the folder tree from `project_structure.md`, updated to reflect the current structure (including `powershell/core`, `powershell/helpers`, `powershell/runners`, `tests/`).

**9. Setup**

Brief setup instructions for anyone cloning the repo:

```markdown
## Setup

1. Clone the repo
2. Create `.env` from the structure in `config/settings.py`
3. Populate Azure App Registration credentials from your own M365 tenant
4. Install Python dependencies: `pip install -r requirements.txt`
5. Run PowerShell scripts 01–08 in order to provision the tenant environment
6. Run `python main.py --run` to execute the pipeline
```

Note that this is a sandbox demo — it requires its own M365 trial tenant and Azure App Registration. The credentials in `.env` are not included.

**10. Build Status**

A brief phase completion table derived from `status.md`:

| Phase | Status |
|---|---|
| Phase 1 — Infrastructure | Complete |
| Phase 2 — Python Pipeline | Complete |
| Phase 3 — Power Automate | Complete |
| Phase 4 — Make.com | Complete |
| Phase 5 — Completion | Pending |

**11. Author**

```markdown
## Author

George Potter — Accounts Payable Officer / Workflow Automation
Melbourne, Australia
```

---

## Step 3 — Confirm

After writing, read back the first 30 lines of the generated README to confirm it opens cleanly with the right title and framing. Report the file path and line count.
