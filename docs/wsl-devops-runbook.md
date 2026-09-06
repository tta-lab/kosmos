# WSL DevOps Runbook

The WSL DevOps stack runs in the single-node NixOS k3s cluster. Nix manages
k3s and the Kepos publisher and subscriber lifecycle; the publisher's live
service and ACL policy is modeled in Jsonnet and rendered into an unmanaged
TOML file. Tanka manages the Kubernetes objects. A NixOS switch never applies
Tanka.

## Endpoints

- Forgejo: `http://forgejo.localhost:17480`
- Woodpecker: `http://woodpecker.localhost:17480`
- Dagger: `tcp://dagger.devops.svc.cluster.local:8080` in-cluster and
  `tcp://127.0.0.1:8080` for the local CLI
- DeepSeek Harness: `http://dsh.localhost:17480` through Kepos (Mac + Pixel 7a)
- Codex Bridge: `http://codex-bridge.localhost:17480` through Kepos (Mac + Baihe)
- k3s API: `https://127.0.0.1:26443`
- Anki Sync: `http://anki.localhost:17480/` through Kepos
- Cloudreve: `http://cloudreve.localhost:17480` through Kepos
- Miniflux: `http://miniflux.localhost:17480` through Kepos
- Hindsight API and MCP: `http://hindsight.localhost:17480` through Kepos
- Hindsight Control Plane: `http://hindsightui.localhost:17480` through Kepos
- ERPNext: `http://erpnext.localhost:17480` through Kepos
- Grafana: `http://grafana.localhost:17480` through the loopback gateway and
  full-trust Kepos subscribers
- Impri: `http://impri.localhost:17480` through Kepos (Mac + Pixel 7a)

For Kubernetes-backed HTTP apps, Caddy binds the host gateway only on
`127.0.0.1:17480`. CoreDNS rewrites their canonical `.localhost` names to that
same gateway inside the cluster. This keeps browser, Git, Woodpecker OAuth,
webhooks, and container-registry URLs consistent. The remaining direct
loopback HTTP service bypasses Caddy and CoreDNS; see the service model below.

Kepos publishes application service IDs including:

- `forgejo` and `woodpecker` both target port `17480`; the preserved HTTP Host
  header selects the Caddy route.
- `navidrome` targets port `4533`.
- `dsh` targets its loopback-only Home Manager user service on port `3080` and
  is restricted to the Mac and Pixel 7a subscribers. Kepos exposes it as
  `http://dsh.localhost:17480`; it has no Caddy or CoreDNS route.
- `codex-bridge` targets the canonical gateway on port `17480` and is
  restricted to the Mac, NUC Windows, Baihe, and the named Bridge subscriber.
  Caddy routes `codex-bridge.localhost` to the Kubernetes Bridge Service. The
  Pod runs as Neil's UID/GID and mounts `/home/neil/.codex` read-write so the
  Bridge and Codex CLI share the same atomically refreshed `auth.json`.
- `dagger` targets the Dagger engine on port `8080` and is restricted to the
  named Mac subscriber. Other allowed subscribers neither see nor can open it.
- `ssh` targets port `22`.
- `anki` targets the canonical gateway on port `17480`; see
  [anki-sync.md](anki-sync.md) for credentials, deployment, and first sync.
- `cloudreve` targets the canonical gateway on port `17480`; see
  [cloudreve.md](cloudreve.md) for the Micron-backed storage, deployment, and
  Sven subscriber placeholder.
- `hindsight` and `hindsightui` are Mac-only services targeting the canonical
  gateway on port `17480`; the preserved Host header selects the API or Control
  Plane route. See [hindsight.md](hindsight.md) for deployment and storage
  details.
- `miniflux` targets the canonical gateway on port `17480`; the preserved HTTP
  Host header selects the RSS reader route. See [miniflux.md](miniflux.md) for
  credentials and first login.
- `erpnext` targets the canonical gateway port `17480`; the preserved HTTP Host
  header selects the ERPNext service route.
