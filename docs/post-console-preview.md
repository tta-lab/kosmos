# Post Console VPN preview

This is the native Koishi Console welcome shell and status footer preview, with
zero accounts, agent bindings, consumers or issued tokens. It is read-only, without Console
config/market/write RPC or authentication, within the existing VPN boundary.
It is not the production Post administration interface.

The Home Manager user unit `lamplit-post-console` uses Nix Node 24 and the
complete immutable Post release selected by `kosmos.wsl.postConsole.artifact`
(default `~/.local/share/lamplit-post/console-current`). Startup performs no
install, download or pull. Missing CLI/template skips startup with a diagnostic.
The release supplies `dist/cli.cjs` and `examples/koishi.preview.yml`, including
all native resources/dependencies. Confirm this contract against the reviewed
Post #4091 release before activation; Nix evaluation cannot prove it.

The unit starts `serve --config ~/.local/state/lamplit-post/console/koishi.yml`.
Bootstrap materializes the sole canonical artifact template only when that YAML
is absent. It resolves the selected prefix to its immutable absolute release
root, requires exactly four `__POST_ARTIFACT_ROOT__` substitutions and rejects
relative roots, apostrophes, control characters, `:` and literal `${{` in
that root. The four plugin keys name the
packaged server `index.cjs`, Console `lib/node/index.js`, status `lib/index.js`
and Post `dist/post-plugin.cjs` executables; directory lookup is not used.
The private config parent permits the native loader's temporary file/rename;
`data/` and `keys/` are separate private children. Post owns automatic key
initialization outside data. No Nix-store secret, environment credential or
operator master-key creation is needed. Restarts preserve operator YAML edits;
new release templates are not synchronized into existing configuration. Existing
YAML pins the materialized release paths: review and update those four paths
explicitly for an upgrade, retaining the previous YAML for rollback.

Only Console `127.0.0.1:5140` is reverse-proxied, at
`https://lamplit-post.nuc.guion.io/` and `http://lamplit-post.localhost:17480/`.
The empty Post root's MCP listener `127.0.0.1:18787` remains unexposed. Caddy
preserves native asset and WebSocket paths, and existing TLS/source restrictions.
Port 18787 is an explicit preview setting because active `aru-cfl-dev` owns
8787; normal Post defaults remain unchanged. No Kubernetes, Kepos policy, DNS,
CA or Cloudflare resource change is required.

## Orc activation after both repositories pass review and merge

Do not activate from an unreviewed mutable Post checkout. First obtain the
exact merged Post artifact, manifest/hash, native HTML/assets/WS smoke and RPC
surface evidence from #4091. Reject any credential/config/market/write RPC.
Extract it into a fresh versioned release directory and verify the published
manifest there. Point `console-current` atomically to that complete release;
keep the old target for rollback. Do not overwrite app-owned YAML.

From the reviewed Kosmos checkout, preserve concurrent edits and confirm HEAD.
Use the already built closure recorded in the implementation report for the
impact comparison; inspect public unit metadata only, never environments or
secret files:

```sh
readlink -f /run/current-system
readlink -f ~/.local/share/lamplit-post/console-current
systemctl --user show flickgrove aru-cfl-dev aru-cfl-prod matrix-mcp-remote keet-mcp keet-mcp-serein -p ActiveState -p FragmentPath
ss -ltn '( sport = :5140 or sport = :18787 )'
nix store diff-closures /run/current-system <reviewed-built-closure>
sudo <reviewed-built-closure>/bin/switch-to-configuration dry-activate
```

Save the old system path, launcher target and any existing preview YAML privately
outside Git (no logs/content dumps). Stop if either application port has another
owner. Inspect the dry activation's actual start/stop/restart list and compare
Home Manager generated user units with their current public unit files. Caddy
reload and the new Post unit are expected. Coordinate any unexpected impact to
FlickGrove, CFL, Matrix or Keet before proceeding; never restart them to test Post.
Do not repeat the original VPN rollout's Kubernetes apply or certificate steps.

```sh
nh os switch . -H wsl
systemctl --user status lamplit-post-console --no-pager
systemctl status caddy --no-pager
ss -ltn '( sport = :5140 or sport = :18787 )'
curl --noproxy '*' --fail http://lamplit-post.localhost:17480/
curl --noproxy '*' --fail --resolve lamplit-post.nuc.guion.io:443:10.80.12.4 https://lamplit-post.nuc.guion.io/
curl --noproxy '*' --resolve unknown.nuc.guion.io:443:10.80.12.4 https://unknown.nuc.guion.io/
```

Require loopback-only listeners and trusted TLS without `-k`. Verify every native
referenced asset and a WebSocket status exchange at `/status` (HTTP serves the
SPA welcome fallback there; the same path supports WS upgrade). Open the VPN
URL in a browser and capture the native welcome shell and status footer widgets/
tooltips. Status has no separate routed page; no additional UI plugin is needed.
Confirm forbidden/sensitive RPCs remain absent, rather than
inferring read-only behavior from buttons. Check representative old routes,
unknown-host 421, outside-VPN 403 and storage-only Pod exception. The latter
source checks need actual matching clients; do not spoof X-Forwarded-For.

Restart only `systemctl --user restart lamplit-post-console` and repeat readiness;
stop only this unit to verify both listeners/WS close within 30 seconds, then
start it again. Confirm YAML persists without printing private state. No IM,
model, webhook delivery, account binding or token issuance belongs in acceptance.
Direct `dig @192.168.6.1 lamplit-post.nuc.guion.io A` already returns `10.80.12.4`.
`--resolve` proves the selected ingress path; Mac OS DNS/VPN/browser acceptance
must separately pass before claiming the user URL ready.

## Rollback

Stop only `systemctl --user stop lamplit-post-console`. Restore the saved
launcher symlink atomically and, only if changed during this rollout, restore
this preview's saved YAML privately. Run
`sudo <saved-system>/bin/switch-to-configuration switch` and restore the saved
Home Manager generation if its user-unit profile did not follow the system
rollback. Inspect the restored user unit before starting it; on a first install
leave Post stopped/disabled if the prior generation has no unit. Verify old
routes and preserved service states. Retain the preview state for investigation;
do not copy/reset other app data, remove Caddy certificate storage, revoke
credentials or alter DNS as part of rollback.
