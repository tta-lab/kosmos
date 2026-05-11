# NixOS-WSL Guide

This host is for trying the Kosmos environment without reinstalling the Intel NUC.

## Install NixOS-WSL

On Windows, install WSL and import the NixOS-WSL distribution from the latest release:

```powershell
wsl --install --no-distribution
```

Download `nixos.wsl` from the NixOS-WSL release page, open it, then start the distro:

```powershell
wsl -d NixOS
```

## Apply This Flake

Inside NixOS-WSL:

```bash
mkdir -p ~/code/projects/tta-lab
cd ~/code/projects/tta-lab
git clone https://github.com/tta-lab/kosmos.git
cd kosmos
git fetch origin feat/tta-lab-wsl-runtime
git switch --track origin/feat/tta-lab-wsl-runtime
sudo nixos-rebuild switch --flake .#wsl --extra-experimental-features "nix-command flakes"
```

The WSL host uses `wsl.defaultUser = "neil"` and keeps Windows PATH out of the shell environment:

```nix
wsl.interop.includePath = false;
wsl.wslConf.interop.appendWindowsPath = false;
```

## TTAL Runtime

Home Manager deploys non-secret config to `~/.config/ttal`, `~/.config/einai`, and `~/.config/temenos`. Real `chat_id`, `.env`, license, kubeconfig, and tunnel tokens are intentionally left out for the later secret-management PR.

Install or update the fast-moving Go CLIs with:

```bash
tta-lab-go-install
```

The installer first runs `kosmos-sync-tta-lab-projects`, then installs the binaries from local checkouts in `~/code/projects/tta-lab`. This avoids `go install module@version` problems with local `replace` directives.

Then start the daemons:

```bash
systemctl --user start temenos einai ttal
systemctl --user status temenos einai ttal
```

The Go binaries live in `~/go/bin`, which is added to Fish and to the user services' `PATH`. The services are enabled for the user manager, but skip cleanly until the matching binary exists.

Proxy setup is dynamic. `kosmos-wsl-proxy-env` reads the Windows host IP from the default route, checks port `7897`, and emits `HTTP_PROXY`, `HTTPS_PROXY`, and `ALL_PROXY`. Fish and the TTAL user services load it automatically. Override the defaults with `KOSMOS_WSL_PROXY_HOST` or `KOSMOS_WSL_PROXY_PORT` if the proxy moves.

Project checkouts use two roots:

- `~/code/projects/<org>/<repo>` for repos we maintain or run from
- `~/code/references/<org>/<repo>` for external research clones

Clone or fetch the active project set from `ttal/projects.toml`:

```bash
kosmos-sync-projects
```

Existing repos are fetched with `git fetch --prune`; the command does not merge or change the working tree. Use `kosmos-sync-projects --collection references` for research-only repos.

Use `kosmos-sync-tta-lab-projects` when you only need the first-party tta-lab checkouts for runtime binaries.

## Rathole Tunnel

The Rathole client scaffold lives in `modules/common/tunnel-rathole-client.nix`. It is imported by the WSL host but disabled until the VPS endpoint and token are ready.

Client secret file:

```toml
[client.services.ssh]
token = "same-token-as-vps"
```

For a future Matrix/Tuwunel tunnel, add a second service:

```nix
client.services.matrix = {
  local_addr = "127.0.0.1:8008";
};
```

and put its token in the secret TOML file.
