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

The `garage-cors-v1` Job idempotently applies the bucket CORS policy required
by Ente Desktop's browser runtime. The wildcard origin does not make objects
public: Garage still requires Museum's signed URLs for object access.

## Initial mobile setup

1. Install the official Ente Photos app and ensure the device's Kepos
   subscriber is connected and approved.
2. On Ente's onboarding screen, tap the lock image seven times.
3. Set the custom server endpoint to `http://ente.localhost:17480`.
4. Create the first account. Without SMTP, read only the one-time code from
   Museum's local-cluster logs; do not store the code in Git:

   ```bash
   KUBECONFIG=/etc/rancher/k3s/k3s.yaml \
     kubectl -n photos logs deployment/museum --since=15m |
     rg 'Skipping sending email.*Verification code:' |
     tail -n 1
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

## Desktop viewing and export

Ente Desktop uses the same custom API endpoint,
`http://ente.localhost:17480`. Browsing downloads previews into the app cache;
it does not automatically create original files in Finder. To keep local
originals, open **Settings > Export data**, select a separate destination
folder, and enable **Continuous export**. Do not use an upload watch folder as
the export destination.

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

## Migration backup and restore

The Ente recovery unit is the PostgreSQL database, the complete Garage data
directory, and the existing `ente-stack-env` agenix secret. Photos cannot be
reconnected from Garage object blocks alone because PostgreSQL holds the Ente
account, album, object, and sharing records. Garage's `meta`, `snapshots`, and
`data` directories must also stay together.

For the 2026 bare-metal migration, mount the Micron ext4 filesystem with UUID
`441ba8bb-d21b-40e4-a921-ef5553e07ff3` at
`/mnt/kosmos-data-backup`. The backup command rejects any other filesystem so
an unmounted directory on the WSL root disk cannot silently receive the copy:

```bash
sudo kosmos-backup-ente \
  /mnt/kosmos-data-backup/kosmos-backup-20260727
```

The command performs one coordinated backup:

1. Scale Museum to zero to stop application writes.
2. Create and validate a custom-format PostgreSQL dump.
3. Stop PostgreSQL and Garage, then copy both physical data directories with
   numeric ownership, ACLs, and extended attributes intact.
4. Restore PostgreSQL, Garage, and Museum to their original replica counts.
5. Write `BACKUP-INFO.json` without Secret values, generate `SHA256SUMS`, and
   verify every copied file before publishing the timestamped backup directory.

A failed copy leaves a hidden `.backup-*.partial` directory for inspection and
still attempts to restore all workloads. Do not treat a partial directory as a
backup.

For the first bare-metal restore, keep the image versions recorded in
`BACKUP-INFO.json` and reuse the existing agenix secret. Before starting the
Photos workloads, restore `garage/` and `postgres-physical/` to the host paths
selected by the new PV definitions with:

```bash
sudo rsync -aHAX --numeric-ids BACKUP/garage/ GARAGE_HOST_PATH/
sudo rsync -aHAX --numeric-ids BACKUP/postgres-physical/ POSTGRES_HOST_PATH/
```

The physical PostgreSQL copy is the shortest exact-version recovery path. The
validated `postgres/ente_db.dump` is the portable fallback: start an empty
PostgreSQL instance of a compatible version and feed the dump to `pg_restore`.
Do not let Museum write to an empty database before the restore completes.

After applying the Secret and Photos manifests, verify `just photos-status`,
run `kosmos-photos-gate-status --strict`, open and download an existing photo
from a client, upload a disposable new photo, restart all three workloads, and
download both again. A successful pod rollout alone does not prove that the
database and Garage object index match.

Images are pinned by version and digest. Before upgrading Museum, PostgreSQL,
or Garage, read upstream migration notes, render and review the Tanka diff, and
make a separate rollback decision. Do not switch an image to `latest`.
