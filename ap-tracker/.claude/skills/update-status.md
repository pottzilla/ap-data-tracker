---
name: update-status
description: Update rules/status.md and rules/issues_log.md after completing work. Marks phases or checklist items as done, appends new issues with their resolutions, and updates the last-modified date. Run at the end of a work session or after resolving a significant issue.
tools: Read, Edit
---

# Update Status — AP Tracker

Keeps `rules/status.md` and `rules/issues_log.md` accurate after completing work. Always read the current file before editing.

---

## When to run this skill

- After completing a phase or sub-task (mark checklist items as `[x]`)
- After resolving a blocker (move `[~]` to `[x]`, add note)
- After discovering and fixing a new issue (append to issues_log.md)
- At the end of any productive work session

---

## Step 1 — Update status.md

Read `.claude/rules/status.md` in full first.

Identify what has changed since the last update:
- Which `[ ]` items are now complete → change to `[x]`
- Which `[~]` items are now resolved → change to `[x]` and add resolution note
- Whether a new phase is now complete → update the phase heading
- Whether there are new blockers → add as `[~]` with reason

If a phase was revised from the original plan, add a row to the Revisions table in that phase's section:

```
| [Step] | [Original plan] | [What actually happened] | [Resolution] |
```

Update the "Last updated" date at the bottom to today's date in the format already used in the file.

Use the Edit tool to make targeted changes. Do not rewrite the whole file — only change the specific lines that need updating.

---

## Step 2 — Update issues_log.md (if a new issue was resolved)

Read `.claude/rules/issues_log.md` first.

If a new problem was encountered and solved during this session, append an entry in the existing format:

```markdown
#### Issue [phase].[next number] -- [Short description]

**Symptom:** [What was observed]

**Cause:** [Root cause]

**Resolution:** [What was done to fix it]

**Artefact:** [Any files created or modified, if relevant]
```

Match the formatting and tone of existing entries — factual, specific, no padding.

---

## Step 3 — Confirm

After editing, read back the changed sections and confirm:
- Dates are correct
- Checklist items reflect actual state
- Any new issues are in the right phase section of issues_log.md

Report what was changed.
