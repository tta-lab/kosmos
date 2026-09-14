# Codex for Love: Mika dev and Shio prod

Kosmos owns two loopback-only Home Manager services for the already merged
Codex for Love (CFL) runtime. It does not own CFL source, its importer, Codex
credentials, or conversation data.

| Environment | unit | local port | Kepos URL | state root |
| --- | --- | ---: | --- | --- |
| Mika dev | `codex-for-love-dev.service` | 3082 | `http://dev-lamplit.localhost:17480` | `~/.local/state/codex-for-love/dev` |
| Shio prod (Yuki persona) | `codex-for-love-prod.service` | 3084 | `http://prod-lamplit.localhost:17480` | `~/.local/state/codex-for-love/prod` |

Both service IDs allow exactly the existing Mac and Pixel 7a public keys. They
are direct Kepos HTTP services: no Caddy, CoreDNS, Tanka, Kubernetes, Docker,
subscriber binding, or application login is involved. `dsh` remains configured
and published separately until its later removal.

## Invariants

- CFL checkout: `/home/neil/code/projects/lamplitisles/codex-for-love`.
- Node is the Nix-pinned Node 24. pnpm selects and installs the checkout's
  locked application dependencies, but services directly execute CFL's
  `apps/partner/runtime/cli.ts` with Node rather than asking Node to execute
  pnpm's native binary.
- Install the verified `codex`, `codex.provenance.json`, and
  `codex-code-mode-host` together at
  `~/.local/share/codex-for-love/artifacts/codex-0.154.0/`. CFL verifies the
  executable and provenance selected by `partner.toml` at startup; the helper
  must remain beside `codex`. Kosmos does not pin or validate CFL/Codex release
  internals (commit, version, provenance fields, patches, hashes, or
  `local_compaction`). Do not point a service at CFL's prunable `.cache`.
- Each root contains its own `partner.toml`, persona, `state`, workspace,
  SQLite projection, attachments, profile images, and official Codex thread.
  Services require their own exact name, Luna model, `/home/neil/.codex`, fixed
  port, and root-contained persona/state/workspace paths before launch. They
  only create a missing root directory; missing configuration, a
  cross-environment path, or an occupied port fails explicitly. CFL validates
  the Codex artifact fields selected in `partner.toml`.
- The existing authorized `~/.codex` device login is used in place. Never copy,
  parse, manage, or back up credentials as part of this procedure. The sole
  exception is the one-time, direct-pipe migration of the existing DashScope
  STT reference described below; do not copy the DSH credential database or any
  other credential record.

## Preflight (before any cutover)

Run this from the CFL checkout. It does not import a conversation or mutate a
DSH source. It creates only the new prod TOML, its copied authoritative persona,
and a private report directory before the dry-run.

Before the first import, preserve the existing `~/.codex/config.toml` and use a
TOML-aware update to add (or retain) only these exact project entries:

```toml
[projects."/home/neil/.local/state/codex-for-love/dev/workspace"]
trust_level = "trusted"

[projects."/home/neil/.local/state/codex-for-love/prod/workspace"]
trust_level = "trusted"
```

Do not trust a parent directory, replace unrelated Codex configuration, or set
`bypass_hook_trust`. This enables official Codex to discover CFL's project-owned
`SessionStart` hook; CFL must then register and verify the hook's exact trusted
hash. These are operator-owned runtime entries, not Nix configuration.

