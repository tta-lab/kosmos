# Codex for Love

Kosmos owns three Home Manager services for the Codex for Love (CFL) runtime.
Mika dev additionally accepts direct WSL-LAN traffic; CFL source, Codex
credentials, and conversation data remain operator-owned.

| Environment | Unit | Local port | Kepos URL | State root |
| --- | --- | ---: | --- | --- |
| Mika dev | `codex-for-love-dev.service` | 3082 (WSL LAN: `192.168.1.179`) | `http://dev-her.localhost:17480` | `~/.local/state/codex-for-love/dev` |
| Mika staging | `codex-for-love-staging.service` | 3083 | `http://staging-her.localhost:17480` | `~/.local/state/codex-for-love/staging` |
| Shio prod | `codex-for-love-prod.service` | 3084 | `http://prod-lamplit.localhost:17480` | `~/.local/state/codex-for-love/prod` |

All three services are direct Kepos HTTP services. They do not use Tanka,
Caddy, CoreDNS, Kubernetes, Docker, a subscriber binding, or an application
login. Mika dev and staging permit Mac and Sven through Kepos; Shio prod keeps
its Mac and Pixel 7a ACL. Dev additionally binds all IPv4 interfaces so Mac can
reach `http://192.168.1.179:3082` directly.

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
