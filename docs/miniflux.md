# Miniflux

Miniflux is Neil's self-hosted RSS aggregator, running in the local k3s cluster
under the `feeds` namespace and exposed to peers through Kepos via the
canonical gateway. The KOReader plugin
[AlgusDark/miniflux.koplugin](https://github.com/AlgusDark/miniflux.koplugin)
reads the same server (selected in FlickNote #1870).

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

Miniflux is an HTTP web service, so it is exposed through the Kepos
subscriber's gateway port — no per-service `[[subscriber.services]]` entry is
needed (that mechanism is only for raw TCP/SSH services such as `dagger` or
`ssh`, which get their own local listener).

Once the WSL publisher advertises `miniflux` (NixOS generation switched
after the `kepos-neo.nix` change), the Mac Kepos Desktop shows it with an
Open action. Access it at:

```text
http://miniflux.localhost:17480
```

`17480` is the Kepos subscriber's default gateway port on the Mac; use the
`gateway_port` from the Mac's `~/.config/kepos/config.toml` if it differs.
macOS resolves `.localhost` to loopback, so the browser sends
`Host: miniflux.localhost`, which Kepos routes to the publisher and the
canonical gateway routes to Miniflux.

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
