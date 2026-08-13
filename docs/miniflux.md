# Miniflux

Miniflux is Neil's self-hosted RSS aggregator, running in the local k3s cluster
under the `feeds` namespace and exposed to peers through Kepos via the
canonical gateway. The KOReader plugin
[AlgusDark/miniflux.koplugin](../research notes #1870) reads the same server.

Components:

- `miniflux` Deployment (Miniflux 2.3.3, PostgreSQL-backed)
- `miniflux-postgres` StatefulSet (PostgreSQL 18, dedicated PV)
- Storage: `/var/lib/kosmos-k3s/feeds/miniflux-db` (PV `kosmos-miniflux-db`)
- Kepos service id: `miniflux` (canonical gateway port `17480`)

Miniflux 2.3.x is PostgreSQL-only; SQLite support was removed upstream.

## First login

The admin password is generated once into the `miniflux-env` Secret by
`scripts/init-miniflux-secrets` (run via `just feeds-deploy`). Print it with:

```bash
just feeds-status
KUBECONFIG=/etc/rancher/k3s/k3s.yaml kubectl get secret miniflux-env -n feeds \
  -o jsonpath='{.data.ADMIN_PASSWORD}' | base64 --decode; echo
```

Sign in at `http://miniflux.localhost:17480` (WSL host) with user `admin`.

## Mac access through Kepos

The Mac subscribes to the published `miniflux` service through
`~/.config/kepos/config.toml` (Kepos Desktop reads this file). Append a
service entry to the existing `[subscriber]` section — keep its current
`enabled`/`gateway_port`/`route` values:

```toml
[subscriber]
enabled = true
gateway_port = 17481
route = "auto"

[[subscriber.services]]
id = "miniflux"
local_port = 18093
```

If the `[subscriber]` section already exists, only append the
`[[subscriber.services]]` block with a free `local_port` (the publisher
advertises port `17480`; the Mac-side `local_port` is the local listener).
Restart Kepos Desktop. Seeing `miniflux` in the service list alone does not
create the local TCP listener.

Access it as `http://miniflux.localhost:18093` — macOS resolves
`.localhost` to loopback, so the browser sends `Host: miniflux.localhost`,
which the canonical gateway uses to route to Miniflux.

## Operations

```bash
just feeds-status          # pods, svc, pvc in the feeds namespace
just feeds-diff            # review pending changes
just feeds-deploy          # apply feeds env + gateway, restart Caddy
```

Verify the web app is serving through the gateway:

```bash
curl --fail http://miniflux.localhost:17480/healthcheck
```

## KOReader plugin (AiPaper)

Install AlgusDark/miniflux.koplugin into `koreader/plugins/` (same install
path as FlickNote #1642), then point it at the server address
`http://miniflux.localhost:17480` with the same account.
