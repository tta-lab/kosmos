# frpc SSH Tunnel

This stage supports an optional OpenFrp frpc client on `kosmos-wsl` for exposing
local SSH through OpenFrp.

The module is off by default:

```nix
kosmos.wsl.frpcSsh.enable = false;
```

## Binary

The OpenFrp frpc binary is not committed to this repo. Install it on WSL at:

```bash
/opt/openfrp/openfrp-frpc
```

Expected version:

```text
OF_0.68.0_37f78258_260326
```

## Required Secret

The system service reads one agenix-managed systemd environment file:

- `secrets/frpc-env.age`: OpenFrp user token and proxy ID list

Create the secret yourself:

```bash
cd /home/neil/code/projects/tta-lab/kosmos/secrets
agenix -e frpc-env.age -i ~/.ssh/agenix_ed25519
```

`frpc-env.age` must be a systemd environment file:

```text
OPENFRP_USER_TOKEN=actual-user-token
OPENFRP_PROXY_IDS=actual-proxy-id
```

## Enable

Enable the system service in `hosts/wsl/default.nix`:

```nix
kosmos.wsl.frpcSsh.enable = true;
```

The system service runs as the low-privilege `openfrp` user:

```bash
/opt/openfrp/openfrp-frpc -u "$OPENFRP_USER_TOKEN" -p "$OPENFRP_PROXY_IDS" -n
```

Both values are loaded from agenix at runtime, so neither value is written into
the Nix store.

The service has no root privileges and uses systemd sandboxing such as
`NoNewPrivileges`, `PrivateTmp`, `ProtectSystem=strict`, and `ProtectHome=true`.
Its only normal writable runtime path is `/var/lib/openfrp-frpc`.

## Risk Model

OpenFrp exposes a local SSH service through a third-party relay. Treat this as
a public network entry point, even when the target machine is inside WSL.

The main risks are:

- the relay provider can see connection metadata
- a leaked OpenFrp token can expose the configured proxy
- the downloaded client binary is not built from source in this repo
- a vulnerable SSH service becomes reachable from the internet
- a compromised frpc process could try to read local user secrets

Current mitigations:

- OpenSSH uses key-only login with password and keyboard-interactive auth off
- root SSH login is disabled
- sshd listens only on WSL loopback addresses
- the frpc token and proxy IDs live in `frpc-env.age`, not plaintext Nix files
- the service runs as the dedicated `openfrp` user, not `root` or `neil`
- the agenix output is owned by `openfrp` with mode `0400`
- systemd blocks access to home directories with `ProtectHome=true`
- systemd makes the system tree read-only with `ProtectSystem=strict`
- the only normal writable path is `/var/lib/openfrp-frpc`
- the client is started with `-n` so it does not self-update
- the binary is installed manually under `/opt/openfrp` and is not committed

Keep the OpenFrp panel config narrow: expose only local SSH on
`127.0.0.1:22`, use only the required proxy ID, and rotate the OpenFrp token if
it is ever pasted into logs, tickets, chat, or shell history.

## SSH Login

OpenSSH is configured for key-only login:

- password auth disabled
- keyboard-interactive auth disabled
- root login disabled
- public key auth enabled
- listen addresses restricted to `127.0.0.1:22` and `[::1]:22`

Neil's SSH public login key is managed in `modules/users/neil.nix`.

## References

- https://gofrp.org/en/docs/examples/ssh/
- https://gofrp.org/en/docs/features/common/authentication/
