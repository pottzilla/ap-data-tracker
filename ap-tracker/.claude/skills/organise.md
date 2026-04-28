---
name: organise
description: Audit and reorganise the ap-tracker project tree for clarity. Hides generated/reference files from the VS Code explorer, moves loose files into logical subfolders, and updates all internal path references after any moves. Run when the file tree feels cluttered or after a phase of the build adds new scripts or files.
tools: Bash, Grep, Read, Edit, Write
---

# Organise — AP Tracker

Cleans up the VS Code explorer and project structure without deleting anything. Three actions in sequence: hide noise, restructure flat folders, fix broken references.

---

## Step 1 — Audit the project tree

Get a full picture of what exists before touching anything:

```bash
find . \
  -not -path "./.venv/*" \
  -not -path "./__pycache__/*" \
  -not -path "./.git/*" \
  | sort
```

Identify clutter across three categories:

| Category | What to look for | Action |
|---|---|---|
| Generated/output files | `*.csv`, `*.log`, report files | Hide via `files.exclude` |
| Reference-only files | `credentials.txt`, `tenant_id.txt`, `sharepoint_ids.txt` | Hide via `files.exclude` |
| Environment noise | `.venv/`, `__pycache__/`, `*.pyc` | Hide via `files.exclude` |
| Loose files at wrong level | Test files at root, scripts without a home | Move to appropriate subfolder |
| Flat folders with 10+ mixed files | Large flat script directories | Split into logical subfolders |

Do not delete anything. Every file stays on disk.

---

## Step 2 — Hide clutter via VS Code files.exclude

Determine the VS Code workspace root — this is the folder opened in VS Code, not necessarily the project subfolder. The `.vscode/settings.json` must sit at the workspace root, not inside a subfolder, or VS Code will not apply it.

Check where the workspace root is:

```bash
# If ap-tracker is opened directly as the workspace root:
ls .vscode/settings.json

# If ap-tracker is a subfolder of a wider workspace (e.g. .APdemo):
ls ../.vscode/settings.json
```

If no `.vscode/settings.json` exists at the correct level, create it. If one exists, read it first and merge — never overwrite existing settings.

**For a workspace root that IS the project folder**, use simple paths:

```json
{
  "files.exclude": {
    "**/__pycache__": true,
    "**/*.pyc": true,
    ".venv": true,
    "credentials.txt": true,
    "tenant_id.txt": true,
    "sharepoint_ids.txt": true,
    "email_send_log.csv": true,
    "environment_verification_report.csv": true
  }
}
```

**For a workspace root one level above the project folder**, prefix each path with the project folder name:

```json
{
  "files.exclude": {
    "**/ap-tracker/**/__pycache__": true,
    "**/ap-tracker/**/*.pyc": true,
    "**/ap-tracker/.venv": true,
    "**/ap-tracker/credentials.txt": true,
    "**/ap-tracker/tenant_id.txt": true,
    "**/ap-tracker/sharepoint_ids.txt": true,
    "**/ap-tracker/email_send_log.csv": true,
    "**/ap-tracker/environment_verification_report.csv": true
  }
}
```

After writing, tell the user to run **Ctrl+Shift+P → Reload Window** in VS Code for the changes to take effect.

---

## Step 3 — Move loose files into subfolders

Look for files sitting at a level where they don't belong. Common patterns:

- Test files (`test_*.py`) at the project root → move to `tests/`
- A flat folder with 10+ scripts of mixed types → split into subfolders by role

**For large flat script folders**, use this grouping logic:

| Pattern | Subfolder |
|---|---|
| Numbered scripts (`01_`, `02_`, ...) — the core sequence | `core/` |
| One-off fix or helper scripts (not part of the main sequence) | `helpers/` |
| Orchestration scripts that call other scripts (`run_*.ps1`) | `runners/` |

Create the subfolders first, then move files:

```bash
mkdir -p powershell/core powershell/helpers powershell/runners

# Move by pattern
mv powershell/0*.ps1 powershell/core/
mv powershell/run_*.ps1 powershell/runners/
# Remaining scripts are helpers
mv powershell/assign_*.ps1 powershell/helpers/
mv powershell/resend_*.ps1 powershell/helpers/
mv powershell/connect_*.ps1 powershell/helpers/
mv powershell/create_*.ps1 powershell/helpers/
```

---

## Step 4 — Fix internal path references after moves

**This step is critical.** Any script that dot-sources or calls another script by path will break after a move. Always scan before and after.

### 4a — Find all cross-references

```bash
grep -rn "\.ps1\|\.py" ./powershell --include="*.ps1" | grep -v "^#"
```

### 4b — Fix Set-Location depth

Scripts that use `Set-Location $PSScriptRoot\..` to anchor to the project root need adjusting when moved into a deeper subfolder.

| Original location | Original Set-Location | New location | Fixed Set-Location |
|---|---|---|---|
| `powershell/script.ps1` | `$PSScriptRoot\..` | `powershell/runners/script.ps1` | `$PSScriptRoot\..\..` |

Use PowerShell to update all affected files at once:

```powershell
$files = Get-ChildItem ".\powershell\runners\*.ps1"
foreach ($f in $files) {
    $content = Get-Content $f.FullName -Raw
    $content = $content -replace [regex]::Escape('$PSScriptRoot\..'), '$PSScriptRoot\..\..'
    Set-Content $f.FullName $content -NoNewline
}
```

### 4c — Fix dot-source paths

After scripts move into `core/` and `helpers/`, any runner that references them needs updated paths:

```powershell
$runners = Get-ChildItem ".\powershell\runners\*.ps1"
foreach ($f in $runners) {
    $content = Get-Content $f.FullName -Raw
    # Core scripts
    $content = $content -replace '\.\\powershell\\(\d{2}_)', '.\powershell\core\$1'
    # Helper scripts (add any helpers referenced by runners)
    $content = $content -replace '\.\\powershell\\assign_supplier_licences\.ps1', '.\powershell\helpers\assign_supplier_licences.ps1'
    Set-Content $f.FullName $content -NoNewline
}
```

After running, verify the changes look correct:

```powershell
Select-String -Path ".\powershell\runners\*.ps1" -Pattern "Set-Location|\. \.\\"
```

Confirm all `Set-Location` lines show the correct depth and all dot-source paths point to `core\` or `helpers\` as appropriate.

---

## Step 5 — Update project_structure.md

After any reorganisation, update `.claude/rules/project_structure.md` to reflect the new layout. This keeps Claude's context accurate in future sessions.

Read the current file, find the affected section, and edit it to match the new folder structure. Use the tree format already established in the file.

---

## Step 6 — Report

```
ORGANISE — AP Tracker
======================

files.exclude:       UPDATED / ALREADY CORRECT / CREATED
Files moved:         [list each file and its old → new path, or NONE]
References fixed:    [list each file edited and what was changed, or NONE]
project_structure:   UPDATED / SKIPPED

Reload VS Code window to apply explorer changes.
```