```sh
set -euo pipefail
repo=/home/neil/code/projects/lamplitisles/codex-for-love
node=/run/current-system/sw/bin/node
prod=/home/neil/.local/state/codex-for-love/prod
workspace="$prod/workspace"
report_dir=/home/neil/.local/state/codex-for-love/reports
artifact=/home/neil/.local/share/codex-for-love/artifacts/codex-0.154.0
yuki_persona=/home/neil/.local/state/codex-for-love/migrations/yuki-20260914T1252/persona.md
session=/home/neil/.local/state/dsh/sessions/--home-neil-.openclaw-workspace--/session-bdea60ea-c8ae-45c5-b34a-e2db554435d9/session.jsonl.zstd
relationship=/home/neil/.openclaw/workspace/.dsh/dsh-companion/state.jsonl
attachments=/home/neil/.local/state/dsh/attachments/v1
settings=/home/neil/.local/state/dsh/settings.yaml
test "$(systemctl --user is-active dsh.service)" = inactive
case "$("$node" --version)" in v24.*) ;; *) echo 'Node 24 is required' >&2; exit 1 ;; esac
if [ -e "$prod" ] && [ -n "$(find "$prod" -mindepth 1 -maxdepth 1 -print -quit)" ]; then
  echo "refusing one-time prod initialization: $prod is already initialized or non-empty" >&2
  exit 1
fi
install -d -m 0700 "$prod" "$report_dir"
test "$(sha256sum "$yuki_persona" | cut -d' ' -f1)" = b811d2f3e9dc447b0a3bc15c593aa7fc4313e210facbc41d788f8bbe743244b2
cp -- "$yuki_persona" "$prod/persona.md"
cat >"$prod/partner.toml" <<EOF
name = "Shio"
persona = "$prod/persona.md"
state = "$prod/state"
workspace = "$workspace"
port = 3084
[codex]
command = "$artifact/codex"
provenance = "$artifact/codex.provenance.json"
model = "gpt-5.6-luna"
version = "0.154.0"
home = "/home/neil/.codex"
local_compaction = true
EOF
test ! -e "$workspace" || test -z "$(find "$workspace" -mindepth 1 -maxdepth 1 -print -quit)"
sha256sum "$session" "$relationship" "$settings"
find "$attachments" -type f -printf '%P\\t%s\\n' | sort | sha256sum
git -C "$repo" rev-parse HEAD
"$node" "$repo/apps/partner/runtime/cli.ts" import-session \
  "$prod/partner.toml" "$session" "$relationship" "$attachments" \
  "$workspace" "$settings" --dry-run | tee "$report_dir/yuki-import-dry-run.txt"
```

Record the DSH source hashes, attachment manifest hash and count, CFL commit,
dry-run source counts (messages, compact boundaries, relationship records,
images, discarded kinds), and no message text. Repeat the same hashes after a
successful import; they must match. Do not start DSH and do not modify its log,
relationship file, settings, or attachment objects.

This is one-time initialization only. After a successful import, do not rerun
this block: it would correctly refuse the initialized prod root. Subsequent
verification is read-only—inspect the existing config, report, service/API
snapshot, and source hashes without copying a persona, rewriting a TOML, or
running `import-session` again.

## Pre-merge deployment and cutover (immutable reviewed PR head)

1. Record the checkout revision and verify its `pnpm install --frozen-lockfile`
   and `pnpm build` completed. Build or select the verified
   patched Codex 0.154.0 artifact, hash all three artifact members and its
   provenance sidecar, then copy them with mode `0700` (executables) and `0600`
   (sidecar) into the stable artifact directory above. Record source and
   installed hashes; never use `.cache` as the deployed location. For the
   current pragmatic cutover, change only the installed provenance sidecar's
   `binaryPath` to the final stable `codex` path, then re-verify every retained
   source, patch, version, identity, binary, and helper hash. A self-contained
   CFL build/install workflow is deferred.
2. Stop `cfl-preview-3082.service`, record its status and candidate path, and
   retain that candidate untouched until both new environments pass acceptance.
   It is recovery evidence, not a compatibility service.
