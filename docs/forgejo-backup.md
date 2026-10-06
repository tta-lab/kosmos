# Forgejo Source Recovery Backup

This is the operator runbook for the daily Forgejo Source Recovery Backup. It
is an off-host recovery copy, not a general-purpose archive and not a full
Forgejo disaster-recovery system.

## Recovery scope

The repository's glossary defines these terms:

- **Source Recovery Backup** preserves Git repositories, LFS objects, and a
  consistent SQLite metadata snapshot. It is intended to recover hosted source
  after loss of the local Forgejo PV.
- **Full Forgejo Backup** would preserve every Forgejo storage domain, including
  Packages/OCI artifacts, attachments, logs, and all instance state. This
  feature is deliberately not a Full Forgejo Backup.
- A **Backup Snapshot** is an encrypted, deduplicated restic record. Unchanged
  blocks are shared between snapshots, so daily runs do not create a new full
  archive.

The source-recovery job runs in namespace `devops` as CronJob
`forgejo-source-backup` at `04:00 Asia/Taipei` (`0 4 * * *`). Kubernetes
`concurrencyPolicy: Forbid` prevents overlapping runs. A Job has a one-hour
deadline, no retries, and `restartPolicy: Never`; a failed stage therefore
leaves a failed Job rather than reporting a successful backup.

## Included and excluded data

The job mounts the existing `forgejo-data` PVC read-only and writes only to a
disposable `emptyDir` staging volume. It passes these three inputs to restic:

| Input | Purpose |
| --- | --- |
| `/var/lib/gitea/repositories` | Git repository storage |
| `/var/lib/gitea/data/lfs` | LFS objects (included even when currently empty) |
| `/staging/forgejo.db` | SQLite online-backup snapshot |

The following are explicitly excluded:

- `/var/lib/gitea/data/packages` (Forgejo Packages/OCI)
- `/var/lib/gitea/data/attachments`
- `/var/lib/gitea/data/repo-archive`
- `/var/lib/gitea/log`
- the live `/var/lib/gitea/data/forgejo.db`, its `-wal`, and its `-shm`

The Bash entrypoint calls SQLite's online `.backup` operation while Forgejo is
running, validates the staged file with `PRAGMA integrity_check`, and then
backs up only the selected inputs. This makes the database snapshot internally
consistent. Git repositories can change while that operation runs, so the
snapshot does not promise one global instant across SQLite and Git; this is a
Source Recovery Backup by design.

## Secret hand-off and first enablement

R2 access keys, the restic repository URL, and the restic encryption password
are supplied only through an optional agenix file. Keep the restic password in
an independent password-manager entry before creating the encrypted file. The
file contains these key names and no other settings:

```text
AWS_ACCESS_KEY_ID=<R2 access key>
AWS_SECRET_ACCESS_KEY=<R2 secret key>
RESTIC_PASSWORD=<independently retained restic password>
RESTIC_REPOSITORY=s3:<private R2 endpoint and bucket>
```

Do not copy the placeholders above literally, and never commit or print their
values. Create the encrypted source file with the exact operator command. The
resulting `.age` file is encrypted and must be committed after editing; never
commit a decrypted copy:

```bash
cd /home/neil/code/projects/tta-lab/kosmos
agenix -e secrets/forgejo-r2-backup.age -i ~/.ssh/agenix_ed25519
git add secrets/forgejo-r2-backup.age
git commit -m "chore(secrets): update encrypted secrets"
```

The optional encrypted source credential is retained by Kosmos. SW consumes
`seafarer/forgejo-r2-backup`, provisioned by the operator.
For later credential rotation, the operator can populate SW from the runtime
agenix file after a WSL switch:

```bash
kubectl --kubeconfig /etc/rancher/k3s/k3s.yaml -n seafarer create secret generic forgejo-r2-backup \
  --from-env-file=/run/agenix/forgejo-r2-backup --dry-run=client -o json \
  | scripts/sw-kubectl apply -f - >/dev/null
```

The local kubectl only renders client-side JSON; the pipe applies it on SW.
The input file must be accessible to the operator. Do not run secret operations
through an agent or log values.
The Secret must contain all four nonempty keys above; retain the restic password
independently. There is no local backup synchronizer or local CronJob.

SW Jsonnet's `forgejoR2BackupEnabled` flag defaults to false. Rendering is offline
and does not read Secrets. After provisioning the Secret, review and explicitly
approve the SW apply:

```bash
just forgejo-backup-show
just forgejo-backup-diff
just forgejo-backup-apply
just forgejo-backup-status
```

These recipes target SW's `seafarer` namespace. Use the enabled flag on future
backup updates; ordinary SW applies omit backup resources and do not prune them.
The CronJob uses required Secret key references, so missing credentials prevent
execution. This remains a source-recovery backup, excluding Packages/OCI.

## Restic lifecycle and checks

The first successful run probes the repository and lazily calls `restic init`
only when the probe reports an unavailable repository. It probes again after a
failed initialization, so a concurrent initializer is accepted while an
unavailable or corrupt repository still fails the Job.

Every successful upload uses host and tag `forgejo-source-recovery`, then runs:

```text
restic forget --tag forgejo-source-recovery --keep-daily 30 --prune
restic check --read-data-subset=1/20
```

Retention keeps 30 daily recovery points for this tag. The bounded check reads
one twentieth of repository data on each run; it is not a substitute for a
periodic full restic check. Inspect Kubernetes state without printing Secret
data:

