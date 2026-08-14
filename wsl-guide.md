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

## TTA Lab Tools

Home Manager deploys non-secret config to `~/.config/lenos` and `~/.config/temenos`.
The project registry under `~/.config/ttal` is unmanaged; normal additions go
through `og clone`. Kosmos deploys the agenix-backed forge-token environment and
injects it only into the og user service.

Proxy is provided by the local Mihomo systemd service at `127.0.0.1:7890`.
The listener accepts HTTP and SOCKS5. MetaCubeXD is served by the loopback-only
controller on port `9090` and published to the Mac through the Kepos
`mihomo-dashboard` service. Enter the controller secret from Clash Verge when
the dashboard asks for it; agents must not read that value. The standalone DNS
listener is disabled while Mihomo's internal DNS processing remains enabled.
Mihomo binds the mixed port to loopback so the systemd CNI forwarder can own a
stable Pod proxy endpoint. `modules/wsl/proxy-topology.json` is the shared
topology source for that endpoint, the Pod and Service CIDRs, and the local
listener; both Nix and Tanka consume it. This address split is not intended as
a general policy against user-configured LAN listeners. The NixOS firewall stays
masked on WSL by design.
The service loads Clash Verge's generated runtime YAML from the mounted Windows
profile through systemd credentials, so the secret-bearing file does not enter
Git or the Nix store. `kosmos.wsl.proxy` in `modules/wsl/proxy.nix`, derived
from `modules/wsl/proxy-topology.json`, is the WSL source of truth for the URL
and base bypass list. It generates the shell and service proxy variables and
`/etc/kosmos/proxy.env` for self-managed services. The
`kosmos-wsl-proxy-env` helper remains a separate dynamic manual bootstrap
fallback. See [environment ownership](docs/environment.md).

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

The installer only installs managed binaries from existing local checkouts in `~/code/projects/tta-lab`. It reports the exact missing Go module and exits if a required checkout is absent. Kosmos does not clone or fetch project repositories.

Then start the daemons:

```bash
systemctl --user start temenos og
systemctl --user status temenos og
```

The Go binaries live in `~/go/bin`, which is added to Fish and to the user services' `PATH`. The services are enabled for the user manager, but skip cleanly until the matching binary exists.

The user services are managed by Home Manager. NixOS only enables `linger` for `neil` so the user manager can keep running without an active login shell.

Fish, Zsh, and the Home Manager user services derive their proxy environment
from `kosmos.wsl.proxy`; see [environment ownership](docs/environment.md).

## Keep WSL Running After SSH Disconnect

WSL has two idle timers:

- `instanceIdleTimeout` stops the distro instance after it has no active console sessions.
- `vmIdleTimeout` stops the shared WSL2 VM after all distro instances are idle.

Set them from Windows, not from NixOS. Open PowerShell and edit the user-level WSL config:

```powershell
notepad $env:USERPROFILE\.wslconfig
```

The complete `.wslconfig` shown in the TTA Lab Tools section already includes
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

For a fresh environment, bootstrap the public Organon checkout anonymously, install
`og` and `project`, then let og own all later clone and credential behavior:

```bash
mkdir -p ~/code/projects/tta-lab
git clone https://github.com/tta-lab/organon.git ~/code/projects/tta-lab/organon
cd ~/code/projects/tta-lab/organon
CGO_ENABLED=0 go install ./cmd/og ./cmd/project
systemctl --user start og

og clone https://github.com/tta-lab/organon.git
og clone https://github.com/tta-lab/temenos.git
og clone https://github.com/tta-lab/diary.git
og clone https://github.com/tta-lab/lenos.git
tta-lab-go-install
```

The existing Organon checkout is reused and registered. Project clones go to
`~/code/projects/<owner>/<repo>`; `og clone --reference <https-url>` creates
research-only checkouts under `~/code/references/<host>/<owner>/<repo>`.
Use `og pull` for repository updates. Kosmos provides no sync wrapper.

For the Podman-backed `k3d` local cluster flow, including the `dev` cluster create command and the `localhost:30432` Postgres mapping, see [docs/k3d-dev-cluster.html](docs/k3d-dev-cluster.html).

## Rathole Tunnel

The Rathole client scaffold lives in `modules/common/tunnel-rathole-client.nix`. It is imported by the WSL host but disabled until the VPS endpoint and token are ready.

Client secret file:

```toml
[client.services.ssh]
token = "same-token-as-vps"
```