- `grafana` targets the canonical gateway port `17480`; the preserved HTTP Host
  header selects the Kosmos-owned observability Grafana route. It is restricted
  to the full-trust subscriber set.
- `impri` targets the canonical gateway port `17480`; the preserved HTTP Host
  header selects the private Approval Inbox route. It is restricted to the Mac
  and Pixel 7a subscribers. See [impri.md](impri.md) for deployment and local
  SQLite persistence.

## Kepos service model: HTTP web services vs raw TCP

The current live policy leaves publisher `kind` unset, so every service is a
TCP tunnel to a WSL loopback port (`target_port`). How a peer reaches a service
depends on the *kind* of service, decided on the subscriber side (Kepos
Desktop / CLI), not by the publisher:

- **Gateway-routed HTTP web services** (`bookorbit`, `forgejo`,
  `woodpecker`, `memos`, `anki`, `hindsight`, `hindsightui`, `codex-bridge`,
  `miniflux`, `ente`, `erpnext`, `grafana`, `impri`, …): target the canonical gateway port `17480` and are
  routed by the preserved `Host` header.
- **Direct loopback HTTP services** (`dsh`): a Home Manager user service binds
  its own `127.0.0.1` port and Kepos publishes that port directly. It has no
  Tanka environment, Caddy route, or CoreDNS rewrite.
- **Raw TCP/SSH services** (`dagger`, `mihomo`, `ssh`): the peer must add a
  `[[subscriber.services]]` entry with a free `local_port` to its
  `~/.config/kepos/config.toml` and restart Kepos Desktop; seeing the service
  in the list alone does not create the local listener.

Both kinds of HTTP service reach the peer through the subscriber gateway at
`http://<id>.localhost:17480` (the default is `17480`,
`DEFAULT_GATEWAY_PORT` in kepos-neo). **No `[[subscriber.services]]` entry is
needed.** The Kepos desktop UI shows HTTP services with an Open action and raw
TCP/SSH services with a Copy command/URL action. The handler table lives in
`kepos-neo` `src/runtime/service-handlers.ts` (`httpUrl` → HTTP,
`localCommand` → TCP/SSH); unknown ids fall back to the HTTP handler.

Do not add `[[subscriber.services]]` entries for any HTTP service — the
subscriber gateway port already serves them all. Adding a gateway-routed HTTP
app needs a Tanka environment, gateway route, and
`[[publisher.services]]` entry in the live policy with `target_port = 17480`.
Adding a direct loopback HTTP app needs a Home Manager user service bound to
`127.0.0.1` plus its direct-port publisher entry in the live policy.

The separate Ente Photos stack publishes `ente` and `ente-storage`, both through
the canonical gateway on port `17480`. See [ente-photos.md](ente-photos.md) for
its deployment order and mobile acceptance checks.

Local WSL clients connect directly to their loopback target: Caddy for
gateway-routed apps or the service port for direct loopback apps. They do not
traverse Kepos.

## Kepos live publisher policy

`kepos/publisher-policy.jsonnet` is the complete publisher policy source. It
keeps named subscriber keys, reusable ACL groups, and service declarations in
code. Render it with:

```bash
just kepos-policy-render
```

The renderer writes `~/.config/kepos/publisher.toml` privately and atomically
in the same directory; that TOML is the unmanaged runtime output, not a file to
edit by hand. The source is versioned in this checkout, but rendering an
uncommitted policy edit neither requires a Git commit nor a NixOS switch.
A fresh publisher needs a complete rendered policy and initialized publisher
state before its user service is enabled.

Kepos reads a valid save within about one second. An invalid or incomplete TOML
keeps the last valid policy active and reports the reload failure in
`journalctl --user -u kepos-publisher.service -n 100 --no-pager`; no Nix
switch, Git commit, or Kepos restart is needed. Removing a labeled subscriber
from `publisher.subscribers` disconnects that subscriber; service and
per-service ACL changes apply to new registry requests and newly opened
tunnels while existing tunnels drain.

