# Standalone Post, Shio prod and Aru retirement

Spec #4334 replaces the old Koishi/pnpm launcher in the existing
`lamplit-post-console` user unit. Nix Node 24 directly runs
`dist/cli.cjs config-check --config …`, then `serve --config …`.
`kosmos.wsl.postConsole.releaseRoot` selects the immutable complete release
(default `~/.local/share/lamplit-post/current`);
`configFile` selects `~/.local/state/lamplit-post/standalone/post.toml`.
Relative state paths resolve from that TOML, independently of cwd.

The read-only condition skips absent/incomplete releases, missing TOML and
unprovisioned administrator files with a diagnostic. Invalid TOML belongs to
CLI preflight. Neither command installs, downloads, seeds or migrates anything.
The cwd's systemd `-` prefix permits the missing-release diagnostic. Startup is
rate limited, UMask is 0077, and SIGTERM stops the control group within 30s.
There is no package-manager UA or runtime npm/pnpm requirement.

Settings UI is loopback 5140; private MCP/assets/health API is loopback 18787.
Caddy already preserves Host to 5140. Configure exactly
`https://lamplit-post.nuc.guion.io` as settings origin, with Secure cookies.
The old `http://lamplit-post.localhost:17480` alias still routes but its Host
is rejected (401); it is not a second authenticated origin. No native `/status`
WebSocket exists. Caddy does not expose MCP. VPN DNS/TLS/source policy remains
as described in [VPN HTTPS](nuc-vpn-https.md).

Shio is **codex-for-love-prod on 3084**. The same change retires both dedicated
aru-cfl-prod (8788) and aru-cfl-dev (8787) adapters and their public tunnel routes.
CFL dev/staging/prod and sources remain; [Aru retirement](aru-cfl.md) records the
retained installations/state and the shared tunnel impact.
CFL already implements Post v1 and `credential … post|post_receiver --stdin`.
Use the same `shio` consumer identity with independent QQ and Matrix scopes.

## Prepare fresh state and release (operator only)

Worker checks use test-owned HOME, artifacts, state and ports only. Orc owns
activation after whole-spec Standards and high-risk Spec review and merge.
Agents must never read/decrypt/print/grep/diff/migrate real private TOML,
credentials, admin hashes/passwords, keys or conversations. The commands below
that create/edit/provision private state are **Neil-only**, not agent probes.
No old YAML/database/key/admin files are imported or reset.

1. Bind the reviewed Kosmos HEAD/closure and native gate receipt to this exact
   preserved, mode-0444 archive (do not rebuild, repackage or relabel it):

   ```sh
   set -eu
   post_archive=/home/neil/code/projects/lamplitisles/lamplit-post/.scratch/deployment-candidates/ca8a87dff8cb05f7d45139a3fe763f8b6b0507bf/lamplit-post-node24.tar.gz
   post_sha=929a66b1f70d6e327582f3a18bf19cfaa0a8d61950245df54cb778e13a4f9028
   printf '%s  %s\n' "$post_sha" "$post_archive" | sha256sum --check
   ```

   Reviewed revision `ca8a87dff8cb05f7d45139a3fe763f8b6b0507bf` has the same
   tree `8178094847996bec27f820367c97b9cc46952e74` as merged Post
   `bb371f5327b868a06e2176be88e0df5d12b2a202`. Keep `revision.json` unchanged.
   Full bundle includes CLI, `dist/web`, local assets, patched SDK dependencies,
   `revision.json` and `artifact-manifest.json`.
