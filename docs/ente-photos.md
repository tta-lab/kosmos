# Ente Photos

Ente Photos is the mobile-first photo and video archive on kosmos-wsl. Museum,
PostgreSQL, and Garage run in the local single-node k3s cluster. There is no
Ente web frontend, public route, server-side ML, high availability, or off-host
backup in this deployment.

## Endpoints

The Ente mobile app uses two private Kepos services:

- `ente.localhost:17480` routes to Museum, the Ente API.
- `ente-storage.localhost:17480` routes to Garage's S3 API.

Museum returns pre-signed Garage URLs, so the phone and Museum must use the
same `ente-storage.localhost:17480` authority. Caddy preserves the HTTP Host
header and routes both names on the shared loopback port. PostgreSQL, Garage
RPC, and Garage administration are not exposed.

## Secrets

Agents must not read or decrypt the Ente secret. Create it interactively:

```bash
agenix -e secrets/ente-stack-env.age
```

Enter exactly these keys as an env file:

```text
POSTGRES_PASSWORD=<openssl rand -hex 32>
ENTE_KEY_ENCRYPTION=<openssl rand -base64 32>
ENTE_KEY_HASH=<openssl rand -base64 64>
ENTE_JWT_SECRET=<openssl rand -base64 32>
GARAGE_RPC_SECRET=<openssl rand -hex 32>
GARAGE_ACCESS_KEY=GK<openssl rand -hex 16>
GARAGE_SECRET_KEY=<openssl rand -hex 32>
```

Run each command separately and paste its output in place of the angle-bracket
expression. Do not include the angle brackets or command text. After rebuilding
NixOS, the root-owned `ente-secret-sync.service` validates the file and applies
Kubernetes Secret `photos/ente-stack-env` only to the guarded local cluster.

## Render and deploy

NixOS owns k3s, retained host directories, agenix, host aliases, and the Kepos
publisher. Tanka owns Kubernetes resources. A NixOS rebuild never applies
Tanka.

```bash
just photos-show
just photos-diff
just photos-apply
sudo systemctl restart ente-secret-sync.service
sudo systemctl status ente-secret-sync.service --no-pager
just diff
just apply
just photos-status
just kepos-status
```

The `photos-apply` command creates the namespace and workloads. On the first
deployment, Pods can remain pending until `ente-secret-sync.service` creates
their Secret. The normal `just apply` then updates the shared Caddy and CoreDNS
gateway configuration in the `devops` environment.

## Initial mobile setup

1. Install the official Ente Photos app and ensure the device's Kepos
   subscriber is connected and approved.
2. On Ente's onboarding screen, tap the lock image seven times.
3. Set the custom server endpoint to `http://ente.localhost:17480`.
4. Create the first account. Without SMTP, read only the one-time code from
   Museum's local-cluster logs; do not store the code in Git:

   ```bash
   KUBECONFIG=/etc/rancher/k3s/k3s.yaml \
     kubectl -n photos logs deployment/museum
   ```

5. Configure the official Ente CLI with API endpoint
   `http://ente.localhost:17480`, add the new account, and grant it the
   self-hosted storage allowance:

   ```bash
   ente account add
   ente admin update-subscription -a <admin-email> -u <user-email> --no-limit
   ```

   The first registered user is Museum's fallback administrator. Replace both
   placeholders with registered, verified email addresses; for one personal
   account they are the same address.
6. Select the device albums to upload and enable background backup.

Before trusting phone cleanup, upload a disposable JPEG and a video larger
than 20 MiB. Open and download both after restarting Museum, PostgreSQL,
Garage, Caddy, and k3s. Then test **Free up device space** with a second
disposable photo and confirm it can be downloaded again.

## Operations

Check the complete local gate and disk usage:

```bash
kosmos-photos-gate-status --strict
```

Inspect workloads and logs:

```bash
KUBECONFIG=/etc/rancher/k3s/k3s.yaml kubectl -n photos get pods,svc,pvc -o wide
KUBECONFIG=/etc/rancher/k3s/k3s.yaml kubectl -n photos logs deployment/museum
KUBECONFIG=/etc/rancher/k3s/k3s.yaml kubectl -n photos logs statefulset/garage
KUBECONFIG=/etc/rancher/k3s/k3s.yaml kubectl -n photos logs statefulset/postgres
df -h /var/lib/kosmos-k3s
```

Application state remains in:

- `/var/lib/kosmos-k3s/ente/postgres`
- `/var/lib/kosmos-k3s/ente/garage`

Both static PVs use `Retain`, but they are on the same WSL virtual disk and are
not a backup. Stop the affected workload before restoring either directory.

Images are pinned by version and digest. Before upgrading Museum, PostgreSQL,
or Garage, read upstream migration notes, render and review the Tanka diff, and
make a separate rollback decision. Do not switch an image to `latest`.