```bash
just forgejo-backup-status
scripts/sw-kubectl -n seafarer get jobs -l app.kubernetes.io/name=forgejo-source-backup
scripts/sw-kubectl -n seafarer logs job/<job-name> -c backup
```

The logs contain stage results only (snapshot validation, upload, retention,
and check). They must not contain R2 credentials or the restic password.

## Restore drill

Perform drills into a test-owned directory first. The operator must provide the
R2/restic environment from the protected secret and password-manager entry;
never paste those values into a command recorded in shell history.

List the retained recovery points and restore the newest one to a temporary
directory:

```bash
restic snapshots --tag forgejo-source-recovery
restore_dir="$(mktemp -d)"
restic restore latest --tag forgejo-source-recovery --target "$restore_dir"
find "$restore_dir" -maxdepth 4 -type f -o -type d | sort
sqlite3 "$restore_dir/staging/forgejo.db" 'PRAGMA integrity_check;'
```

Check that the restored repository directories contain expected Git data and
that LFS objects are present. Do not expect a `data/packages` tree: Packages
and OCI artifacts are outside this backup's contract. For a real recovery,
stop Forgejo writers, make a fresh safety copy of the current PV, restore the
repository root, LFS tree, and staged SQLite file to the paths owned by the
Forgejo container, then preserve UID/GID 1000 and verify Forgejo before
reopening writes. Keep the restored snapshot and safety copy until login,
repository activation, LFS fetch, and representative clone/push checks pass.

Run a repository integrity check after a drill or recovery when the maintenance
window permits a complete read:

```bash
restic check
```

## Implementation index and maintenance notes

The observable behavior is split across these paths:

- `scripts/backup-forgejo` — SQLite online backup, validation, selected restic
  inputs, lazy initialization, retention, and bounded check.
- `tanka/lib/forgejo-backup.libsonnet` — pinned runtime images, read-only PVC,
  staging and temporary volumes, Secret references, and CronJob policy.
- `tanka/environments/sw-devops/main.jsonnet` — disabled-by-default top-level
  flag; backup recipes pass the explicit enable value.
- `tests/backup-forgejo-test` and `tests/forgejo-backup-render-test` — fake
  command behavior and rendered workload contract checks.
- `flake.nix` — verification wiring.

## SW ZFS mount prerequisite

OpenEBS ZFS CSI 2.10.1 reads `ZFSVolume.spec.shared` when publishing each mount.
Without `shared: "yes"`, it rejects a second Pod mounting the same volume.
Only Forgejo's new bound volume needs sharing; leave `zfs-local`, other datasets
and business Pods unchanged. The coordinator enabled sharing on
`openebs/pvc-87ecdf49-1966-4400-a711-63e975775cda` during this migration.
No pool creation, data copy, PVC replacement or application restart is needed.

For an existing bound Forgejo claim, the operator first verifies the bound PV
uses `zfs.csi.openebs.io` and `tank/k8s`, then patches only its volume handle:

```bash
forgejo_pv="$(scripts/sw-kubectl -n seafarer get pvc forgejo-data -o jsonpath='{.spec.volumeName}')"
test -n "$forgejo_pv"
test "$(scripts/sw-kubectl get pv "$forgejo_pv" -o jsonpath='{.spec.csi.driver}')" = zfs.csi.openebs.io
test "$(scripts/sw-kubectl get pv "$forgejo_pv" -o jsonpath='{.spec.csi.volumeAttributes.openebs\.io/poolname}')" = tank/k8s
forgejo_volume="$(scripts/sw-kubectl get pv "$forgejo_pv" -o jsonpath='{.spec.csi.volumeHandle}')"
test -n "$forgejo_volume"
scripts/sw-kubectl -n openebs patch zfsvolume "$forgejo_volume" \
  --type=merge -p '{"spec":{"shared":"yes"}}'
```

For a fresh system with no Forgejo PVC, `just sw-forgejo-provision-show` renders
only a dedicated `zfs-local-forgejo-shared` StorageClass and Forgejo claim;
`just sw-forgejo-provision` refuses an existing claim before applying them.
The class uses the existing `tank/k8s`, `shared: "yes"` and `Retain`. Review and
approve provisioning before running it. On those fresh systems, pass
`zfs-local-forgejo-shared` as the second argument to `sw-devops-*` and
`forgejo-backup-*` recipes. Existing migration commands retain `zfs-local`;
do not change a bound PVC's immutable class.

The backup Pod requests a RW CSI mount, matching Forgejo's mount, while its
container bind remains `readOnly: true`. This avoids the reported ZFS mixed
RW/RO dataset mount failure and preserves read-only backup access. The existing
SQLite online-backup and selected-source recovery contract is unchanged.
Both uppercase and lowercase proxy variables use SW's Kepos Mihomo bridge at
`http://10.42.0.1:17891`, with internal cluster and SW addresses bypassed.

Evidence:

- [Official shared StorageClass semantics](https://github.com/openebs/zfs-localpv/blob/v2.10.1/docs/storageclasses.md#shared-optional-parameter)
- [Per-volume mount check in CSI 2.10.1](https://github.com/openebs/zfs-localpv/blob/v2.10.1/pkg/zfs/mount.go)
- [Mixed RW/RO ZFS mount report](https://github.com/openebs/zfs-localpv/issues/691)
- [Kubernetes CSI uses the volume's read-only setting](https://github.com/kubernetes/kubernetes/blob/v1.34.0/pkg/volume/csi/csi_plugin.go#L500)
- [Container read-only bind enforcement](https://github.com/kubernetes/kubernetes/blob/v1.34.0/pkg/kubelet/kubelet_pods.go#L402)
