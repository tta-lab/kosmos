# WSL DevOps Runbook

Forgejo and Woodpecker run on SW; see [SW migration and hosting](sw-devops-migration.md).
The WSL build host runs Dagger in the single-node NixOS k3s cluster. Nix manages
k3s and the Kepos publisher and subscriber lifecycle; the publisher's live
service and ACL policy is modeled in Jsonnet and rendered into an unmanaged
TOML file. Tanka manages the Kubernetes objects. A NixOS switch never applies
Tanka.

## Local host mappings

NixOS owns `/etc/hosts`; `wsl.wslConf.network.generateHosts = false` prevents
WSL from replacing it at startup. Keep service aliases in
`modules/wsl/k3s.nix` under `networking.hosts`. The WSL module preserves the
base hostname and IPv6 aliases from the former WSL-generated file.
After deploying this setting, check `/etc/hosts` and
`getent hosts grafana.localhost`. Repeat the checks after the next WSL restart to confirm
that WSL leaves the managed file intact. DNS resolver generation remains
owned by WSL.

## Endpoints

- Forgejo: `https://192.168.6.186:8086`
- Woodpecker: `https://192.168.6.186:8087`
- Dagger: `tcp://dagger.devops.svc.cluster.local:8080` in-cluster and
  `tcp://127.0.0.1:8080` for the local CLI
- Codex for Love Mika dev: `http://dev-her.localhost:17480` through Kepos (Mac + Sven), or `http://192.168.1.179:3082` from the WSL LAN
- Codex for Love Mika staging: `http://staging-her.localhost:17480` through Kepos (Mac + Sven)
- Codex for Love Shio prod (Yuki persona): `http://prod-lamplit.localhost:17480` through Kepos (Mac + Pixel 7a)
- Codex Bridge: `http://codex-bridge.localhost:17480` through Kepos (Mac + Baihe)
- Mac SSH: raw `mac-ssh` service through Kepos (Pixel 7a)
- k3s API: `https://127.0.0.1:26443`
- Anki Sync: `http://anki.localhost:17480/` through Kepos
- Cloudreve: `http://cloudreve.localhost:17480` through Kepos
- Miniflux: `http://miniflux.localhost:17480` through Kepos
- ERPNext: `http://erpnext.localhost:17480` through Kepos
- Navidrome: `http://navidrome.localhost:17480` through Kepos
- Penpot: `http://penpot.localhost:17480` through Kepos (Mac), including official MCP; see [penpot.md](penpot.md)
- Grafana: `http://grafana.localhost:17480` through the loopback gateway and
  full-trust Kepos subscribers
- Impri: `http://impri.localhost:17480` through Kepos (Mac + Pixel 7a)

The host Caddy system service binds only `127.0.0.1:17480`. It connects
local applications directly and forwards cluster application hosts to Traefik
at `127.0.0.1:27480`. CoreDNS rewrites cluster application names to the
`cluster-http.devops` Service on port 17480. See [HTTP ingress](http-ingress.md)
for route ownership, deployment and SSH access.

Kepos publishes application service IDs including:

- `navidrome` targets the canonical gateway port `17480`; Caddy routes it to
  the Navidrome Service in the `navidrome` namespace.
- `codex-bridge` targets the canonical gateway on port `17480` and is
  restricted to the Mac, NUC Windows, Baihe, and the named Bridge subscriber.
  Caddy routes `codex-bridge.localhost` to the Kubernetes Bridge Service. The
  Pod runs as Neil's UID/GID and mounts `/home/neil/.codex` read-write so the
  Bridge and Codex CLI share the same atomically refreshed `auth.json`.
- `dagger` targets the Dagger engine on port `8080` and is restricted to the
  configured build clients and SW.
- `ssh` targets port `22`.
- `anki` targets the canonical gateway on port `17480`; see
  [anki-sync.md](anki-sync.md) for credentials, deployment, and first sync.
- `cloudreve` targets the canonical gateway on port `17480`; see
  [cloudreve.md](cloudreve.md) for the Micron-backed storage, deployment, and
  Sven subscriber placeholder.
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

- **Gateway-routed HTTP web services** (`bookorbit`, `forgejo`, `navidrome`,
  `woodpecker`, `memos`, `anki`, `codex-bridge`,
  `miniflux`, `ente`, `erpnext`, `grafana`, `impri`, `meilisearch`, …): target the canonical gateway port `17480` and are
  routed by the preserved `Host` header.
