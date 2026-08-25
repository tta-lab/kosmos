# DeepSeek Harness (DSH) deployment

Operational companion to `docs/dsh-mcp-integration.md` (integration surface)
and `docs/secrets.md` (key rotation). Covers how the DSH runtime is installed,
upgraded, swapped, rolled back, and how plugins are managed — the steps that
`modules/wsl/deepseek-harness.nix` intentionally leaves outside the Nix closure.

## Component map

| Piece | Location | Managed by |
|---|---|---|
| Runtime tree | `/home/neil/.local/share/dsh-runtime` | Not Nix; standalone npm tree, installed with bun |
| Service unit | Home Manager user service `dsh.service` | `modules/wsl/deepseek-harness.nix` |
| Profile/plugin tree | `/home/neil/.local/state/dsh/profiles/web/node_modules` (`DSH_HOME` = `/home/neil/.local/state/dsh`) | `dsh plugin --profile web add …` (pnpm) |
| Secret | agenix `openclaw-deepseek-key` → `/home/neil/.config/openclaw/deepseek-key` | `secrets/` + `modules/wsl/secrets.nix` |
| Exposure | loopback `127.0.0.1:3080` only; Kepos publishes service `dsh` → `http://dsh.localhost:17480` (Mac + Pixel 7a) | `modules/wsl/deepseek-harness.nix` (listener); `kepos/publisher-policy.jsonnet` + `just kepos-policy-render` (Kepos policy) |
| MCP overlay | `modules/wsl/deepseek-harness-mcp.cordis.yml`, passed as immutable `--patch` | this repo |

The service command line, environment, and restart policy live in
`modules/wsl/deepseek-harness.nix` — that file is the single source of truth;
do not duplicate it here. The launcher reads the agenix key at process start
and exports `DEEPSEEK_API_KEY` only inside the service process.

All commands below use paths verbatim. The runtime path
`/home/neil/.local/share/dsh-runtime` is defined once, in the Component map
and in `modules/wsl/deepseek-harness.nix` — keep both in sync and do not
introduce variant spellings.

DSH is an upstream **developer preview** (`npx @deepseek-ai/dsh web` is the
official install per its README); breaking changes are expected, so runtime
upgrades are routine maintenance, not incidents.

## Build a new runtime tree

Distribution channel is the public npm registry — the fork's "packed tree"
(230 `file:` tarball deps into a deleted `/tmp` dir) is obsolete. Use **bun**,
not npm: npm 11 hangs CPU-bound on the dsh dependency graph (see
Troubleshooting). Same `node_modules` shape either way; the service runs under
the Nix-pinned node regardless. Always build a **fresh staging tree** and swap
it in — never `bun add` into the live tree.

1. Check the latest published version:
   ```bash
   npm view @deepseek-ai/dsh version
   ```
2. Build the staging tree:
   ```bash
   mkdir -p /home/neil/.local/share/dsh-runtime.new
   cd /home/neil/.local/share/dsh-runtime.new
   bun add @deepseek-ai/dsh@<version>
   bun pm trust --all   # required: koffi native binding + dsh-subprocess-local helper
   ```
3. **Done when** `node -e "console.log(require('./node_modules/@deepseek-ai/dsh/package.json').version)"`
   prints the target version, and `node -e "require('koffi')"` succeeds.

`bun` writes `bun.lock` + `package.json` into the staging tree; harmless
metadata, the service never reads them.

## Deploy a new runtime tree (swap)

1. `systemctl --user stop dsh`
2. Back up: `mv /home/neil/.local/share/dsh-runtime /home/neil/.local/share/dsh-runtime.<old-version>.bak`
3. Move the staging tree in: `mv /home/neil/.local/share/dsh-runtime.new /home/neil/.local/share/dsh-runtime && chmod 0700 /home/neil/.local/share/dsh-runtime`
4. `systemctl --user start dsh`
5. **Done when** all of:
   - `systemctl --user is-active dsh` prints `active`
   - `ss -tlnp | grep 3080` shows `LISTEN 127.0.0.1:3080`
   - `pgrep -af "flicknote mcp|miniflux-mcp"` shows both stdio children
   - `journalctl --user -u dsh --since "-1 min"` has no `error`/`fail` lines
   - the running process cmdline (`ps -ef | grep dsh/lib/bin.js`) points at the
     new tree

## Rollback

1. `systemctl --user stop dsh`
2. Swap back: `mv /home/neil/.local/share/dsh-runtime /home/neil/.local/share/dsh-runtime.broken` and
   `mv /home/neil/.local/share/dsh-runtime.<old-version>.bak /home/neil/.local/share/dsh-runtime`
3. `systemctl --user start dsh`, then re-run the deploy verification checklist.

## Plugins (profile tree)

- Install: `DSH_HOME=/home/neil/.local/state/dsh ~/.local/share/dsh-runtime/node_modules/.bin/dsh plugin --profile web add <pkg>`
  Packages land in `$DSH_HOME/profiles/web/node_modules` via pnpm — a tree
  independent of the runtime.
- A plugin registers its client bundle by the **exact package name** via
  `window.__ModuleLoader__.load({ id, factory })`; a mismatch surfaces in the
  browser console as `loaded without registering "<pkg>" via __ModuleLoader__.load`.
- Known case: `@liniukesi/dsh-voice-input@0.1.0` publishes the placeholder id
  `@yourname/dsh-voice-input`. Local workaround:
  ```bash
  sed -i 's|@yourname/dsh-voice-input|@liniukesi/dsh-voice-input|' \
    /home/neil/.local/state/dsh/profiles/web/node_modules/@liniukesi/dsh-voice-input/lib/client.js
  systemctl --user restart dsh
  ```
  Caveat: the profile file is hardlinked into the pnpm store (link count 2);
  a later `dsh plugin` operation may restore the store copy, so a fix must
  eventually ship upstream (registry still has only 0.1.0 as of 2026-08).
- MCP servers are configured independently of plugin installation: Kosmos's
  stdio executables are host-managed and wired through the immutable `--patch`
  overlay (see `docs/dsh-mcp-integration.md`). A DSH bundle plugin can package
  a Cordis patch (including MCP config), but that does not install or
  supervise the server executable.

## Troubleshooting

- **npm install hangs** (CPU ~100%, RSS grows past 500 MB, verbose log frozen for
  tens of seconds): npm 11 idealTree resolution explosion over the dsh family
  graph (200+ packages, many rc versions each). It is **not** a proxy problem —
  prove it: `curl -w '%{time_total}' https://registry.npmjs.org/@deepseek-ai/dsh`
  is fast and `npm view` answers instantly. Fix: install with bun.
- **In-place `npm install` in the runtime tree fails/hangs**: the tree's root
  `package.json` can carry stale `file:/tmp/…tgz` deps pointing at a deleted
  directory (old packed-tree era). Always build a fresh tree and swap.
- **Diagnosing a stuck npm**: `nohup npm install --loglevel=verbose > log &`,
  poll `tail log`, and `ps -o pcpu,rss,etime -p <pid>`. Frozen log + busy CPU
  = resolution explosion, not network.
- **Killing npm**: never `pkill -f` a pattern that also appears in your own
  shell command text — it kills your own shell. Kill by exact process name
  (`pgrep -x npm`) or PID.
- **Rollback is a rename**: keep every replaced tree as `dsh-runtime.<version>.bak`;
  no reinstall needed to go back.