The labeled subscriber list is the outer gate and each service `allow` list can
only narrow it. A service with no `allow` inherits the full subscriber set; an
explicit empty list denies that service to everyone. Define those relationships
in Jsonnet rather than copying keys between service entries:

```jsonnet
local subscribers = {
  mac: {label: 'mac', public_key: '<subscriber-public-key>'},
};
local trusted = [subscribers.mac.public_key];
local service(id, name, port, allow) = {
  id: id,
  name: name,
  target_port: port,
  allow: allow,
};
```

Leave `kind` unset for the current TCP-tunnel behavior. `kind = "http"` is an
optional publisher-side HTTP/1.1 adapter that removes caller-provided
`Authorization` and injects `Authorization: Kepos <subscriber-public-key>` at
the target; use it only for a private plaintext HTTP target that explicitly
authorizes that header. It is not a TLS, HTTP/2, or generic reverse-proxy mode.

Keep a private backup of the source and its rendered output. Because the unit
passes the output explicitly with `--config`, a missing policy makes the
service fail closed rather than falling back to state-owned policy.

## Configuration checks

These commands do not change the cluster:

```bash
just show
just diff
just status
just observability-show
just observability-diff
just observability-status
```

`just apply` is the explicit normal apply command. It refuses any kubeconfig
whose active API server is not `https://127.0.0.1:26443`.

## Publisher observability

The publisher is pinned to Kepos commit
`105a22fc963c195f0ec03f6b0a76e037e31e4865`. Its metrics listener binds to
`10.255.255.1:9475` and is reachable only on the k3s CNI interface; it is
not published through Kepos or the application gateway. A dedicated
VictoriaMetrics single-node deployment scrapes that endpoint every 15 seconds,
retains 30 days of data, and stores it on the retained local volume at
`/var/lib/kosmos-k3s/observability/victoria-metrics`.

Grafana is available at `http://grafana.localhost:17480` through the canonical
gateway. It has one VictoriaMetrics datasource and mounts the Kepos-owned
`grafana-dashboard` artifact from the Nix system profile read-only. The
dashboard is retained with Grafana data under
`/var/lib/kosmos-k3s/observability/grafana`; Energy/ClickHouse dashboards and
datasources are intentionally not installed.

Initialize the local Grafana admin Secret (the command refuses a remote
kubeconfig and is idempotent), then inspect or apply the observability
environment explicitly:

```bash
just observability-secrets
just observability-show
just observability-diff
just observability-apply
just observability-status
just observability-deploy
```

`observability-secrets`, `observability-apply`, and `observability-deploy` are
the only mutating observability recipes; each is gated to the local k3s API.
`observability-deploy` applies the environment and then refreshes the
canonical gateway route. No observability command is run as part of a NixOS
switch.

## Deploy

Deploy the NixOS generation first so k3s, its directories, the Woodpecker
Secret sync unit, the packaged Kepos CLI, and the user service exist:

```bash
nh os switch . -H wsl --ask
```

Open a new WSL shell after the switch so the session picks up membership in
the `k3s` group.

The root-owned `woodpecker-secret-sync.service` reads
`/run/agenix/woodpecker-server-env` and
`/run/agenix/woodpecker-postgres-env`, then creates or updates the matching
`devops/woodpecker-server-env` and `devops/woodpecker-postgres-env` Secrets. It
always uses `/etc/rancher/k3s/k3s.yaml` and refuses an API server other than
`https://127.0.0.1:26443`. The unit runs at boot, retries if k3s is not ready,
restarts when either encrypted agenix file changes, and rolls the Woodpecker
server, agents, and PostgreSQL StatefulSet when either Kubernetes Secret is
updated.

Verify the sync before applying the workloads:

```bash
systemctl status woodpecker-secret-sync.service --no-pager
```

The custom Kepos user unit reuses publisher state at
`~/.local/state/kepos-neo/mux-publisher` and reads the rendered live policy at
`~/.config/kepos/publisher.toml`. It deliberately does not create or modify
either. Render `kepos/publisher-policy.jsonnet` before starting a fresh
publisher. The live policy is intentionally not a Home Manager-managed
`~/.config` file.