2. Record public baselines immediately before execution, not old task PIDs:

   ```sh
   umask 077
   post_backup="$HOME/backups/post-$(date -u +%Y%m%dT%H%M%SZ)"
   mkdir -m 0700 -p "$post_backup"
   readlink -f /run/current-system > "$post_backup/system-path"
   readlink -f "$HOME/.local/state/nix/profiles/home-manager" > "$post_backup/home-generation"
   systemctl --user show lamplit-post-console flickgrove aru-cfl-dev aru-cfl-prod matrix-mcp-remote keet-mcp keet-mcp-serein codex-for-love-dev codex-for-love-staging codex-for-love-prod -p Id -p MainPID -p ActiveState -p FragmentPath -p DropInPaths -p ExecStart -p EnvironmentFiles > "$post_backup/public-units"
   systemctl --user cat lamplit-post-console > "$post_backup/old-post-unit"
   systemctl show cloudflared-tunnel-kepos -p MainPID -p ActiveState -p FragmentPath -p ExecStart > "$post_backup/public-tunnel"
   ```

   Save any existing `current` selection's link target. Retain the old writable
   `~/.local/share/lamplit-post/app` and all old state in place, opaque, for
   rollback. Neil may make private stopped snapshots; agents do not inspect them.
   Coordinate active FlickGrove turns and other owners before any system switch.
3. Extract once into an **absent versioned directory**, without touching the old app:

   ```sh
   post_release="$HOME/.local/share/lamplit-post/releases/ca8a87dff8cb05f7d45139a3fe763f8b6b0507bf"
   test ! -e "$post_release"
   install -d -m 0700 "$(dirname "$post_release")"
   mkdir -m 0700 "$post_release"
   tar -xzf "$post_archive" -C "$post_release" --no-same-owner
   python3 - "$post_release" <<'PY'
   import hashlib, json, pathlib, sys
   root = pathlib.Path(sys.argv[1]).resolve()
   manifest = json.loads((root / 'artifact-manifest.json').read_text())
   for f in manifest['files']:
       p = root / f['path']
       assert p.resolve().is_relative_to(root)
       assert p.stat().st_size == f['bytes']
       assert hashlib.sha256(p.read_bytes()).hexdigest() == f['sha256']
   for link in manifest['links']:
       p = root / link['path']
       assert p.readlink().as_posix() == link['target']
       assert p.resolve().is_relative_to(root)
   print('complete artifact inventory verified')
   PY
   chmod -R a-w "$post_release"
   ```

4. Neil creates a new private config (0700 parent, 0600 file), using an editor,
   never a copy from the managed application:

   ```sh
   install -d -m 0700 "$HOME/.local/state/lamplit-post/standalone"
   (umask 077; set -C; : > "$HOME/.local/state/lamplit-post/standalone/post.toml")
   hx "$HOME/.local/state/lamplit-post/standalone/post.toml"
   ```

   Initial TOML contains no credentials:

   ```toml
   data_dir = "./data"
   master_key_file = "./master.key"
   hostname = "127.0.0.1"
   port = 18787
   accounts = []
   bindings = []

   [settings]
   port = 5140
   origin = "https://lamplit-post.nuc.guion.io"
   admin_file = "./administrator.json"
   ```

   Use the **absolute Node path from the reviewed evaluated ExecStart** below
   as `post_node`. Help/config-check are read-only; provision offline with the
   service stopped. Admin record, vault key and machine token are independent.
   Provisioning again replaces the admin password; it is not an idempotent setup.

   ```sh
   post_node=/nix/store/REPLACE_WITH_REVIEWED_NODE24/bin/node
   post_config="$HOME/.local/state/lamplit-post/standalone/post.toml"
   "$post_node" "$post_release/dist/cli.cjs" --help
   "$post_node" "$post_release/dist/cli.cjs" config-check --config "$post_config"
   systemctl --user stop lamplit-post-console
   ! systemctl --user is-active --quiet lamplit-post-console
   ss -ltn '( sport = :5140 or sport = :18787 )'
   # Require both listeners absent before continuing.
   # Neil types a new 12–1024 character password; nothing enters argv/history.
   read -r -s -p 'New Post administrator password: ' post_password; printf '\n'
   printf '%s' "$post_password" | "$post_node" "$post_release/dist/cli.cjs" admin-provision --config "$post_config"
   unset post_password
   "$post_node" "$post_release/dist/cli.cjs" config-check --config "$post_config"
   ln -s "$post_release" "$HOME/.local/share/lamplit-post/current.next"
   mv -T "$HOME/.local/share/lamplit-post/current.next" "$HOME/.local/share/lamplit-post/current"
   ```

