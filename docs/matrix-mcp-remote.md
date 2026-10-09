# Matrix for Agent services

Kosmos runs the managed Matrix for Agent (MFA) Node 24 artifact in two
independent processes, each with its own Matrix client and account token.

| Identity | User service | MCP listener | Credential file | Webhook |
| --- | --- | --- | --- | --- |
| Lamplit Serein | `matrix-mcp-remote` | `127.0.0.1:8768` | `/run/agenix/matrix-serein.env` | Disabled |
| CFL Shio | `matrix-mcp-cfl` | `127.0.0.1:8769` | `/run/agenix/matrix-shio.env` | `http://127.0.0.1:3084/api/matrix/events` |

Serein retains the public URL `https://matrix-mcp.guion.io/mcp` and tunnel
upstream `http://127.0.0.1:8768`. Its URL, account and bearer stay unchanged.
Shio uses only `http://127.0.0.1:8769/mcp`; there is no new public route.
CFL prod receives only Shio's environment file. Never supply Serein's token
as a substitute for a missing Shio credential.

The **Matrix account access token is also that instance's MCP Bearer token**.
The retired separate gateway key cannot be reused. Anyone holding a token has
that account's authority; manage accounts, membership and token issuance or
revocation manually. Keep the two identities and tokens separate.

Available tools are `whoami`, `list_rooms`, `list_room_members`,
`send_message`, and `read_messages`. MFA supports joined plaintext rooms;
E2EE is unsupported. Display names are best-effort current room member names,
not historical names, and may be empty. History is bounded and cursor based.
There is no durable live-event replay after downtime. Each process shares one
Matrix SDK client across its own MCP requests; no client is shared between
Serein and Shio, and there is no stdio child, Supergateway or ID map.

## Optional secret and service gates

`kosmos.wsl.matrixMcpRemote.enable` and the declared
`age.secrets."matrix-serein.env"` gate Serein's service and public tunnel route.
`kosmos.wsl.matrixMcpCfl.enable` and the declared
`age.secrets."matrix-shio.env"` independently gate Shio's service. WSL enables
both options; the new service remains absent, with a warning, until the Shio
encrypted file is provisioned. Missing Shio credentials also omit CFL prod's
Matrix environment file, without affecting Serein, dev or staging. No fallback
credential or placeholder ciphertext is installed.

The existing Serein encrypted artifact was renamed from
`matrix-for-agent.env.age` to `matrix-serein.env.age` with identical bytes.
Its declared default runtime path changes accordingly; a later authorized
switch may reconcile or restart Serein to load the renamed path. This changes
neither its account nor webhook policy. The obsolete runtime/rules name has
no compatibility path. The retired `matrix-mcp-remote-key.age` remains an
operator-cleanup artifact, with no runtime consumer.

Neil provisions **Shio's own Matrix account**, from Kosmos's root:

```bash
cd /home/neil/code/projects/tta-lab/kosmos
agenix -e secrets/matrix-shio.env.age -i ~/.ssh/agenix_ed25519
```

Enter this systemd environment-file format in the editor, replacing the
placeholders with Shio values only:

```text
MATRIX_HOMESERVER_URL=https://<Shio-homeserver-host>
MATRIX_ACCESS_TOKEN=<Shio-Matrix-account-access-token>
```

Keep the token on one line without whitespace. Use quotes only when required
by systemd environment-file syntax. The recipient rule is registered; agenix
owns the default `/run/agenix/matrix-shio.env` as `neil:users` mode `0400`.
Commit only the encrypted artifact. Agents must not create, decrypt, inspect
or migrate plaintext. No token may enter Nix-store text, unit arguments,
tracked plaintext, logs or environment dumps.

Systemd `EnvironmentFile` overrides `Environment`. Each launcher therefore
fixes its listener after loading the file and removes
`MATRIX_WEBHOOK_BEARER_TOKEN`. Serein removes `MATRIX_WEBHOOK_URL`; Shio forces
the exact production callback above. Credential overrides cannot redirect the
callback or change the listener. Shio's callback has no additional bearer:
CFL's local-only trust boundary relies on a loopback receiver and trusted local
processes. CFL owns the runtime adapter from Shio's `MATRIX_ACCESS_TOKEN` to
its account MCP's `CFL_MATRIX_TOKEN`; Kosmos supplies only the secret path.

