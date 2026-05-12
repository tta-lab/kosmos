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

## SSH Login

OpenSSH is configured for key-only login:

- password auth disabled
- keyboard-interactive auth disabled
- root login disabled
- public key auth enabled

Add Neil's SSH public login key in `modules/users/neil.nix` before relying on
remote SSH access.

## References

- https://gofrp.org/en/docs/examples/ssh/
- https://gofrp.org/en/docs/features/common/authentication/
