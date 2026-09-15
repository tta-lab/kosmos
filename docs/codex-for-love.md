# Codex for Love

Kosmos owns two loopback-only Home Manager services for the Codex for Love
(CFL) runtime. CFL source, Codex credentials, and conversation data remain
operator-owned.

| Environment | Unit | Local port | Kepos URL | State root |
| --- | --- | ---: | --- | --- |
| Mika dev | `codex-for-love-dev.service` | 3082 | `http://dev-lamplit.localhost:17480` | `~/.local/state/codex-for-love/dev` |
| Shio prod | `codex-for-love-prod.service` | 3084 | `http://prod-lamplit.localhost:17480` | `~/.local/state/codex-for-love/prod` |

Both services are direct Kepos HTTP services. They do not use Tanka, Caddy,
CoreDNS, Kubernetes, Docker, a subscriber binding, or an application login.
Their Kepos services permit the existing Mac and Pixel 7a keys only.

## Service contract

- Services run CFL's TypeScript CLI with the Nix-pinned Node 24 executable.
- Each environment owns its own `partner.toml`, persona, state, workspace,
  SQLite projection, attachments, profile images, and Codex thread. Do not
  copy or merge one root into the other.
- The launcher requires its own exact name, persona, state, workspace, port,
  model, and `/home/neil/.codex` settings before it starts. Shio's workspace
  also requires `model_reasoning_effort = "low"`.
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
systemctl --user is-active codex-for-love-prod.service
ss -ltn '( sport = :3082 or sport = :3084 )'
curl --fail http://127.0.0.1:3082/
curl --fail http://127.0.0.1:3084/
```

Peer-visible URLs must be accepted from the intended Mac and Pixel devices;
publisher-local checks cannot prove the subscriber path.

## Routine operation

Restart only the affected environment:

```sh
systemctl --user restart codex-for-love-dev.service
systemctl --user restart codex-for-love-prod.service
```

Inspect its recent failure evidence without exposing credentials or
conversation contents:

```sh
journalctl --user -u codex-for-love-dev.service -n 100 --no-pager
journalctl --user -u codex-for-love-prod.service -n 100 --no-pager
```

Do not overwrite or delete production conversation state as routine recovery.
