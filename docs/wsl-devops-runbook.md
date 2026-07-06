# WSL DevOps Runbook

This runbook covers the staging implementation from
`docs/dagger-forgejo-packages-plan.md`.

## Services

- Forgejo staging: `https://git-wsl.guion.io`
- Dagger engine: local only, `tcp://127.0.0.1:8080`
- Woodpecker staging: module present, service gated on secrets

Forgejo and Dagger are enabled in `hosts/wsl/default.nix`. Woodpecker is enabled
there too, but its systemd services do not start until the required env secrets
exist.

## Dagger

The `dagger` command installed by Nix is a wrapper around the pinned Dagger CLI.
It sets:

```text
XDG_CONFIG_HOME=/var/lib/dagger/config
XDG_CACHE_HOME=/var/lib/dagger/cache
_EXPERIMENTAL_DAGGER_RUNNER_HOST=tcp://127.0.0.1:8080
```

The engine runs as a systemd-managed Podman container:

```bash
systemctl status podman-dagger-engine
dagger version
kosmos-dagger-unix-socket-smoke
```

This path does not require Docker daemon. Nix installs the Dagger CLI and owns
the systemd unit, while rootful Podman runs the official Dagger engine OCI image.
Do not replace this with Docker Compose, and do not try to make the engine a
pure Nix service unless there is a tested upstream-supported path.

The `dagger` wrapper defaults to `tcp://127.0.0.1:8080`, but it preserves an
explicit `_EXPERIMENTAL_DAGGER_RUNNER_HOST` override. The Unix socket smoke uses
that override to verify the same `/run/dagger/engine.sock` endpoint that
Woodpecker pipeline containers will receive.

Dagger's runner endpoint is local only. Do not expose it through Cloudflare.

Do not switch the Dagger engine container to host networking just to reach
Forgejo on `127.0.0.1`. In WSL testing, the engine failed to start because it
still needs its own BuildKit/CNI networking. Keep the official privileged engine
container shape.

The CI write path is local, not Cloudflare. The Dagger engine publishes to:

```text
host.containers.internal:3000/guionai/<image>:<tag>
```

`forgejo-internal-registry-proxy.service` binds only on the Podman bridge gateway
and forwards that traffic to Forgejo's loopback listener. This lets the Dagger
engine write packages without exposing Forgejo's local port on WSL `eth0`.

The engine GC policy is written to:

```text
/etc/dagger/engine.json
```

Current policy:

```json
{
  "gc": {
    "maxUsedSpace": "100GB",
    "reservedSpace": "10GB",
    "minFreeSpace": "20%",
    "sweepSize": "50%"
  }
}
```

After changing the engine config, restart the engine container:

```bash
sudo systemctl restart podman-dagger-engine
```

## Forgejo Staging

The staging admin bootstrap credentials are stored outside git:

```text
/root/kosmos-forgejo-admin-init.txt
```

Read it only when you need to log in:

```bash
sudo cat /root/kosmos-forgejo-admin-init.txt
```

Check local service state:

```bash
kosmos-wsl-devops-smoke
systemctl status forgejo
curl -I http://127.0.0.1:3000/
curl -I https://git-wsl.guion.io/v2/
```

The `/v2/` response should be a container-registry response, not the Forgejo HTML
app shell.

Smoke test HTTPS Git clone and push:

```bash
FORGEJO_SMOKE_TOKEN_FILE=/root/kosmos-forgejo-smoke-token.txt kosmos-forgejo-https-git-smoke
```

The helper creates a temporary private repo on `git-wsl.guion.io`, clones it over
HTTPS, commits and pushes one file, then deletes the repo. It expects a Forgejo
token through `FORGEJO_SMOKE_TOKEN` or `FORGEJO_SMOKE_TOKEN_FILE`. The admin
bootstrap password can still be used for initial bring-up by setting
`FORGEJO_SMOKE_USE_ADMIN_BOOTSTRAP=1`, but that should not be the routine smoke
credential.

Smoke test the staging dump timer and backup path:

```bash
kosmos-forgejo-backup-smoke
```

This triggers `forgejo-dump.service` and verifies a non-empty
`forgejo-dump-*.tar.zst` exists in `/var/backup/forgejo`. This proves the staging
dump path only; before production cutover, move or replicate backups to the NUC
data disk and test a restore from that location.

If the public hostname does not reach the WSL tunnel, route it to the `nuc-wsl`
Cloudflare tunnel:

```bash
cloudflared tunnel route dns --overwrite-dns c0e179cd-14fc-4cd9-ba4c-00a445844c74 git-wsl.guion.io
```

Smoke test Packages after the admin user and `GuionAI` org exist. Use lowercase `guionai` in the OCI image path:

```bash
docker login git-wsl.guion.io
docker pull hello-world:latest
docker tag hello-world:latest git-wsl.guion.io/guionai/smoke:latest
docker push git-wsl.guion.io/guionai/smoke:latest
docker pull git-wsl.guion.io/guionai/smoke:latest
```

Dagger publish smoke:

```bash
export FORGEJO_PASSWORD="$(sudo awk -F': ' '$1 == "Password" { print $2; exit }' /root/kosmos-forgejo-admin-init.txt)"
dagger -M call container \
  with-new-file --path /smoke.txt --contents "kosmos dagger registry smoke" \
  with-registry-auth --address git-wsl.guion.io --username neil --secret env://FORGEJO_PASSWORD \
  publish --address git-wsl.guion.io/guionai/dagger-smoke:latest
unset FORGEJO_PASSWORD
docker pull git-wsl.guion.io/guionai/dagger-smoke:latest
```

