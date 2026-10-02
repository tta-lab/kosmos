# Penpot

Penpot and its official MCP server run in the local WSL k3s cluster, in the
`penpot` namespace. The frontend, backend, exporter, admin console, and MCP
images use the same pinned Penpot release. PostgreSQL 15 stores accounts and
design data; Valkey 8.1 handles transient notifications.

## Access

Open `http://penpot.localhost:17480` on WSL or Mac. Caddy routes the canonical
host to `penpot-frontend.penpot.svc.cluster.local:8080`. Kepos publishes the
single `penpot` service only to the named `mac` peer. Leave publisher `kind`
unset; the existing TCP tunnel carries HTTP and WebSocket traffic. The Mac
subscriber gateway needs no separate service binding.

This is a private loopback/Kepos HTTP deployment. Secure cookies and email
verification are disabled, and SMTP is not enabled. Create your account in
the web UI; its login password is separate from the generated infrastructure
credentials. Password resets and email invitations require configuring SMTP.
Do not expose this configuration as a public HTTP service.

## Credentials and storage

`just penpot-secrets` generates the database password (32 random bytes as hex)
and `PENPOT_SECRET_KEY` (64 random bytes as base64) on first deployment. Both
are written directly to `penpot/penpot-credentials`, without printing their
values. The backend and admin console share the PostgreSQL password; backend,
exporter, and admin console share the master key. Repeat deployments keep the
existing Secret. API errors stop initialization, and a missing Secret with an
existing database PVC requires recovery instead of generating a new password.
Tanka renders only Secret references, never secret values.

Two static PVs have `Retain` reclaim policy:

| PVC | Host directory | Purpose |
| --- | --- | --- |
| `penpot-postgres-data` | `/var/lib/kosmos-k3s/penpot/postgres-data` | PostgreSQL data |
| `penpot-assets` | `/var/lib/kosmos-k3s/penpot/assets` | Uploaded images and other assets |

NixOS creates the directories with the image users ownership. Both frontend
and backend mount the assets PVC on this single-node cluster; frontend mounts
it read-only. PV sizes are allocation declarations, not hostPath disk quotas.
Valkey has persistence disabled because it does not own durable design data.

Back up the database, assets, and `penpot-credentials` together. A database
backup alone cannot restore uploaded assets; a cluster rebuild also needs the
same credentials/master key. Kubernetes Secrets are not an off-host backup.
An operator can create a private backup without displaying values:

```bash
umask 077
mkdir -p /path/to/private-backup
KUBECONFIG=/etc/rancher/k3s/k3s.yaml kubectl get secret penpot-credentials \
  -n penpot -o yaml > /path/to/private-backup/penpot-credentials.yaml
KUBECONFIG=/etc/rancher/k3s/k3s.yaml kubectl exec -n penpot \
  deployment/penpot-postgres -- pg_dump -U penpot -d penpot -Fc \
  > /path/to/private-backup/penpot.dump
```

Pause design writes while capturing the database and a matching assets backup.
Store the private backup off-host, preferably encrypted. Agents must not run
the Secret export or inspect it. Restore the Secret before a fresh deploy and
restore the database and matching assets before opening the service to users.

## Deployment

Review and build the NixOS change before switching; new source files must be
staged for Git-backed flake evaluation. Run the required repository Nix checks
and WSL build, then:

```bash
nh os switch . -H wsl
just penpot-show
just penpot-diff
just penpot-deploy
just penpot-status
```

`penpot-deploy` initializes credentials, applies the Penpot environment, waits
for all seven Deployments, updates only the gateway/CoreDNS ConfigMaps, restarts
the gateway, checks `/readyz`, and atomically renders the Kepos policy. Tanka
asks for confirmation before apply; after reviewing the diff, automation can
run `just penpot-deploy always` to use Tanka’s documented
`--auto-approve=always` flag for both applies. Initial
image pulls and backend migrations can take several minutes.

## MCP on Mac

Internal frontend upstreams use full Kubernetes service names because Nginx’s
dynamic resolver does not expand short names through the pod DNS search list.
The official frontend proxies both MCP transports through the same Kepos host:

- `/mcp/stream` → MCP HTTP port 4401.
- `/mcp/ws` → MCP WebSocket port 4402 for the browser plugin.

1. Sign in at `http://penpot.localhost:17480`.
2. Open **Your account → Integrations → MCP Server**, enable MCP, and generate
   your personal key. This key is distinct from `PENPOT_SECRET_KEY`.
3. Copy the server URL from that screen to an HTTP-capable MCP client. It has
   the form `http://penpot.localhost:17480/mcp/stream?userToken=<personal-key>`.
   Keep the full URL in private client configuration, outside this repository.
4. Open a design file and choose **File → MCP Server → Connect**.
5. Ask the agent to list pages before making a small design edit.

Keep the connected Penpot tab awake; MCP executes through the plugin in the
currently focused file/page. The k3s MCP server runs in remote mode and cannot
read or write the Mac client filesystem. No separate Mac Node/MCP server,
plugin manifest server, or published MCP port is required.

Verify Mac login, file save/reopen, an image upload, PNG/PDF export, and MCP
read/write operations. `/readyz` alone does not establish browser or MCP
connectivity. MCP initialization can succeed without a personal key, but design
tool execution then returns an authentication error. A valid personal key and
a live browser connection are required to execute design tools.

Official references: [release](https://github.com/penpot/penpot/releases/tag/2.18.1),
[deployment template](https://github.com/penpot/penpot/blob/2.18.1/docker/images/docker-compose.yaml),
and [MCP setup](https://help.penpot.app/mcp/).
