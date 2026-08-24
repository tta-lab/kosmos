# Woodpecker SQLite → PostgreSQL migration research

## Scope and evidence boundary

This note separates **source-backed facts** from **proposed operational steps**.

- **Source-backed facts** are cited to official Woodpecker documentation, official `woodpecker-ci/woodpecker` source paths for the deployed version, or this repository's committed manifests/scripts.
- **Proposed operational steps** are operator recommendations for a no-data-loss cutover. They are intentionally labeled as proposals, not first-party Woodpecker guarantees.
- I did **not** inspect or print live secret values, did **not** mutate Kubernetes resources, and did **not** deploy anything.

## Current repository-observed Woodpecker deployment

### Committed images and topology

- **Server image:** `woodpeckerci/woodpecker-server:v3.16.0`. Source: `tanka/lib/woodpecker.libsonnet` lines 20-35.
- **Server replicas:** `1`, with `Recreate` strategy. Source: `tanka/lib/woodpecker.libsonnet` lines 20-21.
- **Agent image:** `woodpeckerci/woodpecker-agent:v3.16.0`. Source: `tanka/lib/woodpecker.libsonnet` lines 136, 161-173.
- **Agent replicas:** `3`. Source: `tanka/lib/woodpecker.libsonnet` line 136.
- **Server data mount:** the server mounts PVC `woodpecker-data` at `/var/lib/woodpecker`. Source: `tanka/lib/woodpecker.libsonnet` lines 66-68.

### Committed persistent storage

- **PV name:** `kosmos-woodpecker`.
- **PV size:** `5Gi`.
- **Access mode:** `ReadWriteOnce`.
- **Reclaim policy:** `Retain`.
- **StorageClass:** `kosmos-static`.
- **Host path:** `/var/lib/kosmos-k3s/woodpecker`.
- **PVC name:** `woodpecker-data`, bound by `volumeName: kosmos-woodpecker`, request `5Gi`.

Source: `tanka/lib/storage.libsonnet` lines 37-64.

### Read-only live cluster observation

At planning time, local K3s reported the `woodpecker-agent` StatefulSet as `desired=1`, `ready=1`, `current=1`, with one running pod, `woodpecker-agent-0`. This differs from the committed manifest's `replicas: 3`; the live cluster has drifted or the manifest has not been applied. The migration baseline must therefore be chosen explicitly rather than assuming the committed value is live.

### Committed database configuration

**Exact repo-observable state:**

- The server imports environment variables from Kubernetes Secret `woodpecker-server-env` via `envFrom`, but the manifest does **not** set any `WOODPECKER_DATABASE_*` variables in plaintext. Source: `tanka/lib/woodpecker.libsonnet` line 35.
- The secret-sync path in this repo manages `/run/agenix/woodpecker-server-env` → `devops/woodpecker-server-env`. Source: `modules/wsl/secrets.nix` lines 56-61 and `docs/wsl-devops-runbook.md` lines 128-134.
- The sync script validates only `WOODPECKER_AGENT_SECRET`, `WOODPECKER_FORGEJO_CLIENT`, and `WOODPECKER_FORGEJO_SECRET`; it does **not** require or expose any `WOODPECKER_DATABASE_*` keys. Source: `scripts/sync-woodpecker-secret` lines 28-31, 38, 48.

**What this means:**

- From committed manifests alone, the deployment is **consistent with Woodpecker's container-default SQLite setup**: official v3.16 docs say the default driver is `sqlite3`, the container default datasource is `/var/lib/woodpecker/woodpecker.sqlite`, and SQLite in containers is expected to persist via a mounted data volume. Sources: Woodpecker v3.16 server docs, database section and env var reference. <https://woodpecker-ci.org/docs/3.16/administration/configuration/server>
- Because I did not inspect secrets, I cannot prove whether the live secret currently injects an out-of-band `WOODPECKER_DATABASE_DRIVER`/`WOODPECKER_DATABASE_DATASOURCE` override. The committed repo, however, does not declare one in plaintext.

## Official Woodpecker facts for the deployed version (v3.16)

