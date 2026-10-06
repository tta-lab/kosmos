# SW Forgejo and Woodpecker

SW owns Forgejo, Woodpecker server, agents and PostgreSQL. Their persistent
volumes use the existing `zfs-local` StorageClass in `tank/k8s`; no new pool is
created. Forgejo remains on SQLite. Dagger and Mihomo stay on kosmos-wsl and
are consumed over Kepos raw TCP bindings.

## Addresses and ownership

| Capability | Address |
| --- | --- |
| Forgejo, Git and OCI registry | `https://192.168.6.186:8086` |
| Woodpecker UI and OAuth callback host | `https://192.168.6.186:8087` |
| SW host Mihomo binding | `127.0.0.1:17890` |
| SW host Dagger binding | `127.0.0.1:18080` |
| SW Pod HTTP proxy | `http://10.42.0.1:17891` |
| SW Pod Dagger runner | `tcp://10.42.0.1:18081` |

The two HTTPS listeners bind SW's private IP and reuse the existing
`seafarer-edge-tls` Secret in namespace `seafarer`. A separate Caddy Deployment
owns only these ports. Existing SW business Pods, namespaces, rollout strategies
and the Seafile edge Deployment remain unchanged; this migration must not
restart k3s. Activation applies only SW DevOps resources. Clients must
trust `certs/seafarer-root-ca.pem` and have a VPN route to SW.

`kepos/sw-policy.jsonnet` owns SW's peer policy. `kepos/sw-peer.service` owns
the canonical host runtime, replacing the legacy subscriber. The local policy
allows SW to consume Dagger and Mihomo. Both bindings stay on loopback; the
Kubernetes bridge exposes them only through the CNI interface. SW's internal
Forgejo, Woodpecker and PostgreSQL traffic bypasses the outbound proxy. Git
operations in SW pipelines use the canonical HTTPS URL, preserving the netrc
authentication host. The clone plugin downloads the public CA from an immutable
public repository URL and configures Git certificate verification.

The SW workloads are rendered from `tanka/environments/sw-devops`. Normal
deployment uses `enabled=true`; `false` holds Forgejo and Woodpecker server and
agents at zero replicas for restoration. It still runs PostgreSQL and the edge.

## Commands

All commands run from Kosmos. `scripts/sw-kubectl` uses SSH and explicitly
selects SW's `/etc/rancher/k3s/k3s.yaml` and `default` context; it never uses
the caller's kube context. Application operations require no host sudo.

```bash
just sw-devops-show true
just sw-devops-diff true
just sw-devops-apply true
just sw-devops-status
```

Production applies require an approved, reviewed deployment.

## Pipeline proxy contract

Woodpecker v3.18's server owns `WOODPECKER_BACKEND_HTTP_PROXY`,
`WOODPECKER_BACKEND_HTTPS_PROXY` and `WOODPECKER_BACKEND_NO_PROXY`.
These are string flags, preserving the commas in the bypass list. Do not put
`NO_PROXY` inside `WOODPECKER_ENVIRONMENT`, which is comma-delimited.
The compiler adds both uppercase and lowercase proxy variables to every
pipeline container, including the default clone and custom clone containers:

- [Server string flags](https://github.com/woodpecker-ci/woodpecker/blob/v3.18.0/cmd/server/flags.go#L437)
- [Server configuration](https://github.com/woodpecker-ci/woodpecker/blob/v3.18.0/cmd/server/setup.go#L229)
- [Pipeline compiler wiring](https://github.com/woodpecker-ci/woodpecker/blob/v3.18.0/server/pipeline/items.go#L124)
- [Exact environment map values](https://github.com/woodpecker-ci/woodpecker/blob/v3.18.0/pipeline/frontend/yaml/compiler/option.go#L190)
- [Environment copy for each process](https://github.com/woodpecker-ci/woodpecker/blob/v3.18.0/pipeline/frontend/yaml/compiler/convert.go#L89)
- [Kubernetes Pod environment](https://github.com/woodpecker-ci/woodpecker/blob/v3.18.0/pipeline/backend/kubernetes/pod.go#L280)

## Local retirement and retained recovery

The local devops environment owns only the gateway and Dagger. Old Forgejo and
Woodpecker ingress, routes, Kepos publication, local storage declarations and
secret-sync units are retired. This does not remove live PVs/PVCs, source data,
or backups. Do not prune the old volumes or restart old writers after SW accepts
writes. The optional R2 backup now targets SW; see [backup](forgejo-backup.md).
The source-recovery R2 backup excludes Packages/OCI and cannot replace a full
Forgejo backup.

## Clone TLS and CLI endpoint ownership

Plugin-git 2.6.0 supports `PLUGIN_CUSTOM_SSL_URL` (a URL), not an inline
`PLUGIN_CUSTOM_CERTIFICATE` value. Its HTTP client downloads the CA to a
local file and configures Git `http.sslCAInfo`; TLS verification stays enabled.
The global clone environment downloads the public CA from the immutable
[repository revision](https://raw.githubusercontent.com/tta-lab/kosmos/592591f87b6beb9d6c901a0812b5682367718882/certs/seafarer-root-ca.pem) through the pipeline proxy. The fetched file
was byte-compared with `certs/seafarer-root-ca.pem`; both SHA-256 values were
`0e575ab6392c440e41c3f08f791ea5c3407899e3284e50fb0734d84e72f2c568`.
Clone URLs stay
`https://192.168.6.186:8086/...`; rewriting them to `http://forgejo:3000`
breaks netrc authentication because credentials are keyed by the canonical host.

- [Plugin-git 2.6.0 certificate flags](https://github.com/woodpecker-ci/plugin-git/blob/2.6.0/flags.go#L82)
- [CA download and Git configuration](https://github.com/woodpecker-ci/plugin-git/blob/2.6.0/plugin.go#L142)
- [Go default transport proxy behavior](https://pkg.go.dev/net/http#DefaultTransport)

`WOODPECKER_URL=https://192.168.6.186:8087` is a nonsecret Home Manager session
variable in `modules/configs.nix`. Organon's `InjectDotEnvFallback` loads
`~/.config/ttal/.env` only where the process environment is empty; see its
`internal/config/dotenv.go`, `cmd/og/runtime.go` and `cmd/og/mcp.go`. Fresh shells
use the managed endpoint; existing MCP processes need their own environment
refreshed. Agents must not inspect the private dotenv file.
