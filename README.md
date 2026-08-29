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
- `lenos/`, `temenos/` — non-secret tool config deployed by Home Manager
- `scripts/install-tta-lab-go` — installs Go CLIs from existing local checkouts
- `scripts/install-tta-lab-releases` — installs current FlickNote and Taskwarrior releases from GitHub (run directly, no service)
- `scripts/install-tta-lab-go` — builds and installs tta-lab Go CLIs into ~/go/bin from local checkouts (run directly, no service)
- `scripts/sync-codex-auth.ts` — Bun script that converts OAuth credentials between `~/.codex/auth.json` and `~/.pi/agent/auth.json` (deployed to `~/.pi/sync-codex-auth.ts`); run `just sync-codex-auth codex-to-pi` first to seed the id_token, then `just sync-codex-auth pi-to-codex` works indefinitely
- `packages/tta-lab/` — build helper for the tta-lab tmux project picker
- `configuration.nix` — compatibility entry point for the `kosmos` host
- `disko-config.nix` — declarative NVMe partition layout for bare-metal install
- `install-guide.md` — step-by-step install instructions
- `wsl-guide.md` — NixOS-WSL setup notes
- `docs/environment.md` — environment-variable ownership and scope
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
The mixed listener accepts both HTTP and SOCKS5 clients. MetaCubeXD is bundled
at the loopback-only controller on port `9090` and is published to the Mac as
the Kepos `mihomo-dashboard` service. The standalone DNS listener is disabled;
Mihomo still applies the inherited DNS configuration internally to proxied
hostnames.
Mihomo binds the mixed port to loopback so the systemd CNI forwarder can own a
stable Pod proxy endpoint. `modules/wsl/proxy-topology.json` is the shared
topology source for that endpoint, the Pod and Service CIDRs, and the local
listener; both Nix and Tanka consume it. This address split is not intended as
a general policy against user-configured LAN listeners. The NixOS firewall stays
masked on WSL by design.
Mihomo loads the generated Clash Verge runtime configuration from the mounted
Windows profile through systemd credentials; the configuration is never copied
into the Nix store. The WSL URL and base bypass list have one owner:
`kosmos.wsl.proxy` in `modules/wsl/proxy.nix`, derived from that topology. It
generates both proxy variable cases for shells and managed services. K3s adds
its cluster-only bypasses on top. The `kosmos-wsl-proxy-env` helper remains a
separate dynamic manual bootstrap fallback. See [environment ownership](docs/environment.md).

## Codex CLI

WSL installs OpenAI Codex CLI with npm instead of Nixpkgs because Codex releases often and Nixpkgs can lag. Apply the host, then run:

```bash
openai-codex-install
```

This installs `@openai/codex@latest` into `~/.local/share/npm-global/bin`, which Fish adds to `PATH`.

## Pi Coding Agent

WSL installs Pi with npm so its CLI can track the latest release. Apply the host, then run:

```bash
pi-install
```

This installs `@earendil-works/pi-coding-agent@latest` into
`~/.local/share/npm-global/bin`, plus the latest Mitsupi,
`pi-mcp-adapter`, and `pi-herdr-subagents` packages. It also installs Herdr's
Pi integration. Re-run `pi-install` to refresh them; update other Pi packages
with:

```bash
pi update --all
```

The `pi-mcp-adapter` package loads `~/.pi/agent/mcp.json`, which imports MCP
servers configured for Codex.

## TTA Lab Tools

FlickNote and the GuionAI fork of `taskwarrior` are installed from GitHub
Releases outside Nix. The installer only installs released binaries; it does
not manage the FlickNote daemon. Requires the proxy env (e.g. mihomo's
`http://127.0.0.1:7890`) in the shell:

```bash
bash scripts/install-tta-lab-releases
# or, once executable:
./scripts/install-tta-lab-releases
```

The installer verifies each GitHub release asset's SHA-256 digest and
atomically installs binaries and shell completions to `~/.local`.

Frequently updated Go CLIs stay outside Nix for now and install from local
checkouts into `~/go/bin`:

```bash
tta-lab-go-install
```

This starts the `tta-lab-go-install.service` oneshot user unit. It installs `temenos`, `diary`, `organon` (`og`, `project`, `skill`, `src`, and `web`), and `lenos` from existing checkouts in `~/code/projects/tta-lab`. A missing checkout is an error; Kosmos does not clone or fetch project repositories.

The Home Manager user service `temenos.service` is defined in `modules/common/tta-lab-go.nix`. It starts only after its binary exists in `~/go/bin`.

Fish, Zsh, and the Home Manager user services derive their proxy environment
from `kosmos.wsl.proxy`; see [environment ownership](docs/environment.md).

For a fresh machine, bootstrap the public Organon repository anonymously, install
the repository tools, and start the Home Manager-managed daemon:

```bash
mkdir -p ~/code/projects/tta-lab
git clone https://github.com/tta-lab/organon.git ~/code/projects/tta-lab/organon
cd ~/code/projects/tta-lab/organon
CGO_ENABLED=0 go install ./cmd/og ./cmd/project

og clone https://github.com/tta-lab/organon.git
og clone https://github.com/tta-lab/temenos.git
og clone https://github.com/tta-lab/diary.git
og clone https://github.com/tta-lab/lenos.git
tta-lab-go-install
```

The first `og clone` recognizes the existing Organon checkout and registers it.
Subsequent clones derive paths under `~/code/projects/<owner>/<repo>` and register
their aliases. Use `og clone --reference <https-url>` for research-only checkouts
under `~/code/references/<host>/<owner>/<repo>`. Use `og pull` to update a
registered checkout; Kosmos has no repository sync command.

## License

MIT
