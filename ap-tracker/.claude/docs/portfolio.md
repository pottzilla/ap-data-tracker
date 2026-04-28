## What This Build Demonstrates vs the Original

| Capability                  | Original Build                    | Sandbox Build                         |
|-----------------------------|-----------------------------------|---------------------------------------|
| Email monitoring            | Standard connector                | Graph API direct                      |
| Cycle time calculation      | Ticks expression (Power Automate) | Python datetime + ticks (both)        |
| Duplicate prevention        | Message ID check                  | Message ID check                      |
| Thread message count        | Pending -- IT blocked             | Fully populated via Graph API         |
| Approver categories         | Shared mailbox limitation         | Fully populated via Graph API         |
| Conversation ID tracking    | Not available                     | Fully populated via Graph API         |
| Supplier email simulation   | Manual                            | Automated via PowerShell + Graph API  |
| AI enrichment layer         | Not built                         | Claude API via Make.com native module (3-module scenario: SP Watch -> Anthropic Claude -> SP Update) |
| Shared mailbox              | Production environment            | Replicated in M365 trial tenant       |
| Shared SharePoint site      | Personal OneDrive path            | Proper team site                      |
| Infrastructure provisioning | GUI/manual                        | PowerShell scripted                   |
| Version control             | Not applicable                    | Full GitHub repository                |
| AI Agent Optimization       | Default context loading           | Strict token control & dynamic skills |

## Portfolio Narrative

This project exists to close a specific gap: a process redesign that demonstrably improved AP operations but had no data to prove it. The original flow was built independently, without a brief, to answer a question nobody else had thought to ask. The sandbox reconstruction completes what the original build set out to do -- delivering the Graph API integration that was blocked by an external dependency, extending the pipeline with AI-powered enrichment, and producing a dataset that can finally move the conversation from gut feel to evidence.

The build demonstrates: AP domain expertise, independent automation capability, Graph API technical depth, cross-platform orchestration, AI integration, and the business acumen to frame a technical build as a measurable commercial outcome.

## Custom AI Agent Engineering & Optimization

Beyond the core pipeline, this project demonstrates advanced LLM orchestration and token economics through custom agent engineering. To optimize the AI's interaction with the codebase and minimize API costs, a custom `rules` and `skills` architecture was built into the local development environment:

*   **Global Context Optimization (`token_efficiency.md`):** A custom rule automatically injected into the AI's context window that enforces extreme token efficiency. It mandates diff-only code generation, prohibits conversational filler, and strictly forces targeted file-reading (via `grep` and exact line numbers) rather than loading entire files into memory.
*   **On-Demand Context Restructuring:** Actively re-engineered the agent's background context by isolating heavy historical documents (like `issues_log.md` and `status.md`) from the auto-loaded `rules/` folder into an isolated `docs/` reference folder. 
*   **On-Demand Tooling (`/compact` and `/status` skills):** Created specific "skills" (custom markdown prompts) that allow the developer to trigger specific AI behaviors dynamically. For example, the `/compact` skill forces the AI into a strict zero-filler mode, while the `/status` skill commands the AI to parse the isolated `status.md` file and output a 20-second project snapshot.

**Impact:** These architectural choices reduced the background token consumption of the AI agent by over **25,000 tokens per prompt**, drastically speeding up development cycles while maintaining strict programmatic control over the AI's outputs.
