# Impri

Impri is the private Approval Inbox for agent actions. The web inbox and API
remain private at `http://impri.localhost:17480`; the UI proxies `/v1` to the
API service. Kepos exposes that private service only to the Mac and Pixel 7a
subscribers. The only public Impri route is the Telegram callback endpoint at
`https://approve.guion.io/v1/integrations/telegram/webhook/<channelId>`.

`approve.guion.io` is a host-and-path boundary, not a public Impri UI or API:
the canonical gateway forwards only the Telegram webhook path to the Impri
server and returns its `unknown host` response for every other path. Telegram
button taps therefore reach the server without making the private inbox
public. Impri uses `BASE_URL=https://approve.guion.io` for webhook registration
and `APP_URL=http://impri.localhost:17480` for inbox links.

The deployment runs one API server and one web UI in the `impri` namespace.
Watchers are disabled, services poll Impri for Decisions, and the SSRF guard
continues to reject private callback targets. SQLite data is retained on the
local host at `/var/lib/kosmos-k3s/impri` through a 5 GiB static PV. The Retain
policy protects the data from Tanka deletion, but it does not protect against
loss of the WSL host or its disk.

## Image source

Impri does not publish container images. Kosmos builds the server and UI
Dockerfiles from the security-updated fork at pinned commit
`0dc63b750d2c4537bd41fd37394ea0bc6a634f52`.

This trusted fork pin includes the Telegram environment-proxy dispatcher from
`ede00db` and its final coverage in `0dc63b7`.

Obtain and register the checkout once, then build or load the images:

```bash
og clone https://github.com/birdmanmandbir/impri.git --alias impri-birdman
just impri-images
just impri-images-load
```

The build exports the pinned commit from the checkout, so the checkout's active
branch and working-tree changes do not enter the images.

## Deploy

The public DNS record and Cloudflare hostname route are operator-run external
setup. Do not add a bot token, API key, or tunnel credential to Kosmos. The
existing Nix-managed tunnel is `c0e179cd-14fc-4cd9-ba4c-00a445844c74`
(`nuc-wsl`). In Cloudflare DNS, create this proxied record:

| Name | Type | Target | Proxy status |
| --- | --- | --- | --- |
| `approve.guion.io` | CNAME | `c0e179cd-14fc-4cd9-ba4c-00a445844c74.cfargotunnel.com` | Proxied (orange cloud) |

The equivalent operator command provisions the hostname on the existing
tunnel; it does not create a new tunnel or secret:

```bash
cloudflared tunnel route dns c0e179cd-14fc-4cd9-ba4c-00a445844c74 approve.guion.io
```

Check DNS propagation from more than one public resolver before deploying:

```bash
dig +short CNAME approve.guion.io @1.1.1.1
dig +short CNAME approve.guion.io @8.8.8.8
dig +short A approve.guion.io @1.1.1.1
```

The CNAME lookup should show the `cfargotunnel.com` target (Cloudflare may
flatten a proxied answer); the A lookup should return Cloudflare edge address
records rather than a private WSL address. If either resolver has no answer,
wait for propagation and check the record's orange-cloud status.

After DNS is visible, Nix creates the host storage directory, `.localhost`
hosts entry, and the tunnel ingress. Apply that change first, open a new shell
if needed, then deploy the Tanka environment and gateway route:

```bash
nh os switch . -H wsl
just impri-deploy
just kepos-policy-render
just impri-status
```

`just impri-deploy` loads the pinned Impri images, applies the Impri
environment, and refreshes the canonical gateway. The tunnel credential is
the existing agenix-managed `cloudflared-kepos-credentials`; no additional
credential is expected.

`just impri-secrets` creates the webhook-signing secret if it is absent and
keeps the existing value on later deploys. The first API start creates an admin
API key and prints it once. An operator can retrieve that credential without
exposing it to an agent:

