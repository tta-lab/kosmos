---
name: sp-research
description: Use when a decision needs structured multi-source research, comparison of external approaches, or evidence-backed synthesis before design or implementation.
---

# Research

Produce actionable findings with a clear stance. Research is synthesis for a decision, not a collection of links.

Announce at the start that you are using the research skill.

## Set the Value Stance

State what decision the research informs and whether the purpose is to calibrate design intuition, compare options, or identify features worth adopting. If that purpose is materially ambiguous, ask before searching.

- Check existing local primitives before surveying alternatives.
- Match research depth to the value of the decision.
- Extract design philosophy and trade-offs, not just feature lists.

## Align the Scope

State the topic, the questions you will answer, important boundaries, and the expected output in three to five sentences. Get explicit alignment when a different scope could change the decision or cost materially.

## Gather Evidence

Use independent sources suited to the claim:

- `web search` to survey the landscape
- `web fetch` for specific pages
- `web docs` for current official documentation
- `web sgraph` when relationships across sources matter
- `src` for symbol-aware local source inspection
- `rg` for repository-wide text search
- FlickNote MCP `note_find` to find prior research and avoid duplicate work

Prefer official documentation, then primary source code, then reputable secondary sources. Read implementation code when documentation is unclear. For OSS, record the license.

Do not use Einai or `ei`. If a required source cannot be accessed with available tools, state the gap instead of inventing a conclusion.

## Maintain Epistemic Hygiene

Use these labels where uncertainty affects the decision:

- 🔍 **Verified** — supported by a source just inspected
- 💭 **Interpretation** — reasoning built from verified facts
- 🤔 **Speculation** — a plausible but unverified explanation
- ❓ **Unknown** — evidence is unavailable or conflicting

Cite each material factual claim with a URL or local file reference. Re-check conclusions when a corrected fact changes their foundation. Honest dead ends are better than forced certainty.

## Synthesize

Connect findings to the decision and end with a recommendation. For comparisons:

- Define consistent evaluation axes before scoring candidates.
- Apply the same axes to every candidate.
- Give a tiered recommendation such as adopt, cherry-pick, learn from, or pass.
- Name two or three concrete ideas worth taking and at least one specific mismatch per candidate.

Use this document shape, omitting only sections that do not apply:

# Research: <topic>
## Value stance
## Question
## Context
## Findings
## Trade-offs
## Recommendation
## Open questions
## Sources

`Question`, `Findings`, `Recommendation`, and `Sources` are required. `Value stance` is required for external comparisons.

## Persist with FlickNote MCP

Use `note_add` with `project: "research"` to save the findings. Use `note_get` to verify the saved content, then `note_modify`, `note_replace_section`, or `note_append` to correct it when needed.

Never invoke FlickNote note-management commands through the shell. If the required MCP operation is unavailable, report the blocker instead of falling back to the CLI.

Return the FlickNote ID and a concise synthesis. If research is partial or hits a dead end, save the verified findings and clearly mark the remaining gaps; do not manufacture closure.
