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

Add a listener for the published `miniflux` service in
`~/.config/kepos/config.toml` on the Mac, then restart Kepos Desktop:

```toml
[[subscriber.services]]
id = "miniflux"
local_port = 18093
```

The Kepos publisher must already expose the service (NixOS generation
switched after the `kepos-neo.nix` change); seeing `miniflux` in the Mac
service list alone does not create the local TCP listener. Access it as
`http://miniflux.localhost:18093` with a Host header of `miniflux.localhost`.

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
