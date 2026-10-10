# Unified Matrix gateway

Kosmos declares one `matrix-mcp-remote` user service, using Node 24 at
`127.0.0.1:8768/mcp`. It accepts each caller's own Matrix access token against
one fixed homeserver. Token validation happens on every request; credentials
have separate Matrix clients, even for devices belonging to the same user.
Tool access never enrolls a caller into background delivery. This is custom
Matrix bearer authentication, not MCP OAuth or a separately issued gateway key.

`https://matrix-mcp.lamplit.run/mcp` uses the existing loopback tunnel upstream.
When published, it accepts **any valid token for the fixed homeserver**, rather
than only Serein's configured token. The route remains gated by Serein's declared
secret; Shio-only installation stays local. The old `matrix-mcp.guion.io`
endpoint previously returned HTTP 403; that historical observation does not
establish the new hostname's reachability.

Background owners remain independently configured:

| Identity | systemd input | Receiver | Receiver authentication |
| --- | --- | --- | --- |
| Shio | `/run/agenix/matrix-shio.env` | `http://127.0.0.1:3084/api/matrix/events` | No bearer; trusted local loopback boundary |
| Serein | `/run/agenix/matrix-serein.env` | Optional configured Hosted URL | Independent configured bearer, if present |

Shio ignores inherited receiver URL/bearer overrides. Serein without a webhook
URL is not enrolled for background delivery; its credential still works as a
dynamic MCP caller. CFL prod receives only Shio's environment file, never
Serein's. The five tools remain `whoami`, `list_rooms`, `list_room_members`,
`read_messages`, `send_message`. Joined plaintext rooms only; no E2EE or durable
downtime replay. Each live plaintext webhook includes `conversation_type: "dm" | "room"`,
captured from that identity's synchronized `m.direct` before queued enrichment;
retries retain the original bytes. Operators manually join and mark direct rooms.
Receivers own exact sender allowlists for marked DMs and retain
mention/reply/alias wake policy for rooms.

## Gates and existing inputs

`kosmos.wsl.matrixMcpRemote.enable` controls the unified service. The obsolete
`matrixMcpCfl` option, enduring `matrix-mcp-cfl` service and listener on 8769 are
removed; no forwarding listener or compatibility alias remains.

| Configuration | Gateway | Public Matrix route | CFL prod Matrix input |
| --- | --- | --- | --- |
| Both secrets declared | One on 8768 | `matrix-mcp.lamplit.run` on 8768 | Shio only |
| Serein only | One on 8768 | `matrix-mcp.lamplit.run` on 8768 | None |
| Shio only | One on 8768 | None | Shio only |
| Neither | None, warning | None | None |
| Unified option disabled | None | None | Shio if independently declared |

The existing ciphertext bytes and recipient rules remain unchanged. Both
optional agenix declarations use their default paths, `neil:users`, mode `0400`.
No new secret, user ID field, token copy or format migration is required. Each
input retains systemd `EnvironmentFile` format with `MATRIX_HOMESERVER_URL` and
`MATRIX_ACCESS_TOKEN`. Serein may also contain `MATRIX_WEBHOOK_URL` and
`MATRIX_WEBHOOK_BEARER_TOKEN` (without a `Bearer` prefix). Agents never read,
decrypt, source or migrate these plaintext files. See [secret rules](secrets.md).

## Private startup preparation

The main unit creates `%t/matrix-mcp-remote` (`0700`). Every start/retry first
clears only verified owned runtime files, then synchronously starts the declared
identities' `matrix-mcp-input-shio`/`matrix-mcp-input-serein` oneshot units. These
units each load exactly one original `EnvironmentFile`; systemd handles quoting,
continuations and assignment precedence. Manager-inherited input values are
cleared; empty optional webhook assignments mean absent. They are short preparation helpers,
not extra long-running Matrix clients. No combined environment file or shell
source is used.

