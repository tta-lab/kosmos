# Repository Guidelines

## Quick Reference

**Adding a system package:**
`modules/common/packages.nix` → `environment.systemPackages`.
Use `pkgsUnstable.<name>` for bleeding-edge, `pkgs.<name>` for stable.

**Adding user config:**
Edit source dir (`helix/`, `lenos/`, `temenos/`) → rebuild WSL.
Edit the legacy project registry in `~/.config/ttal/` directly; Kosmos does not manage it.

**Adding or updating a shared agent skill:**
Edit `skills/<name>/SKILL.md` → wire it in `modules/configs.nix` → rebuild WSL.

**Adding a secret:**
1) register in `secrets.nix`, 2) declare in `modules/wsl/secrets.nix`, 3) `agenix -e secrets/<name>.age`.

## Module Map

| What you're changing | File(s) |
|---|---|
| System packages | `modules/common/packages.nix` |
| User dotfiles (fish, git, starship) | `modules/configs.nix` |
| User config dirs (helix, lenos, temenos) | Source dirs → wired in `modules/configs.nix` |
| Shared agent skills | `skills/` → wired in `modules/configs.nix` |
| Project registry | `~/.config/ttal/` (legacy path, not managed by Kosmos) |
| WSL-only services, options, secrets | `modules/wsl/` |
| Shared config (Nix, SSH, rust, shell) | `modules/common/` |
| Bare-metal (NUC) config | `modules/nixos/` |
| User creation | `modules/users/neil.nix` |
| Flake inputs | `flake.nix` |

`hosts/wsl/default.nix` imports all WSL modules. `hosts/kosmos/` does the same for bare-metal.
Do not import bare-metal modules from WSL. Keep `disko-config.nix` out of WSL imports.

Focus is `kosmos-wsl`. Keep bare-metal modules buildable but don't design new work for them unless the task says so.

## Build & Verify

```bash
nix-instantiate --parse configuration.nix   # quick syntax check
statix check .                               # lint
nix --extra-experimental-features 'nix-command flakes' flake check  # full check
nix build .#nixosConfigurations.wsl.config.system.build.toplevel --no-link  # WSL closure (expensive)
nix develop                                  # enter dev shell
```

Run `nix-instantiate --parse` + `statix check .` + `nix flake check` before committing.
Run the full WSL build before changes to packages, users, services, networking, or agenix.
Build `.#nixosConfigurations.kosmos...` only when touching shared or bare-metal modules.
For simple package selection changes, rely on Nix evaluation and the system build.
Do not add tests that only grep source files for the selected package expression.
Before evaluating a Git-backed flake that references new files, stage those files with
`git add`; untracked files are absent from the flake source and can cause misleading
"file not found" failures. Staging is not committing. Review `git diff --cached`
before the commit as usual.

## Editing Rules

- **Never edit managed `~/.config/*` files directly** — edit the repo source and rebuild WSL. The legacy project registry in `~/.config/ttal/` is unmanaged and must be edited there directly.
- **Never edit managed `~/.agents/skills/*` files directly** — edit the corresponding source under `skills/` and rebuild WSL.
- For tmux clipboard on kosmos-wsl, use tmux clipboard/OSC 52 commands such as `copy-selection` or `copy-selection-and-cancel`; do not pipe copy bindings to platform clipboard tools like `pbcopy`, `clip.exe`, or `wl-copy`.
- Edit `~/.config/ttal/projects.toml` directly; Kosmos does not manage a project-registry mutation command.
- NixOS/Home Manager deploys managed config files, including agent rules.
- On kosmos, `og daemon` is managed by a Home Manager systemd user service. Use `systemctl --user status|start|restart og`; do not run `og daemon install`.
- **Home Manager** owns managed `~/.config/*` files, shell, editor, and git config. The legacy project registry is unmanaged. **NixOS modules** own system packages, daemons, networking, hardware.
- Do not use `systemd.tmpfiles` for user dotfiles unless Home Manager can't express the file.
- Name new modules by purpose: `modules/common/editors.nix`, `modules/wsl/backup.nix`, etc.
- Write Nix with two-space indent, one list item per line for long lists, keep `configuration.nix` thin.

## Secrets (agenix)

WSL decrypt key: `/etc/ssh/ssh_host_ed25519_key`.

Expected secret targets:
- `~/.config/ttal/.env`
- `~/.kube/config`
- `~/.config/sops/age/keys.txt`

Adding a secret: (1) register `.age` file in `secrets.nix` with public keys, (2) declare path/owner/mode/target in `modules/wsl/secrets.nix`, (3) run `agenix -e secrets/<name>.age` and paste plaintext. Commit the `.age` file.

Agents must not read, decrypt, or inspect plaintext secrets. If a task needs one, tell Neil the exact command.

## Commit & PR

- Branch + PR for everything. Never push to main.
- Conventional commits: `feat(wsl):`, `fix(proxy):`, `chore:`, `refactor:`
- Commit `flake.lock` when flake inputs change.

After merging config/package changes, deploy on WSL:
```bash
sudo env NIX_CONFIG="$(cat ~/.config/nix/nix.conf)" nixos-rebuild switch --flake .#wsl
```

## AGENTS.user.md

`AGENTS.user.md` in the repo root is the SSOT for user-scope agent instructions. Home Manager sources it to `.codex/AGENTS.md`. Edit `AGENTS.user.md` directly in this repo.
