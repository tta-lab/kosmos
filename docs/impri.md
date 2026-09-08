# Impri

Impri is the private Approval Inbox for agent actions. The web inbox and API
remain private at `http://impri.localhost:17480`; the UI proxies `/v1` to the
API service. Kepos exposes that private service only to the Mac and Pixel 7a
subscribers. There is no public Impri hostname or webhook ingress.

Keet approvals use the standalone adapter in `keet-for-agent`. It polls this
private Impri API with an actions-scoped key and records decisions through the
existing API. The adapter's `packages/impri-keet/README.md` owns its setup and
interaction documentation; Kosmos owns the API/UI hosting described here.

The deployment runs one API server and one web UI in the `impri` namespace.
Watchers are disabled, services poll Impri for Decisions, and the SSRF guard
continues to reject private callback targets. SQLite data is retained on the
local host at `/var/lib/kosmos-k3s/impri` through a 5 GiB static PV. The Retain
policy protects the data from Tanka deletion, but it does not protect against
loss of the WSL host or its disk.

## Image source

Impri does not publish container images. Kosmos builds the server and UI
Dockerfiles from the security-updated fork at pinned commit
`bff19604d9e0998fddf1c84ead217154d21e83ee`.

Obtain and register the checkout once, then build or load the images:

```bash
og clone https://github.com/birdmanmandbir/impri.git --alias impri-birdman
just impri-images
just impri-images-load
```

The build exports the pinned commit from the checkout, so the checkout's active
branch and working-tree changes do not enter the images.

## Deploy

Nix creates the host storage directory and `.localhost` hosts entry. Apply
those host settings first, then deploy the Tanka environment and private
gateway route:

```bash
nh os switch . -H wsl
just impri-deploy
just kepos-policy-render
just impri-status
```

`just impri-deploy` loads the pinned Impri images, applies the Impri
environment, and refreshes the canonical gateway. Impri requires no Cloudflare
Tunnel route. Both `BASE_URL` and `APP_URL` use the private service address.

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
