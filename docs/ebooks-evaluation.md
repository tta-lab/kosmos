# Ebook evaluation

BookOrbit runs in the local `ebooks` namespace for a reading evaluation. It is
private: the only client route is the Kepos-published HTTP host on the canonical
loopback gateway.

## Endpoints

- BookOrbit: `http://bookorbit.localhost:17480`

The database has a ClusterIP service only and is not published through Kepos.

## Deploy

Deploy the NixOS generation first. It creates the retained host directories,
adds the local hostname, and installs the Kepos publisher service:

```bash
nh os switch . -H wsl
```

Then add the `bookorbit` service and its ACL to
`kepos/peer-policy.jsonnet` and run `just kepos-policy-render`; Kepos
hot-reloads that rendered policy without a rebuild or restart.

Then create missing credentials and apply the Tanka environments:

```bash
just ebooks-diff
just ebooks-deploy
just ebooks-status
just kepos-status
```

`just ebooks-deploy` generates random database, JWT, and setup credentials
directly into Kubernetes Secrets when they are absent. Re-running it preserves
the existing credentials. Generated values are never stored in this repository
or printed during deployment.

BookOrbit's first-run page asks for its one-time bootstrap token. Neil can print
that token locally with:

```bash
just bookorbit-bootstrap-token
```

Agents must not run that command or inspect the Secret plaintext.

## Upgrade existing 2.3.0 installation to 3.2.0

