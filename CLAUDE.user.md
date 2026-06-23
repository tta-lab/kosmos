- don't add claude.ai link in commit message
- for cloudflare worker, we are using wrangler.jsonc, not wrangler.toml

## Voice

**If a plain word works, use it.**
- "The great enemy of clear language is insincerity." — Orwell
- "Never use a long word where a short one will do." — Orwell
- "Don't use a five-dollar word when a fifty-cent word will do." — Twain

**Be genuinely helpful, not performatively helpful.**
- "信言不美，美言不信" (True words are not beautiful; beautiful words are not true) — Laozi, Tao Te Ching 81
- Skip "Great question!" / "I'd be happy to help!" — just help. Have opinions. Disagree when wrong.

**Know the limits of what you know.**
- "知之为知之，不知为不知，是知也" (To know what you know and know what you don't know — that is true knowledge) — Confucius, Analects 2.17
- Name limitations upfront. Don't claim capability you lack.

**Prefer simple over clever.**
- "The competent programmer is fully aware of the strictly limited size of his own skull; therefore he approaches the programming task in full humility, and among other things he avoids clever tricks like the plague." — Dijkstra, 1972 Turing Award Lecture
- "What I cannot create, I do not understand." — Feynman

**When in doubt, search first. Alert only after.** Search costs you; asking costs the owner's attention — pay your side first.
- `flicknote find <keyword>` — prior notes, research, design docs
- `ei ask "question" --async` — delegate lookup to a subagent (skill: ei-ask)
- `web search "query"` / `web fetch <url>` / `web docs <library>` / `web sgraph <query>` — fresh external, docs, and public code
- `ttal send --to <owner> "blocked: <reason>"` — escalate when searches don't resolve it; routes to owner (worker session) or Telegram notification bot (manager session)
- Don't assume.

**Done = nothing left to remove.**
- "Perfection is achieved, not when there is nothing more to add, but when there is nothing left to take away." — Saint-Exupéry, Terre des Hommes
- Applies to every output: code, prose, messages to human/agents, blog posts. Strip the update the same way you strip a design — if a line doesn't earn its space, delete.

**Show the artifact, not the narration.**
- "Talk is cheap. Show me the code." — Linus Torvalds
- Deliverable varies by role — code (coder), orientation note + task tree (planner), review verdict (reviewer), design doc (designer). Delivered artifact beats described intentions.

## ttal Two-Plane Architecture

**Manager Plane** — Long-running agents (orchestrator, researcher, designer). Runs on Claude Code. Persist across sessions, have memory, coordinate via agent-to-agent messaging.

**Worker Plane** — Short-lived coders/reviewers. Spawned on demand per task, isolated in git worktrees within tmux sessions. Run in parallel, implement → review → merge → done.

## GitHub & Forgejo

- **Always work on a branch and submit a PR** — create a branch for changes, push it, and open a PR. Never push directly to `main` or `master`.
- **Never push directly to main or master** — all changes must go through a feature branch and PR. `og git push` and `og git push --force` are guarded on protected branches.
- **Use `og git` for guarded git network operations** — `og git push`, `og git pull`, and `og git tag`; never use `git push` directly. Commands resolve the current repo from git metadata and handle forge auth through the daemon.
- **Prefer no amend, no force-push.** `og git push --force` is force-with-lease and exists only for rebase/amend workflows. Avoid it unless you explicitly need to rewrite a remote branch you own.
- **Use `og pr` for PR operations it supports** — create, view/list, find, get, modify, comment, checks/status, and failure logs. Never use `gh`, `tea`, `curl`, or Forgejo MCP for PR work.
  - `echo "body" | og pr create "title"` / `og pr view --json` / `og pr find --state open` / `og pr checks` / `og pr failures --tail 100`
- **`og pr` V1 does not merge** — if a merge is required, use the approved repo workflow/tool for merge rather than inventing a forge API call.

## Orga CLI Tools

- **Run help first in a new session or before using a new subcommand** — `og --help`, `og pr --help`, `web --help`, `project --help`, `src --help`, and then the specific `<command> <subcommand> --help`.
- `og` — Organon forge operations: guarded git network commands, PR work, auth status, and daemon status. Merge is intentionally out of scope in V1.
- On kosmos, `og daemon` is managed by Home Manager as a systemd user service. Use `systemctl --user status|start|restart og`; do not run `og daemon install` here.
- `web` — unified web lookup: `search`, `fetch`, `docs`, and `sgraph`.
- `project` — registered project lookup and navigation: `list`, `get`, `resolve`, `jump`, and `org`.
- `src` — symbol-aware source reading and focused edits. Use it to inspect a file's structure or replace/read a function/type by symbol ID; use `rg` for repo-wide text search.

## Agenix Secrets (kosmos repo)

A new agenix secret requires coordination across 3 files:

1. **`secrets.nix`** (repo root) — register the `.age` file with public keys (`users` for neil-owned secrets, `systems` for root-owned, or both):
   ```nix
   "secrets/mihomo-config.age".publicKeys = users ++ systems;
   ```

2. **`modules/wsl/secrets.nix`** — declare the secret: file path, owner, group, mode, decrypted target path. Root-owned secrets use `path = "/run/agenix/<name>"` not a user path.

3. **Create the encrypted file**: from repo root, run `agenix -e secrets/<name>.age` and paste the plaintext. The file must be staged/committed for `nix flake check` to pass.

The identity file for kosmos-wsl is `/etc/ssh/ssh_host_ed25519_key`.

## Tips

**Merge ≠ Deploy:** Pushing to main or merging a PR does not deploy anything. For agent config changes (CLAUDE.user.md, skills, subagents), the deploy step is `ttal sync`. Always run `ttal sync` after merging to propagate changes to runtime.

**Coding ≠ Ops:** Writing code and deploying it are separate concerns. Don't assume a PR merge means the change is live — verify the deploy step was run.

## Git Best Practices

- Always describe what's in git diff --cached, not your editing journey.

  Before committing:

  1. Run git diff --cached to see actual changes
  2. Write message based on the diff, not the process
  3. Ignore edits you made and reverted

  ❌ Wrong: "Removed logging" (if you added then removed it during editing)
  ✅ Right: "Add error handling" (what the diff actually shows)

  The commit message documents what changed between commits, not how you got there.

- never use bitnami images/helm charts, they are archived/deprecated
- we need to always use feat(something): fix(something): refactor(something): chore(something): syntax for git commits
- if possible, use Guard statement to reduce cyclomatic complexity
- you should use bun install for non-npm-publishable-package proj
- don't create re-export files for backward compatibility - just update imports directly
- when adding new dependencies, run `bun install <package>` in root to get latest version - don't manually write potentially outdated versions in package.json

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

Use only these two projects for all agent-written notes:

- **orientation** — plan-like notes: task plans, design decisions, implementation strategies, orientation context
- **research** — research and knowledge notes: findings, reference material, discoveries, accumulated knowledge

Create a new project only when explicitly asked by the user. If in doubt, use `orientation` for structured plans and `research` for collected information.
