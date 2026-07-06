# WSL DevOps Box Plan

## Goal

Move the devops control plane to the long-running kosmos WSL NUC so Dagger build
cache, Git traffic, CI, and Forgejo package storage do not consume production
cluster worker disk.

The final target shape is:

```text
kosmos WSL
  Forgejo canonical Git server
  Forgejo Packages canonical image registry
  Dagger engine/cache
  Woodpecker agent path to Dagger over internal networking
  Cloudflare HTTP routes for Forgejo HTTPS Git and Packages
      v
production cluster
  pull images from git.guion.io/guionai/<image>:<tag>
```

During staging, use `git-wsl.guion.io`. Do not point production manifests at
`git.guion.io/guionai/*` until the Forgejo data migration and DNS cutover are
complete.

Separate the registry write path from the human/public path:

- WSL-local CI and Dagger publishes use the Podman bridge-only Forgejo proxy:
  `host.containers.internal:3000/guionai/<image>:<tag>` from inside the Dagger
  engine container. The proxy binds on the Podman bridge gateway and forwards to
  Forgejo's loopback listener, so the write path does not traverse Cloudflare.
- Human Git UI, HTTPS clone/push, and external package pulls use the Cloudflare
  hostname, currently `git-wsl.guion.io` during staging and `git.guion.io` after
  cutover.
- Do not route Dagger's runner endpoint or routine CI image pushes through
  Cloudflare. Cloudflare has request upload limits and is the wrong primary path
  for large registry layer uploads when the services already run together.
- Do not switch Dagger engine to Podman host networking for this. The Dagger
  engine manages its own BuildKit/CNI networking and failed to start with
  `--network=host` in WSL testing. Keep the official privileged engine container
  shape unless a new approach is tested end-to-end.

This deliberately makes the NUC WSL instance a personal devops box. Production
does not need WSL for already-running pods, but rollout, reschedule to an empty
node, rollback to an uncached image, and new deployments will depend on
`git.guion.io` being reachable.

The plan should be implemented in small PRs. The expected kosmos files are:

- `modules/wsl/forgejo.nix` for Forgejo and its cloudflared route.
- `modules/wsl/dagger.nix` for Dagger engine/runtime configuration.
- `modules/wsl/woodpecker.nix` for Woodpecker server/agent wiring.
- root `secrets.nix`, plus module-local `age.secrets` or `modules/wsl/secrets.nix`
  entries when a service needs agenix secrets.
- `hosts/wsl/default.nix` to import and enable the modules.

Do not fold the full migration into the first implementation PR. The first PR
should make the staging service reachable and easy to turn off.

## Verified Facts

- Forgejo's container registry publishes OCI images and supports Docker-compatible
  clients.
- Forgejo container image names must use `{registry}/{owner}/{image}`.
- `owner` is a Forgejo user or organization. A unified namespace is possible only
  if it is a real Forgejo user/org, for example
  `git.guion.io/guionai/<image>` because OCI repository names must be lowercase. The Forgejo organization display name can remain `GuionAI`.
- Forgejo packages belong to an owner, not directly to a repository. Packages can
  be linked to repositories later, or auto-linked by image source labels or by
  naming the image after the repository.
- Forgejo package read/write access is owner-based: user-owned packages are
  writable by the user; organization-owned packages are writable by org members
  with write/admin access.
- Forgejo package registry is automatically enabled unless globally disabled.
  Repo-level packages can still be disabled per repository.
- Kubernetes uses a `kubernetes.io/dockerconfigjson` Secret for private registry
  pulls, referenced by `imagePullSecrets` on pods or service accounts.
- Dagger's engine cache is controlled by the Dagger engine. The official engine
  config supports garbage collection settings such as `maxUsedSpace`,
  `reservedSpace`, and `minFreeSpace`.
- Dagger custom runners can be selected with `_EXPERIMENTAL_DAGGER_RUNNER_HOST`,
  including `tcp://<address:port>`.
- Dagger does not encrypt runner traffic itself. If `tcp://` is used, encryption
  and access control must come from the underlying network path.
- The current Forgejo chart stores persistent data under `/data` and uses the
  `gitea-shared-storage` PVC by default.
- The current devops Forgejo environment uses SQLite and a 20Gi
  `local-path-retain` volume.
- `forgejo dump` can dump Forgejo files and database, and has options to include
  package data. Forgejo's upgrade docs still call a synchronized point-in-time
  storage snapshot the most reliable backup shape.
