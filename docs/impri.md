# Impri

Impri is the private Approval Inbox for agent actions. The web inbox and API
share `http://impri.localhost:17480`; the UI proxies `/v1` to the API service.
Kepos exposes the service only to the Mac and Pixel 7a subscribers. Impri is
not exposed through Cloudflare Tunnel.

The deployment runs one API server and one web UI in the `impri` namespace.
Watchers are disabled, services poll Impri for Decisions, and the SSRF guard
continues to reject private callback targets. SQLite data is retained on the
local host at `/var/lib/kosmos-k3s/impri` through a 5 GiB static PV. The Retain
policy protects the data from Tanka deletion, but it does not protect against
loss of the WSL host or its disk.

## Image source

Impri does not publish container images. Kosmos builds the upstream server and
UI Dockerfiles from pinned commit
`edc8147eab60e74d87859a019db81ef59e801e58`. Obtain and register the checkout
once, then build or load the images:

```bash
og clone https://gitlab.com/sekera.radim/impri.git
just impri-images
just impri-images-load
```

The build exports the pinned commit from the checkout, so the checkout's active
branch and working-tree changes do not enter the images.

## Deploy

Nix creates the host storage directory and `.localhost` hosts entry. Apply that
change first, open a new shell if needed, then deploy the Tanka environment and
gateway route:

```bash
nh os switch . -H wsl --ask
just impri-deploy
just kepos-policy-render
just impri-status
```

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

## Inspect

```bash
just impri-show
just impri-diff
just impri-status
just impri-logs
curl --noproxy '*' http://impri.localhost:17480/healthz
```
