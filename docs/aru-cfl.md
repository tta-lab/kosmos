# Aru access to CFL dev and prod

FlickNote #3895 adds two Node 24 Home Manager user services. iPhone Aru reaches
WSL through the existing Cloudflare Tunnel; no VPN or public host IP is needed.
Discovery is public. Pairing is required for chat, history and images.

| Node | Upstream | Loopback listener | Public origin | Install prefix | Persistent state |
| --- | --- | --- | --- | --- | --- |
| dev | `http://127.0.0.1:3082` | `127.0.0.1:8787` | `https://aru-dev.lamplit.run` | `~/.local/share/aru-cfl-dev` | `~/.local/state/aru-cfl-dev` |
| prod | `http://127.0.0.1:3084` | `127.0.0.1:8788` | `https://aru.lamplit.run` | `~/.local/share/aru-cfl-prod` | `~/.local/state/aru-cfl-prod` |

Each prefix has its own versioned `releases/`, `current` symlink and `config.json`.
Each state directory has an independent node identity, device grants, bound CFL
session, SQLite database and staged images. Never copy or rebind dev state to prod.
The services do not create companions, manage CFL, or use a source checkout.
Missing `current/src/cfl/cli.mjs` skips startup via `ConditionPathExists`;
this is waiting for installation, not a healthy running node.

## Prepare and verify the artifact

Use the fixed read-only aru-host commit `98bb251753a68c2158ac25fff924b4b7ff162784`
at `/home/neil/code/projects/lamplitisles/aru-host`. On Linux x64, with Node 24
and Bun 1.3.14 on PATH, run from ko (all build writes stay in a temporary copy):

```bash
work=$(mktemp -d)
chmod 700 "$work"
mkdir "$work/source" "$work/package"
git -C /home/neil/code/projects/lamplitisles/aru-host archive \
  98bb251753a68c2158ac25fff924b4b7ff162784 | tar -x -C "$work/source"
(cd "$work/source" && bun install --frozen-lockfile --cache-dir "$work/cache" && \
  ./package-release.sh "$work/aru-cfl-host-linux-x64.tar.gz")
sha256sum "$work/aru-cfl-host-linux-x64.tar.gz"
tar -xzf "$work/aru-cfl-host-linux-x64.tar.gz" -C "$work/package"
(cd "$work/source" && CFL_TEST_PACKAGE="$work/package" \
  node --test tests/cfl-package.test.mjs tests/cfl-text.test.mjs)
```

Keep the archive and hash in private local working storage, outside Git. The
package includes compiled contracts and production dependencies, including native
sharp for the build OS/architecture. Installer checks platform and dependency
loading. Verify an existing artifact against its recorded SHA-256 before extraction;
a fresh rebuild can have a different archive hash. Tests use fake CFL and temporary
state/ports. They do not establish live connectivity or iOS compatibility.

## Reviewed, unmerged branch deployment

Initial implementation only prepares config, package and evidence. After independent
Standards/high-risk Spec review of the exact current HEAD, the Orc dispatches deployment
from this PR branch. Keep the PR open and unmerged until Neil explicitly requests merge.

Before installation, inspect `ss -ltnp` for 8787/8788 and verify both hostnames' DNS
and routing ownership. An occupied port or unrelated owner of `aru.lamplit.run`
is a blocker to report, not permission to replace it. Record the status of
`codex-for-love-dev`, `codex-for-love-prod`, `keet-mcp` and `matrix-mcp-remote`
user units, plus system `cloudflared-tunnel-kepos`; do not restart existing CFL.
The read-only CFL CLI currently supplies no authorization callback to its HTTP
server, and the socket accepts loopback callers without Origin. Do not assume
this remains true after upstream changes. If authorization fails, stop and report
it; any required `--upstream-headers-file` handoff needs separately provisioned
private JSON and reviewed wiring, without inspecting credentials or disabling auth.

Run as neil, only after deployment dispatch. Set `package` to the extracted,
verified artifact; `umask` protects the installer configuration and runtime files:

```bash
umask 077
package=/absolute/path/to/verified/package
install -d -m 0700 /home/neil/.local/share/aru-cfl-dev /home/neil/.local/share/aru-cfl-prod
(cd "$package" && ./install.sh \
  --prefix /home/neil/.local/share/aru-cfl-dev \
  --data-dir /home/neil/.local/state/aru-cfl-dev \
  --cfl-origin http://127.0.0.1:3082 --base-url https://aru-dev.lamplit.run)
(cd "$package" && ./install.sh \
  --prefix /home/neil/.local/share/aru-cfl-prod \
  --data-dir /home/neil/.local/state/aru-cfl-prod \
  --cfl-origin http://127.0.0.1:3084 --base-url https://aru.lamplit.run)
nh os switch . -H wsl
systemctl --user start aru-cfl-dev aru-cfl-prod
systemctl --user show aru-cfl-dev aru-cfl-prod -p ActiveState -p SubState -p ExecStart -p ConditionResult
systemctl show cloudflared-tunnel-kepos -p ActiveState -p SubState -p ExecStart
stat -c '%a %U %n' /home/neil/.local/state/aru-cfl-{dev,prod}
ss -ltnp '( sport = :8787 or sport = :8788 )'
```