### Supported database drivers and config names

- `WOODPECKER_DATABASE_DRIVER` is the database-driver setting; official v3.16 docs list possible values as `sqlite3`, `mysql`, and `postgres`, with default `sqlite3`. Source: <https://woodpecker-ci.org/docs/3.16/administration/configuration/server>
- `WOODPECKER_DATABASE_DATASOURCE` is the connection string setting; official v3.16 docs give the container default as `/var/lib/woodpecker/woodpecker.sqlite`. Source: <https://woodpecker-ci.org/docs/3.16/administration/configuration/server>
- `WOODPECKER_DATABASE_DATASOURCE_FILE` is also supported; official v3.16 docs say it reads the datasource from a file path. Source: <https://woodpecker-ci.org/docs/3.16/administration/configuration/server>
- The official v3.16 source wires the same settings as follows:
  - `WOODPECKER_DATABASE_DRIVER` → CLI flag `db-driver`, default `sqlite3`.
  - datasource value source order: `WOODPECKER_DATABASE_DATASOURCE_FILE` first, then `WOODPECKER_DATABASE_DATASOURCE`.
  - container default datasource path is returned by `datasourceDefaultValue()` as `/var/lib/woodpecker/woodpecker.sqlite` when `WOODPECKER_IN_CONTAINER` is present.

  Sources:
  - <https://github.com/woodpecker-ci/woodpecker/blob/v3.16.0/cmd/server/flags.go#L355-L370>
  - <https://github.com/woodpecker-ci/woodpecker/blob/v3.16.0/cmd/server/flags.go#L683-L690>

### PostgreSQL support details

- Official v3.16 docs show PostgreSQL configured with:
  - `WOODPECKER_DATABASE_DRIVER=postgres`
  - `WOODPECKER_DATABASE_DATASOURCE=postgres://...`
- Official v3.16 docs say to use **Postgres 11 or newer**.
- Official v3.16 docs say Woodpecker does **not** create the database automatically; operators must create it with `CREATE DATABASE`.

Source: <https://woodpecker-ci.org/docs/3.16/administration/configuration/server>

### Schema migration behavior

- Official v3.16 docs say Woodpecker **automatically handles database migration**, including initial table/index creation, and that new versions automatically upgrade the database unless release notes say otherwise. Source: <https://woodpecker-ci.org/docs/3.16/administration/configuration/server>
- Official v3.16 server startup source pings the datastore and then runs `store.Migrate(...)` during setup. Source: <https://github.com/woodpecker-ci/woodpecker/blob/v3.16.0/cmd/server/setup.go#L72-L95>
- Official v3.16 migration source shows `migration.Migrate(...)` will:
  - initialize schema when the old migrations table does not exist or is empty,
  - run xormigrate migrations,
  - then `syncAll(...)` models.

  Source: <https://github.com/woodpecker-ci/woodpecker/blob/v3.16.0/server/store/datastore/migration/migration.go#L83-L123>

### Backup / restore / export facts

- Official v3.16 docs explicitly say **Woodpecker does not perform database backups** and that backups should be handled by third-party tools from the selected database vendor. Source: <https://woodpecker-ci.org/docs/3.16/administration/configuration/server>
- In the official docs/source reviewed here, I found **schema migration support** but **no first-party documented SQLite→PostgreSQL data-export/import workflow**. Treat the cross-database copy as an external operator task, not a built-in Woodpecker migration feature. Evidence reviewed: the cited v3.16 server docs plus the cited server setup/migration source paths.

## Migration implications for this repository

### Source-backed implications

- The current repo layout matches the official container-default SQLite persistence model: mounted `/var/lib/woodpecker` plus no committed `WOODPECKER_DATABASE_*` override. Repo sources: `tanka/lib/woodpecker.libsonnet`, `tanka/lib/storage.libsonnet`. Official default behavior source: <https://woodpecker-ci.org/docs/3.16/administration/configuration/server>
- Because the server deployment uses **one replica** and `Recreate`, the repo already models Woodpecker as a single active server writer. Source: `tanka/lib/woodpecker.libsonnet` lines 20-21.
- The current secret sync **automatically rolls** the Woodpecker deployment and agents when `woodpecker-server-env` changes. Sources:
  - `docs/wsl-devops-runbook.md` lines 128-134
  - `scripts/sync-woodpecker-secret` lines 73-114

