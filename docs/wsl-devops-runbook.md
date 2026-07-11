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

### Current DNS failure

As of 2026-07-11, the CLI can connect to Dagger Engine v0.21.7 and upload a
build context, but builds that need a public base image stall during image
resolution. `dagger version` is therefore not a sufficient health check.

The failure has two observed layers:

1. `modules/wsl/dagger.nix` declares `--dns=10.88.0.1`, and root Podman reports
   that address in the container's `HostConfig.Dns`. Before the Engine was
   recreated, its `/etc/resolv.conf` instead contained `nameserver 10.87.0.1`.
   Restarting `podman-dagger-engine.service` recreated the outer container and
   corrected that file to `10.88.0.1`, but Dagger build vertices still sent
   registry lookups to `10.87.0.1`. The stale resolver therefore also exists in
   Dagger/BuildKit's internal execution network, outside the outer container's
   visible `/etc/resolv.conf`.
2. `dagger-dnsproxy.service` is listening on `10.88.0.1:53`, but its requests to
   both configured DNS-over-HTTPS upstreams (`1.1.1.1` and `1.0.0.1`) time out.

The result is repeatable lookup failure for both the configured Docker Hub
mirror and the upstream registry:

```text
lookup mirror.gcr.io on 10.87.0.1:53: i/o timeout
lookup registry-1.docker.io on 10.87.0.1:53: i/o timeout
```

This is an Engine/Podman/DNS-path fault, not a project Dockerfile or CPU
architecture problem. Local Docker/Compose builds can still work because they
do not use the Engine's resolver path.

Inspect all three layers before changing configuration:

```bash
dagger version
sudo podman inspect dagger-engine | jq '.[0].HostConfig.Dns'
sudo podman exec dagger-engine cat /etc/resolv.conf
systemctl status dagger-dnsproxy podman-dagger-engine
journalctl -u dagger-dnsproxy -u podman-dagger-engine --since today
```

The incident is resolved only when a Dagger operation can pull a small public
image, not merely when the Engine socket responds. Recreating the Engine is not
sufficient: the 2026-07-11 restart corrected the outer container resolver, but
this functional check still failed through `10.87.0.1`:

```bash
DAGGER_NO_NAG=1 dagger -M call container \
  from --address alpine:3.20 \
  with-exec --args=echo --args=dagger-pull-ok \
  stdout
```

Verify Dagger/BuildKit's internal network resolver as well as the outer Podman
container. Also verify the DNS proxy can reach at least one upstream before
testing Dagger.

The configuration sources for this path are:

- `modules/wsl/dagger.nix`: Engine container, resolver, and DoH upstreams.
- `scripts/dagger-engine-config-smoke`: installed Engine JSON and cache policy.
- `scripts/dagger-unix-socket-smoke`: socket connectivity only.
- `scripts/dagger-local-registry-smoke` and
  `scripts/dagger-large-registry-smoke`: functional Dagger build/publish paths.

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
