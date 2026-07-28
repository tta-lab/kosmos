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

Proxy is provided by the local Mihomo systemd service at `127.0.0.1:7890`.
The listener accepts HTTP and SOCKS5. MetaCubeXD is served by the loopback-only
controller on port `9090` and published to the Mac through the Kepos
`mihomo-dashboard` service. Enter the controller secret from Clash Verge when
the dashboard asks for it; agents must not read that value. The standalone DNS
listener is disabled while Mihomo's internal DNS processing remains enabled.
The service loads Clash Verge's generated runtime YAML from the mounted Windows
profile through systemd credentials, so the secret-bearing file does not enter
Git or the Nix store. The `kosmos-wsl-proxy-env` helper remains available for
manual bootstrap fallback.

Verify both proxy protocols locally:

```bash
curl --proxy http://127.0.0.1:7890 https://www.google.com/generate_204
curl --socks5-hostname 127.0.0.1:7890 https://www.google.com/generate_204
```

**Windows `.wslconfig` required:**

```ini
[general]
instanceIdleTimeout=-1

[wsl2]
networkingMode=mirrored
firewall=true
vmIdleTimeout=-1

[experimental]
hostAddressLoopback=true
```

K3s containerd starts after the local Mihomo service and uses its loopback
listener for image pulls.

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
systemctl --user start temenos einai ttal og
systemctl --user status temenos einai ttal og
```

The Go binaries live in `~/go/bin`, which is added to Fish and to the user services' `PATH`. The services are enabled for the user manager, but skip cleanly until the matching binary exists.

The user services are managed by Home Manager. NixOS only enables `linger` for `neil` so the user manager can keep running without an active login shell.

Fish and TTAL services use the local Mihomo systemd service through
`HTTP_PROXY`/`HTTPS_PROXY`/`ALL_PROXY` (and lowercase equivalents) at
`http://127.0.0.1:7890`.

## Keep WSL Running After SSH Disconnect

WSL has two idle timers:

- `instanceIdleTimeout` stops the distro instance after it has no active console sessions.
- `vmIdleTimeout` stops the shared WSL2 VM after all distro instances are idle.

Set them from Windows, not from NixOS. Open PowerShell and edit the user-level WSL config:

```powershell
notepad $env:USERPROFILE\.wslconfig
```

The complete `.wslconfig` shown in the TTAL Runtime section already includes
both timeout settings. Keep its mirrored networking, firewall, and
`hostAddressLoopback` settings when changing the idle timers.

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

Microsoft introduced `general.instanceIdleTimeout` in the WSL 2.5.4 release to
control distribution termination timeouts. If `instanceIdleTimeout` is ignored,
update Store WSL first:

```powershell
wsl --update
wsl --shutdown
```

`vmIdleTimeout` is documented in Microsoft's `.wslconfig` reference. The
`instanceIdleTimeout` setting is documented in WSL release notes rather than the
main `.wslconfig` reference. If the installed WSL build does not accept it, keep
`vmIdleTimeout=-1` and use the fallback below.

Fallback for old or broken WSL versions: create a Windows scheduled task at logon that runs a long-lived command such as:

```powershell
wsl.exe -d NixOS --exec sleep infinity
```

That keeps a real WSL process alive even after SSH sessions disconnect. It is a workaround; prefer the `.wslconfig` timers when the installed WSL version supports them.

References:

- https://learn.microsoft.com/windows/wsl/wsl-config
- https://github.com/microsoft/WSL/releases/tag/2.5.4

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