Each helper validates its token/URLs and derives the full user ID with a bounded
10-second `whoami` against its own homeserver, including the response body.
Redirects are refused. The main preparation step requires all declared inputs,
checks normalized homeservers agree and rejects duplicate user IDs or tokens.
It atomically writes a private `0600` UTF-8 `webhooks.json` array with exactly
`user_id`, `access_token`, `url`, optional `bearer_token`; size is bounded to
1 MiB (at most two entries, within MFA's 16-entry limit). It deletes the input
fragments and replaces itself with MFA, using only fixed homeserver, loopback
listener and `MATRIX_WEBHOOK_CONFIG` for Matrix environment settings.

Paths must be regular, owned and private; symlinks, hard links, permissive or
unowned runtime paths fail safely. A declared missing/unreadable/invalid input,
homeserver mismatch or preparation failure blocks launch, clears owned outputs
and emits only a sanitized diagnostic. No credentials appear in unit arguments,
Nix-store text or logs. MFA revalidates its configured IDs at startup and opens
the listener only after all configured identities synchronize successfully.
The main stop hook also stops any in-flight input helper. Runtime files disappear
when the main service stops. Restart, proxy/network,
`NoNewPrivileges`, private temp, `UMask=0077`, 15-second bounded stop and
control-group cleanup policies are retained. SDK timers may require the bounded
forced stop after graceful HTTP closure.

## Immutable artifact

`kosmos.wsl.matrixMcpRemote.artifact` defaults to:

```text
/home/neil/.local/share/matrix-for-agent/releases/17fe5c59c0b4b47cac515883127c9d933e8f0566/cli.js
```

This release must be built from approved MFA main
`17fe5c59c0b4b47cac515883127c9d933e8f0566` (tree
`cad228458cff245c08dba95457ef36c674ce7018`, equal to reviewed PR5 head
`7989a3da4ff24caf39ac4a8ea2e8c2bd2bdf9570` tree).
Neither service builds/downloads on startup. `ConditionPathExists` skips a
missing release, and the startup helper refuses an unreadable/missing artifact.
A release is provisioned in a separately authorized follow-up, retaining MFA's
license and Node runtime. Never run `bun run build` against the shared checkout's
`dist/cli.js`: it is the historical protected `ac36…` artifact. Redirect the
Node-target build into an owned staging directory and retain its SHA256, source
head/tree and LICENSE before placing a new immutable release.

## DM producer upgrade

Preparation and the source PR precede live activation. The unified release
changes both Shio and Serein: old Hosted Chat's closed parser rejects the new
field with HTTP 400, including group messages. Before activation, obtain
Owner/CF agent confirmation that Hosted Chat has deployed
`d7b032c3250c9242729d1022bcbc646c0478478a` or a newer compatible build;
Platform `e3b0d4b279368444ae3f7382c96e59873ed8b516` supplies Hosted
`matrix.dmAllowList` configuration. Sequence Platform config support, Hosted
receiver, then unified MFA. Pending coordination does not authorize activation.

After independent review, merge and explicit Orc activation authorization,
recheck source/tree, protected hashes and destination ownership. Provision only
the verified bundle, LICENSE and upstream notices into the absent release directory by atomic
no-replace installation; retain the old `9e5751b` release and saved system
closure. Apply `nh os switch . -H wsl` as Neil and observe managed gateway
reconciliation. Do not repeat the historical override/caller cutover below.
Verify loaded new artifact, independent input success and private metadata,
PID-owned 8768/local unauthenticated 401, zero restarts and at least 20 seconds
of stability within a 120-second readiness budget. Preserve CFL prod's
`[@xq-2:matrix.dsh.local, @sooya:matrix.dsh.local]` list and existing policies.

On activation failure, use the recorded prior closure's
`bin/switch-to-configuration switch` with guarded profile restoration from the
concrete release report; preserve both bundles and configuration history.
Do not restore credential or conversation state. Readiness establishes configured
producer availability; live DM delivery and Partner replies remain unverified.

## Public hostname activation

After review and merge, verify the merged tree equals the reviewed tree and
record the current NixOS generation and loaded Tunnel ingress for rollback.
Apply the merged checkout as Neil with `nh os switch . -H wsl`, then observe
`cloudflared-tunnel-kepos.service` reconciliation and its loaded configuration.
The routes must map `matrix-mcp.lamplit.run` to `http://127.0.0.1:8768` and
`keet-serein.lamplit.run` to `http://127.0.0.1:8767`. Existing local listeners,
Matrix background inputs, webhook URLs, artifacts and tokens stay unchanged.

Check local Matrix/Keet readiness and CFL prod health, then request both public
`/mcp` URLs without credentials. HTTP 401 establishes reachability to the
authentication boundary; record 403, 404 or other outcomes accurately rather
than claiming authenticated success. The operator updates Cloudflare client
MCP URLs and performs authenticated verification using existing credentials;
this hostname change makes no Cloudflare client secret or control-plane edits.
If rollback is necessary, activate the captured prior system closure with
`sudo <saved-system>/bin/switch-to-configuration switch` and verify its prior
ingress and local health. Do not restore identity or conversation state.

## Ordered production handoff

Historical unified-gateway cutover procedure, completed on 2026-10-10. Do not
repeat these artifact, override or caller migration steps for a hostname change.

The original consolidation PR prepared source and owned tests only. Merge did
**not** activate it. Live activation and CFL caller edits were a subsequent
coordinated Orc-owned follow-up.

Historical rollout metadata observed on 2026-10-10: both operator `release.conf`
overrides reference wrappers and `cli.js` under
`~/.local/share/matrix-for-agent/candidates/2ff91d631a29f37807607b614e36fe7f088c578e/`.
That reply-aware historical CLI has SHA256
`33ec389d64c766090dab6fb611a243216e10af41dca8d7f86945b5c4f132632c`.
It and the registered `ac36…` dist must remain untouched. The operator CFL
`partner.toml`/native MCP caller still targets 8769 until the follow-up.

1. Review the concrete release, evaluated unit and this plan. Stage the approved
   new immutable bundle and LICENSE at the managed release path, verify their
   hashes against the owned build, and verify secret-path metadata only. Do not
   replace the old candidate or inspect credential values.
2. Coordinate CFL prod receiver readiness on 3084 before gateway startup; preserve
   its artifact, tokens, aliases, native/state and receiver configuration. Back
   up only the specific operator caller configuration and two Matrix override
   files, with UID/mode/SHA256 records in a private operator backup directory.
3. Pause the old Matrix units for cutover. Remove only these two exact regular,
   UID-1000 override files **if their current hashes still match**:
   `~/.config/systemd/user/matrix-mcp-remote.service.d/release.conf`
   (`dd64a6526cff705b40fdab615111b7124d379337248786a6de0769a2f461c179`) and
   `~/.config/systemd/user/matrix-mcp-cfl.service.d/release.conf`
   (`6dcd85be15c040e1dda94a2a19696010c424971a0c722f2029169149ee573999`).
   Re-inspect and reconcile any mismatch; never delete a drop-in directory,
   unrelated overrides or managed unit files wholesale.
4. Apply the reviewed Kosmos checkout with `nh os switch . -H wsl` as Neil.
   Check one managed gateway and declared preparation units, no 8769 listener,
   runtime directory/file permissions, and the existing Serein-only tunnel gate.
   Change only CFL's operator-owned Matrix MCP endpoint from
   `http://127.0.0.1:8769/mcp` to `http://127.0.0.1:8768/mcp`, then restart only
   the affected CFL prod caller when the unified gateway is ready.
5. Verify authenticated identity/tool behavior with an operator-approved method
   that does not expose tokens, and delivery only from approved real traffic.
   No synthetic live events, paid-provider triggers or private-history probes.
   Verify local and public behavior separately; do not assume the external 403
   is resolved. Record sanitized results and release/unit hashes.

Rollback is also an operator action: stop the unified gateway, restore the
previous reviewed Nix generation and only the backed-up caller endpoint and
exact verified UID/hash Matrix overrides, then start the previous immutable
units in a coordinated order. Restore a backup only if the destination is absent
or matches the expected cutover hash; stop on unrecognized changes. Keep both
historical artifacts intact. Do not copy/reset/restore CFL conversation state,
rekey secrets, overwrite managed files directly or run both generations together.

## Owned verification

The flake check evaluates both/Serein/Shio/neither/disabled gates and runs private
runtime fixtures. Optional host checks use synthetic `EnvironmentFile`s in owned
transient test units; actual MFA checks use a separate user/network namespace so
fixed callback 3084 and gateway 8768 cannot touch production. See the local
implementation report for commands, artifact hashes and results. Existing MFA
PR4's 27 tests/236 assertions are head-bound evidence reused via equal trees;
this PR adds Kosmos startup/generated-config seams, not live interoperability.