## Inspect impact and activate Post (Orc)

Require reviewed clean merged Kosmos HEAD and the matching built WSL closure.
Compare four protected generated public units (FlickGrove, matrix-mcp-remote,
keet-mcp, keet-mcp-serein) with installed files; separately
compare CFL dev/staging/prod base units and existing public override contracts.
Do not read environment values. Review **all** closure drift, including packages,
system services and Home Manager, not just the intended Post unit:

```sh
post_closure=/nix/store/REPLACE_WITH_REVIEWED_WSL_CLOSURE
nix store diff-closures /run/current-system "$post_closure"
sudo "$post_closure/bin/switch-to-configuration" dry-activate
```

Coordinate every unrelated start/stop/restart in the fresh plan with its owner.
Expect both Aru units to stop/disappear and their two tunnel routes to be removed.
The shared tunnel connector may restart, briefly affecting Matrix/Keet public
traffic; coordinate its actual dry-activate plan and verify remaining routes.
Use its public ExecStart to locate the generated config, validate ingress, and
check the two retired names against the final 404 rule. Keep Matrix/Keet
destinations, the credential-file reference and HTTP2 transport unchanged.
Application units for CFL/FlickGrove/Matrix/Keet must remain unchanged.
Home Manager may activate user units during the switch. Abort if active work
cannot tolerate the plan. Keep old system/HM generations and release selection.
As regular Neil, from the merged checkout, Orc then runs:

```sh
nh os switch . -H wsl
systemctl --user start lamplit-post-console
systemctl --user is-active lamplit-post-console
ss -ltn '( sport = :5140 or sport = :18787 or sport = :3084 or sport = :8787 or sport = :8788 )'
curl --noproxy '*' --fail --resolve lamplit-post.nuc.guion.io:443:10.80.12.5 https://lamplit-post.nuc.guion.io/
```

Verify the retired Aru units are inactive/absent, no Aru-owned listeners remain on
8787/8788, and shared Matrix/Keet tunnel routes still work. Do not infer ownership
from port numbers alone or stop a new unrelated port owner. Keep Aru files/state.
Verify real static resource hashes, canonical Host/Origin, unauthenticated API
rejection, loopback listeners and protected PIDs. Neil logs in at the VPN URL;
agents never capture his password/cookie/config responses. `settings_ready`
means management is available; only `ready`/healthy proves native SDK/API ready.
A failed upstream credential may leave authenticated management for repair.
Mac OS DNS, trusted TLS and real browser login need separate device acceptance;
`--resolve` alone does not prove them. No Caddy/Tanka/DNS rollout is needed; only
the two Aru routes are removed from the shared Cloudflare connector config.

## Provision QQ + Matrix, then enable Shio (Neil and Orc)

1. In Post settings register `shio`, fixed receiver
   `http://127.0.0.1:3084/api/post/events`, with a new receiver secret. Registering
   alone has no grants. Before adding any chat scopes, save all wake switches
   false and aliases empty. Issue its separate machine token once and securely
   retain it for CFL. Never reuse platform credentials or the receiver secret as token.
2. Enter QQ official App ID/AppSecret and Matrix user ID/homeserver/access token
   in password fields. Do not copy `/run/agenix/matrix-shio.env` or old Post vault
   credentials. Save/connect both accounts. Grant only intended chats and explicit
   private senders; Matrix rooms must be joined and plaintext. QQ adding the bot,
   profile-share QR and granting access are independent actions.
3. Keep **all wake switches false and aliases empty** until CFL is ready. Leave
   the intended binding enabled with active QQ/Matrix scopes so CFL's startup
   `list_accounts` probe sees both accounts. Pausing/revoking all scopes would
   prevent that probe; an empty registration is insufficient. Quiesce intended
   chats during cutover, disable only Shio's old Matrix webhook if present, and
   inspect shared MFA/Keet ownership before changing anything. Never stop a
   shared gateway blindly. Already admitted/unknown deliveries need inspection;
   holding wakes is not an automatic replay queue.
