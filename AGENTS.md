# Repository Guidelines

## Quick Reference

**Adding a system package:**
`modules/common/packages.nix` → `environment.systemPackages`.
Use `pkgsUnstable.<name>` for bleeding-edge, `pkgs.<name>` for stable.

**Adding user config:**
Edit source dir (`helix/`, `lenos/`, `temenos/`) → rebuild WSL.
Use `og clone <https-url>` to obtain and register project checkouts. Kosmos does not sync repositories.

**Adding or updating agent skills:**
Agent skills are no longer managed by Kosmos. Each machine owns its own
`~/.agents/skills/` — deploy a skill by copying its directory into that
path. Only the portable agent rules (`AGENTS.user.md`) are synced by
`scripts/sync-agent-config`.

**Adding a secret:**
1) register in `secrets.nix`, 2) declare in `modules/wsl/secrets.nix`, 3) `agenix -e secrets/<name>.age`.

**Adding a Kepos-exposed service (WSL):**
Add a Tanka environment + lib under `tanka/` (namespace/Service/Deployment),
wire the route in `tanka/lib/gateway.libsonnet` (Caddy + CoreDNS rewrite),
add the `<app>.localhost` hosts entry and storage dirs in
`modules/wsl/k3s.nix`, register the service in `modules/wsl/kepos-neo.nix`,
then `nh os switch` + `just <app>-deploy`. HTTP web services use
`targetPort = 17480` (canonical gateway, Host-header routed) and peers reach
them via the subscriber gateway port — never configure
`[[subscriber.services]]` on peers for HTTP services; that is only for raw
TCP/SSH services like `dagger`. See `docs/wsl-devops-runbook.md` for the
full service model.

## Module Map

| What you're changing | File(s) |
|---|---|
| System packages | `modules/common/packages.nix` |
| User dotfiles (fish, git, starship) | `modules/configs.nix` |
| User config dirs (helix, lenos, temenos) | Source dirs → wired in `modules/configs.nix` |
| Portable agent rules | `AGENTS.user.md`, `scripts/sync-agent-config` |
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

- **Never edit managed `~/.config/*` files directly** — edit the repo source and rebuild WSL. The project registry in `~/.config/ttal/` is unmanaged; use `og clone` for additions and direct edits only for archive/migration work.
- `~/.agents/skills/*` is **not** managed by Kosmos — each machine owns its skills directly; deploy by copying skill directories into `~/.agents/skills/`.
- For tmux clipboard on kosmos-wsl, use tmux clipboard/OSC 52 commands such as `copy-selection` or `copy-selection-and-cancel`; do not pipe copy bindings to platform clipboard tools like `pbcopy`, `clip.exe`, or `wl-copy`.
- Use `og clone` for normal project additions. Edit the unmanaged `~/.config/ttal/projects.toml` directly only for archive or migration work that og does not expose.
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
nh os switch . -H wsl --ask
```

Run `nh` as the regular user. It delegates builds to `nix-daemon` and elevates
only the system activation. The user Nix config is loaded automatically and
contains credentials; never expand its contents into `NIX_CONFIG` or another
command-line argument. Configure substituters and their trusted keys in the
NixOS modules, not the user config, and do not grant trusted-user access just
to use a cache.

## AGENTS.user.md

`AGENTS.user.md` in the repo root is the SSOT for portable user-scope agent
instructions. Home Manager sources it to `.codex/AGENTS.md` on WSL;
`scripts/sync-agent-config` links it from a Mac checkout.
Host-specific rules belong in `~/.codex/AGENTS.machine.md`, outside this
repository. Edit `AGENTS.user.md` directly in this repo.
