# Repository Guidelines

## Project Structure & Module Organization

This repository defines NixOS configs for the `kosmos-wsl` NixOS-WSL host and a dormant `kosmos` bare-metal Intel NUC target.

Current stage: focus on `kosmos-wsl`. There is no real bare-metal `kosmos` machine in use yet. Keep bare-metal modules buildable where practical, but do not design new work around bare-metal deployment unless the task says so.

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
nix build .#nixosConfigurations.wsl.config.system.build.toplevel --no-link
```

Lint, validate the flake, and build the WSL host closure without a result symlink. Build `.#nixosConfigurations.kosmos.config.system.build.toplevel` only when touching shared or bare-metal code that needs that check.

## Coding Style & Naming Conventions

Write Nix in the existing style: two-space indentation, short attrsets, and one list item per line for long lists. Keep `configuration.nix` thin; add host behavior under `hosts/` or matching platform modules.

Name new modules by purpose, for example `modules/nixos/backup.nix` or `modules/common/editors.nix`. Do not import bare-metal modules from the WSL host.

Keep the boundary clear: NixOS modules own system packages, daemon services, WSL settings, SSH, networking, tunnels, and hardware. Home Manager owns `~/.config/*`, fish functions, Git settings, prompt config, and other user-session behavior. Do not use `systemd.tmpfiles` for normal user dotfiles unless Home Manager cannot express the file.

When adding user-owned config paths, prefer Home Manager. Use Home Manager for parent directories under `$HOME`, non-secret dotfiles, shell/editor/git config, and user services. Use agenix only for the encrypted secret payload and decrypted file target; let Home Manager create user-owned parent directories where practical.

## Config Management (Home Manager)

Git-tracked config dirs (`ttal/`, `helix/`, `einai/`, `temenos/`) are the source of truth for user config managed by Home Manager. `modules/configs.nix` sources them into `~/.config/*` via the nix store, making runtime files read-only symlinks.

**Never edit runtime files directly under `~/.config/`.** Always edit the repo source file and let Home Manager propagate the change.

Workflows for updating config (e.g. `ttal/projects.toml`):

1. **Add a project entry**: use `ttal project add` — this writes to the runtime file. Then *also* add the entry manually to `ttal/projects.toml` in this repo to keep the source of truth in sync.
2. **Simplify a project entry**: edit only `ttal/projects.toml` in this repo; `ttal project modify` is not needed.
3. **Deploy the change**: merge the PR and run `ttal sync` (or `nixos-rebuild switch --flake .#wsl` for immediate effect on WSL).

Do not run `ttal project add` or `ttal project modify` and call it done — they only affect the runtime file, which is ephemeral. The repo source must always match.

## Testing Guidelines

There is no unit test suite. Validate by parsing, linting, flake checks, and building the NixOS toplevel. Run at least:

```bash
nix-instantiate --parse configuration.nix
statix check .
```

Prefer behavior tests for scripts and generated outputs. Avoid grep-only assertions over static config files; they are brittle and often duplicate the config instead of testing behavior. Add a config-file assertion only for a clear safety invariant, and keep it in a narrowly named test.

Run the WSL host build before changes to packages, users, services, networking, WSL behavior, Home Manager config, or agenix wiring. Run the bare-metal host build only when the change affects shared modules or bare-metal modules.

## Security & Configuration Tips

Do not commit private keys, passwords, Rathole tokens, proxy secrets, GitHub/Forgejo tokens, kubeconfig, `.env`, or host-specific credentials. Keep public, non-secret config in this repo; manage WSL secrets with agenix.

For agenix on `kosmos-wsl`, use `/etc/ssh/ssh_host_ed25519_key` as the private decrypt key. Never put private age or SSH keys in the repo, and never reference a private key through a Nix store path.

Expected WSL secret targets:

- `~/.config/ttal/.env`
- `~/.kube/config`
- `~/.ttal/kubeconfig`
- `~/.config/sops/age/keys.txt`

`lenos/config.json` in this repo is non-secret and belongs at `~/.config/lenos/config.json`. `einai/config.toml` is not a secret.

The secret Lenos config at `~/.local/share/lenos/config.json` is not managed by agenix yet.

Agents must not read, decrypt, print, grep, diff, migrate, or inspect plaintext secrets. If a task requires touching or reading a plaintext secret, stop and tell Neil the exact command he needs to run.

Keep `disko-config.nix` out of WSL imports; a wrong device path can wipe the wrong disk.

For WSL, keep Windows PATH disabled unless a workflow proves it is needed. Prefer HTTPS remotes in `ttal/projects.toml`; existing `ttal` credentials are token-based, not SSH-key based.

## Commit & Pull Request Guidelines

Use concise conventional subjects such as `feat(wsl): add NixOS-WSL host` or `fix(proxy): update noProxy list`. Commit `flake.lock` when flake inputs change. Use `ttal push` when available; if bootstrapping WSL before `ttal` exists, plain `git push` is acceptable. Pull requests should describe what changed, why it changed, and which validation commands passed. Include deploy notes for changes that require `nixos-rebuild switch --flake .#wsl`.
## Temp Files in Config Contexts

When config files (tmux, shell rc, systemd units, etc.) need unique temp files, use `mktemp` — don't rely on framework variable expansion (`#{}`, `$RANDOM`, PID, etc.) which often doesn't work in binding/command contexts:

```
f=$(mktemp --suffix=-tmux-buffer.txt)
```

`mktemp` guarantees uniqueness and avoids collisions across sessions, windows, and restarts without any expansion tricks.
## CLAUDE.user.md Maintenance

`CLAUDE.user.md` in the repo root is the SSOT for user-scope agent instructions. Home Manager sources it to both `.claude/CLAUDE.md` and `.codex/AGENTS.md` at runtime. When adding or changing user-scope preferences, edit `CLAUDE.user.md`. After merging, the change is applied by manually running `sudo env NIX_CONFIG="$(cat ~/.config/nix/nix.conf)" nixos-rebuild switch --flake .#wsl`.
