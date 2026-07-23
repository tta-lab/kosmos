# Hermes Agent on WSL

Hermes Agent is installed with the official upstream installer rather than
built as a Nix package. Nix manages the command used to install it and the two
long-running user services.

## Install and update

Run the installer as `neil` after deploying this configuration:

```bash
hermes-agent-install
```

The command downloads the official installer, skips the interactive setup, and
installs into the upstream per-user layout:

```text
code and virtualenv  ~/.hermes/hermes-agent
CLI symlink          ~/.local/bin/hermes
state and config     ~/.hermes
```

The official installer uses its locked uv environment with the curated `all`
extra. That includes the web dashboard and its browser chat dependencies. It
also installs the Node runtime used to build the dashboard frontend on first
launch.

Update Hermes through its own supported update path:

```bash
hermes update
```

## Setup

The non-interactive installer does not choose a model or configure a messaging
channel. Run setup after the first install:

```bash
hermes setup
hermes gateway setup
```

Hermes owns the credentials and configuration below `~/.hermes`; they are not
copied into this repository or managed with agenix.

## Services

Home Manager enables two systemd user services:

- `hermes-gateway` runs the messaging gateway.
- `hermes-dashboard` serves the dashboard at `http://127.0.0.1:9119`.

The dashboard is explicitly bound to IPv4 loopback. It is not reachable from
the LAN or from the Cloudflare tunnel. Use local port forwarding when accessing
it from another device.

```bash
systemctl --user status hermes-gateway hermes-dashboard
systemctl --user restart hermes-gateway hermes-dashboard
journalctl --user -u hermes-gateway -u hermes-dashboard -f
```

Both services start automatically after login and survive logout because the
`neil` user has lingering enabled. If Hermes has not been installed yet, the
units stay inactive because their executable condition is not met.
