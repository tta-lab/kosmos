# Kosmos

NixOS configuration for a headless dev/ops environment. It supports both the Intel NUC bare-metal host and a lower-cost NixOS-WSL trial host.

## Structure

- `flake.nix` — flake inputs and host outputs
- `hosts/kosmos/` — bare-metal NixOS host for the Intel NUC
- `hosts/wsl/` — NixOS-WSL host config
- `modules/common/` — shared Nix, packages, locale, shell, and tool config
- `modules/nixos/` — bare-metal boot, network, SSH, proxy, firewall, and containers
- `modules/wsl/` — WSL-specific settings
- `modules/users/` — shared user definitions
- `configuration.nix` — compatibility entry point for the `kosmos` host
- `disko-config.nix` — declarative NVMe partition layout for bare-metal install
- `install-guide.md` — step-by-step install instructions
- `wsl-guide.md` — NixOS-WSL setup notes

## Quick Start

```bash
# Syntax check (requires nix)
nix-instantiate --parse configuration.nix

# Build bare-metal host
nix flake check
nix build .#nixosConfigurations.kosmos.config.system.build.toplevel --no-link

# Build WSL host
nix build .#nixosConfigurations.wsl.config.system.build.toplevel --no-link
```

## Rathole Tunnel

Both hosts import `modules/common/tunnel-rathole-client.nix`, but the service is disabled by default. To enable it:

1. Set the real VPS address in `client.remote_addr`.
2. Change `services.rathole.enable` to `true`.
3. Put service tokens in `/var/lib/secrets/rathole/client.toml`, not in git.

The initial tunnel maps remote traffic to local SSH on `127.0.0.1:22`. Add another service for Matrix/Tuwunel when needed.

## License

MIT