### Important consequence for cutover timing

If you add Postgres `WOODPECKER_DATABASE_*` values to the existing live `woodpecker-server-env` secret, this repo's secret-sync path will roll Woodpecker immediately. Therefore the secret change itself is effectively part of the cutover and must not happen until the target PostgreSQL database is ready and the maintenance window has begun.

## Proposed no-data-loss migration plan (operator-authored)

> This section is a proposal, not first-party Woodpecker documentation.

### 1. Rehearse the database copy off-line first

1. Provision an empty PostgreSQL database for Woodpecker.
2. Take a **copy** of the current SQLite database file from the persistent volume path after quiescing writes in a rehearsal environment.
3. Use an external SQLite→PostgreSQL copy method in a disposable rehearsal.
4. Start a disposable Woodpecker **v3.16.0** server against that copied PostgreSQL database and let its normal startup migrations run.
5. Verify users, repos, pipeline history, secrets metadata, and recent logs look complete before planning the live cutover.

Reasoning: Woodpecker provides schema migration, but the official docs/source reviewed here do not provide a first-party cross-database data-export/import tool.

### 2. Preserve the current agent count explicitly

- Record both values before the window: the committed manifest targets **3** agents, while the live cluster observation was **1** ready agent.
- Before migration, either reconcile the live StatefulSet to **3** and verify three ready agents, or deliberately make **1** the declared baseline in a separate change.
- Do not begin the migration while the source-of-truth decision is unresolved. Once the baseline is chosen, restore exactly that count after cutover.
- It is acceptable to scale agents down temporarily during the maintenance window; this is not the steady-state count.

### 3. Choose the secret-delivery method before cutover

Two supported Woodpecker config shapes exist in v3.16:

- `WOODPECKER_DATABASE_DRIVER=postgres` plus `WOODPECKER_DATABASE_DATASOURCE=...`
- `WOODPECKER_DATABASE_DRIVER=postgres` plus `WOODPECKER_DATABASE_DATASOURCE_FILE=/path/to/file`

Proposal for this repo:

- **Smallest change:** keep the current `envFrom` pattern and add `WOODPECKER_DATABASE_DRIVER` and `WOODPECKER_DATABASE_DATASOURCE` to the existing Woodpecker secret at cutover time.
- **More secret-hygienic option:** adopt `WOODPECKER_DATABASE_DATASOURCE_FILE`, but that requires a manifest change to mount the secret as a file because the current repo only injects `envFrom`.

In either case, do **not** print the DSN, commit plaintext credentials, or update the live secret early.

### 4. Safe cutover ordering

1. **Prepare PostgreSQL first**: create the database and validate network reachability from the cluster.
2. **Freeze new writes**: announce a maintenance window, stop new webhook-driven pipeline starts, and wait for active pipelines to finish.
3. **Scale agents down temporarily** (proposal: to `0`) so no new jobs start while the server is being switched.
4. **Stop the Woodpecker server** so the SQLite file becomes quiescent.
5. **Take a cold backup** of the SQLite database file / persistent-volume contents.
6. **Run the external SQLite→PostgreSQL copy** into the empty Postgres database.
7. **Update Woodpecker DB config** to `postgres` only after the copy has completed and validation checks pass.
8. **Start the server against PostgreSQL** and allow normal Woodpecker startup migrations to run.
9. **Verify the server first**, then restore the chosen baseline agent replica count.
10. **Re-enable incoming writes** only after verification succeeds.

### 5. Abort / rollback criteria

Abort the PostgreSQL cutover and return to SQLite **before re-enabling new builds** if any of the following occur:

