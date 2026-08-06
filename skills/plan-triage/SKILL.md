---
name: plan-triage
description: Use when a FlickNote implementation plan has review findings that require disposition before the plan can be executed.
---

# Plan Triage

Categorize each review finding, fix what is actionable in the FlickNote plan, and report the resulting readiness verdict.

## Inputs

Work from a FlickNote plan ID and the review findings supplied by the user or current conversation. Always use FlickNote MCP `note_get` to load the current plan before editing; do not rely on a stale copy in chat.

## 1. Categorize

For each finding, choose one category:

**Actionable — fix now**

- Gaps that would block an implementer
- Wrong assumptions verified against the codebase
- Missing error handling or relevant edge cases
- Shortcuts that create material technical debt
- Ambiguities resolvable from available evidence

Format: `[FIX] <summary> — <why it matters>`

**False positive — push back**

- Assumptions verified as correct
- Impossible edge cases in the actual system
- Complexity that is justified by a concrete requirement

Format: `[FALSE POSITIVE] <summary> — <why it is wrong>`

**Deferrable — follow up later**

- Useful improvements that do not block delivery
- Nonessential simplification or polish

Format: `[DEFER] <summary> — <why it can wait>`

Record a concrete, useful deferred item with FlickNote MCP `note_add` using `project: "deferable"`, and include `Source plan: <id>` in the note content. Do not record vague possibilities.

**Needs user — cannot resolve from evidence**

- Business requirements or product decisions
- Priority trade-offs
- Integration choices the reviewer cannot verify

Format: `[ASK] <summary> — <question>`

## 2. Fix

Address every `[FIX]` item directly through FlickNote MCP:

- `note_modify` for an exact localized edit
- `note_replace_section` for a complete section subtree
- `note_append` for missing trailing steps
- `note_insert` for content adjacent to an existing section

Keep fixes minimal. If a finding requires a material redesign or an unapproved product choice, recategorize it as `[ASK]`.

Use `note_get` after editing to verify the saved plan and ensure every actionable finding was addressed.

Never invoke FlickNote note-management commands through the shell. If the required MCP operation is unavailable, report the blocker instead of falling back to the CLI.

## 3. Report

# Plan Triage Round <n>: <plan title>

## Fixed
- [x] <finding> — <what changed>

## False Positive
- [FALSE POSITIVE] <finding> — <why>

## Deferred
- [DEFER] <finding> — <why and deferable note ID, when created>

## Needs User
- [ASK] <finding> — <question>

## Verdict
**Ready / Needs Revision / Needs Rethink**

Verdict rules:

- **Ready** — all actionable findings are fixed and no `[ASK]` remains
- **Needs Revision** — one or more `[ASK]` decisions remain
- **Needs Rethink** — small plan edits cannot resolve a fundamental problem

Include the round number and previous verdict when applicable. If the same plan remains stuck after two rounds, show the unresolved evidence and ask the user for a decision instead of looping automatically.

Do not start implementation or automatically invoke review after reporting.