## Managed artifact

The checkout is `/home/neil/code/projects/lamplitisles/matrix-for-agent`.
The existing tested artifact revision is
`4379ddfb13cccdd34436ca0ac3acd37ec47800e1`. Neither service builds or downloads
at startup. A missing checkout can be obtained with `og clone`; build an
approved revision explicitly:

```bash
og clone https://192.168.6.186:8086/LamplitIsles/matrix-for-agent.git
cd /home/neil/code/projects/lamplitisles/matrix-for-agent
bun install --frozen-lockfile
bun run typecheck
bun test
bun run build
node dist/cli.js --help
```

Both services use the Nix Node 24 executable and `dist/cli.js`.
`ConditionPathExists` and a launcher readability check fail safely if the
artifact is missing. Do not change the shared artifact while either service
runs. Updating it requires explicit operator rebuild/restarts. MFA closes HTTP
on SIGTERM, but SDK timers may keep Node alive; each unit retains the existing
15-second bounded stop and control-group cleanup, `UMask=0077` and restart policy.

## Ordered production handoff

Initial `IMPL_COMPLETE` means code, documentation, tests and PR are ready;
**nothing is activated**. Shio's operator-provisioned secret must be available
before live activation. The Orc owns independent reviews, merges and later authorization.

1. Neil provisions Shio's encrypted file. The CFL worker prepares the reviewed
   production artifact and operator TOML using the Shio endpoint on `8769`,
   mention/alias rules and the runtime credential adapter.
2. If CFL startup needs Shio's authenticated `whoami` before its receiver is
   ready, bootstrap only the new Shio process with a temporary operator-owned
   unit override: reset `ExecStart` to a wrapper using the same Nix Node and
   artifact, export `MATRIX_MCP_LISTEN=127.0.0.1:8769`, unset both webhook
   variables, then exec Node. Keep the Shio environment file and unit safety
   settings. Prepare the override before the authorized switch/start so the
   callback cannot run early. Never override Serein's launcher or credential.
3. Once Shio MCP is ready, the CFL worker starts the reviewed prod receiver
   using Shio's secret only. If required, temporarily append
   `/run/agenix/matrix-shio.env` to the existing operator `release.conf` while
   preserving all existing environment files and override settings.
4. After receiver readiness, remove only the temporary Shio bootstrap override
   to restore its managed fixed callback. The final Kosmos generation supplies
   the managed prod environment file; the CFL worker removes only any temporary
   duplicate append. Ko does not restart CFL prod. Record any unavoidable
   Serein or unrelated unit reconciliation during the authorized Nix switch.

There are no cyclic hard `Requires` dependencies. Preserve the previous unit
generation and operator overrides for rollback; do not reset account or
conversation state. Runtime files remain operator-owned; edit repository
sources for managed configuration.

Prefer service metadata, loopback listeners, unauthenticated MCP `401` and CFL
static readiness for verification. A nontriggering invalid-schema callback
request is permissible only if needed. Never send fake events to live prod,
trigger a paid Partner, send Matrix messages or read private history. Do not
inspect credentials, process environments or raw service logs. A successful
build cannot establish live authenticated connectivity or receiver readiness.

## Local checks

```bash
python3 tests/matrix-for-agent-test.py scripts/matrix-for-agent-run
python3 tests/matrix-for-agent-cfl-test.py scripts/matrix-for-agent-cfl-run
nix build .#checks.x86_64-linux.matrix-mcp-remote --no-link
nix build .#checks.x86_64-linux.matrix-mcp-cfl --no-link
```

Checks use fake credentials, test-owned temporary artifacts and fake runtimes;
they bind no production ports. Evaluation covers both identities, neither,
Serein only, Shio only and disabled services, independent secret gates, prod
identity isolation and unchanged dev/staging/Keet services. The existing
optional real-artifact test uses only ephemeral fake Matrix and MCP endpoints.
