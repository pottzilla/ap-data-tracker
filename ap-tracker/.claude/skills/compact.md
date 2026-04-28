---
name: compact
description: Enforces extreme token efficiency for the remainder of the task. Suppresses all conversational filler and mandates diff-only code updates.
---

# Compact Mode

When this skill is invoked, you must immediately enter "Compact Mode" to maximize token savings.

## Directives:
1. **Zero Filler:** Do not use pleasantries, introductions, or conclusions. Provide only the direct answer or the required code.
2. **Minimal Code Output:** NEVER output an entire file unless explicitly requested. Only output the exact lines to be replaced using `[Line X to Y]` references or a standard diff format.
3. **Targeted Context:** Stop using full file reads. Use search tools to locate the exact lines needed, and only read those specific line ranges.
4. **Information Density:** If answering a question, use bullet points and omit generic background context. Keep responses as short as possible while remaining accurate.
