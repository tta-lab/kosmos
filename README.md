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
- `ttal/`, `einai/`, `temenos/` — non-secret runtime config deployed to `~/.config`
- `scripts/sync-projects` — clones or fetches repos listed in `ttal/projects.toml`
- `packages/tta-lab/` — pinned release packages for tta-lab tools that are not in nixpkgs
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

## TTAL Runtime

The WSL host installs pinned release builds for `flicknote` and the GuionAI fork of `taskwarrior`. Frequently updated Go CLIs stay outside Nix for now and install into `~/go/bin`:

```bash
tta-lab-go-install
```

This starts the `tta-lab-go-install.service` oneshot user unit, which runs the `go install` set for `ttal`, `temenos`, `diary`, `organon`, `einai`, and `lenos`.

The user services `temenos.service`, `einai.service`, and `ttal.service` are defined in `modules/common/tta-lab-go.nix`. They only start after their binary exists in `~/go/bin`.

Code lives under two roots:

- `~/code/projects/<org>/<repo>` for repos we maintain or run from
- `~/code/references/<org>/<repo>` for external research clones

After applying the WSL host, clone or fetch the active project set from `ttal/projects.toml`:

```bash
kosmos-sync-projects
```

Use `remote = "git@host:org/repo.git"` in `ttal/projects.toml` when a repo is not on GitHub. Entries without `remote` default to `git@github.com:<org>/<repo>.git`.

## License

MIT
