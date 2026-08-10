# Beads server

Beads is a CLI, not a web application. This workload provides its external
`dolt sql-server` for Beads server mode so WSL and the Mac share the same live
task graph and can write concurrently.

- WSL endpoint: `127.0.0.1:3307`
- Mac endpoint after Kepos setup: `127.0.0.1:13307`
- Kubernetes service: `beads.beads.svc.cluster.local:3307`

The server does not use `bd dolt push` or `bd dolt pull` for normal work. All
clients use the same named server database instead. Keep one database per
project and use the same database and issue prefix in every clone.

## Access boundary

Dolt's official server image initializes `root@'%'` with no password so a
client entering through the hostPort can connect. The database has no public
listener: its only host port binds to `127.0.0.1`, and the Kepos `beads` service
allows only the existing Mac subscriber. Kepos is therefore the network and
peer-identity boundary for this initial deployment.

Do not expose port 3307 directly or extend the Kepos allow list without first
adding SQL credentials and TLS. This setup is suitable only for the current
single-user WSL and Mac trust boundary.

## Deploy

NixOS owns the retained host directory and Kepos publication. Tanka owns the
Dolt server and Kubernetes objects:

```bash
nh os switch . -H wsl --ask
just beads-diff
just beads-deploy
just beads-status
just kepos-status
```

The image is the official Dolt 2.2.3 image pinned to its digest. The database
is retained under `/var/lib/kosmos-k3s/beads`; that protects it from a Tanka
delete but is not an off-host backup. Initialize and regularly exercise a
Dolt-native `bd backup` destination before relying on it for important work.

## Mac setup

Install the supported client:

```bash
brew install beads
```

Add the following service to the existing Mac Kepos subscriber configuration,
then restart Kepos Desktop:

```toml
[[subscriber.services]]
id = "beads"
local_port = 13307
```

For a project, choose a stable database name and prefix once. Set the
machine-local connection values before running `bd` so it never tries to start
a local Dolt server:

```bash
export BEADS_DOLT_SERVER_MODE=1
export BEADS_DOLT_AUTO_START=0
export BEADS_DOLT_SERVER_HOST=127.0.0.1
export BEADS_DOLT_SERVER_PORT=13307
export BEADS_DOLT_SERVER_USER=root

cd /path/to/project
bd init --server --external --database project_beads --prefix project
bd dolt test
```

The first clone creates the server database. On every additional clone, use the
same database and prefix, and add `--reinit-local` to create only its local
Beads metadata:

```bash
bd init --server --external --database project_beads --prefix project \
  --reinit-local
bd dolt test
```

`--reinit-local` does not discard or replace the existing server database; the
tool still refuses that separately without an explicit discard authorization.

On WSL, use the same commands with port `3307`. Client connection settings are
machine-local: do not commit a Mac port into a project configuration shared
with WSL. The environment variables above take precedence over the local Beads
configuration.

Use `bd vc commit` only when an explicit Dolt history checkpoint is useful.
Server mode intentionally avoids a Dolt commit after every task write because
that creates concurrent-writer failures.
