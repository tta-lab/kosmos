# WSL DevOps Runbook

The WSL DevOps stack runs in the single-node NixOS k3s cluster. Nix manages
k3s and the Kepos publisher and subscriber; Tanka manages the Kubernetes
objects. A NixOS switch never applies Tanka.

## Endpoints

- Forgejo: `http://forgejo.localhost:17480`
- Woodpecker: `http://woodpecker.localhost:17480`
- Dagger: `tcp://dagger.devops.svc.cluster.local:8080` in-cluster and
  `tcp://127.0.0.1:8080` for the local CLI
- k3s API: `https://127.0.0.1:26443`
- Anki Sync: `http://anki.localhost:17480/` through Kepos

Caddy binds the host gateway only on `127.0.0.1:17480`. CoreDNS rewrites the
two canonical `.localhost` names to that same gateway inside the cluster. This
keeps browser, Git, Woodpecker OAuth, webhooks, and container-registry URLs
consistent.

Kepos publishes application service IDs including:

- `forgejo` and `woodpecker` both target port `17480`; the preserved HTTP Host
  header selects the Caddy route.
- `navidrome` targets port `4533`.
- `dagger` targets the Dagger engine on port `8080` and is restricted to the
  named Mac subscriber. Other allowed subscribers neither see nor can open it.
- `ssh` targets port `22`.
- `anki` targets the canonical gateway on port `17480`; see
  [anki-sync.md](anki-sync.md) for credentials, deployment, and first sync.

The separate Ente Photos stack publishes `ente` and `ente-storage`, both through
the canonical gateway on port `17480`. See [ente-photos.md](ente-photos.md) for
its deployment order and mobile acceptance checks.

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

## Deploy

Deploy the NixOS generation first so k3s, its directories, the Woodpecker
Secret sync unit, the packaged Kepos CLI, and the user service exist:

```bash
sudo env NIX_USER_CONF_FILES="$HOME/.config/nix/nix.conf" \
  nixos-rebuild switch --flake .#wsl
```

Open a new WSL shell after the switch so the session picks up membership in
the `k3s` group.

The root-owned `woodpecker-secret-sync.service` reads
`/run/agenix/woodpecker-server-env` and creates or updates
`devops/woodpecker-server-env`. It always uses
`/etc/rancher/k3s/k3s.yaml` and refuses an API server other than
`https://127.0.0.1:26443`. The unit runs at boot, retries if k3s is not ready,
restarts when the encrypted agenix file changes, and rolls the Woodpecker
server and agents when the Kubernetes Secret is updated.

Verify the sync before applying the workloads:

```bash
systemctl status woodpecker-secret-sync.service --no-pager
```

The upstream Kepos Home Manager module reuses the publisher state at
`~/.local/state/kepos-neo/mux-publisher`. If the state is absent, the module
initializes it before starting the publisher.

Print the WSL publisher public key without exposing its private state:

```bash
just kepos-publisher-key
```

The WSL subscriber for the Mac publisher is declaratively disabled because the
current nested network cannot establish that direction. Its configuration,
identity, pinned publisher contact, and state at
`~/.local/state/kepos-neo/subscriber` remain intact for a future retry. The Mac
publisher may keep the WSL subscriber key in its allowlist.

While disabled, WSL does not listen on the subscriber gateway `17481` or the
local SSH endpoint `127.0.0.1:2222`. To inspect the retained subscriber public
key without starting the service:

```bash
just kepos-subscriber-key
```

Do not remove the subscriber state or Mac allowlist entry. Resume this direction
only after selecting and verifying a network or relay path from orientation
notes 1724 and 1725, then set `enableMacSubscriber` in
`modules/wsl/kepos-neo.nix` to `true` and rebuild WSL.

Apply the Kubernetes objects explicitly:

```bash
just diff
just apply
just status
```

Forgejo and Woodpecker use static local PVs with a `Retain` reclaim policy.
Dagger starts with a fresh cache at `/var/lib/kosmos-k3s/dagger`.

## Recover

Reapplying NixOS or Tanka does not delete the retained Forgejo and Woodpecker
data under `/var/lib/kosmos-k3s`. There is no legacy-systemd rollback command.

If the Woodpecker Secret is missing or stale, repair the encrypted secret,
rebuild NixOS, and verify the sync unit. To retry without changing the secret:

```bash
sudo systemctl restart woodpecker-secret-sync.service
sudo journalctl -u woodpecker-secret-sync.service -n 100 --no-pager
just apply
```

If application data must be restored, scale the affected workload down before
restoring its retained directory in `/var/lib/kosmos-k3s`, preserve the file
ownership documented by the NixOS tmpfiles rules, then run `just apply`. Do not
copy data back to the removed legacy services.

## Runtime checks

```bash
just status
kosmos-devops-gate-status --strict
just kepos-status
curl --fail http://forgejo.localhost:17480/api/healthz
curl --fail http://woodpecker.localhost:17480/healthz
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

On the Mac, add a raw TCP listener for the published `dagger` service to
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
