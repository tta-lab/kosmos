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
sudo nixos-rebuild switch --flake .#wsl
```

The WSL host uses `wsl.defaultUser = "neil"` and keeps Windows PATH out of the shell environment:

```nix
wsl.interop.includePath = false;
wsl.wslConf.interop.appendWindowsPath = false;
```

## TTAL Runtime

The flake deploys non-secret config to `~/.config/ttal`, `~/.config/einai`, and `~/.config/temenos`. Real `chat_id`, `.env`, license, kubeconfig, and tunnel tokens are intentionally left out for the later secret-management PR.

Install or update the fast-moving Go CLIs with:

```bash
tta-lab-go-install
```

Then start the daemons:

```bash
systemctl --user start temenos einai ttal
systemctl --user status temenos einai ttal
```

The Go binaries live in `~/go/bin`, which is added to Fish and to the user services' `PATH`. The services are enabled for the user manager, but skip cleanly until the matching binary exists.

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
