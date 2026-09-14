# Codex for Love: Mika dev and Yuki prod

Kosmos owns two loopback-only Home Manager services for the already merged
Codex for Love (CFL) runtime. It does not own CFL source, its importer, Codex
credentials, or conversation data.

| Environment | unit | local port | Kepos URL | state root |
| --- | --- | ---: | --- | --- |
| Mika dev | `codex-for-love-dev.service` | 3082 | `http://dev-lamplit.localhost:17480` | `~/.local/state/codex-for-love/dev` |
| Yuki prod | `codex-for-love-prod.service` | 3084 | `http://prod-lamplit.localhost:17480` | `~/.local/state/codex-for-love/prod` |

Both service IDs allow exactly the existing Mac and Pixel 7a public keys. They
are direct Kepos HTTP services: no Caddy, CoreDNS, Tanka, Kubernetes, Docker,
subscriber binding, or application login is involved. `dsh` remains configured
and published separately until its later removal.

## Invariants

- CFL checkout: `/home/neil/code/projects/lamplitisles/codex-for-love` at
  `17542aee587779e795b149f17311473b65ebf3d2`.
- Node is the Nix-pinned Node 24 and application dependencies are selected by
  the checkout's pnpm lockfile.
- Install the verified `codex`, `codex.provenance.json`, and
  `codex-code-mode-host` together at
  `~/.local/share/codex-for-love/artifacts/codex-0.154.0/`. CFL verifies the
  executable and provenance at startup; the helper must remain beside `codex`.
  Do not point a service at CFL's prunable `.cache`.
- Each root contains its own `partner.toml`, persona, workspace, SQLite
  projection, attachments, profile images, and official Codex thread. The
  services only create a missing root directory; missing configuration, a bad
  CFL commit, absent artifact member, or an occupied port fails explicitly.
- The existing authorized `~/.codex` device login is used in place. Never copy,
  parse, manage, or back up credentials as part of this procedure.

## Preflight (before any cutover)

Run this from the CFL checkout. It is read-only except for the dry-run's
operator-selected report file; choose a new path outside either destination.

```sh
set -euo pipefail
repo=/home/neil/code/projects/lamplitisles/codex-for-love
prod=/home/neil/.local/state/codex-for-love/prod
session=/home/neil/.local/state/dsh/sessions/--home-neil-.openclaw-workspace--/session-bdea60ea-c8ae-45c5-b34a-e2db554435d9/session.jsonl.zstd
relationship=/home/neil/.openclaw/workspace/.dsh/dsh-companion/state.jsonl
attachments=/home/neil/.local/state/dsh/attachments/v1
settings=/home/neil/.local/state/dsh/settings.yaml
systemctl --user is-active --quiet dsh.service && { echo 'dsh.service must be inactive' >&2; exit 1; } || true
test "$(systemctl --user is-active dsh.service)" = inactive
test ! -e "$prod" || test -z "$(find "$prod" -mindepth 1 -maxdepth 1 -print -quit)"
sha256sum "$session" "$relationship" "$settings"
find "$attachments" -type f -printf '%P\\t%s\\n' | sort | sha256sum
git -C "$repo" rev-parse HEAD
pnpm --dir "$repo" --filter @lamplitisles/partner cli import-session \
  "$prod/partner.toml" "$session" "$relationship" "$attachments" \
  "$prod/workspace" "$settings" --dry-run | tee /safe/operator-records/yuki-import-dry-run.txt
```

Record the DSH source hashes, attachment manifest hash and count, CFL commit,
dry-run source counts (messages, compact boundaries, relationship records,
images, discarded kinds), and no message text. Repeat the same hashes after a
successful import; they must match. Do not start DSH and do not modify its log,
relationship file, settings, or attachment objects.

## Post-merge installation and cutover

1. Verify the checkout is the pinned commit and its `pnpm install --frozen-lockfile`
   and `pnpm build` completed at that commit. Build or select the verified
   patched Codex 0.154.0 artifact, hash all three artifact members and its
   provenance sidecar, then copy them with mode `0700` (executables) and `0600`
   (sidecar) into the stable artifact directory above. Record source and
   installed hashes; never use `.cache` as the deployed location.
2. Stop `cfl-preview-3082.service`, record its status and candidate path, and
   retain that candidate untouched until both new environments pass acceptance.
   It is recovery evidence, not a compatibility service.
3. Create `dev/partner.toml` from CFL's `apps/partner/config.example.toml`.
   Use name `Mica`, port `3082`, model `gpt-5.6-luna`, the stable artifact and
   provenance paths, `local_compaction = true`, and a new `dev/workspace`.
   Copy the reviewed assets `assets/mika-avatar.png` and
   `assets/dev-user-avatar.png` into that workspace's `.lamplit/profile/`, set
   them as companion and user avatars, and copy CFL's test-only
   `apps/partner/persona.example.md` as the Mika persona. Do not copy Yuki
   data or avatars.
4. Create the prod TOML with port `3084`, model `gpt-5.6-luna`, stable artifact
   paths, and its own `prod/workspace`. Re-run preflight, then run the same
   `import-session` command without `--dry-run` only with an absent or empty
   prod destination. The importer creates the official thread and imports
   history, relationship records, historical images, and Yuki avatars. Do not
   initialize prod separately or replace the preview candidate.
5. From merged Kosmos main, run `nh os switch . -H wsl`, then
   `just kepos-policy-render`. The latter atomically replaces only the generated
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
from the owner devices. Record service journal excerpts without credentials or
message contents.

In browsers, verify Mika's fresh identity and the two configured avatars; send
one bounded real Luna response only there. Verify Yuki's imported identity,
avatars, visible history, compact boundaries, relationship history, historical
images, refresh and pagination against the dry-run/import report. Check STT
readiness, context usage, and manual compact readiness. Restart each service
independently and repeat its readiness check. Keep Yuki read-only until the
owner deliberately sends its first post-cutover message; send no email,
external Partner message, or synthetic Yuki message.

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