- For SQLite, the Forgejo upgrade docs say the database file is included in the
  dump; the warning about separate `psql`/`mysql` dumps applies to those external
  database engines.

## Current State

In `project get devops`:

- `devops-forgejo` runs Forgejo at `git.guion.io`.
- Forgejo currently has no explicit `[packages]` config in
  `environments/devops-forgejo/main.jsonnet`; this should mean package registry
  defaults apply, but we should smoke test before relying on it.
- `devops-registry` runs a standalone Docker registry in the production cluster:
  `registry-docker-registry.devops.svc:5000`, NodePort `30500`.
- `devops-dagger` runs Dagger engine in the production cluster and is configured
  to push to that internal registry over HTTP.

In kosmos WSL:

- Podman is enabled with Docker compatibility and Docker socket support.
- `docker-compose` is installed.
- In this staging PR, Forgejo is wired through NixOS at `git-wsl.guion.io`.
- In this staging PR, Dagger is wired through NixOS as a pinned CLI plus a
  systemd-managed Podman engine container.
- Woodpecker agent is the intended CI runner. Forgejo Actions is out of scope.
  In this staging PR, the Woodpecker module exists but services are gated on
  env secrets.

## Recommendation

Adopt a phased **WSL DevOps Box** migration.

Use the existing `GuionAI` organization as the Forgejo owner, but use lowercase `guionai` in OCI image references:

```text
git.guion.io/guionai/<image>:<tag>
```

Keep the old cluster Forgejo, cluster registry, and cluster Dagger during rollout
until WSL Forgejo backup/restore, package push/pull, and one service migration
have been proven. Do not cut `git.guion.io` over until a tested backup exists.

Prefer NixOS modules and systemd services for all long-running WSL services:

- Forgejo through the NixOS Forgejo module if it fits.
- Cloudflared through existing NixOS cloudflared wiring.
- Dagger CLI through Nix. Dagger engine through the official OCI image managed
  by systemd/Podman, not Docker daemon and not Compose.
- Woodpecker agent through a NixOS/systemd service.
- Backup through a NixOS timer.

Podman/Docker compatibility remains useful because Dagger's official engine is
distributed and operated as an OCI container. The goal is to avoid a Docker
daemon and Compose ownership, not to repackage the Dagger engine as a pure Nix
service. Repackaging the engine would put upgrade and cache behavior on us
instead of the supported Dagger path.

## Proposed Phases

### Phase 0: WSL Forgejo Staging

Deploy a new Forgejo instance on kosmos WSL through NixOS without taking over
`git.guion.io` yet. Use a temporary route such as:

```text
git-wsl.guion.io
```

or a local-only route through SSH port forwarding.

The staging instance should use the same Forgejo version as the cluster instance
or a deliberately planned upgrade path. Its persistent data should live under a
clear NUC path such as:

```text
/var/lib/forgejo
```

Configure Forgejo explicitly enough that future readers do not rely on unclear
defaults:

- `ROOT_URL = https://git-wsl.guion.io/` during staging.
- package registry enabled.
- HTTP Git enabled.
- Git SSH disabled or left unadvertised for MVP V1.
- SQLite path and data directory documented.

Success criteria:

- web login works
- HTTPS git clone and push work
- package registry `/v2/` endpoint works
- storage path and backup path are documented
- service can be stopped and started cleanly from Nix/systemd
- `curl -I https://git-wsl.guion.io/v2/` returns a registry-style response, not
  the Forgejo HTML app shell

### Phase 1: Staging Package and Dagger Smoke

Create or confirm the `GuionAI` org on the WSL Forgejo instance.

Create separate tokens:

- publish token: package write, plus repo access only if needed
- pull token: package read for production cluster image pulls

Store the publish token in kosmos agenix if it is used by a WSL service. Store
the Kubernetes pull token as a Kubernetes source secret for Reflector, not in
application manifests.

Smoke test package push/pull against the staging hostname:

```bash
docker login git-wsl.guion.io
docker pull hello-world:latest
docker tag hello-world:latest git-wsl.guion.io/guionai/smoke:latest
docker push git-wsl.guion.io/guionai/smoke:latest
docker pull git-wsl.guion.io/guionai/smoke:latest
```

Deploy Dagger on WSL through NixOS/systemd and confirm it can publish to the
staging Forgejo package registry. The Dagger cache must have an explicit GC
policy before real builds run.

