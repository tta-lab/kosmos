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

The `mihomo` CLI is installed for local proxy experiments. Do not enable the NixOS service until `~/.config/mihomo/config.yaml` is handled through secrets; start with normal HTTP/SOCKS ports before trying TUN mode in WSL.

Codex CLI is installed outside Nixpkgs so it can track OpenAI's fast npm releases:

```bash
openai-codex-install
```

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

The user services are managed by Home Manager. NixOS only enables `linger` for `neil` so the user manager can keep running without an active login shell.

Proxy setup is dynamic. `kosmos-wsl-proxy-env` reads the Windows host IP from the default route, checks port `7897`, and emits `HTTP_PROXY`, `HTTPS_PROXY`, and `ALL_PROXY`. Fish and the TTAL user services load it automatically. Override the defaults with `KOSMOS_WSL_PROXY_HOST` or `KOSMOS_WSL_PROXY_PORT` if the proxy moves.

## Keep WSL Running After SSH Disconnect

WSL has two idle timers:

- `vmIdleTimeout` stops the shared WSL2 VM after all distro instances are idle.
- `instanceIdleTimeout` stops the distro instance after it has no active console sessions on newer Store WSL builds.

Set them from Windows, not from NixOS. Open PowerShell and edit the user-level WSL config:

```powershell
notepad $env:USERPROFILE\.wslconfig
```

Use this content:

```ini
[general]
instanceIdleTimeout=-1

[wsl2]
vmIdleTimeout=-1
```

Then restart WSL:

```powershell
wsl --shutdown
wsl -d NixOS
```

Verify the WSL version supports the general instance timeout:

```powershell
wsl --version
wsl --list --running
```

If `instanceIdleTimeout` is ignored, update Store WSL first:

```powershell
wsl --update
wsl --shutdown
```

`vmIdleTimeout` is documented in Microsoft's `.wslconfig` reference. If
`instanceIdleTimeout` is not accepted by the installed WSL build, keep
`vmIdleTimeout=-1` and use the fallback below.

Fallback for old or broken WSL versions: create a Windows scheduled task at logon that runs a long-lived command such as:

```powershell
wsl.exe -d NixOS --exec sleep infinity
```

That keeps a real WSL process alive even after SSH sessions disconnect. It is a workaround; prefer the `.wslconfig` timers when the installed WSL version supports them.

Project checkouts use two roots:

- `~/code/projects/<org>/<repo>` for repos we maintain or run from
- `~/code/references/<org>/<repo>` for external research clones

Clone or fetch the active project set from `ttal/projects.toml`:

```bash
kosmos-sync-projects
```

Existing repos are fetched with `git fetch --prune`; the command does not merge or change the working tree. Use `kosmos-sync-projects --collection references` for research-only repos.

Use `kosmos-sync-tta-lab-projects` when you only need the runtime repos required by `tta-lab-go-install`.

For the Podman-backed `k3d` local cluster flow, including the `dev` cluster create command and the `localhost:30432` Postgres mapping, see [docs/k3d-dev-cluster.html](docs/k3d-dev-cluster.html).

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
