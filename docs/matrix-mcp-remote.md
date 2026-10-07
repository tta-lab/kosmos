# Independent Matrix MCP over Cloudflare Tunnel

The WSL user service `matrix-mcp-remote` exposes the original Matrix stdio
MCP tools, including E2EE, through Supergateway's Streamable HTTP endpoint:

```text
MCP client with Authorization: Bearer <gateway key>
  → https://matrix-mcp.guion.io/mcp
  → existing Kepos Cloudflare Tunnel
  → 127.0.0.1:8768/mcp
  → Supergateway → independent matrix-mcp stdio children
```

The Matrix homeserver is **`https://ddd444.xyz`**. The MCP hostname is
**`matrix-mcp.guion.io`**, with endpoint **`https://matrix-mcp.guion.io/mcp`**.
The intended Matrix account is `@xj-1:matrix.dsh.local`; the operator creates a
new login/device for this existing account. This change does not create DNS
or deploy anything. Shio's `codex-for-love-prod` service and Matrix identity remain independent.

## Package and transport decision

[Supergateway 4.1.0](https://github.com/supercorp-ai/supergateway/tree/v4.1.0)
has no incoming authentication or bind-host option. The Nix package instead
builds [upstream commit 60e35ced](https://github.com/supercorp-ai/supergateway/tree/60e35ced67eeead0ba025ec8cf1bccdb34763465)
(version 4.2.0-rc.1) with its committed npm lock and a fixed dependency hash.
Its native `--host 127.0.0.1` and `--apiKeyFile` provide loopback listening and
incoming authentication. `--oauth2Bearer` configures outbound headers and
is not used for ingress authentication. No local gateway fork is needed.

Matrix uses the existing `uvx` capability with `matrix-mcp==0.9.0`. Its Python
dependencies resolve through uv at runtime; only the Matrix package version
is pinned, unlike the fully hash-pinned Supergateway npm dependency closure.
The first request needs package download access. The service inherits the
WSL proxy environment and provides `cloudflared` for homeserver Access auth.

The gateway runs in **stateless** mode: a child belongs to one HTTP request,
not a long-lived HTTP session. Clients need no session ID; GET and DELETE on
`/mcp` return 405 after authentication. Each launcher acquires the shared
`~/.local/state/matrix-mcp-remote/stdio.lock` before starting Matrix and holds
it for the entire stdio child lifetime. Matrix calls therefore run serially:
a waiting request starts its Matrix process only after the previous child
exits, so it reads the latest numeric room/event ID map. Matrix 0.9.0 loads
that map as a snapshot and saves without a process lock; its device-specific
E2EE lock alone does not protect the mapping. The launcher uses util-linux
`flock --no-fork`, retaining the lock in the child without an extra wrapper.
Completion or process termination releases the OS lock; the fixed lock file
persists and must not be removed while the service is running. A slow call
also delays later requests, which may reach client timeouts. Stateful gateway
mode would retain separate children per client session with stale snapshots.

All remote identity state lives under
`~/.local/state/matrix-mcp-remote`: `config/matrix-mcp/config.json`, the
adjacent device-specific `e2ee-*` store/lock and ID mapping files, plus
separate `data` and `cache` directories. HOME is unchanged. Matrix can fall
back to `~/.config/matrix-mcp/config.json` when its XDG config is absent, so
both the unit and every child launcher require the independent config first.
Do not remove/replace config or change identity while the service is running.
The existence check prevents normal missing-config fallback; it cannot make
concurrent operator deletion atomic with Matrix's later config read.

## Operator provisioning

Read [secrets.md](secrets.md). Agents must not read or create plaintext
credentials. The gateway secret is optional: without its `.age` file, neither
the service nor its tunnel ingress is configured. A present but empty key
file makes Supergateway fail startup rather than run without authentication.
The service also requires the independent Matrix config before starting.

1. Choose a new device identity for `@xj-1:matrix.dsh.local` and a separate gateway bearer
   key. Save the bearer key in a password manager. Register its encrypted
   artifact from the repository root:

   ```bash
   agenix -e secrets/matrix-mcp-remote-key.age -i ~/.ssh/agenix_ed25519
   ```

   The plaintext format is one raw bearer key per line, **not** an environment
   assignment. Prefer one independently generated, high-entropy key. Do not
   put it in command arguments, Nix, logs or chat. Recipients are already
   registered in `secrets.nix`; commit only the encrypted `.age` artifact.
   Agenix provides the user-readable 0400 runtime file at its default path.

2. With the service stopped, create the separate state root and authenticate
   using the built-in **hidden password prompt if password login is supported**.
   The homeserver versions endpoint responded, but login discovery currently
   resets TLS connections; its supported login methods remain unverified:

   ```bash
   systemctl --user stop matrix-mcp-remote.service  # if already installed
   umask 077
   matrix_remote_root="$HOME/.local/state/matrix-mcp-remote"
   install -d -m 0700 "$matrix_remote_root" "$matrix_remote_root/config" \
     "$matrix_remote_root/config/matrix-mcp" "$matrix_remote_root/data" \
     "$matrix_remote_root/cache"
   export XDG_CONFIG_HOME="$matrix_remote_root/config"
   export XDG_DATA_HOME="$matrix_remote_root/data"
   export XDG_CACHE_HOME="$matrix_remote_root/cache"
   uvx --from matrix-mcp==0.9.0 matrix-mcp auth password https://ddd444.xyz \
     '@xj-1:matrix.dsh.local' \
     --device-name 'xj-1 remote MCP' \
     --config "$XDG_CONFIG_HOME/matrix-mcp/config.json"
   chmod 600 "$XDG_CONFIG_HOME/matrix-mcp/config.json"
   ```

   **Omit `--password`**: Matrix MCP 0.9.0 prompts interactively with hidden
   input. Do not enter a password if no hidden prompt appears. Run this in a
   dedicated operator shell so the XDG exports do not affect unrelated
   commands. No login or credential provisioning was performed in this PR.

   If the homeserver supports SSO instead, use the same isolated directories:

   ```bash
   uvx --from matrix-mcp==0.9.0 matrix-mcp auth sso https://ddd444.xyz \
     --device-name 'xj-1 remote MCP' \
     --config "$XDG_CONFIG_HOME/matrix-mcp/config.json"
   chmod 600 "$XDG_CONFIG_HOME/matrix-mcp/config.json"
   ```

   Sign into `@xj-1:matrix.dsh.local`; SSO uses a local browser callback.
   If SSO requires Cloudflare Access, add `--cloudflare-access` and ensure
   `cloudflared` is on PATH. Resolve homeserver login access before deployment
   if neither flow works. Do not copy Shio's config, access token, device ID
   or E2EE store. Verify the new Matrix device from another trusted Matrix
   client before relying on encrypted room access. Preserve its crypto store
   across restarts; do not recreate a store under an existing device ID.

3. After the PR is merged and encrypted key provisioned, run the documented
   checks, then activate as the regular user:

   ```bash
   nh os switch . -H wsl
   systemctl --user start matrix-mcp-remote.service
   systemctl --user is-active matrix-mcp-remote.service
   ss -ltn 'sport = :8768'
   ```

   Confirm only `127.0.0.1:8768` listens. After confirming the hostname,
   create its DNS route to the existing tunnel with the existing operator
   Cloudflare workflow. Nix supplies the ingress rule; no additional tunnel
   or Kepos peer-policy service is needed. Default unmatched ingress stays
   404 and Serein's Keet ingress remains present.

4. Check unauthenticated access returns 401 locally and through the tunnel:

   ```bash
   curl -s -o /dev/null -w '%{http_code}\n' http://127.0.0.1:8768/mcp
   curl -s -o /dev/null -w '%{http_code}\n' https://matrix-mcp.guion.io/mcp
   ```

   Configure the MCP client for Streamable HTTP at
   `https://matrix-mcp.guion.io/mcp`, with a secret-managed Authorization
   bearer header. Call `matrix_whoami` and verify the chosen new account/device,
   then verify an encrypted-room read with that account. Do not paste the key
   into a curl argument or capture authenticated debug logs. These are live
   operator checks, not automated tests.

Rotate the key by editing the encrypted artifact, switching WSL, and restarting
`matrix-mcp-remote` (keys are read at gateway startup). Stop this service before
Matrix reauthentication or restoring its state. Provision a new device if
intentionally starting a fresh E2EE store.

## Resource ownership and verification

| Resource | Creator / owner | Retained state and lifetime | Replacement / terminal cleanup | Observable evidence |
|---|---|---|---|---|
| Gateway process and listener | systemd user unit | API keys and listener for service lifetime | Restart closes old process; SIGTERM runs upstream cleanup; systemd kills remaining cgroup after 15s | Fake probe starts with `/dev/null`, checks actual socket address, stops and rebinds same port |
| Stdio child and descendants | Supergateway request / OwnedChildProcesses | One Matrix process tree per POST | Response completion stops group; gateway shutdown terminates then escalates after 5s; cgroup is final owner | Concurrent fixture calls use distinct PIDs; all PIDs disappear after completion and stop, including a descendant of a hanging request |
| HTTP transport/request | Supergateway stateless request | Request IDs, pending responses, stream callbacks | Each request closes its transport; reconnect creates a fresh child; no session map | Repeated ID across concurrent requests routes correct replies; reconnect works without a session ID |
| Timers / pending work | Supergateway child/request cleanup | Bounded shutdown polling and one-way message grace; modern continuation handling remains upstream-owned | Gateway closes active/retained children; process exit releases remaining timers | Hanging-request shutdown settles within probe deadline; restart works |
| Shared stdio lifetime lock | Launcher / Matrix child | One exclusive lock shared by all requests, acquired before ID-map load | Child completion/termination releases descriptor; gateway kills waiting and active process groups; systemd cgroup is final owner | Concurrent snapshot fixture preserves distinct room/event refs; gateway stop releases lock, then restart serves a new call |
| E2EE store lock | Matrix per-tool driver | Fixed remote device store while crypto call is active | Driver `aclose` releases lock in finally; process termination releases OS lock; store persists | Hanging fixture holds a fake crypto lock; stop releases it for reacquisition/restart (not a real E2EE/network test) |
| Independent config/state | Operator; launcher selects directory | Credentials, device keys and mappings persist across service restarts | Operator stops unit before identity replacement; persistent files are never removed by unit | Fixture Shio config cannot satisfy missing independent config; launcher refuses before and after independent-file removal |

Run the isolated behavioral check with:

```bash
nix build .#checks.x86_64-linux.matrix-mcp-remote --no-link
```

It uses only test-owned temporary files, fake MCP processes, a compatible
snapshot ID-store fixture and a fake crypto lock. The ID-store probe fails
with the old launcher because concurrent children both allocate ref 1;
serialization preserves each room/event reference. It verifies auth rejection
before child creation, empty-key failure, loopback binding, serialized
concurrent requests, reconnect, shutdown of active and waiting children,
descendants, lock release and restart. It does not validate actual Matrix credentials, E2EE
interoperability, DNS or the live Cloudflare Tunnel. Required repository Nix
checks and the full WSL closure build remain necessary before committing.