Hard gate before moving on: prove both a direct Docker/Podman client and a
Dagger build can push and pull the same staging image.

### Phase 2: Kubernetes Pull Secret

Create a pull token with read access to packages. Avoid reusing the publish token
for production pulls.

Create a `kubernetes.io/dockerconfigjson` Secret in each namespace that will pull
private Forgejo images, or attach it through the namespace's default service
account if that matches the app model.

Production images should be private by default. Use one canonical registry pull
secret, then mirror or replicate it into every namespace that needs to pull
`git.guion.io/guionai/*` images. This can be handled by the existing secret
mirroring pattern if it supports `kubernetes.io/dockerconfigjson` secrets; if
not, add that support before the first service migration.

The current production cluster uses Emberstack Reflector
(`docker.io/emberstack/kubernetes-reflector:10.0.55`) in `kube-system`. Existing
mirrored secrets use annotations such as:

```yaml
reflector.v1.k8s.emberstack.com/reflection-allowed: "true"
reflector.v1.k8s.emberstack.com/reflection-allowed-namespaces: "apps-dev,apps-prod"
reflector.v1.k8s.emberstack.com/reflection-auto-enabled: "true"
```

For the Forgejo registry pull secret, create the canonical source secret with
`type: kubernetes.io/dockerconfigjson` and valid `.dockerconfigjson` data. Prefer
Reflector auto-mirrors instead of pre-creating destination secrets, so Reflector
can create the mirrored secrets with the correct type.

Initial reflection targets:

```text
apps-dev
apps-prod
apps-share
```

Use one canonical source name, for example:

```text
forgejo-packages
```

Destination namespaces should use the same secret name so app manifests do not
need namespace-specific imagePullSecret values.

Audit notes:

- `apps-dev` and `apps-prod` currently pull many Guion application images from
  `registry-docker-registry.devops.svc:5000`; these are first-class migration
  targets.
- `apps-share` currently pulls `document` from
  `registry-docker-registry.devops.svc:5000` and should receive the pull secret.
- `supa-dev` and `supa-prod` currently run `ghcr.io/guionai/pgwire-supabase-proxy`.
  Add them to reflection targets only if this image moves to Forgejo Packages or
  becomes private under `git.guion.io/guionai`.
- `infra-dev` and `infra-prod` currently do not run GuionAI/private app images
  that need the Forgejo pull secret.

Example shape:

```bash
kubectl create secret docker-registry forgejo-packages \
  --docker-server=<forgejo-host> \
  --docker-username=<forgejo-user> \
  --docker-password=<forgejo-token> \
  --docker-email=<email> \
  -n <namespace>
```

Then verify with a throwaway pod using:

```yaml
imagePullSecrets:
  - name: forgejo-packages
```

First test this against the staging hostname. After cutover, the server becomes
`git.guion.io`.

Do not migrate a production deployment until a private staging image has been
pulled by a pod in `apps-dev` through the mirrored secret.

### Phase 3: Forgejo Data Migration Dry Run

Do at least one dry-run migration into WSL Forgejo before changing DNS.

The preferred migration strategy is a cold copy of the current `/data` volume,
because the current instance uses SQLite and stores repositories, configuration,
packages, attachments, and database state on the same persistent volume.

Dry-run outline:

1. Put the source cluster Forgejo into maintenance mode or schedule a short
   downtime window.
2. Scale cluster Forgejo down to zero replicas so SQLite and repository state are
   consistent.
3. Create a safety backup with `forgejo dump` including repositories, LFS,
   attachments, package data, custom dir, and database.
4. Copy the source PVC contents mounted at `/data` to the WSL Forgejo data path.
5. Preserve `app.ini` secrets such as `SECRET_KEY`, `INTERNAL_TOKEN`,
   `JWT_SECRET`, and `LFS_JWT_SECRET`.
6. Adjust hostname and SSH settings for the WSL target only if they differ during
   staging.
7. Start WSL Forgejo.
8. Run `forgejo doctor check --all --log-file /tmp/doctor.log`.
9. Run `forgejo admin regenerate hooks` and regenerate authorized keys if SSH
   behavior is wrong.
10. Verify web login, git clone, git push, package list, package pull, and admin
    org membership.
11. Keep the source cluster Forgejo stopped only for the test window, then either
    discard the WSL test data or mark it as a dry-run copy.

