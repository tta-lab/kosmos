# Hindsight

Kosmos runs Hindsight 0.9.2 in the local k3s cluster with one API Deployment
and one external PostgreSQL StatefulSet. The API uses PGroonga for keyword
search, pgvector for vectors, and the multilingual
`sentence-transformers/paraphrase-multilingual-MiniLM-L12-v2` embedding model
on CPU. The embedding model is baked into the application image and loaded
from a local path, so pod startup does not depend on Hugging Face.

The canonical endpoints are:

- API: `http://hindsight.localhost:17480`
- UI: `http://hindsightui.localhost:17480`

## Runtime

The steady-state resources are rendered by
`tanka/environments/hindsight`:

- Deployment `hindsight-multilingual`
- Service `hindsight`
- StatefulSet and Service `hindsight-postgres`
- retained static PV/PVC backed by
  `/var/lib/kosmos-k3s/hindsight-postgres`

The application image is `localhost/kosmos/hindsight:0.1.1`. The PostgreSQL
image is `localhost/kosmos/hindsight-postgres:0.1.1` and contains PostgreSQL
18, PGroonga 4.0.8, and pgvector 0.8.6. Both use `imagePullPolicy: Never`, so
they must be loaded into k3s before apply.

The database Secret is generated once by `scripts/init-hindsight-secrets`.
The script refuses a non-local Kubernetes API, never replaces an existing
Secret, and does not print credentials. Tanka intentionally does not render
the Secret.

## Deploy

Build, test, load, and apply the complete workload:

```bash
just hindsight-deploy
```

Or inspect and apply the pieces explicitly:

```bash
just hindsight-images
just hindsight-images-load
just hindsight-show
just hindsight-diff
just hindsight-apply
just hindsight-status
```

The local-cluster guard requires the API server to be exactly
`https://127.0.0.1:26443`. Apply the WSL tmpfiles ownership declaration after
changing `modules/wsl/k3s.nix`:

```bash
nh os switch . -H wsl --ask
```

Verify the observable service after deployment:

```bash
KUBECONFIG=/etc/rancher/k3s/k3s.yaml \
  kubectl -n hindsight rollout status deployment/hindsight-multilingual --timeout=300s
KUBECONFIG=/etc/rancher/k3s/k3s.yaml \
  kubectl -n hindsight rollout status statefulset/hindsight-postgres --timeout=300s
curl --fail http://hindsight.localhost:17480/health
curl --fail http://hindsightui.localhost:17480/ >/dev/null
```

Logs are available with `just hindsight-logs`.

## Recall check

`scripts/hindsight-recall-eval` sends read-only recall requests for a reviewed
JSONL golden set. Each record contains `query`, one of the language categories
`chinese`, `english`, or `mixed`, and a non-empty
`relevant_memory_texts` array. The gate requires all categories, a relevant
top-5 result for every query, and p95 latency no greater than 1000 ms.

```bash
scripts/hindsight-recall-eval \
  --url http://hindsight.localhost:17480 \
  --bank BANK_ID \
  --golden /private/path/recall-golden.jsonl
```

Keep golden sets private when they contain memory text.

## Backup

Create a PostgreSQL custom-format dump in a private directory. The archive
contains all Hindsight memories and must be handled as a secret.

```bash
hindsight_backup_dir=/home/neil/backups/hindsight
hindsight_dump_name="hindsight-$(date -u +%Y%m%dT%H%M%SZ).dump"
hindsight_dump="$hindsight_backup_dir/$hindsight_dump_name"
hindsight_pod_dump="/tmp/$hindsight_dump_name"

install -d -m 0700 "$hindsight_backup_dir"
KUBECONFIG=/etc/rancher/k3s/k3s.yaml \
  kubectl -n hindsight exec hindsight-postgres-0 -- sh -c \
    'exec pg_dump -Fc --no-password --username="$POSTGRES_USER" --dbname="$POSTGRES_DB"' \
    > "$hindsight_dump"
chmod 0600 "$hindsight_dump"
KUBECONFIG=/etc/rancher/k3s/k3s.yaml \
  kubectl -n hindsight cp "$hindsight_dump" \
    "hindsight-postgres-0:$hindsight_pod_dump"
KUBECONFIG=/etc/rancher/k3s/k3s.yaml \
  kubectl -n hindsight exec hindsight-postgres-0 -- \
    pg_restore --list "$hindsight_pod_dump" >/dev/null
KUBECONFIG=/etc/rancher/k3s/k3s.yaml \
  kubectl -n hindsight exec hindsight-postgres-0 -- \
    rm -- "$hindsight_pod_dump"
(
  cd "$hindsight_backup_dir"
  sha256sum "$hindsight_dump_name" > "$hindsight_dump_name.sha256"
)
chmod 0600 "$hindsight_dump.sha256"
```

Copy the dump and checksum to separate protected storage. A backup on the same
WSL filesystem does not protect against host or disk loss.

Before any restore, stop all Hindsight writers, take a safety backup, validate
the selected dump, and use `pg_restore --clean --if-exists --no-owner
--exit-on-error --single-transaction`. A restore is an operator-run recovery
procedure, not part of normal deployment.

## Verification

Run the smallest repository checks for this workload:

```bash
just tanka-test
bash tests/hindsight-render-test
bash tests/init-hindsight-secrets-test
bash tests/hindsight-images-test
bash tests/hindsight-recall-eval-test
git diff --check
```
