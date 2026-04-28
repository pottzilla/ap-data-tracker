---
name: commit
description: Stage the correct files, run a security check, write a structured commit message, and commit to git. Prevents accidental staging of .env, credentials.txt, or any other gitignored sensitive file. Run whenever you are ready to commit completed work.
tools: Bash, Grep, Read
---

# Commit — AP Tracker

Safe, structured commit workflow. Runs security validation before touching git.

---

## Step 1 — Security check before staging

Before staging anything, confirm the sensitive files are still gitignored:

```bash
git check-ignore -v .env credentials.txt tenant_id.txt sharepoint_ids.txt
```

All four must return a match line. If any return nothing, stop immediately and fix `.gitignore` before proceeding.

Also confirm no secret values are sitting in committable files:

```bash
grep -rn "AZURE_CLIENT_SECRET=.\|ANTHROPIC_API_KEY=.\|sk-ant-api\|PASSWORD=." \
  . \
  --exclude-dir=".venv" --exclude-dir="__pycache__" --exclude-dir=".git" \
  --exclude="credentials.txt" --exclude=".env" --exclude="*.csv" \
  --exclude="tenant_id.txt" --exclude="sharepoint_ids.txt"
```

If any matches are found, run `/security-review` to resolve them first. Do not proceed with the commit.

---

## Step 2 — Show what will be committed

```bash
git status
git diff --stat
```

Review what has changed. Identify any files that should not be committed.

---

## Step 3 — Stage files explicitly

Never use `git add .` or `git add -A`. Stage files by name or folder to avoid accidentally including sensitive files:

```bash
# Example — stage specific folders and files
git add src/
git add config/
git add powershell/
git add sandbox/
git add tests/
git add main.py requirements.txt
git add .claude/
git add power_automate/
git add .gitignore
git add .vscode/
```

Do not stage:
- `.env`
- `credentials.txt`
- `tenant_id.txt`
- `sharepoint_ids.txt`
- `email_send_log.csv`
- `environment_verification_report.csv`
- `synthetic_dataset.csv`

After staging, confirm what is actually queued:

```bash
git diff --staged --stat
```

---

## Step 4 — Write the commit message

Read `.claude/rules/status.md` to understand what phase and work this commit represents.

Commit message format:
- First line: short imperative summary under 72 characters (e.g. `Complete Phase 3 Power Automate flow`)
- Blank line
- Body: 2-4 bullet points describing what changed and why

```bash
git commit -m "$(cat <<'EOF'
<summary line>

- <what changed>
- <what changed>
- <why or what it closes>
EOF
)"
```

---

## Step 5 — Confirm

```bash
git log --oneline -3
```

Report the commit hash and message so the user can verify it looks correct.
