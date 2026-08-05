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
sudo env NIX_CONFIG="$(cat ~/.config/nix/nix.conf)" \
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

WSL runs publisher and subscriber roles in one `kepos-device.service`. The
device owns one shared HyperDHT node while keeping the two identities separate.
Publisher state remains at `~/.local/state/kepos-neo/mux-publisher`; subscriber
state remains at `~/.local/state/kepos-neo/subscriber`. Existing complete state
is reused, and partial publisher state fails closed.

Home Manager generates one TOML file for the shared bootstrap list, publisher
policy, and subscriber policy. It contains public policy only. Private seeds
remain in the two state directories and are never copied into the Nix store.

Print the two WSL public role keys without exposing either private seed:

```bash
just kepos-publisher-key
just kepos-subscriber-key
```

The subscriber still pins the Mac publisher key declared in
`modules/wsl/kepos-neo.nix` and maps its published `ssh` service to
`127.0.0.1:2222`. Its HTTP gateway remains on port `17481`, leaving the local
Kubernetes ingress on port `17480` unchanged.

One device normally binds one HyperDHT UDP endpoint, but the preferred port may
already be occupied. Keep the Windows Hyper-V inbound rule for UDP
`49737-49741`; the shared runtime does not make that firewall range obsolete.

Inspect or operate the user service with:

```bash
just kepos-status
just kepos-logs
just kepos-restart
```

Add the WSL subscriber public key to the Mac publisher allowlist and restart
its publisher. Then connect to the Mac through the local Kepos listener:

```bash
ssh -p 2222 <mac-user>@127.0.0.1
```

### Migrate to the shared Kepos device service

Before switching from the former two-service generation:

1. Record the current NixOS generation with
   `readlink -f /nix/var/nix/profiles/system`.
2. Record the WSL publisher and subscriber public keys, and record both Mac
   role keys from Kepos Desktop. These four values must not change.
3. Record `MainPID`, `ExecStart`, and state for the old units:

   ```bash
   systemctl --user show kepos-publisher.service kepos-subscriber.service \
     -p Id -p MainPID -p ExecStart -p ActiveState
   ```

4. Confirm in Windows that the Hyper-V inbound UDP `49737-49741` rule remains
   enabled.
5. Release both state locks before switching:

   ```bash
   systemctl --user stop kepos-publisher.service kepos-subscriber.service
   ```

Deploy only after the Kosmos PR is merged and its checks pass:

```bash
sudo env NIX_CONFIG="$(cat ~/.config/nix/nix.conf)" \
  nixos-rebuild switch --flake .#wsl
```

Inspect the combined runtime:

```bash
systemctl --user status kepos-device.service --no-pager
systemctl --user show kepos-device.service \
  -p MainPID -p ExecStart -p ActiveState
ss -uanp
journalctl --user -u kepos-device.service --since=-10m --no-pager
```

Confirm there is one Kepos device PID and one bound HyperDHT UDP endpoint. Test
both directions and check that each command returns the remote hostname:

```bash
# Run in WSL: WSL subscriber to Mac publisher
ssh -p 2222 <mac-user>@127.0.0.1 hostname

# Run on the Mac: Mac subscriber to WSL publisher
ssh -p 2222 neil@127.0.0.1 hostname
```

Record all four role keys again, restart once with `just kepos-restart`, and
repeat the PID/socket, key, and bidirectional SSH checks.

If the migration fails, return to the immediately previous generation and
restore the former units:

```bash
sudo nixos-rebuild switch --rollback
systemctl --user daemon-reload
systemctl --user restart kepos-publisher.service kepos-subscriber.service
```

The rollback reuses the same state formats and identities; do not move, merge,
or regenerate either state directory.

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
