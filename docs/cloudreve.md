# Cloudreve

Cloudreve is a private file-management service in the `cloudreve` Kubernetes
namespace. It uses PostgreSQL and Redis and stores Cloudreve's local files and
PostgreSQL data on the 2 TiB Micron SATA disk rather than the WSL root disk.

## Endpoint and access

- WSL and Kepos subscribers: `http://cloudreve.localhost:17480`
- Health check: `http://cloudreve.localhost:17480/api/v4/site/ping`

Kepos publishes `cloudreve` through the canonical HTTP gateway. It is available
to personal devices plus the `sven-mac` placeholder subscriber. The placeholder
is a deliberately unusable generated public key; replace it with Sven's actual
Kepos subscriber public key in `kepos/publisher-policy.jsonnet`, then run
`just kepos-policy-render`. Kepos hot-reloads the valid rendered ACL; do not
rebuild WSL for that policy change.

The first Cloudreve account to register becomes the administrator. Register the
owner account before replacing the Sven placeholder or sharing the endpoint.
Then set the site's URL to `http://cloudreve.localhost:17480` in the Cloudreve
admin dashboard and adjust users, groups, and storage quotas there.

## Micron data disk

The retained disk is Windows `\\.\PHYSICALDRIVE0` (`Micron_5200_MTFDDAK1T9TDD`),
partition 1, ext4 UUID `441ba8bb-d21b-40e4-a921-ef5553e07ff3`. NixOS mounts it
at `/mnt/kosmos-cloudreve`; Cloudreve uses only its `cloudreve/` subdirectory.

`cloudreve-storage.service` verifies that exact filesystem UUID before creating
any hostPath directories. The static PVs use `hostPath.type: Directory`, so an
unavailable disk leaves the Pods pending rather than writing data to the WSL
root filesystem.

Install the Windows logon task once from an elevated Windows PowerShell. It
copies its runtime script into `%LOCALAPPDATA%`, takes only the verified Micron
disk offline in Windows, attaches it bare to WSL, and keeps the NixOS WSL
instance alive without leaving a visible PowerShell window. A one-minute
recovery trigger restarts the task if its persistent process is interrupted;
healthy executions ignore those repeated triggers. It also reattaches the disk
after a WSL shutdown and Task Scheduler retries a failed task execution up to
three times:

```powershell
& "\\wsl.localhost\NixOS\home\neil\code\projects\tta-lab\kosmos\windows\install-cloudreve-wsl-disk-task.ps1"
```

The task is named `Kosmos-Cloudreve-WSL-Disk`. Its log is
`%LOCALAPPDATA%\Kosmos\cloudreve-wsl-disk.log`. Do not use `wsl --unmount`
or `wsl --shutdown` to intentionally detach the disk while Cloudreve is in
use; the task will restart it shortly afterward.

Rerun the installer after changing either Windows script. Updating the checkout
does not reconcile an already registered task or its copy in `%LOCALAPPDATA%`.

## Deploy and verify

```bash
nh os switch . -H wsl --ask
just cloudreve-diff
just cloudreve-deploy
just cloudreve-status
curl --fail --header 'Host: cloudreve.localhost' \
  http://127.0.0.1:17480/api/v4/site/ping
```

`cloudreve-env` is the agenix source of truth. Its root-only decrypted file is
`/run/agenix/cloudreve-env`; it contains exactly:

```dotenv
POSTGRES_PASSWORD=<64 lowercase hexadecimal characters>
SESSION_SECRET=<128 lowercase hexadecimal characters>
```

`cloudreve-secret-sync.service` validates that file after k3s starts, creates
or updates the `cloudreve/cloudreve-env` Kubernetes Secret, and restarts
Cloudreve only when its Secret changes. A password change also updates the
PostgreSQL role through its local in-Pod socket. Cloudreve receives no
`CR_CONF_*` environment variables because it logs configuration overrides.
The synchronizer does not wait for the Cloudreve rollout: Kubernetes reconciles
the workload and its storage independently. `just cloudreve-deploy` is the
explicit operation that waits for rollout readiness. The systemd reconciler is
also asynchronous, so a pending PostgreSQL password rotation retries without
blocking `nh os switch`.

To change the credentials, edit the encrypted source and activate NixOS:

```bash
agenix -e secrets/cloudreve-env.age
nh os switch . -H wsl --ask
```
