# Environment Variables

Choose an environment-variable owner by scope. Do not put non-secret values in
an agenix file merely because a shell can source it.

| Need | Owner | Effective scope |
| --- | --- | --- |
| Non-secret interactive setting | `home.sessionVariables` in `modules/configs.nix` | Newly started Fish and Zsh sessions |
| WSL HTTP proxy | `modules/wsl/proxy-topology.json` via `kosmos.wsl.proxy` | System environment, Fish/Zsh, and explicitly configured Home Manager services |
| A Home Manager service setting | Its `Service.Environment` | That service only |
| Shell-only secret | `secrets/env.age`, deployed as `~/.config/env` | Fish only |
| Service secret | agenix target plus that service's `EnvironmentFile` or startup wrapper | That service only |

`home.sessionVariables` does not change an existing shell and does not inject a
variable into independently installed systemd user services. Give those services
an explicit environment or a documented generated interface.

## WSL HTTP Proxy

`modules/wsl/proxy-topology.json` is the shared source for the local Mihomo
listener, Pod proxy endpoint, Pod and Service CIDRs, and base `NO_PROXY`
entries. `kosmos.wsl.proxy` derives the host environment and both uppercase and
lowercase proxy variables from it. It feeds NixOS, `home.sessionVariables`,
DSH, Temenos, and og; Tanka derives Pod workload proxy settings from the same
data. K3s extends only the base bypass list with cluster-local hostnames.

`kosmos-wsl-proxy-env` is intentionally separate: it discovers a reachable WSL
host proxy at runtime for manual bootstrap work. Do not use it as a second place
to configure the local Mihomo endpoint.

## Shell Secret File

`secrets/env.age` decrypts to `~/.config/env`. It currently holds the Exa API
key and must contain Fish `set -gx` statements. It is sourced only by Fish, so
it is not a place for shared settings, Zsh variables, proxy configuration, or
service credentials. See [Secrets](secrets.md) for safe editing instructions.

## Pi Retry Watchdog

`PI_RETRY_STALL_TIMEOUT_MS=0` is a non-secret interactive setting in
`home.sessionVariables`. It takes effect in newly started Fish and Zsh sessions.
