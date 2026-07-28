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
- `ttal/`, `einai/`, `temenos/` — non-secret runtime config deployed by Home Manager
- `scripts/sync-projects` — clones or fetches repos listed in `ttal/projects.toml`
- `packages/tta-lab/` — pinned release packages for tta-lab tools that are not in nixpkgs
- `configuration.nix` — compatibility entry point for the `kosmos` host
- `disko-config.nix` — declarative NVMe partition layout for bare-metal install
- `install-guide.md` — step-by-step install instructions
- `wsl-guide.md` — NixOS-WSL setup notes
- `docs/k3d-dev-cluster.html` — Podman + k3d local cluster setup for WSL

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

The initial tunnel maps remote traffic to local SSH on `127.0.0.1:22`.

## Proxy

Proxy is provided by the local Mihomo systemd service at `127.0.0.1:7890`.
Mihomo loads the generated Clash Verge runtime configuration from the mounted
Windows profile through systemd credentials; the configuration is never copied
into the Nix store. The `kosmos-wsl-proxy-env` helper remains available for
manual bootstrap fallback.

## Codex CLI

WSL installs OpenAI Codex CLI with npm instead of Nixpkgs because Codex releases often and Nixpkgs can lag. Apply the host, then run:

```bash
openai-codex-install
```

This installs `@openai/codex@latest` into `~/.local/share/npm-global/bin`, which Fish adds to `PATH`.

## TTAL Runtime

The WSL host installs pinned release builds for `flicknote` and the GuionAI fork of `taskwarrior`. Frequently updated Go CLIs stay outside Nix for now and install from local checkouts into `~/go/bin`:

```bash
tta-lab-go-install
```

This starts the `tta-lab-go-install.service` oneshot user unit. It first runs `kosmos-sync-tta-lab-projects`, then installs `ttal`, `temenos`, `diary`, `organon` (`og`, `skill`, `src`, and `web`), `einai`, and `lenos` from `~/code/projects/tta-lab`.

The Home Manager user services `temenos.service`, `einai.service`, `ttal.service`, and `og.service` are defined in `modules/common/tta-lab-go.nix`. They only start after their binary exists in `~/go/bin`.

Fish and TTAL services use the local Mihomo systemd service through
`HTTP_PROXY`/`HTTPS_PROXY`/`ALL_PROXY` (and lowercase equivalents) at
`http://127.0.0.1:7890`.

Code lives under two roots:

- `~/code/projects/<org>/<repo>` for repos we maintain or run from
- `~/code/references/<org>/<repo>` for external research clones

After applying the WSL host, clone or fetch the active project set from `ttal/projects.toml`:

```bash
kosmos-sync-projects
```

Use `remote = "https://host/org/repo.git"` in `ttal/projects.toml` when a repo is not on GitHub. Entries without `remote` default to `https://github.com/<org>/<repo>.git`.

For HTTPS remotes, `kosmos-sync-projects` reads only the required token from
`~/.config/ttal/.env`. Forgejo uses `FORGEJO_TOKEN`; GitHub uses the project's
`github_token_env`, then the mapping in `~/.config/ttal/orgs.toml`, then
`GITHUB_TOKEN` or `GH_TOKEN`.

To sync only the runtime repos needed by `tta-lab-go-install`:

```bash
kosmos-sync-tta-lab-projects
```

## License

MIT