4. Neil sets `[post]` and removes obsolete `[matrix]` if present in the existing
   prod config, preserving model, workspace, native thread and every other key:

   ```sh
   hx "$HOME/.local/state/codex-for-love/prod/partner.toml"
   ```

   ```toml
   [post]
   endpoint = "http://127.0.0.1:18787"
   agent_id = "shio"
   ```

   Use the actual installed candidate CLI; no CFL source rebuild or launcher
   replacement is expected. The verified candidate at preparation time is
   `c8db35198e5f91b239070cf4d952d486fe2820a1`. Recheck public ExecStart first;
   preserve its `--native-package-root` and all Keet/Amare environment references.
   Neil supplies each secret via the existing atomic credential writer:

   ```sh
   cfl_cli="$HOME/.local/share/codex-for-love/candidates/c8db35198e5f91b239070cf4d952d486fe2820a1/package/vendor/runtime/cli.mjs"
   cfl_config="$HOME/.local/state/codex-for-love/prod/partner.toml"
   read -r -s -p 'Post machine token for shio: ' post_token; printf '\n'
   printf '%s' "$post_token" | /run/current-system/sw/bin/node "$cfl_cli" credential "$cfl_config" post --stdin
   unset post_token
   read -r -s -p 'Distinct Post receiver secret: ' post_receiver; printf '\n'
   printf '%s' "$post_receiver" | /run/current-system/sw/bin/node "$cfl_cli" credential "$cfl_config" post_receiver --stdin
   unset post_receiver
   ```

   These preserve unrelated credential keys. If obsolete `matrix` remains,
   Neil removes only that key using his private editor; unknown keys fail closed.
   Resolve `state` relative to the TOML directory (`./state` if omitted), then run
   `hx <resolved-state-directory>/credentials.json` privately. Preserve every
   other key; do not replace the file with a partial template. No agent opens it.
   No Matrix-only environment references are changed speculatively; coordinate verified conflicts separately.
5. After human prerequisites and authorized fresh impact checks, Orc restarts
   **only codex-for-love-prod**, preserving the installed candidate/native root:

   ```sh
   systemctl --user restart codex-for-love-prod
   systemctl --user is-active codex-for-love-prod
   curl --noproxy '*' --fail http://127.0.0.1:3084/
   ```

   Check startup account discovery and original static hashes, with bounded
   readiness polls (up to 120s); abort restart loops. A no-auth `{}` probe to
   `/api/post/events` was 404 before cutover; this is not receiver readiness.
   Authenticated receiver/schema probes are a later explicitly authorized check.
6. Only then enable intended wake rules, one controlled scope at a time. Later
   explicit acceptance uses human-originated QQ and Matrix markers, exact source/
   account/reply facts, image/file availability and durable receipt/dedupe evidence
   on the existing Shio thread. No model run or outgoing real IM send is part of
   Worker checks. Do not replay historic intake or retry unknown sends. Record
   actual pending gaps; local fixture success is not production IM acceptance.

## Updates and narrow rollback

For updates select a new reviewed complete immutable version, stop only Post,
privately snapshot fresh standalone TOML/data/key/admin together, validate,
then atomically change `current`. Never overlay an initialized release or run
runtime installation. SIGTERM must close both listeners and release ownership
before reopen; preserve the same external key. Never delete locks speculatively.

For rollback hold the affected binding's wakes first. Stop only Post, restore the
saved release selection and matching public unit generation after inspecting the
system/HM rollback's whole impact. Keep fresh standalone data/key/admin intact;
do not point the old managed app at them. Old app/state remains opaque in its
original location. If safe old authenticated ownership cannot be established,
leave Post stopped. Restore only Shio's changed config/credential references
privately if necessary, then restart only prod after checking duplicate Matrix
intake is impossible. Retain candidate/native arguments and all CFL histories,
receipts, workspace and threads. Never restore a database over current history,
resend an unknown send or automatically replay a held delivery. Caddy certificate
storage, DNS and unrelated services are outside this rollback. If restoring Aru
availability, restore the saved system/HM and two tunnel routes after impact
review; reuse retained Aru installations/state without copying or replaying it.