Internal Dagger publish smoke:

```bash
FORGEJO_SMOKE_TOKEN_FILE=/root/kosmos-forgejo-smoke-token.txt kosmos-dagger-local-registry-smoke
```

The helper publishes from Dagger to
`host.containers.internal:3000/guionai/local-dagger-smoke:latest`, then pulls the
same repository through `127.0.0.1:3000`. This is the path WSL Woodpecker jobs
should use for image writes. It uses the same token-first credential handling as
the HTTPS Git smoke.

## Woodpecker Secrets

Woodpecker needs two env files.

Server env:

```text
WOODPECKER_AGENT_SECRET=<shared-agent-secret>
WOODPECKER_FORGEJO_CLIENT=<forgejo-oauth-client-id>
WOODPECKER_FORGEJO_SECRET=<forgejo-oauth-client-secret>
```

Agent env:

```text
WOODPECKER_AGENT_SECRET=<same-shared-agent-secret>
```

Create them as agenix secrets:

```bash
agenix -e secrets/woodpecker-server-env.age
agenix -e secrets/woodpecker-agent-env.age
```

Then register both files in root `secrets.nix` with `users ++ systems`, add the
files to git, and rebuild WSL.

After secrets exist, check:

```bash
kosmos-woodpecker-preflight
systemctl status woodpecker-server
systemctl status woodpecker-agent-wsl-podman
```

Before secrets exist, `kosmos-woodpecker-preflight` should report the missing
age files as pending while still checking the Dagger and Podman sockets that the
future agent will need.

Woodpecker uses the Podman/Docker backend. Pipeline containers that need Dagger
receive this global environment variable from the Woodpecker server:

```text
_EXPERIMENTAL_DAGGER_RUNNER_HOST=unix:///run/dagger/engine.sock
```

The agent mounts `/run/dagger` into every pipeline step with
`WOODPECKER_BACKEND_DOCKER_VOLUMES`. Before relying on this from CI, verify from
a throwaway Woodpecker job that the socket exists and `dagger version` can reach
the engine.

## Kubernetes Pull Secret

The staging package pull token is stored outside git:

```text
/root/kosmos-forgejo-k8s-packages-pull-token.txt
```

The source Kubernetes secret is:

```text
devops/forgejo-packages
```

It has type `kubernetes.io/dockerconfigjson` and Reflector annotations for:

```text
apps-dev
apps-prod
apps-share
```

Verify source and mirrored secret metadata without printing secret data:

```bash
kosmos-forgejo-k8s-pull-secret-smoke
```

Private image pull smoke in `apps-dev`:

```bash
FORGEJO_PULL_SECRET_SMOKE_IMAGE=git-wsl.guion.io/guionai/dagger-smoke:latest \
  kosmos-forgejo-k8s-pull-secret-smoke
```

The helper checks that the source and mirrored secrets are
`kubernetes.io/dockerconfigjson`, verifies the Reflector annotations on the
source secret, creates a throwaway pod in `apps-dev`, waits for a populated
`imageID`, then deletes the pod. The smoke image is scratch-based, so the pod can
fail after the pull; the pass condition is the successful image pull, not a
running container.

## Forgejo Migration Preflight

Current source Forgejo in the production cluster:

```text
namespace: devops
deployment: forgejo
pod: forgejo-*
http service: forgejo-http:3000
ssh service: forgejo-ssh:22
pvc: gitea-shared-storage
pvc storage class: local-path-retain
pvc size: 20Gi
data volume mount: data -> gitea-shared-storage
image: registry-docker-registry.devops.svc:5000/forgejo:ttal-prreview-filter-rootless
```

Check this before any dry run:

```bash
kosmos-forgejo-migration-dry-run --preflight
kubectl get deploy,pod,pvc -n devops | grep -E 'forgejo|gitea-shared-storage'
kubectl get deploy forgejo -n devops \
  -o jsonpath='{range .spec.template.spec.containers[*]}{.name}{" "}{.image}{"\n"}{end}'
kubectl get pvc gitea-shared-storage -n devops \
  -o custom-columns='NAME:.metadata.name,STATUS:.status.phase,VOLUME:.spec.volumeName,SC:.spec.storageClassName,SIZE:.spec.resources.requests.storage'
df -h /var/lib/forgejo /var/backup/forgejo
```

Do not run the dry-run copy while `deployment/forgejo` is serving writes. The
SQLite-backed source must be put in a maintenance window and scaled to zero
before copying `/data`.

During a maintenance window, run the guarded cold-copy dry run:

```bash
kosmos-forgejo-migration-dry-run --execute-copy --confirm-stop-source
```

The helper refuses to stop the source deployment unless both flags are present.
It records the original replica count, scales `devops/deployment/forgejo` to
zero, mounts `devops/gitea-shared-storage` into a temporary copy pod, streams a
tar copy of `/data` to `/var/lib/forgejo-migration-dry-runs/<timestamp>`, and
then restores the original replica count with a trap.

That command proves the cold-copy path only. A full migration dry run still needs
the copied data restored or mounted into a target Forgejo instance, then checked
with login, clone, push, package list, and package pull.

## Production Cutover Guardrails

Do not move `git.guion.io` until all of these are true:

- Forgejo staging login works.
- HTTPS clone and push work.
- Packages push and pull work through `git-wsl.guion.io`.
- Dagger can publish an image to `git-wsl.guion.io/guionai/*`.
- A Kubernetes pod in `apps-dev` pulls a private staging image using the mirrored
  `forgejo-packages` secret.
- A cold copy or restore dry run of the current Forgejo `/data` volume has been
  tested.
