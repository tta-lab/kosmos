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

The system services read one agenix-managed systemd environment file:

- `secrets/frpc-env.age`: OpenFrp user tokens and proxy ID lists

Create the secret yourself:

```bash
cd /home/neil/code/projects/tta-lab/kosmos
agenix -e secrets/frpc-env.age -i ~/.ssh/agenix_ed25519
```

`frpc-env.age` must be a systemd environment file:

```text
OPENFRP_USER_TOKEN_SLOW=actual-slow-user-token
OPENFRP_PROXY_IDS_SLOW=actual-slow-proxy-id
OPENFRP_USER_TOKEN_FAST=actual-fast-user-token
OPENFRP_PROXY_IDS_FAST=actual-fast-proxy-id
```

## Enable

Enable the system service in `hosts/wsl/default.nix`:

```nix
kosmos.wsl.frpcSsh.enable = true;
```

The module starts two system services as the low-privilege `openfrp` user:

```bash
/opt/openfrp/openfrp-frpc -u "$OPENFRP_USER_TOKEN_SLOW" -p "$OPENFRP_PROXY_IDS_SLOW" -n
/opt/openfrp/openfrp-frpc -u "$OPENFRP_USER_TOKEN_FAST" -p "$OPENFRP_PROXY_IDS_FAST" -n
```

All four values are loaded from agenix at runtime, so no token or proxy ID is
written into the Nix store.

The service has no root privileges and uses systemd sandboxing such as
`NoNewPrivileges`, `PrivateTmp`, `ProtectSystem=strict`, and `ProtectHome=true`.
Their only normal writable runtime paths are `/var/lib/openfrp-frpc-slow` and
`/var/lib/openfrp-frpc-fast`.

## Risk Model

OpenFrp exposes a local SSH service through a third-party relay. Treat this as
a public network entry point, even when the target machine is inside WSL.

The main risks are:

- the relay provider can see connection metadata
- a leaked OpenFrp token can expose the configured proxy
- OpenFrp remote-config mode requires the token in frpc command-line arguments
- the downloaded client binary is not built from source in this repo
- a vulnerable SSH service becomes reachable from the internet
- a compromised frpc process could try to read local user secrets

Current mitigations:

- OpenSSH uses key-only login with password and keyboard-interactive auth off
- root SSH login is disabled
- sshd listens only on WSL loopback addresses
- the frpc tokens and proxy IDs live in `frpc-env.age`, not plaintext Nix files
- both services run as the dedicated `openfrp` user, not `root` or `neil`
- the agenix output is owned by `openfrp` with mode `0400`
- systemd blocks access to home directories with `ProtectHome=true`
- systemd makes the system tree read-only with `ProtectSystem=strict`
- the only normal writable paths are under `/var/lib/openfrp-frpc-*`
- the client is started with `-n` so it does not self-update
- the binary is installed manually under `/opt/openfrp` and is not committed
- any frpc exit is treated as service failure, because OpenFrp may exit `0`
  after a remote startup failure

Keep the OpenFrp panel config narrow: expose only local SSH on
`127.0.0.1:22`, use only the required proxy IDs, and rotate the OpenFrp tokens
if they are ever pasted into logs, tickets, chat, or shell history.

Local process command lines can expose the OpenFrp user token while frpc is
running. This is a limitation of OpenFrp remote-config mode, whose documented
Linux startup command uses `-u <token> -p <proxy-id>`. Treat the WSL host and
local admin users as trusted. To remove this exposure, switch from OpenFrp
remote-config mode to provider-generated full frpc config files stored in
agenix.

Panel-provided remote SSH endpoints are intentionally not stored in this repo.
Use the `slow` and `fast` service names to compare providers or routes:

```bash
systemctl status openfrp-frpc-slow
systemctl status openfrp-frpc-fast
```

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
