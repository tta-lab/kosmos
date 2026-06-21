# Hermes Agent on WSL

Hermes Agent is installed only for the WSL host. The NixOS module is
`modules/wsl/hermes-agent.nix`.

## Packages

The repo uses the official upstream flake:

```nix
hermes-agent.url = "github:NousResearch/hermes-agent";
hermes-agent.inputs.nixpkgs.follows = "nixpkgs-unstable";
```

WSL installs two upstream package variants:

- `messaging` for the gateway service and CLI
- `tui` for interactive terminal use

The gateway service does not use the upstream `messaging` package directly. It
uses a small patched copy named `hermesGateway`.

## Upstream Nix Issue

Upstream Hermes Agent 0.17.0 has a Nix packaging issue around the bundled cron
plugin.

Gateway startup eventually imports:

```python
from cron.scheduler_provider import resolve_cron_scheduler
```

The Python environment has the real `cron` dependency, and that dependency does
provide `scheduler_provider`. The failure is caused by import shadowing.

The upstream Nix package also exposes a bundled Hermes plugin named `cron` in
plugin search paths:

```text
share/hermes-agent/plugins/cron
lib/python*/site-packages/plugins/cron
```

When gateway startup adds those plugin paths to Python's import path, Python may
resolve `import cron` to the bundled plugin instead of the real Python `cron`
dependency. The bundled plugin is not the dependency package, so it lacks
`cron.scheduler_provider` and gateway startup fails with:

```text
ModuleNotFoundError: No module named 'cron.scheduler_provider'
```

## Local Workaround

`modules/wsl/hermes-agent.nix` builds a patched copy of the upstream `messaging`
package:

1. Copy the upstream package into a new Nix output.
2. Build a filtered bundled plugin directory without
   `share/hermes-agent/plugins/cron`.
3. Rewrite the Hermes wrapper scripts so `HERMES_BUNDLED_PLUGINS` points at the
   filtered plugin directory.
4. Rewrite the final wrapper `exec` so it starts the upstream Python env, imports
   the real `cron.scheduler_provider` first, and then enters `hermes_cli.main`.

This puts the real Python `cron` dependency into `sys.modules` before Hermes
plugin discovery can add the bundled plugin directory to Python import search.

The TUI package is not patched. It is installed separately with
`hermesPackages.tui`.

## Service

The gateway is managed by systemd:

```bash
systemctl status hermes-agent
sudo systemctl restart hermes-agent
journalctl -u hermes-agent -f
```

Hermes state and setup files live under:

```text
/var/lib/hermes/.hermes
```

This repo does not manage Telegram, Feishu, or other Hermes platform tokens with
agenix. They are owned by the Hermes instance and should be written by
interactive setup or by editing files under `/var/lib/hermes/.hermes` as the
`hermes` user.

## Removing the Workaround

Remove the local patch only after upstream changes its Nix package so the
bundled `cron` plugin no longer shadows the Python `cron` dependency.

To verify that, run the gateway under the service environment and confirm it
does not fail with `cron.scheduler_provider`:

```bash
sudo systemctl restart hermes-agent
journalctl -u hermes-agent -n 120 --no-pager
```
