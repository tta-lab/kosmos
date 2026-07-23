# WSL DevOps Runbook

The WSL DevOps stack runs in the single-node NixOS k3s cluster. Nix manages
k3s and the Kepos publisher; Tanka manages the Kubernetes objects. A NixOS
switch never applies Tanka.

## Endpoints

- Forgejo: `http://forgejo.localhost:17480`
- Woodpecker: `http://woodpecker.localhost:17480`
- Dagger: `tcp://dagger.devops.svc.cluster.local:8080` in-cluster and
  `tcp://127.0.0.1:8080` for the local CLI
- k3s API: `https://127.0.0.1:26443`

Caddy binds the host gateway only on `127.0.0.1:17480`. CoreDNS rewrites the
two canonical `.localhost` names to that same gateway inside the cluster. This
keeps browser, Git, Woodpecker OAuth, webhooks, and container-registry URLs
consistent.

Kepos publishes four service IDs:

- `forgejo` and `woodpecker` both target port `17480`; the preserved HTTP Host
  header selects the Caddy route.
- `navidrome` targets port `4533`.
- `ssh` targets port `22`.

Local WSL clients connect directly to the loopback Caddy endpoint. They do not
traverse Kepos.

## Configuration checks

These commands do not change the cluster:

```bash
just show
just diff
just status
```

`just apply` is the explicit normal apply command. It refuses any kubeconfig
whose active API server is not `https://127.0.0.1:26443`.

## First cutover

Deploy the NixOS generation first so k3s, its directories, the packaged Kepos
CLI, and the user service exist:

```bash
sudo env NIX_CONFIG="$(cat ~/.config/nix/nix.conf)" \
  nixos-rebuild switch --flake .#wsl
```

Open a new WSL shell after the switch so the session picks up membership in
the `k3s` group.

Initialize the multiplex Kepos state once. The command preserves the seed and
allowlist from the current Navidrome multiplex publisher, and only replaces
the declared service list. It does not print either secret:

```bash
just kepos-init
```

Then perform the DevOps cutover:

```bash
just cutover
```

The cutover command:

1. stops the legacy Forgejo, Woodpecker, and Dagger systemd services;
2. copies Forgejo and Woodpecker data to `/var/lib/kosmos-k3s` while SQLite is
   stopped, then changes the copied Woodpecker OAuth callback to
   `http://woodpecker.localhost:17480/authorize`;
3. creates the Kubernetes Woodpecker secret from the existing agenix runtime
   file without printing it;
4. applies Tanka, waits for every workload, checks both HTTP health paths, and
   verifies that Dagger can pull and run a public image;
5. writes a cutover marker that keeps the legacy services and Cloudflare
   tunnel disabled across reboots.

The command restarts the legacy services automatically if prepare, apply,
rollout, health checks, or the Dagger pull fail. The migration writes a
`migration-prepared` marker only after both copied databases and the Kubernetes
secret are ready. Rollback refuses to overwrite the legacy data unless that
marker exists and both copied SQLite databases pass an integrity check.

Forgejo and Woodpecker use static local PVs with a `Retain` reclaim policy.
Dagger starts with a fresh cache at `/var/lib/kosmos-k3s/dagger`.

## Rollback

```bash
just rollback
```

Rollback deletes the k3s workloads but retains their PVs, copies Forgejo and
Woodpecker data back to the legacy directories while the pods are stopped,
restores the old OAuth callback, and restarts the legacy systemd services.
This preserves writes made after cutover instead of silently returning to the
pre-cutover SQLite snapshot.

## Runtime checks

```bash
just status
just kepos-status
curl --fail http://forgejo.localhost:17480/api/healthz
curl --fail http://woodpecker.localhost:17480/healthz
```

`just cutover` includes a public-image pull because socket reachability is not
enough. To repeat that check manually:

```bash
_EXPERIMENTAL_DAGGER_RUNNER_HOST=tcp://127.0.0.1:8080 \
  dagger -M call container from --address alpine:3.20 \
  with-exec --args=echo --args=dagger-pull-ok stdout
```

Cloudflare is not part of the new request path. Keep the legacy units only
through first-cutover acceptance; remove them and their Cloudflare module in a
follow-up cleanup after rollback is no longer needed.
