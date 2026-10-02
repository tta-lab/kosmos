# Nix history retention on WSL

Kosmos WSL retains 30 days of NixOS and Neil's user profile history.
The official NixOS and Home Manager `nix.gc` modules schedule weekly
`nix-collect-garbage --delete-older-than 30d` runs, respectively as root and
Neil. The user run covers the Home Manager profile under
`~/.local/state/nix/profiles/`, which root's profile discovery does not cover.
Both timers are persistent by default and catch up on missed runs.
Nix serializes store garbage collection when the two runs overlap.

Deleting a generation removes its rollback option. The current generation
and references from retained generations remain protected. Nix's day-based
retention also keeps the generation active at the retention boundary.
Garbage collection removes only unreachable store objects; it does not clean
language caches, container images, service data, or the Windows disk directly.

## Inspect and run

```bash
sudo nix-env -p /nix/var/nix/profiles/system --list-generations
nix-env -p "$HOME/.local/state/nix/profiles/home-manager" --list-generations

# Preview history removal without running store GC.
sudo nix-env -p /nix/var/nix/profiles/system --delete-generations 30d --dry-run
nix-env -p "$HOME/.local/state/nix/profiles/home-manager" --delete-generations 30d --dry-run

# One-time cleanup, user history first, then root history and store GC.
nix-env -p "$HOME/.local/state/nix/profiles/home-manager" --delete-generations 30d
sudo nix-collect-garbage --delete-older-than 30d

systemctl list-timers nix-gc.timer
systemctl --user list-timers nix-gc.timer
journalctl -u nix-gc.service
journalctl --user -u nix-gc.service
df -h / /mnt/c
```

Deploy merged configuration with `nh os switch . -H wsl`. Check both timers
after activation. To exercise the scheduled commands manually, use
`systemctl --user start nix-gc.service` and `sudo systemctl start nix-gc.service`.

## Returning space to Windows

Free space reported inside WSL is distinct from free space on C:. After
cleanup, `sudo fstrim -v /` can discard free ext4 blocks. A non-sparse WSL
VHDX may still require offline compaction to return storage to Windows.
Arrange a separate service interruption before shutting down WSL and
compacting its VHDX; do not shut down the environment from an active agent
session. Do not infer physical savings from the sum of Nix package sizes:
store hardlinks and retained references affect actual recovery.

References:

- [Nix 2.28 garbage collection](https://nix.dev/manual/nix/2.28/command-ref/nix-collect-garbage)
- [Home Manager garbage collection options](https://nix-community.github.io/home-manager/options/home-manager/nix.html)
- [Microsoft compact vdisk](https://learn.microsoft.com/en-us/windows-server/administration/windows-commands/compact-vdisk)
