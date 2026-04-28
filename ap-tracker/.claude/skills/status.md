---
name: status
description: Print a clean, readable summary of the current AP Tracker build state — phases complete, phases pending, immediate next action, and any open blockers. Reads from docs/status.md. Run at the start of a session or after a break to reorient quickly.
tools: Read
---

# Status — AP Tracker

Reads `docs/status.md` and prints a structured build snapshot.

---

## Output format

Read `.claude/docs/status.md` in full, then produce a summary in this format:

```
AP TRACKER — BUILD STATUS
==========================

COMPLETE
--------
Phase 1 — Tenant and Infrastructure
Phase 2 — Python Pipeline (pending live enrichment test)
Phase 3 — Power Automate

IN PROGRESS
-----------
Phase 5 — Completion
  Next action: [first unchecked item from Phase 5]

PENDING
-------
(none)
  - Synthetic dataset generated and imported
  - Live pipeline running for 2+ weeks
  - GitHub repository published
  - Portfolio document complete

OPEN BLOCKERS
-------------
[Any items marked [~] or flagged as blocked, with the reason]

IMMEDIATE NEXT ACTION
---------------------
[Single most important thing to do right now, derived from the first
 incomplete item in the lowest-numbered incomplete phase]
```

Keep the output tight. Do not reprint the full status file — summarise it. The goal is a 20-second reorientation, not a full read-through.

If `docs/status.md` has a "last updated" date, include it at the top so the user knows how current the snapshot is.