`nh` reconciles managed ingress; any tunnel restart can briefly affect Keet/Matrix.
Inspect the running tunnel's ExecStart to find its loaded Nix-store config, then
run `cloudflared tunnel --config PATH ingress validate` and
`cloudflared tunnel --config PATH ingress rule https://aru-dev.lamplit.run/.well-known/aru.json`
(and the prod URL). Confirm exact destinations, existing Keet/Matrix rules, final
404 and HTTP2 transport; compare existing services' health to the preflight.
Never inspect the tunnel credential JSON. Do not hand-edit generated config.

## DNS and public boundary handoff

Cloudflare IPs and the earlier dev discovery 404 do not prove tunnel ownership.
No authenticated Cloudflare controlplane tool is supplied for this work. In the
operator's authorized Cloudflare dashboard, identify the existing **kepos** tunnel
in the correct account and its UUID; in the `lamplit.run` zone inspect the exact
records (or effective wildcard) for both origins. They must be proxied CNAMEs to
that tunnel's `<UUID>.cfargotunnel.com`. Create only missing dedicated records;
report conflicts before changing another owner's record. Do not change tunnel
credentials or existing hostname rules. [Cloudflare DNS routing documentation](https://developers.cloudflare.com/cloudflare-one/networks/connectors/cloudflare-tunnel/routing-to-tunnel/dns/)
explains the CNAME target and authenticated CLI alternative; no credential fallback
or account/zone guessing is part of this handoff.

Ensure these origins have no Access login/service-token requirement, cached API
responses, or JavaScript challenge that the native client cannot satisfy. Verify
actual responses from the phone's external network, independently for both origins:

```bash
curl -fsS https://aru-dev.lamplit.run/.well-known/aru.json
curl -fsS https://aru.lamplit.run/.well-known/aru.json
curl -sS -o /dev/null -w '%{http_code}\n' https://aru-dev.lamplit.run/aru/v1/diagnostics
curl -sS -o /dev/null -w '%{http_code}\n' https://aru.lamplit.run/aru/v1/diagnostics
```

Require protocol JSON discovery **200** and protected-route **401** without a device
credential. Check the same paths on each loopback listener. 404, Cloudflare 403,
redirect/login HTML or 502 are failures. Paired diagnostics must also report CFL
available with the intended existing session; inspect privately, without logging
chat or credentials. Do not send deployment test messages or trigger real models.

## Private pairing and iOS acceptance

Pair dev first, then prod. For each, set `name=dev` or `name=prod` below. Service stdout
is a private `pairing.log`, truncated at restart; stderr alone goes to the journal.
Do not paste pairing links, QR images, grants or private diagnostics into reports/PRs.
Each token expires after ten minutes and works once; restarting/reissuing replaces
the bootstrap token, while existing node identity and device grants persist.

```bash
umask 077
name=dev
state="/home/neil/.local/state/aru-cfl-$name"
current="/home/neil/.local/share/aru-cfl-$name/current"
# Reissue using the fork CLI; retain the startup envelope's node and public origin.
node "$current/aru-selfhostctl" pairing "$state" > "$state/pairing-token.json"
node -e 'const fs=require("fs");const d=process.argv[1];
const e=JSON.parse(fs.readFileSync(d+"/pairing.log","utf8").split("\n")[0]);
e.pairingToken=JSON.parse(fs.readFileSync(d+"/pairing-token.json","utf8")).token;
process.stdout.write("aru://pair?"+new URLSearchParams(e));' "$state" \
  | nix shell --inputs-from . nixpkgs#qrencode -c qrencode -o "$state/pairing.png"
# Display this private PNG locally; scan in Aru. Never upload it to a public QR tool.
node "$current/aru-selfhostctl" devices "$state"
# To revoke only this node's selected device:
node "$current/aru-selfhostctl" revoke "$state" DEVICE_ID
```

For **each node**, Neil verifies the existing companion and session, older history,
a text exchange, image upload/download, both-end synchronization, Wi-Fi/cellular
reconnect and a separately coordinated adapter restart. Neil sends the real messages.
Unknown admission means inspect CFL's existing operation before retrying; never
automatically resend an uncertain intent. Revoked-device reads must fail (403);
expiry/reuse must reject bootstrap (401). Record dev and prod iOS **PENDING** until
Neil supplies separate results; server readiness is not phone acceptance.

## Stop and recover

Stop only `systemctl --user stop aru-cfl-dev` or `aru-cfl-prod`. Preserve private state;
back it up with that adapter stopped (including SQLite WAL files), or SQLite backup.
For package failure, restore that prefix's `current` to retained `previous` if present,
restart only that adapter and recheck identity/diagnostics. First installs have no
previous package: remain stopped until repaired. Never delete state to force identity.
To withdraw exposure, remove only the affected Aru hostname's managed ingress in
`modules/wsl/kepos-tunnel.nix`, review/build/switch the branch and retain Keet/Matrix,
credentials and default 404. If retiring both, disable `kosmos.wsl.aruCfl.enable`.
Remove only dedicated Aru DNS records after checking ownership, never a shared wildcard.
PR remains unmerged even after successful server or phone verification.
