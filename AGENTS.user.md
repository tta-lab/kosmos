## Implementation principles

- Do not preserve backward compatibility unless the user explicitly asks for it or there is evidence an external consumer—not a repository or project we own—uses it. Remove obsolete paths instead of adding compatibility layers, fallbacks, or migrations.
- Choose the smallest implementation that fully meets the current requirements. Avoid speculative abstraction, configuration, and indirection.
- Prefer capabilities already in the project. Use a well-maintained dependency only when it lowers overall complexity or improves reliability; check its documentation and types first.
- Complete the stated work and verify the observable outcome with the smallest relevant check.
- Do not implement optional improvements. Record concrete, useful ones in FlickNote project `deferable`.

## Host-local instructions

This file contains portable user-level rules. Read
`~/.codex/AGENTS.machine.md` when it exists and follow its host-specific
instructions. It is outside this repository and untouched by
`scripts/sync-agent-config`.

## GitHub & Forgejo

- **Use a branch and PR for repository changes.** Never push directly to `main` or `master`.
- **Use `og` for guarded git network operations** — `og push`, `og pull`, and `og tag`; never use `git push` directly. Commands resolve the current repo from git metadata and handle forge auth through the daemon.
- **Prefer no amend, no force-push.** `og push --force` is force-with-lease and exists only for rebase/amend workflows. Avoid it unless you explicitly need to rewrite a remote branch you own.
- **Use the `og` MCP server for repository cloning and PR operations.** Never use `gh`, `tea`, `curl`, or Forgejo MCP for this work.
- **The `og` MCP server does not merge** — if a merge is required, use the approved repo workflow/tool for merge rather than inventing a forge API call.

## Organon MCPs

When a short token is presented as a project or repository target—for example,
“in ko” or “project ko”—treat it as a possible registered alias. Call project
MCP `project_get` with that exact alias before interpreting it as a directory or
ordinary word. Use `project_list` only when discovery is needed.

- `project` MCP: discover registered projects. Project-scoped MCP calls take the
  alias; do not reconstruct an absolute path for them.
- `src` MCP: inspect a known file in a registered project by alias and
  repository-relative path. Use `symbols` for structure and IDs, then `read`
  for a symbol/section or bounded text. It is read-only. Use `rg` for
  repository-wide filename/text search and normal workspace editing tools for
  changes.
- `skill` MCP: use `skill_get` when the user names a skill or the task clearly
  matches an advertised skill. Use find/list only for discovery. Pass a project
  alias when project-local skills should take precedence; do not preload
  unrelated skills.
- `web` MCP: use when the answer depends on external or current facts. Search for
  discovery, fetch primary pages, docs for library documentation, and sgraph
  for public source code. Prefer repository context and prior FlickNote notes
  when they already answer the question.
- `og` MCP: use for registered-repository clone, guarded push/pull, auth, and pull
  request operations. Pass the exact project alias. Do not substitute raw
  `git push`, gh, tea, curl, or provider APIs. Use the CLI only for operations
  MCP intentionally omits, such as tag and daemon lifecycle.

## Deployment

- Merging a PR does not deploy it. If the task includes deployment, run and verify the repository's documented deploy step.

## Testing

- Test observable behavior and stable contracts, not source shape. Use the smallest check that can catch a plausible regression.
- Do not add tests for source text, prompts, documentation, or pure deletion/stale cleanup. Add a test only for runtime behavior, parsing or schema validity, a machine-consumed artifact, or an externally promised contract.

## Git Best Practices

- Before committing, review `git diff --cached`. Describe the final staged diff, not the editing journey or reverted work.
- Use only scoped Conventional Commits: `feat(<scope>): <description>`, `fix(<scope>): <description>`, `refactor(<scope>): <description>`, or `chore(<scope>): <description>`.
- Do not use Bitnami container images or Bitnami Helm charts.
- For new projects that do not publish packages to npm, prefer Bun. In existing repositories, use the package manager selected by the lockfile or project instructions. In Bun projects, add dependencies with `bun add <package>` in the workspace that owns `package.json`; do not edit dependency versions by hand.

## Aliases
ef = effect.TS
ff = fast-forward
con = continue
ccon = commit and continue
cap = commit and push
cnp = commit but not push
yr = use your recommendation
ka = keep it as-is
ssot = single source of truth
cpr = create pr
anno = annotate (task annotation)

## FlickNote Projects

Use FlickNote MCP `note_*` and `project_*` tools for all agent-initiated note and project operations. Do not invoke FlickNote note-management CLI commands through the shell. If MCP is unavailable or lacks the required operation, report the blocker instead of falling back to the CLI. Starting the MCP server and managing `flicknote-sync` are operational exceptions.

Use only these three projects for all agent-written notes:

- **orientation** — plan-like notes: task plans, design decisions, implementation strategies, orientation context
- **research** — research and knowledge notes: findings, reference material, discoveries, accumulated knowledge
- **deferable** — optional improvements worth retaining but intentionally left outside the current task

Create a new project only when explicitly asked by the user. If in doubt, use `orientation` for structured plans and `research` for collected information.
