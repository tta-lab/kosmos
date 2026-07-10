# WSL DevOps Runbook

This is the current operating note for the WSL DevOps control plane.
Historical k3s migration, restore-smoke, and backup helper scripts were removed
after cutover.

## Services

- Forgejo: `https://git.guion.io`
- Woodpecker: `https://ci.guion.io`
- Dagger engine: local only, `tcp://127.0.0.1:8080` and
  `unix:///run/dagger/engine.sock`

Forgejo, Dagger, and Woodpecker are enabled from `hosts/wsl/default.nix`.
Cloudflare routes for `git.guion.io` and `ci.guion.io` are served by the WSL
`nuc-wsl` tunnel, not by the production k3s cluster.

## Health Checks

Use the gate command for normal checks:

```bash
kosmos-devops-gate-status --strict
```

Use the smoke command when checking all local services after a deploy:

```bash
kosmos-wsl-devops-smoke
```

Check public ingress:

```bash
kosmos-cloudflared-ingress-smoke
curl -I https://git.guion.io/v2/
curl -I https://ci.guion.io/
```

The `/v2/` response should be a container-registry response, not the Forgejo
HTML app shell.

Use `--deep` only when you want the Kubernetes private-image pull smoke:

```bash
kosmos-devops-gate-status --deep --strict
```

## Dagger

Nix installs the Dagger CLI wrapper. The engine is a systemd-managed rootful
Podman container running the official Dagger engine image.

```bash
systemctl status podman-dagger-engine
dagger version
kosmos-dagger-unix-socket-smoke
```

Dagger cache policy is written to:

```text
/etc/dagger/engine.json
```

After changing the engine config:

```bash
sudo systemctl restart podman-dagger-engine
```

Do not expose the Dagger engine through Cloudflare. Woodpecker receives the Unix
socket mount and talks to it locally.

## Forgejo

Local checks:

```bash
systemctl status forgejo
curl -I http://127.0.0.1:3000/
curl -I https://git.guion.io/v2/
```

The admin bootstrap credentials are stored outside git:

```text
/root/kosmos-forgejo-admin-init.txt
```

Read them only when initial login or recovery needs it:

```bash
sudo cat /root/kosmos-forgejo-admin-init.txt
```

The WSL-local registry publish path is:

```text
host.containers.internal:3000/guionai/<image>:<tag>
```

`forgejo-internal-registry-proxy.service` binds only on the Podman bridge
gateway and forwards to Forgejo's loopback listener. This lets Dagger publish
packages without sending registry writes through Cloudflare.

Package and Git smoke tests use the agenix-backed Forgejo smoke token:

```bash
kosmos-forgejo-https-git-smoke
kosmos-dagger-local-registry-smoke
kosmos-dagger-large-registry-smoke
```

## Woodpecker

Check service state:

```bash
systemctl status woodpecker-server
systemctl status woodpecker-agent-wsl-podman
kosmos-woodpecker-preflight
```

Run the Dagger job smoke when validating CI end to end:

```bash
kosmos-woodpecker-dagger-job-smoke
```

Woodpecker data from the old cluster was not migrated. Re-enable repos and
secrets in the WSL instance as needed.

## Backup

No Forgejo or Woodpecker backup automation is part of the current WSL DevOps
setup. The old migration-time dump, restore-smoke, data-disk, and replication
helpers were removed to keep the live system small.

If backup becomes important, design it as a new change with a clear restore
test. Do not revive the old cutover scripts as routine backup tooling.
