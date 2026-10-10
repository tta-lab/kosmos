# Codex for Love

Kosmos owns three Home Manager services for the Codex for Love (CFL) runtime.
Mika dev additionally accepts direct WSL-LAN traffic; CFL source, Codex
credentials, and conversation data remain operator-owned.

| Environment | Unit | Local port | Kepos URL | State root |
| --- | --- | ---: | --- | --- |
| Mika dev | `codex-for-love-dev.service` | 3082 (WSL LAN: `192.168.1.179`) | `http://dev-her.localhost:17480` | `~/.local/state/codex-for-love/dev` |
| Mika staging | `codex-for-love-staging.service` | 3083 | `http://staging-her.localhost:17480` | `~/.local/state/codex-for-love/staging` |
| Shio prod | `codex-for-love-prod.service` | 3084 | `http://prod-lamplit.localhost:17480` | `~/.local/state/codex-for-love/prod` |

All three services remain direct Kepos HTTP services and also have host Caddy
routes for SSH access at the same `.localhost:17480` addresses. Their workloads
do not use Kubernetes, Docker, a subscriber binding, or an application login. Mika dev permits Mac and Sven through Kepos; Mika staging additionally
permits Pixel 7a for installed-PWA acceptance. Shio prod keeps its Mac and
Pixel 7a ACL. Dev additionally binds all IPv4 interfaces so Mac can reach
`http://192.168.1.179:3082` directly.

## Service contract

- Services run CFL's TypeScript CLI with the Nix-pinned Node 24 executable.
- Each environment owns its own `partner.toml`, persona, state, workspace,
  SQLite projection, attachments, profile images, and Codex thread. Mika dev
  and staging use matching initial Markdown and profile images, with distinct
  state and session data.
- The launcher requires its own exact name, persona, state, workspace, port,
  listener, model, and `/home/neil/.codex` settings before it starts. Mika dev
  and staging require `model_reasoning_effort = "medium"`; Shio requires
  `model_reasoning_effort = "low"`.
- `flicknote`, `project`, and `web` must be available on the service `PATH`.
  The launcher fails closed when any is unavailable.

## Shio Matrix ownership

Prod alone appends the declared `age.secrets."matrix-shio.env".path` to its
existing environment files. Missing Shio credentials omit this wiring; dev and
staging receive no Matrix secret. Serein's separate `matrix-serein.env` is
never supplied to CFL. The reviewed CFL runtime reads Shio's
`MATRIX_ACCESS_TOKEN` and injects `CFL_MATRIX_TOKEN` for its account MCP
connection at the unified `http://127.0.0.1:8768/mcp`. Kosmos does not copy or
rename token values. CFL owns its production artifact, operator TOML/native MCP
configuration and `release.conf`; Kosmos owns the secret path and one
`matrix-mcp-remote` gateway. The previously deployed operator caller still uses
8769; its endpoint change is a coordinated follow-up, not part of this PR's live
work. The enduring second `matrix-mcp-cfl` service and listener are removed.

The gateway's separately configured Shio background owner forwards to
`http://127.0.0.1:3084/api/matrix/events` without a webhook bearer, relying on the
receiver's loopback trust boundary. Serein's optional Hosted receiver and bearer
remain independent. Public MCP accepts any valid token for the fixed homeserver
when Serein's secret enables the existing route; background owners are never
selected by MCP callers. Keep tokens out of units, Nix-store text, argv and logs.

Follow the [ordered Matrix handoff](matrix-mcp-remote.md#ordered-production-handoff):
provision the new approved immutable gateway artifact, coordinate receiver
readiness, back up exact UID/hash overrides and caller config, cut over the
managed launch and CFL endpoint together, then verify approved traffic. Preserve
CFL tokens, aliases, native/state and receiver configuration. No new secret edit
is required. Initial PR delivery performs no switch, restart or caller write;
the Orc owns activation after independent review. Rollback restores only the
verified generation/overrides/endpoint, never conversation state. Never substitute
Serein's identity or use fake live events or paid triggers.

## Deploy and verify

For a configuration change, validate the branch before merge:

```sh
nix-instantiate --parse configuration.nix
statix check .
nix --extra-experimental-features 'nix-command flakes' flake check
nix build .#nixosConfigurations.wsl.config.system.build.toplevel --no-link
```

After merge, apply the WSL generation and render the Kepos policy from its
Jsonnet source:

```sh
nh os switch . -H wsl
just kepos-policy-render
```

Check each service independently:

```sh
systemctl --user is-active codex-for-love-dev.service
systemctl --user is-active codex-for-love-staging.service
systemctl --user is-active codex-for-love-prod.service
ss -ltn '( sport = :3082 or sport = :3083 or sport = :3084 )'
curl --fail http://127.0.0.1:3082/
curl --fail http://127.0.0.1:3083/
curl --fail http://127.0.0.1:3084/
```

Peer-visible URLs must be accepted from the intended Mac and Pixel devices;
publisher-local checks cannot prove the subscriber path.

## Routine operation

Restart only the affected environment:

```sh
systemctl --user restart codex-for-love-dev.service
systemctl --user restart codex-for-love-staging.service
systemctl --user restart codex-for-love-prod.service
```

Inspect its recent failure evidence without exposing credentials or
conversation contents:

```sh
journalctl --user -u codex-for-love-dev.service -n 100 --no-pager
journalctl --user -u codex-for-love-staging.service -n 100 --no-pager
journalctl --user -u codex-for-love-prod.service -n 100 --no-pager
```

Do not overwrite or delete production conversation state as routine recovery.
