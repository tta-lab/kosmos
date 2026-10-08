# Remote Matrix MCP (Matrix for Agent)

The WSL user service `matrix-mcp-remote` runs the managed Matrix for Agent
(MFA) Node artifact directly. The existing option
`kosmos.wsl.matrixMcpRemote.enable`, hostname `matrix-mcp.guion.io`, public
endpoint `https://matrix-mcp.guion.io/mcp`, and tunnel upstream
`http://127.0.0.1:8768` stay the same. One shared Matrix SDK client serves all
MCP requests; there is no stdio child, Supergateway, login command, or ID map.

The **Matrix access token is also the MCP Bearer token**. The retired separate
gateway key cannot be reused. Callers keep the URL and update their secret
`Authorization: Bearer <Matrix access token>` header or `MCP_CONFIG` bearer
field. Anyone holding that token has the Matrix account's authority; manage
accounts, membership, token issuance and revocation manually.

Available tools are `whoami`, `list_rooms`, `list_room_members`,
`send_message`, and `read_messages`. MFA supports joined plaintext rooms;
E2EE is unsupported. Display names are best-effort current room member names,
not historical names, and may be empty. History is bounded and cursor based.
There is no durable live-event replay after downtime. This service disables
webhooks. Existing unrelated Shio configuration and runtime are independent.

## Operator handoff: tomorrow

Secret provisioning, activation, service restarts and caller Bearer updates
are deliberately deferred. The implementation work does not perform them.
Complete the artifact and secret steps, prepare the caller credential change,
then schedule activation and caller rollout together.

### Prepare the managed artifact

Required tested MFA revision: `4379ddfb13cccdd34436ca0ac3acd37ec47800e1`.
The checkout is `/home/neil/code/projects/lamplitisles/matrix-for-agent`.
Kosmos follows its existing managed-checkout service pattern and installs no
MFA dependencies or builds/downloads at service startup. The bundled artifact
is not a Nix package. For a missing checkout, obtain it with:

```bash
og clone https://192.168.6.186:8086/LamplitIsles/matrix-for-agent.git
```

In a clean checkout at the required revision, build explicitly:

```bash
cd /home/neil/code/projects/lamplitisles/matrix-for-agent
git checkout 4379ddfb13cccdd34436ca0ac3acd37ec47800e1
bun install --frozen-lockfile
bun run typecheck
bun test
bun run build
node dist/cli.js --help
```

The service uses an explicit Nix Node 24 executable and
`dist/cli.js`. A missing artifact prevents startup via `ConditionPathExists`;
the launcher also fails safely if it disappears between checking and launch.
Do not change this checkout while the service is running. An updated artifact
requires an explicit operator rebuild and restart; no auto-update runs.
MFA closes HTTP on SIGTERM, but SDK timers can keep the Node process alive;
the unit retains `TimeoutStopSec=15` and control-group cleanup to bound stop.

### Provision the new optional secret

From Kosmos's root, Neil runs exactly:

```bash
cd /home/neil/code/projects/tta-lab/kosmos
agenix -e secrets/matrix-for-agent.env.age -i ~/.ssh/agenix_ed25519
```

Use this systemd environment-file template, replacing placeholders in the
editor only:

```text
MATRIX_HOMESERVER_URL=https://<homeserver-host>
MATRIX_ACCESS_TOKEN=<Matrix-account-access-token>
```

Keep the token on one line without whitespace. Do not add quotes unless
needed by systemd environment-file syntax. Do not put values in Nix, shell
argv, tracked plaintext, logs, or generated unit files. Do not copy any old
Mindroom config. The new file is registered for the existing recipients,
owned by `neil:users` with mode `0400`, and defaults to
`/run/agenix/matrix-for-agent.env`. Only encrypted bytes are committed.

`EnvironmentFile` values take precedence over systemd `Environment` values.
The launcher therefore fixes `MATRIX_MCP_LISTEN=127.0.0.1:8768` after loading
that environment, and removes `MATRIX_WEBHOOK_URL` and
`MATRIX_WEBHOOK_BEARER_TOKEN`. Adding those variables to the credential file
cannot change the bind or enable a webhook.

The declared `age.secrets."matrix-for-agent.env"` attribute gates both the
service and Matrix tunnel route. With no encrypted file, evaluation warns and
disables both, even if the old gateway secret still exists. Disabling the
option also removes both. The encrypted
`secrets/matrix-mcp-remote-key.age` and its recipient entry remain retired
operator-cleanup artifacts, with no runtime consumer. There is no migration
or dual-running path.

### Activate and verify

After the encrypted file is committed and the caller credential change is
ready, run the repository's required Nix checks/build, then activate as the
regular user:

```bash
cd /home/neil/code/projects/tta-lab/kosmos
nh os switch . -H wsl
test -r /run/agenix/matrix-for-agent.env
systemctl --user restart matrix-mcp-remote.service
systemctl --user is-active matrix-mcp-remote.service
ss -ltn 'sport = :8768'
curl -s -o /dev/null -w '%{http_code}\n' https://matrix-mcp.guion.io/mcp
```

Expect a loopback listener and an unauthenticated `401`. Check the tunnel is
active after the switch. Complete the prepared caller Bearer update, then use
the caller's secret-managed MCP connection to list exactly the five tools and
call `whoami` and `list_rooms`. Verify the intended account and joined
plaintext rooms without logging credentials or message content. Do not put
the token in a curl command or dump the environment. A successful Nix build
alone does not prove Matrix connectivity or deployed authentication.

## Local checks

```bash
python3 tests/matrix-for-agent-test.py scripts/matrix-for-agent-run
nix build .#checks.x86_64-linux.matrix-mcp-remote --no-link
# Optional, after building the required MFA revision:
python3 tests/matrix-for-agent-test.py scripts/matrix-for-agent-run \
  "$(command -v node)" \
  /home/neil/code/projects/lamplitisles/matrix-for-agent/dist/cli.js
```

The flake check evaluates enabled, disabled, and absent-secret configurations
and runs the launcher with a test-owned fake executable and artifact. It
checks environment precedence, disabled webhooks, credential forwarding and
missing-artifact failure without binding the production port. The separate
optional artifact integration check uses an ephemeral loopback fake Matrix
host and MCP listener; it never connects to real accounts or services.
