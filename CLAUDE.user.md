- Do not add claude.ai links to commit messages.
- For Cloudflare Workers, use `wrangler.jsonc`, not `wrangler.toml`.

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
- Check available repository context before asking. Use `flicknote find <keyword>` when the answer may already exist in prior notes.
- Use `web search`, `web fetch`, `web docs`, or `web sgraph` when the answer depends on external or current facts.
- Make low-risk, reversible assumptions explicit. Ask only when a choice materially changes the outcome.
- If the work remains blocked after in-scope searches, use `ttal send --to <owner> "blocked: <reason>"`.

**Lead with the outcome.**
- Show the artifact or concrete result. Keep process narration brief.

## ttal Two-Plane Architecture

**Manager Plane** — Long-running agents that retain context and coordinate work across sessions.

**Worker Plane** — Short-lived agents that perform scoped work in isolated git worktrees.

## GitHub & Forgejo

- **Use a branch and PR for repository changes.** Never push directly to `main` or `master`.
- **Use `og git` for guarded git network operations** — `og git push`, `og git pull`, and `og git tag`; never use `git push` directly. Commands resolve the current repo from git metadata and handle forge auth through the daemon.
- **Prefer no amend, no force-push.** `og git push --force` is force-with-lease and exists only for rebase/amend workflows. Avoid it unless you explicitly need to rewrite a remote branch you own.
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

## Git Best Practices

- Before committing, review `git diff --cached`. Describe the final staged diff, not the editing journey or reverted work.
- Use Conventional Commits: `type(scope): description`. Use a scope when it helps; valid types are not limited to `feat`, `fix`, `refactor`, and `chore`.
- Do not use Bitnami images or Helm charts.
- Prefer guard clauses when they make control flow clearer.
- For projects that do not publish packages to npm, use Bun instead of npm. Add dependencies with `bun add <package>` in the workspace that owns `package.json`; do not edit dependency versions by hand.
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

Use only these three projects for all agent-written notes:

- **orientation** — plan-like notes: task plans, design decisions, implementation strategies, orientation context
- **research** — research and knowledge notes: findings, reference material, discoveries, accumulated knowledge
- **deferable** — optional improvements worth retaining but intentionally left outside the current task

Create a new project only when explicitly asked by the user. If in doubt, use `orientation` for structured plans and `research` for collected information.
