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

After editing the file, activate the WSL configuration so agenix can decrypt
it and the optional synchronizer can create `devops/forgejo-r2-backup`:

```bash
nh os switch . -H wsl
systemctl status forgejo-r2-backup-secret-sync.service --no-pager
KUBECONFIG=/etc/rancher/k3s/k3s.yaml \
  kubectl get secret forgejo-r2-backup -n devops -o name
```

The synchronizer validates the four keys, requires `RESTIC_REPOSITORY` to use
restic `s3:` syntax, refuses a non-local Kubernetes API server, and never emits
secret values. Do not edit `/run/agenix/forgejo-r2-backup` or the Kubernetes
Secret by hand. If the encrypted file does not exist, Nix does not declare the
secret or synchronizer and the backup workload remains disabled.

The devops Jsonnet has an explicit top-level enable flag. The normal
`just show`, `just diff`, and `just apply` commands leave the backup resources
out. After the Kubernetes Secret exists, use the gated recipes; each verifies
the local API server and all four Secret keys before rendering or applying the
enabled workload:

```bash
just forgejo-backup-show
just forgejo-backup-diff
just forgejo-backup-apply
just forgejo-backup-status
```

This gate is the deployment boundary: no backup CronJob or ConfigMap is
rendered by the normal environment, and the enabled render/apply path refuses
to proceed until the synchronized Secret is present.

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
KUBECONFIG=/etc/rancher/k3s/k3s.yaml \
  kubectl -n devops get jobs -l app.kubernetes.io/name=forgejo-source-backup
KUBECONFIG=/etc/rancher/k3s/k3s.yaml \
  kubectl -n devops logs job/<job-name> -c backup
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
- `tanka/environments/devops/main.jsonnet` — disabled-by-default top-level
  flag; the gated recipes pass the explicit enable value.
- `scripts/sync-forgejo-r2-backup-secret` — agenix environment validation and
  local-only Kubernetes Secret synchronization.
- `scripts/check-forgejo-r2-backup-secret` and `justfile` — the render/apply
  gate and status commands.
- `modules/wsl/secrets.nix` and `secrets.nix` — optional agenix declaration,
  systemd synchronizer, and recipient mapping; the operator creates the
  encrypted file separately with agenix and commits that encrypted artifact
  after editing.
- `tests/backup-forgejo-test` and `tests/forgejo-backup-render-test` — fake
  command behavior and rendered workload contract checks.
- `flake.nix` and `kepos/publisher-policy.jsonnet` — verification wiring and
  the pinned Kepos publisher cap.

`README.md` was inspected: it has no Forgejo operator workflow, so it only
records the requested Kepos pin and does not duplicate this runbook. `AGENTS.md`
was inspected: its existing secret, Tanka, and verification conventions cover
this feature, so no new agent-only command or convention was added there.