The pinned target is `ghcr.io/bookorbit/bookorbit:3.2.0` at multi-architecture
index `sha256:1020eef9f004be972ac60e79dd5f416129f0d3d91491b803aa8fa656acb2b6a6`
(amd64 and arm64). [Issue #1461](https://github.com/bookorbit/bookorbit/issues/1461)
identifies 3.0.0 as the minimum server for official iOS login. The
[3.2.0 release](https://github.com/bookorbit/bookorbit/releases/tag/v3.2.0)
adds separate ebook/audio covers with automatic migration.

[Upstream updating instructions](https://bookorbit.app/installation/#updating)
confirm automatic database migrations at startup. The
[3.2.0 entrypoint](https://github.com/bookorbit/bookorbit/blob/v3.2.0/server/entrypoint.sh)
runs them before serving traffic; pending migrations 0074–0100 include device
auth sessions and cover tables. The
[cover backfill](https://github.com/bookorbit/bookorbit/blob/v3.2.0/server/src/modules/cover/cover-slot-backfill.service.ts)
also moves legacy cover files and updates database state in the background.
Readiness alone does not establish backfill completion. PostgreSQL remains on
our existing pgvector PG18 image; the upstream PG16→18 procedure is not needed.
Existing port, PostgreSQL variables, PUID/PGID, writable `/data`, `/books` and
`/tmp`, read-only root filesystem and health route remain appropriate.

These are **operator-only** steps after approval, in a maintenance window.
This PR has not deployed, backed up, restored or tested live Web/iOS login.
No NixOS switch, route/TLS change or new bootstrap is required for this upgrade.
Before starting, ensure enough backup/restore space and a protected backup
location outside the WSL virtual disk. Preserve the existing `bookorbit-env`
Secret through your approved secure recovery process; it must match restored
state. Do not print it or regenerate credentials. See [secrets guidance](secrets.md).
If recovery of that Secret or a restore rehearsal is unavailable, stop here.

Stop all application writers, then the database, and archive both retained
directories together. Run in Bash, replacing the backup destination with an
existing protected filesystem; do not run deployment concurrently:

```bash
set -euo pipefail
export KUBECONFIG=/etc/rancher/k3s/k3s.yaml
export KUBECTL_CONTEXT=default
# Use --context explicitly for each direct cluster operation.
kubectl --context="$KUBECTL_CONTEXT" -n ebooks scale deployment/bookorbit --replicas=0
kubectl --context="$KUBECTL_CONTEXT" -n ebooks wait --for=delete pod -l app.kubernetes.io/name=bookorbit --timeout=180s
kubectl --context="$KUBECTL_CONTEXT" -n ebooks scale statefulset/bookorbit-postgres --replicas=0
kubectl --context="$KUBECTL_CONTEXT" -n ebooks wait --for=delete pod -l app.kubernetes.io/name=bookorbit-postgres --timeout=180s
```

Confirm both pods are absent and shutdown completed before archiving. Abort on
timeouts; investigate forced termination before trusting a cold backup. Then:

```bash
umask 077
backup_dir=/REPLACE/with/off-WSL-protected-location/bookorbit-pre-3.2.0
mkdir -m 700 "$backup_dir"
sudo tar --numeric-owner -cpf "$backup_dir/state.tar" -C /var/lib/kosmos-k3s/ebooks bookorbit bookorbit-db
sudo tar -tf "$backup_dir/state.tar" >/dev/null
sudo sha256sum "$backup_dir/state.tar" >"$backup_dir/state.tar.sha256"
```

Abort on backup errors. Retain the checksum, old checkout/manifest and old
image digest from the PR base. The cold archive includes `/data`,
`/books` and PGDATA with numeric ownership; never copy a running PGDATA tree.
Archive readability/checksum is not a restore test: rehearse restoration into
isolated storage with the same PG18 image before proceeding. Keep backup data
and Secret recovery material private and out of Git and logs.

With a verified backup, start PostgreSQL, then deploy the approved checkout:

```bash
kubectl --context="$KUBECTL_CONTEXT" -n ebooks scale statefulset/bookorbit-postgres --replicas=1
kubectl --context="$KUBECTL_CONTEXT" -n ebooks rollout status statefulset/bookorbit-postgres --timeout=180s
just ebooks-diff
just ebooks-deploy
kubectl --context="$KUBECTL_CONTEXT" -n ebooks rollout status deployment/bookorbit --timeout=600s
just ebooks-status
curl --fail --silent --show-error http://bookorbit.localhost:17480/api/v1/health
curl --fail --silent --show-error http://bookorbit.localhost:17480/api/v1/auth/login-options
```

Review the diff before apply: only the BookOrbit image should change (plus the
intentional replica restoration). `ebooks-deploy` waits for the gateway, so the
explicit BookOrbit rollout check is required. The health response must report
`status: ok` and a healthy database; login-options must return JSON rather than
404. Privately inspect application startup logs for successful SQL migrations
and `cover.slot_backfill` completion/errors; background work may outlast rollout.
Do not share raw logs, tokens or account details.

Log in on the Web using the existing account; verify the library, covers,
progress and highlights. Then use the official iOS app with the existing
Kepos-reachable server URL and verify login no longer rejects `deviceLabel` or
`clientKind`; open a copied EPUB, advance progress and verify it on the Web.
Check any audiobook covers if present. If a KOReader device uses plugin v1.3.x,
follow the [2.5.0 manual plugin update notice](https://github.com/bookorbit/bookorbit/releases/tag/v2.5.0)
in Settings > KOReader; never publish its credential-bearing plugin download.

### Recovery boundary

After the new app has started, an image-only downgrade or `rollout undo` is not
a safe recovery: SQL schema and cover files may already have changed. Stop the
app and database using the same scale/wait sequence above. Preserve failed state
separately; restore **both** directories from the same verified cold archive
into empty target directories with original numeric ownership, and retain the
matching Secret. With both workloads stopped, move the failed directories to a
separate protected location first; the absence checks below prevent an overlay
restore. Use the backup path from above and verify its checksum before extraction:

```bash
sudo sha256sum --check "$backup_dir/state.tar.sha256"
sudo test ! -e /var/lib/kosmos-k3s/ebooks/bookorbit
sudo test ! -e /var/lib/kosmos-k3s/ebooks/bookorbit-db
sudo tar --numeric-owner -xpf "$backup_dir/state.tar" -C /var/lib/kosmos-k3s/ebooks
kubectl --context="$KUBECTL_CONTEXT" -n ebooks set image deployment/bookorbit bookorbit=ghcr.io/bookorbit/bookorbit:2.3.0@sha256:62048532c82ad4cfe9b728707136f140516f0f35766c2dc97969f22ed67794ae
kubectl --context="$KUBECTL_CONTEXT" -n ebooks scale statefulset/bookorbit-postgres --replicas=1
kubectl --context="$KUBECTL_CONTEXT" -n ebooks rollout status statefulset/bookorbit-postgres --timeout=180s
kubectl --context="$KUBECTL_CONTEXT" -n ebooks scale deployment/bookorbit --replicas=1
kubectl --context="$KUBECTL_CONTEXT" -n ebooks rollout status deployment/bookorbit --timeout=600s
```

Keep the existing pinned PG18 image. Restore the repository's old image pin
from the PR base before any later Tanka apply; do not run the 3.2.0 deploy recipe
against restored state. Recheck health and Web library/progress; old 2.3.0 will
still lack official iOS support. Recovery loses writes made after the backup.
PV `Retain` and a Git revert provide no data rollback. A restore without a verified backup requires operator investigation,
not ad hoc schema edits or deletion of PVCs.

## Evaluation

Put only a disposable or copied Chinese EPUB into each app. On desktop, phone,
and the Viwoods AiPaper, verify:

1. Login and open the same book.
2. Change font, spacing, theme, and paginated layout.
3. Turn at least twenty pages and check latency and ghosting.
4. Long-press Chinese text, save several highlights, close the reader, and
   reopen each highlight.
5. Suspend and resume the AiPaper.
6. Disconnect and reconnect Kepos, then confirm progress and highlights remain.

Do not import the full library until one candidate passes this evaluation and
its retained state has survived a pod restart.

## Storage

Static PVs use `Retain` and keep temporary evaluation data under:

- `/var/lib/kosmos-k3s/ebooks/bookorbit`
- `/var/lib/kosmos-k3s/ebooks/bookorbit-db`

These directories remain on the WSL virtual disk and are not backups. Removing
the Tanka resources does not remove them automatically.