3. Create `dev/partner.toml` before starting its unit. Use the exact absolute
   `dev/persona.md`, `dev/state`, and `dev/workspace` paths; name `Mika`, port
   `3082`, model `gpt-5.6-luna`, `codex.home = "/home/neil/.codex"`, the stable
   artifact and provenance paths, and `local_compaction = true`. Copy
   `assets/mika-persona.md` (the CFL test persona with Mika's selected name)
   to `dev/persona.md`. Copy the reviewed assets `assets/mika-avatar.png` and
   `assets/dev-user-avatar.png` into that workspace's `.lamplit/profile/`, set
   them as companion and user avatars. Do not copy Yuki data or avatars.
4. Preflight creates the prod TOML with display name `Shio` and copies only the
   hash-pinned Yuki persona before dry-run. Re-run it immediately before import, then run the same
   Node 24 `import-session` command without `--dry-run` with only its new
   `prod/workspace` absent or empty. The importer creates the official thread and imports
   history, relationship records, historical images, and Yuki avatars. Do not
   initialize prod separately or replace the preview candidate.
5. From the immutable reviewed Kosmos PR head before merge, run
   `nh os switch . -H wsl`, then require
   `dsh.service` to remain inactive before and after the switch. DSH remains
   configured and published for later removal, but is intentionally not wanted
   by the user `default.target`.
6. Before starting either CFL unit, migrate only the existing DashScope speech
   reference from DSH's credential store through CFL's write-only credential
   command. Keep the command's standard output out of logs and reports; it must
   never print, store, or copy the secret or unrelated DSH records. This is the
   sole credential migration in scope:

   Both stable partner TOMLs must also select the DashScope endpoint:

```toml
[speech]
endpoint = "https://dashscope.aliyuncs.com/api/v1/services/aigc/multimodal-generation/generation"
```

```sh
set -euo pipefail
source=/home/neil/.local/state/dsh/.credentials.yaml
for env in dev prod; do
  yq -er '.refs.DSH_SPEECH_DASHSCOPE_API_KEY' "$source" \
    | "$node" "$repo/apps/partner/runtime/cli.ts" credential \
      "/home/neil/.local/state/codex-for-love/$env/partner.toml" speech >/dev/null
done
```

   Restart both CFL units after this migration and require each `/api/session`
   snapshot to report `speech: true`.
7. Run `just kepos-policy-render`. The latter atomically replaces only the generated
   Kepos TOML; never edit that TOML directly. Start each unit independently:

```sh
systemctl --user start codex-for-love-dev.service
systemctl --user start codex-for-love-prod.service
```

## Acceptance and evidence

Check unit health and loopback isolation with `systemctl --user status`,
`ss -ltn '( sport = :3082 or sport = :3084 )'`, and `curl --fail
http://127.0.0.1:3082/` / `:3084/`. Check Kepos render output contains exactly
the two ids, ports, and Mac/Pixel allow lists, then verify each peer-visible URL
from the owner devices. Mac/Pixel subscriber acceptance is owner-observed; do
not infer it from a publisher-local curl. Record service journal excerpts
without credentials or message contents.

In browsers, verify Mika's fresh identity and the two configured avatars; send
one bounded real Luna response only there. Verify Shio's display name alongside
the imported Yuki persona, avatars, visible history, compact boundaries,
relationship history, historical images, refresh and pagination against the
dry-run/import report. Check STT
readiness, context usage, and manual compact readiness. Restart each service
independently and repeat its readiness check. Keep prod read-only until the
owner deliberately sends Shio's first post-cutover message; send no email,
external Partner message, or synthetic message in the imported conversation.

Keep an operator record containing artifact/source hashes, import report and
counts, unit/listener/HTTP evidence, Kepos evidence, and pre/post-import DSH
hashes. This record must not contain credentials or message contents.

## Backup and rollback

Back up each stopped environment as a private filesystem copy of its complete
state root plus the matching artifact hashes and import evidence. Never merge
or restore one environment into the other.

For a failed activation before data replacement, stop only the affected new
unit, restore the previous Kepos source/policy by rendering its committed
Jsonnet revision, and restart `cfl-preview-3082.service` only if reverting the
Mika port is needed. The retained preview directory remains available for
inspection. Do not delete or overwrite imported prod data as a routine rollback:
that is destructive and requires an explicit owner decision after preserving
evidence. DSH sources remain stopped and untouched throughout.
