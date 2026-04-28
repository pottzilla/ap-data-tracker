---
name: security-review
description: Scan the ap-tracker project for credentials, secrets, and IDs that must not be committed to GitHub. Checks .gitignore coverage, finds hardcoded secret values in committable files, and redacts any IDs found in documentation files by replacing them with .env references. Run before every GitHub push.
tools: Bash, Grep, Read, Edit
---

# Security Review — AP Tracker

Pre-push credential and ID sweep. Ensures no secrets, tokens, or tenant IDs reach GitHub.

## What This Covers

This project holds three categories of sensitive data:

| Category | Examples | Expected Location |
|---|---|---|
| Secrets | Azure client secret, Anthropic API key, sandbox password | `.env` only |
| Credential IDs | Azure client ID, tenant ID | `.env` only |
| Infrastructure IDs | SharePoint site ID, list ID | `.env` / `sharepoint_ids.txt` |

All three categories must be gitignored or absent from committable files before pushing.

---

## Step 1 — Verify .gitignore coverage

Check that every file containing real secrets is listed in `.gitignore`:

```bash
cat .gitignore
```

The following must all be present:
- `.env`
- `credentials.txt`
- `tenant_id.txt`
- `sharepoint_ids.txt`
- `email_send_log.csv`
- `environment_verification_report.csv`
- `synthetic_dataset.csv`
- `__pycache__/`
- `*.pyc`
- `.venv/`

If any are missing, add them immediately before proceeding.

Then confirm git is honouring the rules:

```bash
git check-ignore -v .env credentials.txt tenant_id.txt sharepoint_ids.txt
```

Each file must return a match line. If any return nothing, git is not ignoring them — investigate before proceeding.

---

## Step 2 — Scan for hardcoded secret VALUES in committable files

Secret values have a distinct shape. Search for them explicitly across all non-ignored source files:

```bash
grep -rn "AZURE_CLIENT_SECRET=.\|ANTHROPIC_API_KEY=.\|sk-ant-api" \
  . \
  --exclude-dir=".venv" --exclude-dir="__pycache__" --exclude-dir=".git" \
  --exclude="credentials.txt" --exclude=".env" --exclude="*.csv" \
  --exclude="tenant_id.txt" --exclude="sharepoint_ids.txt"
```

Also check for passwords:

```bash
grep -rn "PASSWORD=.\|_password\s*=\s*['\"][^$]" \
  . \
  --include="*.py" --include="*.ps1" --include="*.md" \
  --exclude-dir=".venv" --exclude-dir="__pycache__"
```

**If any matches are found outside `.env` and `credentials.txt`:** The file must either be added to `.gitignore` or the value must be removed and replaced with an environment variable reference.

---

## Step 3 — Scan for infrastructure IDs in committable files

GUIDs and tenant-specific IDs embedded in documentation or code will be publicly visible on GitHub. They are not secrets on their own, but they expose the tenant structure and should not be committed.

Known ID patterns for this project:

```bash
grep -rn "5a1827f0\|7dd1e04a\|19450205\|6e367054\|5c8d1e48" \
  . \
  --exclude-dir=".venv" --exclude-dir="__pycache__" --exclude-dir=".git" \
  --exclude="credentials.txt" --exclude=".env" --exclude="*.csv" \
  --exclude="tenant_id.txt" --exclude="sharepoint_ids.txt"
```

Also run a broader GUID pattern sweep to catch any new IDs added since the last review:

```bash
grep -rPn "[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}" \
  . \
  --include="*.md" --include="*.py" \
  --exclude-dir=".venv" --exclude-dir="__pycache__" --exclude-dir=".git"
```

**If matches are found in `.claude/rules/`, `.claude/CLAUDE.md`, or `power_automate/`:**

Redact the raw ID value and replace with a reference to the relevant `.env` variable. Use this substitution pattern:

| Found | Replace with |
|---|---|
| Raw Azure client ID | `see .env (AZURE_CLIENT_ID)` |
| Raw tenant ID | `see .env (AZURE_TENANT_ID)` |
| Raw SharePoint site ID | `see .env (SHAREPOINT_SITE_ID)` |
| Raw SharePoint list ID | `see .env (SHAREPOINT_LIST_ID)` |
| Client secret expiry date | `see credentials.txt` |

Use the Edit tool to make each substitution in-place. Do not rewrite surrounding content.

---

## Step 4 — Check Python and PowerShell source files

Source files should reference credentials only via environment variables or by reading `credentials.txt` at runtime. They must never contain literal secret values.

```bash
grep -rn "client_secret\s*=\s*['\"][^${\"]" \
  ./src ./config ./sandbox \
  --include="*.py"
```

```bash
grep -rn '\$clientSecret\s*=\s*"[^$]' \
  ./powershell \
  --include="*.ps1"
```

Hardcoded tenant email addresses (`@APdatademo.onmicrosoft.com`) in PowerShell scripts are acceptable — they are sandbox-only demo values, not credentials.

---

## Step 5 — Report findings

After all checks, produce a brief summary:

```
SECURITY REVIEW — AP Tracker
==============================

.gitignore coverage:   PASS / FAIL
Secret values scan:    PASS / FAIL — [list any files with issues]
Infrastructure IDs:    PASS / FAIL — [list any files with issues, or CLEAN]
Source file scan:      PASS / FAIL

Actions taken:
- [list any IDs redacted and which files were edited]
- [or: No changes required]

Safe to push: YES / NO
```

If any check fails and cannot be resolved immediately, do not push. Fix the issue first and re-run the skill.