- SQLite backup cannot be taken cleanly.
- The external copy reports errors or incomplete row transfer.
- Woodpecker server fails datastore ping or migration against PostgreSQL.
- Expected users, repos, pipeline history, cron state, or recent build logs are missing in spot checks.
- Agents do not reconnect cleanly after the server comes up.
- A fresh test pipeline cannot be scheduled and completed.

Rollback proposal:

- Revert Woodpecker DB config to the prior SQLite-backed settings.
- Restart the server on the original SQLite volume.
- Keep the PostgreSQL copy for later debugging, but do not accept writes there.

Important operational rule: once PostgreSQL has accepted new authoritative writes, rolling back to SQLite without reconciling those new writes creates a split-brain/data-loss risk. The safest rollback point is **before** new traffic is re-enabled.

### 6. Post-cutover verification checklist

1. Server pod becomes Ready and `/healthz` passes.
2. All baseline Woodpecker agent pods become Ready—3 if the repo target was reconciled first, otherwise 1 if the live count is deliberately retained.
3. Login through the forge still works.
4. Existing repositories are still visible.
5. Historical pipelines/build numbers/logs appear intact in spot checks.
6. A new test pipeline can be triggered, scheduled, run, and reported back successfully.
7. Keep the SQLite backup and original PV contents unchanged until the PostgreSQL-backed system has passed a soak period.

## Recommended conclusion

A no-data-loss migration is feasible, but **Woodpecker itself only supplies the schema-migration portion**. For this repo, the risky parts are the **external SQLite→PostgreSQL data copy** and the fact that the existing `woodpecker-server-env` secret-sync path will **immediately roll** Woodpecker when DB settings change. The safest approach is:

1. reconcile the committed/live agent-count drift before the migration window,
2. rehearse the copy off-line,
3. treat the secret update as the actual cutover switch,
4. take a cold SQLite backup after stopping writes,
5. bring the server up on PostgreSQL before restoring the chosen baseline agent count.

## Sources consulted

### Official Woodpecker documentation / source

- Woodpecker v3.16 server configuration docs: <https://woodpecker-ci.org/docs/3.16/administration/configuration/server>
- Official source, v3.16.0, DB flags/defaults: <https://github.com/woodpecker-ci/woodpecker/blob/v3.16.0/cmd/server/flags.go#L355-L370>
- Official source, v3.16.0, container datasource default: <https://github.com/woodpecker-ci/woodpecker/blob/v3.16.0/cmd/server/flags.go#L683-L690>
- Official source, v3.16.0, datastore setup/startup migrate: <https://github.com/woodpecker-ci/woodpecker/blob/v3.16.0/cmd/server/setup.go#L72-L95>
- Official source, v3.16.0, datastore migration flow: <https://github.com/woodpecker-ci/woodpecker/blob/v3.16.0/server/store/datastore/migration/migration.go#L83-L123>

### Repository sources inspected

- `tanka/lib/woodpecker.libsonnet`
- `tanka/lib/storage.libsonnet`
- `scripts/sync-woodpecker-secret`
- `modules/wsl/secrets.nix`
- `docs/wsl-devops-runbook.md`


## Current official upgrade options for the pinned versions (primary-source check)