- **Direct Partner HTTP services** (`dev-her`, `staging-her`, `prod-lamplit`): a Home Manager user service
  owns its port and Kepos publishes that port directly. Mika dev binds all IPv4
  interfaces for the WSL LAN; staging and prod bind `127.0.0.1`. They also have host Caddy routes; their workloads have no
  Tanka environment or CoreDNS rewrite.
- **Raw TCP/SSH services** (`dagger`, `mihomo`, `ssh`, `mac-ssh`): the peer must add a
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
Adding a direct HTTP app needs a Home Manager user service and its direct-port
publisher entry in the live policy. Bind it to `127.0.0.1` unless LAN access is
an explicit requirement.

Codex for Love follows this direct-service model: Mika dev binds
`0.0.0.0:3082` (including WSL LAN `192.168.1.179`), Mika staging binds
`127.0.0.1:3083`, and Shio prod (with the Yuki persona) binds
`127.0.0.1:3084`. All three have host Caddy routes, but no Tanka workload, CoreDNS rewrite,
or subscriber binding. Its configuration and verification steps are in
[codex-for-love.md](codex-for-love.md).

The separate Ente Photos stack publishes `ente` and `ente-storage`, both through
the canonical gateway on port `17480`. See [ente-photos.md](ente-photos.md) for
its deployment order and mobile acceptance checks.

Penpot and its official MCP share the gateway-routed `penpot` service, published
only to Mac. See [penpot.md](penpot.md) for credential generation, retained
storage, deployment, and MCP activation.

Meilisearch is a gateway-routed HTTP service published only to the `mac` peer.
It is available there at `http://meilisearch.localhost:17480`; see
[meilisearch.md](meilisearch.md) for its key-handling and deployment contract.

Local WSL clients connect directly to their loopback target: Caddy for
gateway-routed apps or the service port for direct loopback apps. They do not
traverse Kepos.

## Kepos live peer policy

`kepos/peer-policy.jsonnet` owns named peer keys, explicit service ACLs,
local service sources, and bindings. Run `just kepos-policy-render` to write
`~/.config/kepos/peer.toml` privately and atomically. This is unmanaged runtime
output; edit the Jsonnet source rather than the TOML. Rendering a policy does
not require a commit or NixOS switch.

The peer reloads valid changes within about one second. Invalid changes keep
the last valid configuration active and report a failure in
`journalctl --user -u kepos-peer.service -n 100 --no-pager`. Removing a peer or
revoking a service grant closes its affected channels. Service `allow` lists
are explicit immediate-peer public keys; missing or empty lists deny access.

All current remote devices use `connection = "accept"`, preserving their
existing dial direction. Mac's SSH service is bound to `127.0.0.1:2222` for
NUC-local SSH clients. The separate `mac-ssh` service explicitly republishes
that upstream Mac service to Pixel 7a: Mac grants only Kosmos upstream access,
and Kosmos grants only Pixel downstream access. Local sources use
`source = {local_port: 17480}` for Caddy-routed services or their direct service
port. WSL's peer gateway uses `127.0.0.1:17481`; Caddy owns `17480`.

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

Deploy the NixOS generation first so k3s, its directories, the packaged Kepos CLI, and the user service exist:

```bash
nh os switch . -H wsl
```

Open a new WSL shell after the switch so the session picks up membership in
the `k3s` group.

Woodpecker Secrets are operator-managed in SW's `seafarer` namespace.
A WSL switch does not synchronize or roll SW workloads. Encrypted source
credentials remain retained for recovery; see [secrets](secrets.md).

Kepos is a Nix-pinned executable supervised by the `kepos-peer` user unit,
not a Kubernetes container. Its canonical state is
`~/.local/state/kepos-neo/peer`; its live policy is
`~/.config/kepos/peer.toml`. Neither is created by activation. Prepare the
identity and render the policy before activating a fresh installation.
`just kepos-peer-key` prints only the public key, and `just kepos-status`
checks supervision.

The peer cutover retains WSL's previous publisher key and the Mac's active
subscriber key. The disabled reverse subscriber unit has been removed; the Mac
can supply services over its existing dial connection once it runs the peer
runtime and explicitly grants those services. Its old publisher identity is
not a second alias. Backed-up legacy identity files are operator-owned and are
not removed by Nix activation.

For a version update, change the Kepos input, validate/build the WSL closure,
and run `nh os switch . -H wsl` after merging. Updating or restarting Codex
Bridge does not update this peer. One-time identity conversion and rollback
steps belong in the deployment PR handoff, not activation hooks.

