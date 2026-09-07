# ClipCascade private P2S relay

ClipCascade is a private clipboard relay for approved personal devices. Kosmos
runs the upstream ClipCascade 3.2.0 server in the local `clipcascade` k3s
namespace with peer-to-peer mode disabled. Clients use the canonical gateway
URL:

```text
http://clipcascade.localhost:17480
```

The service is published through Kepos only to the personal-device ACL. It is
not an Internet route, and no P2P/WebRTC/STUN service is enabled. The gateway
preserves the HTTP Host header and WebSocket Upgrade/cookie handshake while
forwarding to the ClusterIP Service.

## Source and image

The image is built from the upstream Git tag `3.2.0`, pinned to commit
`faf6ac0688057b79933408470452eb02afef9625`. Register the checkout with
Organon before building it:

```bash
og clone https://github.com/Sathvik-Rao/ClipCascade.git --alias clipcascade
```

The builder exports only that commit with `git archive`; active branches,
working-tree edits, ignored files, and an existing `target/` directory are not
part of the build context. Kosmos's multi-stage Dockerfile compiles the Maven
server source and copies only the resulting JAR into a non-root JRE image. The
image is tagged `localhost/kosmos/clipcascade:faf6ac06` and carries source,
revision, and 3.2.0 provenance labels.

Build and inspect the image without changing k3s:

```bash
just clipcascade-images
```

The builder's runtime probe uses `--network=none`. The Maven build can fetch
dependencies when needed, but verification never contacts a registry or live
service. Import the exact OCI archive into local k3s only when an operator is
ready to deploy:

```bash
just clipcascade-images-load
```

Both modes leave the registered checkout untouched. The loader requires the
local k3s `ctr` store and explicit `sudo`; it does not push to a registry or
retag after import.

## Configuration and storage

The Deployment has one replica and a `Recreate` strategy because the encrypted
H2 file database is single-writer state. Its retained static PV is mounted at
`/database`, backed by `/var/lib/kosmos-k3s/clipcascade`. Nix creates that
directory with ownership for UID/GID `10001`, the image's application user.
Logs use a memory-backed emptyDir at `/app/logs`; clipboard history is not
given a separate persistent volume.

The server receives `CC_P2P_ENABLED=false` and the exact allowed origin
`http://clipcascade.localhost:17480`. The database URL uses H2 AES file
encryption and the password comes from the external Kubernetes Secret
`clipcascade/clipcascade-database`. The Secret is generated locally and is not
rendered by Tanka, committed, placed in agenix, or printed by the initializer.
It is safe to run the initializer repeatedly; an existing Secret is kept.

Initialize or inspect the local-only Secret workflow:

```bash
just clipcascade-secrets
```

The command refuses any kubeconfig whose active API server is not
`https://127.0.0.1:26443`. Do not copy its generated value into this checkout
or a shared transcript. If the Secret is lost, the retained H2 database cannot
be opened with a replacement password; follow the operator's protected backup
and recovery procedure before deleting it.

## Deploy and inspect

After this PR is merged, activate the NixOS changes first so the host entry,
CoreDNS/gateway dependencies, and retained directory exist:

```bash
nh os switch . -H wsl
```

Then inspect the exact desired objects and apply them deliberately:

```bash
just clipcascade-show
just clipcascade-diff
just clipcascade-apply
just clipcascade-deploy
just clipcascade-status
just clipcascade-logs
just kepos-policy-render
```

`clipcascade-deploy` builds and loads the pinned image, initializes the local
Secret if absent, applies the `clipcascade` environment, applies the shared
`devops` gateway environment, and waits for the canonical gateway rollout.
Rendering the Kepos policy is a separate local operation; it hot-reloads the
publisher policy without a NixOS switch. The service entry is `clipcascade`,
targets gateway port `17480`, and is limited to the existing personal-device
subscriber set.

The health endpoint is public within the private route and does not require a
login:

```bash
curl --noproxy '*' -fsS http://clipcascade.localhost:17480/health
```

The response should be `OK`. A `421 unknown host` response indicates a missing
Host route or stale gateway; a connection failure indicates that the local
gateway or Kepos path is not ready.

## First login and client acceptance

An empty database creates ClipCascade's upstream bootstrap administrator. Log
in once through the private URL, then immediately change the administrator's
username and password in the account/admin controls. Do not put either
bootstrap or replacement credential in manifests, scripts, documentation, or
agent messages. Create additional users only for the personal devices that
need the relay.

Configure each client with the private server URL above, then perform these
checks from an approved device:

1. Load the login page, complete the CSRF-protected form, and confirm the
   authenticated `JSESSIONID` cookie is retained for the next request.
2. Start the client's P2S connection and confirm the WebSocket handshake to
   `/clipsocket` succeeds through the gateway with the login cookie and an
   HTTP `Upgrade` request. Do not use the P2P/WebRTC mode.
3. Leave one client idle long enough to cover its heartbeat/reconnect interval,
   then confirm it remains connected or reconnects without a new login.
4. Copy a short text value on one device and confirm it arrives once on the
   other device; repeat in the opposite direction.
5. Relay a small image and a small file, checking that each arrives intact and
   that a deliberately oversized payload is rejected by the client/server
   limit rather than creating persistent log or database growth.
6. Log out, verify the WebSocket closes, and confirm a subsequent connection
   requires login again. Check `just clipcascade-logs` only for operational
   errors; logs are intentionally ephemeral.

These checks exercise the cookie-to-WebSocket hand-off, idle behavior, text,
image, and file relay. They require real clients after deployment and are not
performed by the repository render tests.

## Repository contract review

`README.md` remains unchanged: it documents the repository structure and shared
proxy topology, not per-service deployment workflows. This runbook owns the
ClipCascade operator contract.

`AGENTS.md` remains unchanged: its existing Kubernetes-backed HTTP service
workflow already covers a Tanka environment, canonical gateway route, local
hosts entry, retained storage, and Kepos ACL. ClipCascade introduces no new
agent convention.