- The repository is currently pinned to `woodpeckerci/woodpecker-{server,agent}:v3.16.0` and `codeberg.org/forgejo/forgejo:15.0.3-rootless`. Sources: `tanka/lib/woodpecker.libsonnet`, `tanka/lib/forgejo.libsonnet`.
- **Woodpecker release state:** at research time, Woodpecker's official latest release was `v3.18.0`, while `v3.17.0` is the immediately newer minor after the repo's pinned `v3.16.0`. Sources: <https://github.com/woodpecker-ci/woodpecker/releases/latest>, <https://github.com/woodpecker-ci/woodpecker/releases/tag/v3.18.0>, <https://github.com/woodpecker-ci/woodpecker/releases/tag/v3.17.0>.
- **Forgejo release state:** Forgejo's official docs currently label **Latest** as `v16.0.3` and **LTS** as `v15.0.7`, and the official container registry publishes both `15.0.7-rootless` and `16.0.3-rootless`. Sources: <https://forgejo.org/docs/latest/admin/installation/docker/>, <https://codeberg.org/forgejo/forgejo/releases.atom>, <https://codeberg.org/forgejo/-/packages/container/forgejo/versions>.
- **Official Woodpecker upgrade/backup guidance:** Woodpecker says new versions automatically upgrade the database unless release notes say otherwise, and Woodpecker does **not** perform database backups; backups must be handled separately by the selected database vendor/tooling. Source: <https://woodpecker-ci.org/docs/3.17/administration/configuration/server>.
- **Official Forgejo upgrade/backup guidance:** Forgejo's upgrade guide says to perform a **full backup before upgrading**; it treats that as a requirement for upgrades to a new stable release, recommends a synchronized point-in-time snapshot of **all** Forgejo storage as the reliable backup method, says multi-storage deployments may require shutting Forgejo down for a consistent backup, and warns that although `forgejo dump` can collect files and database into a zip, the SQL dump inside has long-standing reinjection bugs. Sources: <https://forgejo.org/docs/latest/admin/upgrade/>, <https://forgejo.org/docs/latest/admin/command-line/>.
- **Official Forgejo upgrade mechanics:** Forgejo says normal upgrades are done by replacing the binary or container image and letting the upgrade procedure handle migrations; it also says the database version is stored in the database specifically to prevent accidental downgrades. Sources: <https://forgejo.org/docs/latest/admin/upgrade/>.
- **Conservative recommendation for this repo:**
  - **Woodpecker:** because the PostgreSQL database is intentionally fresh, initialize the new deployment directly on `v3.18.0`; server and agents must use the same tag. Do not add a separate `v3.17.0` migration step. Source: <https://github.com/woodpecker-ci/woodpecker/releases/tag/v3.18.0>.
  - **Forgejo:** leave the current `15.0.3-rootless` deployment unchanged for this migration. Any Forgejo patch or major upgrade is a separate later change; the Forgejo PV and repository data are not reset.
- **Woodpecker v3.17 notes relevant here:** the official `v3.17.0` release notes include Kubernetes-agent/backend items (`Gate Kubernetes nodeSelector backend step config behind agent config`, `refactor: rework k8s utils to handle resource names and labels`, `Stamp trusted commit-branch and event pod labels`, `Use toLabelValue instead of toDNSName in Kubernetes step label`) and Forgejo-integration fixes (`fix(forgejo): treat 404 on empty repos as empty pull request list`, `Correct forge_id and org handling on user/repo`). Source: <https://github.com/woodpecker-ci/woodpecker/releases/tag/v3.17.0>.
- **Woodpecker v3.18 compatibility:** its official release notes rename `WOODPECKER_GRPC_VERIFY` to `WOODPECKER_GRPC_SKIP_VERIFY` and reject incompatible gRPC-protocol agents. This repo does not set the renamed variable, but server and all agents must be upgraded together, not independently. Source: <https://github.com/woodpecker-ci/woodpecker/releases/tag/v3.18.0>.
- **Reset / data-loss guardrails:** Woodpecker's own schema includes Woodpecker-side objects such as agents, pipelines, repos, secrets, users, and related metadata, so resetting the Woodpecker database can discard Woodpecker metadata/history/state. But that does **not** delete Forgejo-hosted Git repositories, because Forgejo stores repository data under its own repository root (`%(APP_DATA_PATH)s/gitea-repositories` in Forgejo 15 by default) and the rootless container uses Forgejo data under `/var/lib/gitea`. Therefore: resetting Woodpecker's DB is still a metadata-loss event, but **Forgejo data must not be reset unless explicitly authorized**. Sources: <https://github.com/woodpecker-ci/woodpecker/blob/v3.16.0/server/store/datastore/migration/migration.go>, <https://forgejo.org/docs/v15.0/admin/config-cheat-sheet/>, <https://forgejo.org/docs/v15.0/admin/installation/docker/>.

## Chosen fresh-PostgreSQL migration policy

This is the operator-approved variant of the proposal above. It intentionally does **not** copy the existing SQLite data.

