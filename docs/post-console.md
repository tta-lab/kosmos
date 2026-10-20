# Native managed Post service

FlickNote #4111 replaces the former empty preview with the authenticated native
Koishi application from Post #4110. The existing user unit
`lamplit-post-console` runs Nix Node 24 and real pnpm 12.3.4. Its sole writable
application root is `~/.local/share/lamplit-post/app`
(`kosmos.wsl.postConsole.appRoot`); cwd is the same directory.

The app owns `package.json`, lockfile, workspace settings, patches, modules,
`post/` (the local `koishi-plugin-post=file:./post` package), CLI and sole
`koishi.yml`. Native Market changes those dependencies; native Config changes
that YAML. Startup checks initialization, runs `pnpm run config-check`, then
`pnpm run start`. It never installs, downloads, seeds or synchronizes files.
An absent/incomplete root skips with a diagnostic and no restart loop.
The working directory's systemd `-` prefix permits that missing-root diagnostic.

The app supplies `verifyDepsBeforeRun:false` and `frozenLockfile:false`,
without an exact `packageManager` redirect. Normal pnpm 12 owns module replacement.
The explicit service PATH also supplies Nix Bash: pnpm 12 resolves `sh` through
PATH to run application scripts. No app `scriptShell` override is needed.
pnpm supplies the actual `npm_config_user_agent` inherited by native Installer;
the service does not synthesize it. The native CLI supervisor handles code 51;
ordinary failures use systemd on-failure with rate limiting. SIGTERM stops the
complete control group within 30 seconds. UMask is 0077; operator installation
creates the app root with mode 0700. Native plugin scripts run as the user.

UI remains loopback 5140 (root assets, WebSocket `/status`), private API remains
loopback 18787. Caddy still exposes only the UI at
`https://lamplit-post.nuc.guion.io/` and `http://lamplit-post.localhost:17480/`.
Existing VPN source restrictions, TLS, DNS and ingress policies are unchanged.
CFL retains 8787. There is no auth proxy, second database or admin HTTP API.
Native Auth shares Post's existing provider; its upstream SHA256 password and
token-generation limitations remain documented in Post, within the VPN boundary.
Accounts/model execution/IM enrollment are separate work.

## Operator-only first replacement

Orc owns target deployment after both independent reviews and both merges.
Workers use disposable HOME/app/data/key/ports and synthetic credentials only.
No agent may read/decrypt/print/grep/diff/migrate real plaintext secrets, including
the master key and administrator delivery file.

1. Obtain the **final reviewed merged** Post seed, merged source revision,
   SHA256, manifest verification command and owned native acceptance evidence
   from #4110. Record these together with the reviewed Kosmos HEAD and closure.
   The integration candidate with SHA256
   `143040fb12c32355f55d9299da39638b46c83319fc2c89b7199c2d2d27d987d2`
   is dirty, fixture-only and forbidden as the deployment seed.
   Final seed binding remains pending until Post supplies it.
2. From the reviewed Kosmos checkout, confirm clean HEAD and coordinate the
   maintenance window. Save public unit/PID baselines and system path, privately:

   ```sh
   set -eu
   umask 077
   post_backup="$HOME/backups/post-$(date -u +%Y%m%dT%H%M%SZ)"
   mkdir -m 0700 -p "$post_backup"
   readlink -f /run/current-system > "$post_backup/system-path"
   systemctl --user show flickgrove aru-cfl-dev aru-cfl-prod matrix-mcp-remote keet-mcp keet-mcp-serein -p Id -p MainPID -p ActiveState -p FragmentPath > "$post_backup/protected-units"
   systemctl --user cat lamplit-post-console > "$post_backup/old-public-unit"
   readlink -f "$HOME/.local/share/lamplit-post/console-current" > "$post_backup/old-release-path"
   systemctl --user stop lamplit-post-console
   cp -a "$HOME/.local/state/lamplit-post/console/koishi.yml" "$post_backup/preview-koishi.yml"
   ```

   These backup commands copy opaque private config without displaying it.
   Retain the old immutable release and Home Manager generation for rollback.
   Confirm Post has stopped, both 5140/18787 are released, and protected PIDs
   remain unchanged. Do not stop any other service or inspect its environment.
3. Set `post_seed` to the absolute final archive and `post_seed_sha256` to its
   reviewed hash, then initialize only an absent root. Do not overlay an
   initialized app. The archive contains root-relative contents:

   ```sh
   test "${post_seed#/}" != "$post_seed"
   printf '%s  %s\n' "$post_seed_sha256" "$post_seed" | sha256sum --check
   post_app="$HOME/.local/share/lamplit-post/app"
   test ! -e "$post_app"
   install -d -m 0700 "$HOME/.local/share/lamplit-post"
   mkdir -m 0700 "$post_app"
   tar --extract --gzip --file "$post_seed" --directory "$post_app" --no-same-owner
   chmod 0700 "$post_app"
   ```

   Verify the extracted artifact using the final Post handoff's manifest
   command. Stop on failure; keep Post stopped until the seed is corrected.
   The app is an operator-owned writable installation, not a release symlink.
