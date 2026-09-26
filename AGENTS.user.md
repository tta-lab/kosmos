## Implementation principles

- Do not preserve backward compatibility unless the user explicitly asks for it or there is evidence an external consumer—not a repository or project we own—uses it. Remove obsolete paths instead of adding compatibility layers, fallbacks, or migrations.
- Choose the smallest implementation that fully meets the current requirements. Avoid speculative abstraction, configuration, and indirection.
- Build larger changes as working end-to-end slices. Add each capability on top of a working system; do not leave the main path dependent on unfinished infrastructure.
- Prefer capabilities already in the project. Use a well-maintained dependency only when it lowers overall complexity or improves reliability; check its documentation and types first.
- Complete the stated work and verify the observable outcome with the smallest relevant check.
- Do not implement high effort optional improvements. Record concrete, useful ones in `.scratch/defered/`.

## Host-local instructions

This file contains portable user-level rules. Read
`~/.codex/AGENTS.machine.md` when it exists and follow its host-specific
instructions. It is outside this repository and untouched by
`scripts/sync-agent-config`.

## GitHub & Forgejo

- Use `og` commands instead of `git` for clone, pull, and push. Use the
  harness's typed `og` tools for pull-request creation and modification:
  Organon's MCP tools in Codex and its native typed adapter in Pi. Use `og`
  for forge authentication status, comments, and CI status or logs; keep
  governed forge workflows off `gh` and `tea`.
- For authorized local GitHub artifact releases that `og` does not support,
  use `gh` with its existing login to check release authentication, create or
  publish the release, upload assets, and verify downloads. This exception
  covers release operations only; keep Git and pull-request workflows,
  including approval-gated merges, on `og`.

## Tools

These tools are available to you. When you need to use one, use the current
harness’s tool discovery rather than guessing how to call it.

When a short token is presented as a project or repository target—for example,
“in ko” or “project ko”—treat it as a possible registered alias. Use the
`project` tool with that exact alias before interpreting it as a directory or
ordinary word. List projects only when discovery is needed.

- `project`: discover registered projects. Project-scoped tool calls take the
  alias; do not reconstruct an absolute path for them.
- `src`: inspect a known file in a registered project by alias and
  repository-relative path. Use `symbols` for structure and IDs, then `read`
  for a symbol/section or bounded text. It is read-only. Use `rg` for
  repository-wide filename/text search and normal workspace editing tools for
  changes.
- `web`: use when the answer depends on external or current facts. Search for
  discovery, fetch primary pages, docs for library documentation, and sgraph
  for public source code. Prefer repository context and prior FlickNote notes
  when they already answer the question.

### Explicit skill invocation

- A `$query` token in user prose explicitly invokes a skill whose frontmatter
  `name` contains `query`, case-insensitively. Ignore tokens in code, shell
  snippets, paths, and monetary expressions.
- Prefer an exact name match; otherwise use context and ask only when the choice
  remains materially ambiguous. Report no match instead of substituting.
- Load the selected skill's complete instructions through the current harness
  and follow them for that turn.

### Waiting for delegated agents

- Wait on all relevant active agent IDs in one call with a 290-second timeout.
  On timeout, repeat; when agents become terminal, process their results and
  continue only with the remaining active IDs. Shorten the timeout only when
  the user requests frequent updates or the tool requires a lower maximum.

## Deployment

- Merging a PR does not deploy it. If the task includes deployment, run and verify the repository's documented deploy step.

## Testing

- Tests must not read, write, replace, or delete live state, including a CLI’s
  real data or config directories, installed executables, credentials, or
  production services. Use test-owned temporary directories, fixtures, fakes,
  or injected paths. Cleanup may remove only artifacts created by that test
  inside its test-owned location.
- Test observable behavior and stable contracts, not source shape. Use the smallest check that can catch a plausible regression.
- Do not add tests for source text, prompts, documentation, or pure deletion/stale cleanup. Add a test only for runtime behavior, parsing or schema validity, a machine-consumed artifact, or an externally promised contract.

## Git Best Practices

- Never add files under `.scratch/` to Git; they are local working material only.
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

## FlickNote Notes and Projects

Use FlickNote MCP `note_*` and `project_*` tools for all agent-initiated note and project operations. Do not invoke FlickNote note-management CLI commands through the shell. If MCP is unavailable or lacks the required operation, report the blocker instead of falling back to the CLI. Starting the MCP server and managing the FlickNote daemon are operational exceptions.

Create notes without specifying a project by default. Set or change a note's project only when the user requests a specific destination or to correct a verified misassignment.

Create a new project only when explicitly asked by the user. Scope projects to durable products, initiatives, or responsibilities rather than repositories or note types. Write each project's summary as a stable membership boundary that states what work belongs there and clarifies nearby ambiguous boundaries.
