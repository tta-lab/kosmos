# Kosmos

NixOS configuration for an Intel NUC (12th Gen i5-1240P) — headless dev/ops machine.

## Structure

- `configuration.nix` — initial NixOS config (Phase 1 bootstrap)
- `disko-config.nix` — declarative NVMe partition layout
- `flake.nix` — flake-based config (Phase 2)
- `modules/` — modular configs extracted from monolithic config
- `install-guide.md` — step-by-step install instructions

## Quick Start

```bash
# Syntax check (requires nix)
nix-instantiate --parse configuration.nix

# Build flake (Phase 2)
nix flake check
nix build .#nixosConfigurations.kosmos.config.system.build.toplevel --no-link
```

## License

MIT