Apply the Kubernetes objects explicitly:

```bash
just diff
just apply
just status
```

### Codex Bridge image updates

The Codex Bridge Deployment uses the published
`ghcr.io/lamplitisles/kepos-codex-bridge:latest` image with
`imagePullPolicy: Always`. Bridge main CI publishes this tag. Publishing a new
image does not restart an existing Pod, so use the existing
`just codex-bridge-deploy` path and deliberately restart or recreate the
`codex-bridge` Deployment when you want a Pod to pull the current image. No
automatic updater or rollout is configured.

Forgejo and Woodpecker use SW ZFS-local PVCs on `tank/k8s`; their former local
data and `Retain` PVs remain preserved for recovery. Dagger retains its local
cache at `/var/lib/kosmos-k3s/dagger`.

## Seafarer CA trust

The public Seafarer Root CA is declarative WSL trust policy in
`certs/seafarer-root-ca.pem`; Node receives the evaluated NixOS CA bundle via
the managed `NODE_EXTRA_CA_CERTS` session variable. Apply it with the normal
WSL rebuild:

```bash
nh os switch . -H wsl
```

Open a fresh shell after activation so Node receives the session variable. To
replace the Root CA, update that PEM in a reviewed configuration change and
rebuild; do not retain a mutable `/usr/local` copy or disable TLS verification.

## Recover

The retired local Forgejo and PostgreSQL data and migration backups are retained.
Removing their manifests or tmpfiles declarations does not delete source data.
Never prune or delete the old PVs/PVCs as part of configuration activation.
After SW accepts writes, restarting old writers would expose stale data.

Forgejo source recovery is documented in the [backup runbook](forgejo-backup.md).
It excludes Packages/OCI and is not a full instance restore. Use the full
migration archive for migration recovery, with operator-controlled secrets.

### Back up Woodpecker PostgreSQL

Woodpecker does not back up its database. Create a private custom-format dump
from the PostgreSQL pod and validate that the archive can be listed. The dump
contains operational metadata and must be handled as a secret:

```bash
woodpecker_backup_dir=/home/neil/backups/woodpecker
install -d -m 0700 "$woodpecker_backup_dir"
woodpecker_dump_name="woodpecker-$(date -u +%Y%m%dT%H%M%SZ).dump"
woodpecker_dump="$woodpecker_backup_dir/$woodpecker_dump_name"

scripts/sw-kubectl -n seafarer exec statefulset/woodpecker-postgres -- \
    pg_dump --username=woodpecker --dbname=woodpecker --format=custom \
    > "$woodpecker_dump"

test -s "$woodpecker_dump"
scripts/sw-kubectl -n seafarer exec -i statefulset/woodpecker-postgres -- \
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
scripts/sw-kubectl -n seafarer exec -i statefulset/woodpecker-postgres -- \
    pg_restore --list < "$woodpecker_dump" >/dev/null

scripts/sw-kubectl -n seafarer scale statefulset/woodpecker-agent --replicas=0
scripts/sw-kubectl -n seafarer scale deployment/woodpecker --replicas=0
scripts/sw-kubectl -n seafarer rollout status deployment/woodpecker --timeout=120s
scripts/sw-kubectl -n seafarer rollout status statefulset/woodpecker-agent --timeout=120s

scripts/sw-kubectl -n seafarer exec -i statefulset/woodpecker-postgres -- \
    pg_restore --username=woodpecker --dbname=woodpecker \
      --clean --if-exists --no-owner --exit-on-error --single-transaction \
      < "$woodpecker_dump"

just sw-devops-apply true
scripts/sw-kubectl -n seafarer rollout status deployment/woodpecker --timeout=120s
scripts/sw-kubectl -n seafarer rollout status statefulset/woodpecker-agent --timeout=120s
curl --noproxy '*' --cacert certs/seafarer-root-ca.pem --fail https://192.168.6.186:8087/healthz
```

After restore, verify Forgejo login, repository activation, historical builds,
and one representative pipeline before accepting new CI work. Never copy a
running PostgreSQL data directory. Restore into SW's PVC
with writers stopped and verify historical builds before accepting work.

## Runtime checks

```bash
just status
kosmos-devops-gate-status --strict
just kepos-status
curl --noproxy '*' --cacert certs/seafarer-root-ca.pem --fail https://192.168.6.186:8086/api/healthz
curl --noproxy '*' --cacert certs/seafarer-root-ca.pem --fail https://192.168.6.186:8087/healthz
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