4. Edit **only the new app YAML**, without reading the old config/key, to keep
   these explicit existing absolute paths:

   ```yaml
   plugins:
     post:
       data_dir: /home/neil/.local/state/lamplit-post/console/data
       master_key_file: /home/neil/.local/state/lamplit-post/console/keys/post.key
       port: 18787
   ```

   Preserve the seed's other native plugin entries, UI host 127.0.0.1/port 5140,
   `auth.admin.enabled:false`, `daemon.autoRestart:false`, empty account/binding
   settings and `logger.root: logs`. Native logs stay in app/logs **outside**
   exclusive Post data. Do not copy/reset/migrate the database, key or queue.
5. Select the exact Nix tools from the reviewed built unit's public PATH and
   ExecStart; use those same absolute pnpm/Node paths below. Do not use corepack,
   another checkout's toolchain or expand user Nix config into argv.
   Replace the placeholders with the public built paths:

   ```sh
   export PATH="<reviewed-pnpm-store-path>/bin:<reviewed-node24-store-path>/bin:<reviewed-coreutils-store-path>/bin:<reviewed-bash-store-path>/bin:$PATH"
   cd "$post_app"
   pnpm --version
   node --version
   pnpm run config-check
   install -d -m 0700 "$HOME/.local/state/lamplit-post/admin-delivery"
   pnpm run admin-provision --file "$HOME/.local/state/lamplit-post/admin-delivery/first-owner.txt"
   pnpm run config-check
   ```

   Provisioning is offline with Post stopped. It creates a new 0600 delivery
   file and prints only result/path; repeated provision never resets user0.
   Agents must never open that real file. Require reviewed fail-closed Auth
   evidence before activating management, even if no first-owner login yet.
6. Inspect impact before switching. Compare protected generated user unit
   files byte-for-byte with installed public unit files (not secret expanded
   configs). Inspect closure changes and the actual activation start/stop list:

   ```sh
   nix store diff-closures /run/current-system <reviewed-built-closure>
   sudo <reviewed-built-closure>/bin/switch-to-configuration dry-activate
   ```

   Only Post's unit is intentionally changed. Coordinate any unrelated impact
   with its owner before activation; never restart protected units to test Post.
   No Caddy/Tanka/DNS/certificate rollout is needed. Then, as regular Neil,
   Orc runs from the merged Kosmos checkout:

   ```sh
   nh os switch . -H wsl
   systemctl --user start lamplit-post-console
   systemctl --user is-active lamplit-post-console
   ss -ltn '( sport = :5140 or sport = :18787 or sport = :8787 )'
   curl --noproxy '*' --fail http://lamplit-post.localhost:17480/
   curl --noproxy '*' --fail --resolve lamplit-post.nuc.guion.io:443:10.80.12.5 https://lamplit-post.nuc.guion.io/
   ```

   Check protected PIDs against the fresh baseline. Require loopback listeners,
   native login/assets/WS and rejected unauthenticated management mutations.
   Human Neil alone reads the delivery file locally, logs in at the VPN URL as
   admin, changes password in native account settings, then deletes the file.
   Agents must not capture the password, login token or private config response.
   Use owned-fixture evidence for authenticated mutation acceptance.
7. Restart only Post; confirm readiness and unchanged manifest/lock/YAML/modules,
   persistent native identity and single provider ownership. Stop only Post and
   require both listeners/WS to close within 30 seconds, then start it.
   Unknown sends remain unresolved; never replay them automatically.
   Host `--resolve` evidence does not prove Mac scoped DNS/browser access;
   Neil's Mac VPN/OS DNS/login must separately pass before claiming it ready.

## Explicit updates and rollback

Before an update, stop only Post and privately snapshot the entire current app
(including manifest, lock, workspace/patches, modules, YAML, CLI and local Post
package). Do not print its content. Preserve existing data/key/queue in place.
From the final reviewed update handoff, replace only release-owned CLI/Post
resources and any reviewed patch changes. Preserve administrator dependency
choices and YAML. Explicitly run `pnpm install` with the reviewed tools to
refresh the local file dependency, then `pnpm run config-check` before start.
Never unpack a seed over the live initialized app or synchronize release trees.

For app rollback, stop only Post, retain the failed app privately, restore the
chosen complete matching app snapshot, config-check and start. Never restore an
older database over the current database, regenerate keys or replay unknown
sends. For first-replacement rollback, keep the new app privately, restore the
old preview config from the private backup to its original path, retain/restore
the saved launcher symlink, and restore the saved system/Home Manager generation.
The old public unit must point to its old release/config before starting Post.
Coordinate system rollback impact with other owners; do not blindly restart
their units. Keep the new Auth-bearing database/key untouched; do not reopen an
unauthenticated preview against enrolled accounts. If that safety condition
cannot be established, leave Post stopped. Ingress, ACME storage and unrelated
service state are not part of app rollback.