Print the WSL publisher public key without exposing its private state:

```bash
just kepos-publisher-key
```

The WSL subscriber for the Mac publisher is declaratively disabled because the
current nested network cannot establish that direction. Its configuration,
identity, pinned publisher contact, and state at
`~/.local/state/kepos-neo/subscriber` remain intact for a future retry. The Mac
publisher may keep the WSL subscriber key in its allowlist.

While disabled, WSL does not listen on the subscriber gateway `17481` or the
local SSH endpoint `127.0.0.1:2222`. To inspect the retained subscriber public
key without starting the service:

```bash
just kepos-subscriber-key
```

Do not remove the subscriber state or Mac allowlist entry. Resume this direction
only after selecting and verifying a network or relay path from orientation
notes 1724 and 1725, then set `enableMacSubscriber` in
`modules/wsl/kepos-neo.nix` to `true` and rebuild WSL.

Apply the Kubernetes objects explicitly:

```bash
just diff
just apply
just status
```

Forgejo and Woodpecker use static local PVs with a `Retain` reclaim policy.
Dagger starts with a fresh cache at `/var/lib/kosmos-k3s/dagger`.

## Seafarer CA trust

The public Seafarer Root CA is declarative WSL trust policy in
`certs/seafarer-root-ca.pem`; Node receives the evaluated NixOS CA bundle via
the managed `NODE_EXTRA_CA_CERTS` session variable. Apply it with the normal
WSL rebuild:

```bash
nh os switch . -H wsl --ask
```

Open a fresh shell after activation so Node receives the session variable. To
replace the Root CA, update that PEM in a reviewed configuration change and
rebuild; do not retain a mutable `/usr/local` copy or disable TLS verification.

## DeepSeek Harness runtime

The `dsh` Web profile runtime is a standalone npm tree outside the Nix
closure. Install, upgrade, swap, rollback, and plugin troubleshooting:
[`docs/dsh-deployment.md`](dsh-deployment.md).

## Recover

Reapplying NixOS or Tanka does not delete the retained Forgejo and Woodpecker
PostgreSQL data under `/var/lib/kosmos-k3s`. There is no legacy-systemd rollback
command. Forgejo source recovery, including its SQLite-consistent metadata
snapshot, is documented in the [Forgejo Source Recovery Backup runbook](forgejo-backup.md).
That backup intentionally excludes Packages/OCI artifacts and is not a full
Forgejo-instance restore.

If the Woodpecker Secret is missing or stale, repair the encrypted secret,
rebuild NixOS, and verify the sync unit. To retry without changing the secret:

```bash
sudo systemctl restart woodpecker-secret-sync.service
sudo journalctl -u woodpecker-secret-sync.service -n 100 --no-pager
just apply
```

### Back up Woodpecker PostgreSQL

Woodpecker does not back up its database. Create a private custom-format dump
from the PostgreSQL pod and validate that the archive can be listed. The dump
contains operational metadata and must be handled as a secret:

```bash
woodpecker_backup_dir=/home/neil/backups/woodpecker
install -d -m 0700 "$woodpecker_backup_dir"
woodpecker_dump_name="woodpecker-$(date -u +%Y%m%dT%H%M%SZ).dump"
woodpecker_dump="$woodpecker_backup_dir/$woodpecker_dump_name"

KUBECONFIG=/etc/rancher/k3s/k3s.yaml \
  kubectl -n devops exec statefulset/woodpecker-postgres -- \
    pg_dump --username=woodpecker --dbname=woodpecker --format=custom \
    > "$woodpecker_dump"

test -s "$woodpecker_dump"
KUBECONFIG=/etc/rancher/k3s/k3s.yaml \
  kubectl -n devops exec -i statefulset/woodpecker-postgres -- \
    pg_restore --list < "$woodpecker_dump" >/dev/null
(
  cd "$woodpecker_backup_dir"
  sha256sum "$woodpecker_dump_name" > "$woodpecker_dump_name.sha256"
)
chmod 0600 "$woodpecker_dump" "$woodpecker_dump.sha256"
```

