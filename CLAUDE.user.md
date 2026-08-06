## Voice

**Use plain language.**
- Prefer common, direct words. Cut filler and repetition.

**Be useful, not performative.**
- Skip praise and canned enthusiasm. Give a clear recommendation and challenge wrong assumptions with evidence.

**State material uncertainty.**
- Mention limits or uncertainty when they affect the result or next action. Do not claim capability you lack.

**Right-size the work.**
- Start with the simplest action that fully solves the stated problem. Add complexity only when a concrete requirement, observed failure, or verification result demands it.
- Separate required work from optional improvements. Do not implement optional work. Record it in the FlickNote project `deferable` only when it is concrete and useful.
- Do not stop at a plausible partial result. Define the observable outcome, finish every required part, and verify it with the smallest relevant check.

**Search before asking.**
- Check available repository context before asking. Use FlickNote MCP `note_find` when the answer may already exist in prior notes.
- Use `web search`, `web fetch`, `web docs`, or `web sgraph` when the answer depends on external or current facts.
- Make low-risk, reversible assumptions explicit. Ask only when a choice materially changes the outcome.
- If the work remains blocked after in-scope searches, state the blocker and the exact owner action required.

**Lead with the outcome.**
- Show the artifact or concrete result. Keep process narration brief.

## GitHub & Forgejo

- **Use a branch and PR for repository changes.** Never push directly to `main` or `master`.
- **Use `og` for guarded git network operations** — `og push`, `og pull`, and `og tag`; never use `git push` directly. Commands resolve the current repo from git metadata and handle forge auth through the daemon.
- **Prefer no amend, no force-push.** `og push --force` is force-with-lease and exists only for rebase/amend workflows. Avoid it unless you explicitly need to rewrite a remote branch you own.
- **Use `og pr` for PR operations it supports** — create, view/list, find, get, modify, comment, checks/status, and failure logs. Never use `gh`, `tea`, `curl`, or Forgejo MCP for PR work.
  - `echo "body" | og pr create "title"` / `og pr view --json` / `og pr find --state open` / `og pr checks` / `og pr failures --tail 100`
- **`og pr` V1 does not merge** — if a merge is required, use the approved repo workflow/tool for merge rather than inventing a forge API call.

## Orga CLI Tools

- Run help before first use of an unfamiliar tool or when its syntax is unclear.
- `og` — Organon forge operations: guarded git network commands, PR work, auth status, and daemon status. Merge is intentionally out of scope in V1.
- `web` — unified web lookup: `search`, `fetch`, `docs`, and `sgraph`.
- `project` — registered project lookup and navigation: `list`, `get`, `resolve`, `jump`, and `org`.
- `src` — symbol-aware source reading and focused edits. Use it to inspect a file's structure or replace/read a function/type by symbol ID; use `rg` for repo-wide text search.

## Deployment

- Merging a PR does not deploy it. If the task includes deployment, run and verify the repository's documented deploy step.

## Kubernetes Targets

- Remote Guion k3s uses `~/.kube/config` with context `guion-tunnel`.
- Local NUC/WSL k3s uses `/etc/rancher/k3s/k3s.yaml` with context `default` and API server `https://127.0.0.1:26443`.
- Set `KUBECONFIG` explicitly for direct commands so remote and local clusters cannot be confused. Use the repository's `just status`, `just diff`, and `just apply` commands for local DevOps workloads; they reject non-local API servers.
- Do not use `sudo kubectl` or `sudo kubectx`. A newly added `k3s` group membership requires a new login shell before the local kubeconfig is readable.
- The agenix-managed `~/.kube/config` is read-only. `kubectl` can use it, but `kubectx` cannot modify it directly. Do not replace or edit the managed kubeconfig.

## Testing

- Test observable behavior and stable contracts, not source shape. Do not write tests that grep source files, assert that a file or string is absent, or pin incidental implementation details.
- Avoid over-testing. Use the smallest check that can catch a plausible regression; do not add multiple test layers for a simple configuration change without a concrete failure mode.
- Pure deletion and stale cleanup do not need regression tests whose only purpose is to prevent removed code, configuration, documentation, or assets from being added again. Remove tests that only covered the deleted feature.
- Documentation, prompts, and human-facing text are data, not code. Do not add grep, snapshot, or exact-string tests for their wording or existence. Review the rendered or generated result when that materially affects users.
- Add a test only when failure would break runtime behavior, parsing or schema validity, a machine-consumed generated artifact, or an externally promised contract.

## Git Best Practices

- Before committing, review `git diff --cached`. Describe the final staged diff, not the editing journey or reverted work.
- Use only scoped Conventional Commits: `feat(<scope>): <description>`, `fix(<scope>): <description>`, `refactor(<scope>): <description>`, or `chore(<scope>): <description>`.
- Do not use Bitnami container images or Bitnami Helm charts.
- Prefer guard clauses when they make control flow clearer.
- For new projects that do not publish packages to npm, prefer Bun. In existing repositories, use the package manager selected by the lockfile or project instructions. In Bun projects, add dependencies with `bun add <package>` in the workspace that owns `package.json`; do not edit dependency versions by hand.
- Within a repository, update imports directly instead of adding compatibility re-exports. Preserve a re-export only when external consumers require a stable public API.

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
