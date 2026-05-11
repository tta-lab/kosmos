# Repository Guidelines

## Project Structure & Module Organization

This repository defines NixOS configs for the `kosmos` Intel NUC and a lower-cost NixOS-WSL trial host.

- `flake.nix` declares inputs, host outputs, and the dev shell.
- `hosts/kosmos/` is the bare-metal Intel NUC entry point.
- `hosts/wsl/` is the NixOS-WSL entry point.
- `modules/common/` contains shared Nix, packages, shell, SSH, and the disabled Rathole client scaffold.
- `modules/nixos/` contains bare-metal boot, network, proxy, firewall, and container config.
- `modules/wsl/` and `modules/users/` contain WSL options and shared users.
- `configuration.nix` is a compatibility entry for `hosts/kosmos`.
- `disko-config.nix` defines the NUC NVMe layout. Treat changes as destructive until tested.
- `helix/` and `tmux/` hold user tool configs that are imported or installed by modules.
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

## Testing Guidelines

There is no unit test suite. Validate by parsing, linting, flake checks, and building the NixOS toplevel. Run at least:

```bash
nix-instantiate --parse configuration.nix
statix check .
```

Run the matching host build before changes to packages, boot, users, disks, services, networking, or WSL behavior.

## Security & Configuration Tips

Do not commit private keys, passwords, Rathole tokens, proxy secrets, or host-specific credentials. Replace `<mac-ip>` and `vps.example.com` during install or deploy. Keep `disko-config.nix` out of WSL imports; a wrong device path can wipe the wrong disk.

## Commit & Pull Request Guidelines

Use concise conventional subjects such as `feat(wsl): add NixOS-WSL host` or `fix(proxy): update noProxy list`. Pull requests should describe what changed, why it changed, and which validation commands passed. Include deploy notes for changes that require `nixos-rebuild switch --flake .#kosmos`, `nixos-rebuild switch --flake .#wsl`, or `nh os switch . -H kosmos`.
