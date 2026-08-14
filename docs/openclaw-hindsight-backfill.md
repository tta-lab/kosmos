# Safe OpenClaw → Hindsight backfill

**Scope:** installed `@vectorize-io/hindsight-openclaw` **0.10.0** and OpenClaw **2026.7.1-2** only. No config, secrets, session store, or transcript content was inspected.

## Finding

An old `agent:main:main` transcript can go into Neil's intended post-migration bank **only with a fixed-bank override**. With `dynamicBankGranularity: ["user"]`, this legacy key parses as provider/channel `main` with no sender ID, so `mirror-config` derives `anonymous` (or `<bankIdPrefix>-anonymous`). `--bank-strategy agent` derives `main`. Neither is Neil's bank. `--bank-strategy fixed --fixed-bank '<exact-neil-bank-id>'` uses the supplied ID verbatim—no prefix is added. [^plugin-source]

Changing `session.dmScope` to `per-peer` isolates *future* DMs by sender across channels; it does not add a sender ID to the historical `agent:main:main` header. Establish Neil's new per-peer session/bank first, then use that exact bank ID as the fixed value. With user-only granularity, the normal bank ID is the URL-encoded sender ID plus any configured prefix. [^openclaw-session] [^plugin-source]

## Safe procedure

1. Move to `session.dmScope: "per-peer"` through the normal OpenClaw config flow, then let Neil send a new DM. Determine the resulting exact bank ID without displaying transcript text (for example, normal plugin routing observability or a dry-run of a known new Neil session). Do not guess from a display name. [^openclaw-schema]
2. Preview all selected `main` transcripts. This reads JSONL to make the plan but prints only agent/bank/session IDs, message counts, and character counts; it does not start Hindsight, enqueue retains, or write a checkpoint. Keep even that metadata private.

   ```bash
   /home/neil/.openclaw/npm/projects/vectorize-io-hindsight-openclaw-c23cf52a67/node_modules/.bin/hindsight-openclaw-backfill \
     --openclaw-root "$HOME/.openclaw" \
     --agent main --exclude-archive \
     --bank-strategy fixed --fixed-bank '<exact-neil-bank-id>' \
     --dry-run --json
   ```

3. After reviewing the plan, run it once with a dedicated checkpoint and a clean queue drain:

   ```bash
   /home/neil/.openclaw/npm/projects/vectorize-io-hindsight-openclaw-c23cf52a67/node_modules/.bin/hindsight-openclaw-backfill \
     --openclaw-root "$HOME/.openclaw" \
     --agent main --exclude-archive \
     --bank-strategy fixed --fixed-bank '<exact-neil-bank-id>' \
     --checkpoint "$HOME/.openclaw/data/hindsight-backfill-neil.json" \
     --max-pending-operations 0 --wait-until-drained --json
   ```

   `--max-pending-operations 0` waits until the bank queue is empty before each enqueue. `--wait-until-drained` waits for touched banks and marks entries complete only after a clean drain. [^backfill-help] [^plugin-source]

4. If interrupted, resume with exactly the same scope, bank, and checkpoint:

   ```bash
   /home/neil/.openclaw/npm/projects/vectorize-io-hindsight-openclaw-c23cf52a67/node_modules/.bin/hindsight-openclaw-backfill \
     --openclaw-root "$HOME/.openclaw" \
     --agent main --exclude-archive \
     --bank-strategy fixed --fixed-bank '<exact-neil-bank-id>' \
     --checkpoint "$HOME/.openclaw/data/hindsight-backfill-neil.json" \
     --resume --max-pending-operations 0 --wait-until-drained --json
   ```

## Limits and duplication risks

- The CLI has no session-key/session-ID/file selector. `--agent main` selects every top-level `*.jsonl` in that agent's live sessions directory. `--limit` follows path-sorted discovery and is **not** a safe selector for `agent:main:main`. [^plugin-source]
- Archives are included by default; `--exclude-archive` avoids migration backups that may overlap live sessions. The planner does not deduplicate duplicate session files. [^backfill-help] [^plugin-source]
- Planned IDs are `backfill::<bankId>::<agentId>::<sessionId>`. A run without `--resume` enqueues all entries again. `--resume` skips only `completed`; without `--wait-until-drained`, already-`enqueued` entries are enqueued again. Do not rely on server document-ID behaviour: the backfill retain request is asynchronous and does not request append mode. [^plugin-source]
- Active plugin retention settings apply: role filtering (default user/assistant), format/tool-call handling, transcript cleanup, Hindsight endpoint, and retain context. Do not put `--api-token` on the shell command line; use existing plugin SecretRef-backed configuration. [^plugin-readme] [^plugin-source]
- Do not run OpenClaw session cleanup as part of this task; it maintains/removes session-store material, not Hindsight imports. [^openclaw-cli]

[^plugin-readme]: Installed plugin README, `README.md`, sections “Backfilling Existing OpenClaw History”, “Retention details”, and configuration table: `/home/neil/.openclaw/npm/projects/vectorize-io-hindsight-openclaw-c23cf52a67/node_modules/@vectorize-io/hindsight-openclaw/README.md`.
[^backfill-help]: Installed v0.10.0 CLI: `/home/neil/.openclaw/npm/projects/vectorize-io-hindsight-openclaw-c23cf52a67/node_modules/.bin/hindsight-openclaw-backfill --help`.
[^plugin-source]: Installed v0.10.0 source: `dist/backfill.js` (CLI/runtime/checkpoint), `dist/backfill-lib.js` (discovery, plan, IDs), and `dist/index.js` (`parseSessionKey`, `deriveBankId`, `prepareRetentionTranscript`) under `/home/neil/.openclaw/npm/projects/vectorize-io-hindsight-openclaw-c23cf52a67/node_modules/@vectorize-io/hindsight-openclaw/`.
[^openclaw-session]: Installed OpenClaw docs, `docs/concepts/session.md`, “DM isolation”: `/home/neil/.local/share/npm-global/lib/node_modules/openclaw/docs/concepts/session.md`.
[^openclaw-schema]: Installed OpenClaw schema: `openclaw config schema`, `session.dmScope` enum/description (also `docs/concepts/session.md`).
[^openclaw-cli]: Installed OpenClaw CLI: `openclaw sessions --help` and `openclaw sessions cleanup --help`; matching docs at `/home/neil/.local/share/npm-global/lib/node_modules/openclaw/docs/cli/sessions.md`.
