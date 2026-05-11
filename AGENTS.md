# Repository Guidelines

## Project Structure & Module Organization

This repository defines NixOS configs for the `kosmos` Intel NUC and a lower-cost NixOS-WSL trial host.

- `flake.nix` declares inputs, host outputs, and the dev shell.
- `hosts/kosmos/` is the bare-metal Intel NUC entry point.
- `hosts/wsl/` is the NixOS-WSL entry point.
- `modules/common/` contains shared Nix, packages, SSH, system shell enablement, user services, and the disabled Rathole client scaffold.
- `modules/nixos/` contains bare-metal boot, network, proxy, firewall, and container config.
- `modules/wsl/` and `modules/users/` contain WSL options and shared users.
- `modules/configs.nix` uses Home Manager for user files, fish functions, Git config, and prompt config.
- `configuration.nix` is a compatibility entry for `hosts/kosmos`.
- `disko-config.nix` defines the NUC NVMe layout. Treat changes as destructive until tested.
- `helix/`, `ttal/`, `einai/`, and `temenos/` hold non-secret user/runtime config managed by Home Manager.
- `.github/workflows/check.yml` runs syntax and lint checks in CI.

## Build, Test, and Development Commands

Use Nix commands from the repo root.

```bash
nix develop
```

Enter the dev shell with Nix tooling.

```bash
nix-instantiate --parse configuration.nix
```

Check Nix syntax without full evaluation.

```bash
statix check .
nix flake check
nix build .#nixosConfigurations.kosmos.config.system.build.toplevel --no-link
nix build .#nixosConfigurations.wsl.config.system.build.toplevel --no-link
```

Lint, validate the flake, and build both host closures without result symlinks.

## Coding Style & Naming Conventions

Write Nix in the existing style: two-space indentation, short attrsets, and one list item per line for long lists. Keep `configuration.nix` thin; add host behavior under `hosts/` or matching platform modules.

Name new modules by purpose, for example `modules/nixos/backup.nix` or `modules/common/editors.nix`. Do not import bare-metal modules from the WSL host.

Keep the boundary clear: NixOS modules own system packages, daemon services, WSL settings, SSH, networking, tunnels, and hardware. Home Manager owns `~/.config/*`, fish functions, Git settings, prompt config, and other user-session behavior. Do not use `systemd.tmpfiles` for normal user dotfiles unless Home Manager cannot express the file.

## Testing Guidelines

There is no unit test suite. Validate by parsing, linting, flake checks, and building the NixOS toplevel. Run at least:

```bash
nix-instantiate --parse configuration.nix
statix check .
```

Run the matching host build before changes to packages, boot, users, disks, services, networking, or WSL behavior.

## Security & Configuration Tips

Do not commit private keys, passwords, Rathole tokens, proxy secrets, GitHub/Forgejo tokens, kubeconfig, `.env`, or host-specific credentials. Keep public, non-secret config in this repo; move secrets to a later sops/agenix-backed flow. Keep `disko-config.nix` out of WSL imports; a wrong device path can wipe the wrong disk.

For WSL, keep Windows PATH disabled unless a workflow proves it is needed. Prefer HTTPS remotes in `ttal/projects.toml`; existing `ttal` credentials are token-based, not SSH-key based.

## Commit & Pull Request Guidelines

Use concise conventional subjects such as `feat(wsl): add NixOS-WSL host` or `fix(proxy): update noProxy list`. Commit `flake.lock` when flake inputs change. Use `ttal push` when available; if bootstrapping WSL before `ttal` exists, plain `git push` is acceptable. Pull requests should describe what changed, why it changed, and which validation commands passed. Include deploy notes for changes that require `nixos-rebuild switch --flake .#kosmos`, `nixos-rebuild switch --flake .#wsl`, or `nh os switch . -H kosmos`.
