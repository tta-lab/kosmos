# frpc SSH Tunnel

This stage supports an optional frpc client on `kosmos-wsl` for exposing local
SSH through a remote frps server.

The module is off by default:

```nix
kosmos.wsl.frpcSsh.enable = false;
```

## Required Values

Before enabling it, choose:

- `serverAddr`: frps server hostname or IP address
- `serverPort`: frps bind port, usually `7000`
- `remotePort`: public TCP port on the frps server for SSH
- `secrets/frpc-token.age`: frps token encrypted with agenix

Create the token secret yourself:

```bash
cd /home/neil/code/projects/tta-lab/kosmos/secrets
agenix -e frpc-token.age -i ~/.ssh/agenix_ed25519
```

## Enable

Add host-specific values to `hosts/wsl/default.nix`:

```nix
kosmos.wsl.frpcSsh = {
  enable = true;
  serverAddr = "frps.example.com";
  serverPort = 7000;
  remotePort = 2222;
};
```

The frpc config uses file-based token auth, so the token is not written into the
Nix store.

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