For final migration, repeat the same flow but keep the source cluster Forgejo
stopped after the final copy. DNS and Cloudflare routes move only after WSL
verification passes.

`forgejo dump` remains useful as an extra artifact and rollback backup. It should
not be the only migration mechanism unless the dry run proves the restore path
end-to-end.

### Phase 4: CI Build Path on kosmos WSL

Dagger is part of the staging MVP: the WSL NixOS configuration should provide a
pinned CLI wrapper and a systemd-managed engine container with an explicit cache
GC policy before real builds run.

If the Dagger engine must run as the official engine container, run it through a
systemd-managed Podman/Docker-compatible unit. Do not introduce Docker Compose
for this.

Do not require Docker daemon for the WSL path. The intended implementation is:

```text
NixOS module -> systemd unit -> rootful Podman -> official Dagger engine image
```

The Dagger CLI itself is installed by Nix, but the engine remains the supported
OCI image.

Configure Dagger engine cache on WSL with an explicit GC policy so it cannot eat
the whole WSL disk. A starting policy can be:

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

Then update Dagger publish targets from:

```text
registry-docker-registry.devops.svc:5000/<image>:<tag>
```

to the internal WSL Forgejo Packages endpoint for CI writes:

```text
host.containers.internal:3000/guionai/<image>:<tag>
```

The public pull reference after cutover should remain:

```text
git.guion.io/guionai/<image>:<tag>
```

For private registry publish, prefer Dagger registry auth rather than relying on
ambient Docker login state in scripts.

Success criteria:

- Dagger engine starts after WSL reboot without manual shell state.
- cache config is present under the engine's real config path.
- a build can publish to Forgejo Packages through
  `host.containers.internal:3000/guionai/*`.
- the same package can be pulled through a local or public registry address.
- before production CI migration, the internal path is proven with a large enough
  image to matter.
- stopping the engine leaves Forgejo and cloudflared unaffected.
- a throwaway Woodpecker job can reach the Dagger Unix socket before production
  build pipelines are migrated.

### Phase 4b: Woodpecker Agent and Internal Runner Endpoint

Woodpecker server and agent are the CI path. Forgejo Actions is intentionally
out of scope.

The Woodpecker agent should build through the WSL Dagger engine. Keep the runner
endpoint internal to the WSL devops box when possible.

If a named endpoint is useful, reserve:

```text
dagger.guion.io
```

The Woodpecker agent would set:

```bash
_EXPERIMENTAL_DAGGER_RUNNER_HOST=tcp://dagger.guion.io:<port>
```

This endpoint must not be exposed as unauthenticated public TCP. Dagger runner
traffic can include source code, secrets, registry credentials, and build outputs.
The acceptable options are:

- private network only, for example VPN/WireGuard/Tailscale-style routing
- Cloudflare private tunnel/WARP-style access where the CI runner can join the
  private route
- SSH or another encrypted transport if Dagger supports it in the selected
  version and we verify it end-to-end

Plain public `tcp://dagger.guion.io:<port>` is not acceptable.

For MVP, prefer local host or Unix-socket style connectivity between Woodpecker
and Dagger if they run on the same WSL box. Only add `dagger.guion.io` after a
real remote runner needs it.

### Phase 5: Cutover `git.guion.io`

Cutover only after a successful dry run and a fresh final backup.

Cutover steps:

1. Freeze pushes and CI on the cluster Forgejo.
2. Stop cluster Forgejo.
3. Take final `forgejo dump` and final cold `/data` copy.
4. Restore/copy into WSL Forgejo.
5. Start WSL Forgejo using production `ROOT_URL = https://git.guion.io`.
6. Move Cloudflare HTTP route for `git.guion.io` to WSL.
7. Verify login, HTTPS clone/push, PR view, package push/pull, and admin tasks.
8. Keep cluster Forgejo data untouched for at least one release window.

Git SSH is not part of MVP V1. Revisit SSH after HTTP Git, package pulls, and CI
are stable on WSL.

Rollback is DNS/route reversal plus restarting the cluster Forgejo with its
untouched pre-cutover data. Any writes accepted by WSL after cutover would need
manual reconciliation before rollback, so rollback should be decided quickly.

Cutover is not complete until a production cluster pod pulls a private
`git.guion.io/guionai/*` image through the mirrored secret and a developer can
push to a test repository over HTTPS Git.