Copy both files to separate protected storage. A dump left only on this WSL
filesystem does not protect against host or disk loss.

### Restore Woodpecker PostgreSQL

Restore only from a validated custom-format dump. First take a fresh safety
backup of the current database with the procedure above. Then set the explicit
archive path, stop Woodpecker writers, and restore in one transaction:

```bash
woodpecker_backup_dir=/home/neil/backups/woodpecker
woodpecker_dump_name=woodpecker-YYYYMMDDTHHMMSSZ.dump
woodpecker_dump="$woodpecker_backup_dir/$woodpecker_dump_name"
test -s "$woodpecker_dump"
(
  cd "$woodpecker_backup_dir"
  sha256sum --check "$woodpecker_dump_name.sha256"
)
KUBECONFIG=/etc/rancher/k3s/k3s.yaml \
  kubectl -n devops exec -i statefulset/woodpecker-postgres -- \
    pg_restore --list < "$woodpecker_dump" >/dev/null

KUBECONFIG=/etc/rancher/k3s/k3s.yaml \
  kubectl -n devops scale statefulset/woodpecker-agent --replicas=0
KUBECONFIG=/etc/rancher/k3s/k3s.yaml \
  kubectl -n devops scale deployment/woodpecker --replicas=0
KUBECONFIG=/etc/rancher/k3s/k3s.yaml \
  kubectl -n devops rollout status deployment/woodpecker --timeout=120s
KUBECONFIG=/etc/rancher/k3s/k3s.yaml \
  kubectl -n devops rollout status statefulset/woodpecker-agent --timeout=120s

KUBECONFIG=/etc/rancher/k3s/k3s.yaml \
  kubectl -n devops exec -i statefulset/woodpecker-postgres -- \
    pg_restore --username=woodpecker --dbname=woodpecker \
      --clean --if-exists --no-owner --exit-on-error --single-transaction \
      < "$woodpecker_dump"

just apply
KUBECONFIG=/etc/rancher/k3s/k3s.yaml \
  kubectl -n devops rollout status deployment/woodpecker --timeout=120s
KUBECONFIG=/etc/rancher/k3s/k3s.yaml \
  kubectl -n devops rollout status statefulset/woodpecker-agent --timeout=120s
curl --fail http://woodpecker.localhost:17480/healthz
```

After restore, verify Forgejo login, repository activation, historical builds,
and one representative pipeline before accepting new CI work. For a physical
directory restore instead, stop the PostgreSQL StatefulSet before touching
`/var/lib/kosmos-k3s/woodpecker-postgres`, preserve the ownership declared by
the NixOS tmpfiles rule, then run `just apply`. Never copy live PostgreSQL data
or restore data into a removed legacy service.

## Runtime checks

```bash
just status
kosmos-devops-gate-status --strict
just kepos-status
curl --fail http://forgejo.localhost:17480/api/healthz
curl --fail http://woodpecker.localhost:17480/healthz
```

To check that Dagger can pull and run a public image rather than only accepting
a socket connection:

```bash
dagger -M call container from --address alpine:3.20 \
  with-exec --args=echo --args=dagger-pull-ok stdout
```

The packaged Dagger 0.21.7 CLI defaults to the matching K3s engine at
`tcp://127.0.0.1:8080`.

## Mac Dagger client through Kepos

`dagger` is a raw TCP service, so it needs an explicit subscriber listener
(HTTP web services do not; see the service model above). On the Mac, add a raw
TCP listener for the published `dagger` service to
`~/.config/kepos/config.toml` under the existing subscriber configuration:

```toml
[[subscriber.services]]
id = "dagger"
local_port = 18080
```

Restart Kepos Desktop, then point the Mac Dagger CLI at that listener:

```bash
export _EXPERIMENTAL_DAGGER_RUNNER_HOST=tcp://127.0.0.1:18080
dagger core version
```

Port `18080` avoids colliding with a local Dagger engine. The Kepos publisher
must be deployed after adding the service; seeing `dagger` in the Mac service
list alone does not create the local TCP listener.
