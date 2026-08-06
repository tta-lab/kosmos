---
name: sp-complete-design
description: Use when the user asks to finalize and hand back an existing design or implementation plan stored in FlickNote.
---

# Complete a Design

Finalize an existing FlickNote design or plan without starting review or implementation.

## 1. Load the Note

Use FlickNote MCP `note_get` to read the full editable content, metadata, and section tree. The note must live in the `orientation` project; use `note_modify` to move it there if needed.

## 2. Review as the Implementer

Check:

- Could someone execute it without asking for missing context?
- Are file paths, commands, expected results, and ordering accurate?
- Are goal, anti-goals, exit criteria, tests, risks, and dependencies clear?
- Does any stage still hide a design decision?
- Should an oversized plan be split into deliverable phases?

Write fixes directly through FlickNote MCP:

- `note_modify` for an exact localized edit
- `note_replace_section` for a complete section subtree
- `note_append` for trailing material
- `note_insert` for content adjacent to an existing section

## 3. Resolve Missing Context

Search the repository, prior notes with `note_find`, or external sources for facts that do not require user judgment. Fold useful findings into the note.

Ask the user only for decisions that materially change scope, behavior, or trade-offs. Persist the answer with the appropriate FlickNote MCP edit before continuing.

## 4. Final Check

Use `note_get` again and confirm that:

- The note is the single source of truth
- No required work is stored only in chat
- No task annotation or task tree is required
- No unresolved question blocks execution

Never invoke FlickNote note-management commands through the shell. If the required MCP operation is unavailable, report the blocker instead of falling back to the CLI.

## 5. Hand Back

Return:

- FlickNote ID
- One paragraph describing what and why
- Major stages
- Remaining risks, if any

Keep the summary under 200 words. Stop there. Do not invoke review, implementation, or another next phase.