### Phase 6: First Service Migration

Pick one low-risk service and change only its image publishing and deployment
image reference.

Success criteria:

- WSL Dagger builds the image.
- Image appears in Forgejo Packages.
- Production namespace pulls it with `forgejo-packages`.
- Rollout succeeds.
- Rollback to the previous image source is documented and tested.

After the first service works, migrate the rest gradually.

### Phase 7: Decommission Old Infra

Do not remove old infra immediately.

After all services have moved to Forgejo Packages:

- stop using `devops-dagger`
- remove or scale down the cluster Dagger engine
- keep `devops-registry` read-only or idle for one release window
- keep cluster Forgejo PVC untouched until the WSL instance has survived at least
  one backup/restore cycle and one release window
- remove old registry only after no deployments reference
  `registry-docker-registry.devops.svc:5000`
- clean Dagger and registry hostPath data from the worker after backups or an
  explicit decision that rollback data is no longer needed

## Implementation Checks

- Verify Emberstack Reflector creates `kubernetes.io/dockerconfigjson`
  auto-mirrors correctly before migrating the first private image.
- Verify `git-wsl.guion.io` handles Forgejo package registry `/v2/` requests
  through Cloudflare.
- Verify cloudflared routes for `git-wsl.guion.io` and later `git.guion.io`
  point to Forgejo's HTTP port, not to an unrelated WSL service.
- Verify large-image behavior on the internal WSL registry path before migrating
  real CI jobs. Cloudflare request upload limits still matter for public/manual
  uploads, but routine WSL CI publishes should not use Cloudflare.
- Verify NUC disk mount and backup target paths before moving real Forgejo data.
- Verify `kosmos-forgejo-cutover-preflight` passes without
  `--allow-same-filesystem` before cutover, so the latest Forgejo dump is not
  only on the same filesystem as the live Forgejo state.
- Verify `kosmos-forgejo-backup-replicate` copies non-empty dumps to the NUC
  data disk backup directory, and then point cutover preflight at that directory.
- Verify `kosmos-forgejo-restore-smoke` passes against a cold-copy directory
  before treating the migration dry run as proven.
- Verify a cold copy can be used to start a target Forgejo instance and pass
  login, clone, push, package list, and package pull checks. A tar copy alone is
  not a completed migration dry run.
- Verify WSL reboot behavior for Forgejo, Dagger, Woodpecker, and cloudflared.

## Decisions

- Staging hostname: `git-wsl.guion.io`.
- Image owner: existing Forgejo org `GuionAI`; OCI image references use lowercase `guionai`.
- Production images: private by default.
- WSL devops scope: Forgejo, Forgejo Packages, Woodpecker server, Woodpecker
  agent, Dagger engine, cloudflared routes, and backups all live on kosmos WSL.
- Dagger cache cap: start with `100GB`.
- Backup target: use the NUC's additional disk as the first backup target.
- Database: start with SQLite to match the current cluster Forgejo; revisit
  Postgres after WSL Forgejo is stable.
- Production pull secret distribution: use the existing Emberstack Reflector
  auto-mirror pattern, with a `kubernetes.io/dockerconfigjson` source secret.
- Publish token storage: use agenix on kosmos WSL.
- MVP V1 pull-secret namespaces: `apps-dev`, `apps-prod`, and `apps-share`.
- Backup: part of the full plan, but not required for MVP V1 staging.
- Git SSH: not needed in the near future; keep MVP V1 to HTTPS Git and packages.

## Sources

- Forgejo Container Registry:
  https://forgejo.org/docs/latest/user/packages/container/
- Forgejo Package Registry:
  https://forgejo.org/docs/latest/user/packages/
- Forgejo Access Token Scope:
  https://forgejo.org/docs/latest/user/token-scope/
- Forgejo Configuration Cheat Sheet:
  https://forgejo.org/docs/latest/admin/config-cheat-sheet/
- Forgejo CLI / dump:
  https://forgejo.org/docs/latest/admin/command-line/
- Forgejo upgrade backup guidance:
  https://forgejo.org/docs/latest/admin/upgrade/
- Kubernetes private registry pulls:
  https://kubernetes.io/docs/tasks/configure-pod-container/pull-image-private-registry/
- Dagger engine configuration:
  https://docs.dagger.io/reference/configuration/engine/
- Dagger custom runner:
  https://docs.dagger.io/reference/configuration/custom-runner/