### Service and agent sequence

- Keep the old SQLite PV at `/var/lib/kosmos-k3s/woodpecker` untouched as a rollback/archive artifact; do not delete or overwrite it during the cutover.
- Create the new PostgreSQL workload and initialize an empty `woodpecker` database.
- Start Woodpecker Server directly on `v3.18.0` with the new PostgreSQL database. The Server and Agent images must use the same `v3.18.0` tag.
- Keep the live agent baseline at **1** during the database cutover and initial reconfiguration. After PostgreSQL is healthy, the repositories and secrets have been recreated, and one complete test pipeline succeeds, scale the StatefulSet to **2** and verify `2/2 Ready`.
- The committed manifest currently says `replicas: 3`, while live K3s currently has `1/1`; the implementation must make the two-step target explicit rather than letting an apply silently change the count.

### PostgreSQL and agenix secret handling

- Generate PostgreSQL credentials once during provisioning using a cryptographically secure random hex password; do not derive them from the repository or print them in logs.
- Encrypt the generated environment with agenix as a new file, proposed name `secrets/woodpecker-postgres-env.age`. The plaintext payload should contain only the PostgreSQL bootstrap values and Woodpecker's server-side database settings, for example `POSTGRES_DB`, `POSTGRES_USER`, `POSTGRES_PASSWORD`, `WOODPECKER_DATABASE_DRIVER=postgres`, and `WOODPECKER_DATABASE_DATASOURCE`.
- The generation/encryption step is a one-time bootstrap operation, not a value regenerated on every NixOS switch. The encrypted `.age` file is the source of truth; declare it in `secrets.nix` and `modules/wsl/secrets.nix`, then sync a Kubernetes Secret before starting the new Server.
- Keep the PostgreSQL DSN in a server-only Kubernetes Secret or mounted datasource file. Do not add the DSN to the agent environment or to a checked-in manifest. The existing `WOODPECKER_AGENT_SECRET` remains the shared Server/Agent credential and must not be replaced by the database password.
- Do not put the existing Woodpecker `deployment` secret value into this document or Git. A Woodpecker database reset removes its stored secret. Before the reset, record only its scope/name and event allowlist; after the new Server is healthy, recreate/rotate the secret with name `deployment` and the same allowed events: `manual`, `push`, and `tag`. If the old value is not already held in an external secret source, the owner must provide a new value; Woodpecker cannot reveal a masked old value for automatic recovery.

### Fresh-Server reconfiguration inventory

After the new empty database starts, re-enable and test these repositories in Woodpecker:

- `GuionAI/flick-backend` — `fix (web): reply to block comment root`
- `GuionAI/slias-services` — `feat (payments): require approval cards for payment mutations (#82)`
- `GuionAI/document-service` — `MANUAL PIPELINE @ main`
- `GuionAI/flicknote-services` — `fix (gateway): route Ycloud webhook to Slias agent (#124)`
- `GuionAI/seafarer` — `MANUAL PIPELINE @ main`

For each repository, verify activation, Forgejo webhook delivery, branch/event filters, repository Secrets, and at least one representative pipeline. The listed commit/PR labels are the planning inventory, not a substitute for checking the current default branch after reset.

### Cutover order

1. Generate and encrypt the PostgreSQL secret; deploy the PostgreSQL workload and verify readiness.
2. Record the current Woodpecker/Forgejo endpoints and the one-agent baseline; take a cold backup of the old SQLite PV even though it will not be imported.
3. Stop new Woodpecker work, scale agents to `0`, and stop the old Server.
4. Apply the new Server configuration with Woodpecker `v3.18.0` and the PostgreSQL Secret; allow the empty database schema to initialize.
5. Verify Server health, Forgejo OAuth, repository activation, and the recreated `deployment` Secret.
6. Restore **1** agent and run a test pipeline.
7. Scale agents to **2**, verify `2/2 Ready`, and test one manual, one push, and one tag-triggered path where applicable.
8. Keep the old SQLite PV for the agreed retention period; schedule PostgreSQL backups before declaring the migration complete.