```bash
KUBECONFIG=/etc/rancher/k3s/k3s.yaml kubectl logs deployment/impri-server -n impri
```

Paste the bootstrap key into the login screen at
`http://impri.localhost:17480`. Do not store the plaintext key in this
repository.

## Configure Telegram approvals

In the private inbox, open Notifications and create a Telegram channel with
the BotFather token, destination chat ID, `approval_mode: true`, and the
numeric Telegram user IDs allowed to tap Approve or Reject. Leave `hmac_secret`
empty so Impri generates and stores it in its own database. The bot token and
the Impri API key are operator-entered secrets; they remain in Impri's
database or the operator's local shell and are never stored in Kosmos or its
agenix files.

Because the server has `BASE_URL=https://approve.guion.io`, saving an enabled
approval channel registers this callback automatically:

```text
POST https://approve.guion.io/v1/integrations/telegram/webhook/<channelId>
```

If an existing channel was created before the public base URL was deployed,
or automatic registration failed, trigger it from the private API after the
deployment:

```bash
curl -X POST \
  http://impri.localhost:17480/v1/notification-channels/<channelId>/setup-webhook \
  -H 'Authorization: Bearer im_...' \
  -H 'Content-Type: application/json'
```

The response should contain `"ok": true` and the `approve.guion.io` URL.
Never put the real token or API key in this repository, a manifest, or a
shared command transcript.

## Inspect

```bash
just impri-show
just impri-diff
just impri-status
just impri-logs
curl --noproxy '*' http://impri.localhost:17480/healthz
```

The following no-secret probe runs inside the Impri server Pod and verifies
the outbound HTTPS path used for Telegram notifications. Telegram may return
an application-level non-2xx response for the root URL; receiving any HTTP
status still proves that the proxy path is usable. A connection error or
`fetch failed` indicates that the Pod proxy, `NODE_USE_ENV_PROXY=1`, or its
bypass list is not working. The server image's trusted Telegram dispatcher
uses Node global `fetch`, and this environment flag makes that path honor the
Pod's `HTTP_PROXY`/`HTTPS_PROXY` settings.

```bash
KUBECONFIG=/etc/rancher/k3s/k3s.yaml kubectl exec \
  -n impri deployment/impri-server -- \
  node -e 'fetch("https://api.telegram.org", {signal: AbortSignal.timeout(10000)}).then((response) => { console.log(`Telegram HTTPS reachable: ${response.status}`); }).catch((error) => { console.error(`Telegram HTTPS probe failed: ${error.message}`); process.exit(1); })'
```

Use these boundary probes after DNS and deployment. They contain no bot token
or API key: the synthetic callback path should reach Impri and return `404`
for its unknown channel, while a public UI/API path should remain the
gateway's `421 unknown host` response. To check the secret guard on a real
channel, replace `probe` with its channel ID; without Telegram's secret header
that request returns `403`.

```bash
curl -sS -o /dev/null -w '%{http_code}\n' \
  -X POST https://approve.guion.io/v1/integrations/telegram/webhook/probe \
  -H 'Content-Type: application/json' -d '{}'
curl -sS -o /dev/null -w '%{http_code}\n' https://approve.guion.io/healthz
```

Finally, use `just impri-images-load`, the private test-notification control,
and a real pending action to verify delivery and callback handling. A test
button for a synthetic action may correctly report `Action not found`; for a
real action, confirm its decision in the private inbox or with
`GET /v1/actions/<actionId>`.

## Repository contract review

`README.md` remains unchanged: it documents Kosmos's host structure and shared
proxy topology, and does not promise Impri endpoints or Telegram operations.
The Impri-specific public/private boundary belongs in this runbook.

`AGENTS.md` remains unchanged: its existing rule for a Kubernetes-backed HTTP
service already requires a Tanka environment, canonical gateway route, local
hosts entry, and Kepos policy entry. This change adds a path-restricted route
and server Pod proxy variables within those established seams; it introduces
no new agent workflow or convention.
