# Hindsight

Hindsight 0.9.2 keeps its existing API, UI, LLM bridge, worker identity, and
RRF reranker. The migration adds a separately persisted PostgreSQL 18 service
with PGroonga 4.0.8 and pgvector 0.8.6, and runs a multilingual local
`sentence-transformers/paraphrase-multilingual-MiniLM-L12-v2` embedding model
on CPU. The model and database dependencies are baked into two local images;
the multilingual pod uses the fixed local Hindsight image, while the legacy pod
retains its official digest-pinned image and fixed-point pod template. The new
database and multilingual pods never download model or image artifacts at
runtime. The legacy pod's pg0 mount and configuration remain unchanged for
rollback availability.

The legacy Deployment still uses the fixed-point official image
`ghcr.io/vectorize-io/hindsight:0.9.2@sha256:84ab276b8f501546deb6ea9c64a57291718b4e16a59dd9e02a02fdd5adfe9028`
and leaves its pull policy and pod labels untouched.

The canonical gateway endpoints remain:

- API and MCP: `http://hindsight.localhost:17480`
- Control Plane: `http://hindsightui.localhost:17480`

The canonical `hindsight` Service is deliberately stage-dependent. During the
candidate stage it selects the retained embedded-pg0 deployment. The separate
`hindsight-candidate` Service selects the multilingual deployment for import
and evaluation. The final stage moves the canonical selector to the
multilingual deployment and leaves the legacy deployment scaled to zero for
rollback.

The non-secret LLM policy is unchanged: `openai-responses` through
`http://codex-bridge.localhost:17480/hindsight`, model `gpt-5.6-luna`, reasoning
effort `high`, 300-second operation timeout, and `rrf` reranking. The
`bridge-managed-oauth` value is only an initializer marker; the bridge supplies
the managed identity. Cluster and loopback destinations bypass the configured
Mihomo pod proxy.

## Images and storage

The image recipes are in `images/hindsight-postgres/` and `images/hindsight/`.
Their upstream bases are digest-pinned, and the rendered stack tag is currently
`0.1.0`. The manifests use these fully qualified local references:

- `localhost/kosmos/hindsight:0.1.0`
- `localhost/kosmos/hindsight-postgres:0.1.0`

A recipe change must bump that stack version in the image labels,
`scripts/build-hindsight-images`, and `tanka/lib/hindsight.libsonnet`; never
overwrite a tag already used by a deployment.

Build and inspect both images with rootless Podman:

```bash
just hindsight-images
```

When the images are ready to use in the single-node local k3s cluster, load
them into that cluster's containerd store. This is the only step that uses
elevation and it writes no registry:

```bash
just hindsight-images-load
```

The loader creates a private temporary directory, exports two OCI archives,
imports them with `sudo k3s ctr images import`, and removes only that directory.
Podman and Tanka use the same `localhost/kosmos/...` references, so no registry
or post-import retagging is needed.
The external database and multilingual manifests use `imagePullPolicy: Never`,
so this load must happen before applying either stage. The legacy Deployment
retains its fixed-point pull-policy behavior.

The old embedded database remains at
`/var/lib/kosmos-k3s/hindsight` and is mounted only by the legacy deployment.
The external database uses the separate retained directory
`/var/lib/kosmos-k3s/hindsight-postgres`, PostgreSQL PVC
`hindsight-postgres-data`, and StatefulSet `hindsight-postgres`. Both volumes
use `Retain`; neither is an off-host backup.

## Secrets and operator commands

Bootstrap the cluster-local database Secret once. The helper refuses any
non-local Kubernetes API server, generates a random password in a private
temporary file, creates `hindsight-database` in namespace `hindsight`, and
deletes the temporary file. Repeating it preserves the existing Secret. No
credential is stored in this repository.

```bash
just hindsight-candidate-secrets
```

The candidate and final stages each expose show, diff, apply, status, and logs
targets. All mutating targets retain the local-cluster guard (`https://127.0.0.1:26443`):

```bash
just hindsight-candidate-show
just hindsight-candidate-diff
just hindsight-candidate-apply
just hindsight-candidate-status
just hindsight-candidate-logs

just hindsight-final-show
just hindsight-final-diff
just hindsight-final-apply
just hindsight-final-status
just hindsight-final-logs

just hindsight-rollback
```

`hindsight-apply` and the historical `hindsight-*` targets remain aliases for
the safe candidate environment. Use the explicit final targets for a cutover.

## Candidate, migration, and cutover sequence

The following is the complete operator sequence. It prepares and verifies the
blue-green migration; it is intentionally not run by CI or by this change.

1. Build/load the pinned images and create the Secret:

   ```bash
   nh os switch . -H wsl --ask
   just hindsight-images-load
   just hindsight-candidate-secrets
   ```

   The currently observed source bank is `yuki-memory`; this is informational
   only. Never rely on a source-bank default. Set `BANK` explicitly before
   continuing. The guard below fails clearly when it is unset and keeps the
   candidate and final export evidence in one private directory:

   ```bash
   : "${BANK:?BANK must be set explicitly (currently observed source bank: yuki-memory)}"
   export CANDIDATE_BANK="${BANK}-candidate"
   umask 077
   export EVIDENCE_DIR="$PWD/hindsight-$BANK-$(date +%Y%m%d%H%M%S)"
   mkdir "$EVIDENCE_DIR"
   export CANDIDATE_ARCHIVE="$EVIDENCE_DIR/candidate-export.zip"
   export FINAL_ARCHIVE="$EVIDENCE_DIR/final-export.zip"
   ```

2. Render and inspect the candidate before applying it:

   ```bash
   just hindsight-candidate-show
   just hindsight-candidate-diff
   just hindsight-candidate-apply
   kubectl --kubeconfig=/etc/rancher/k3s/k3s.yaml -n hindsight \
     rollout status statefulset/hindsight-postgres --timeout=300s
   kubectl --kubeconfig=/etc/rancher/k3s/k3s.yaml -n hindsight \
     rollout status deployment/hindsight-multilingual --timeout=600s
   ```

   Candidate rendering keeps `deployment/hindsight` at one replica and keeps
   the canonical `hindsight` Service on it. The PostgreSQL and multilingual
   workloads are independently addressable through `hindsight-candidate`.

3. Export the source bank with Hindsight's official whole-bank command. Run the
   command in the legacy pod and copy the archive to an operator-owned,
   access-controlled directory; do not edit the pg0 volume or delete the pod.

   ```bash
   : "${BANK:?BANK must be set explicitly (currently observed source bank: yuki-memory)}"
   export CANDIDATE_BANK="${BANK}-candidate"
   export LEGACY_POD="$(kubectl --kubeconfig=/etc/rancher/k3s/k3s.yaml -n hindsight \
     get pod -l 'app.kubernetes.io/name=hindsight,app.kubernetes.io/part-of=kosmos-hindsight' \
     -o jsonpath='{.items[0].metadata.name}')"
   kubectl --kubeconfig=/etc/rancher/k3s/k3s.yaml -n hindsight \
     exec "$LEGACY_POD" -- \
     hindsight-admin export-bank --bank "$BANK" --output /tmp/hindsight-bank.zip
   kubectl --kubeconfig=/etc/rancher/k3s/k3s.yaml -n hindsight \
     cp "$LEGACY_POD:/tmp/hindsight-bank.zip" "$CANDIDATE_ARCHIVE"
   ```

   Inspect the archive manifest before import and retain it with the
   operator's migration evidence:

   ```bash
   unzip -p "$CANDIDATE_ARCHIVE" manifest.json | jq .
   unzip -p "$CANDIDATE_ARCHIVE" manifest.json | jq . >"$EVIDENCE_DIR/candidate-manifest.json"
   unzip -l "$CANDIDATE_ARCHIVE"
   ```

   The official export intentionally omits stored `embedding` and
   `search_vector` values. It carries bank-level counts such as
   `document_count`, `fact_count`, `observation_count`, and
   `mental_model_count`; those counts are the source side of the reconciliation
   below. Do not treat an archive containing old vectors as a valid migration
   input.

4. Import into the empty external database through the candidate pod. The
   import command recreates embeddings and derived search state (entities,
   links, and indexes) from the exported memories. It does not call retain,
   LLM fact extraction, consolidation, or webhooks.

   ```bash
   : "${BANK:?BANK must be set explicitly (currently observed source bank: yuki-memory)}"
   export MULTILINGUAL_POD="$(kubectl --kubeconfig=/etc/rancher/k3s/k3s.yaml -n hindsight \
     get pod -l 'app.kubernetes.io/name=hindsight,kosmos.tta-lab.org/role=multilingual' \
     -o jsonpath='{.items[0].metadata.name}')"
   kubectl --kubeconfig=/etc/rancher/k3s/k3s.yaml -n hindsight \
     cp "$CANDIDATE_ARCHIVE" "$MULTILINGUAL_POD:/tmp/hindsight-bank.zip"
   kubectl --kubeconfig=/etc/rancher/k3s/k3s.yaml -n hindsight \
     exec "$MULTILINGUAL_POD" -- \
     hindsight-admin import-bank --archive /tmp/hindsight-bank.zip --target-bank "$CANDIDATE_BANK"
   ```

   Keep the legacy service serving while this import and all candidate checks
   run. The temporary candidate bank keeps the canonical bank id free for the
   final import (the import command refuses an existing target bank). Capture
   the import summary and compare its bank-level counts with
   `manifest.json`. Then check for failed or pending operations and inspect the
   candidate bank stats:

   ```bash
   : "${BANK:?BANK must be set explicitly (currently observed source bank: yuki-memory)}"
   export CANDIDATE_BANK="${BANK}-candidate"
   export CANDIDATE_URL=http://127.0.0.1:18888
   kubectl --kubeconfig=/etc/rancher/k3s/k3s.yaml -n hindsight \
     port-forward service/hindsight-candidate 18888:8888
   ```

   Leave that port-forward running in one terminal, then run the checks in a
   second terminal:

   ```bash
   : "${BANK:?BANK must be set explicitly (currently observed source bank: yuki-memory)}"
   export CANDIDATE_BANK="${BANK}-candidate"
   export CANDIDATE_URL=http://127.0.0.1:18888
   curl --fail "$CANDIDATE_URL/v1/default/banks/$CANDIDATE_BANK/operations?status=pending"
   curl --fail "$CANDIDATE_URL/v1/default/banks/$CANDIDATE_BANK/operations?status=failed"
   curl --fail "$CANDIDATE_URL/v1/default/banks/$CANDIDATE_BANK/stats" | jq .
   ```

   Reconcile the manifest's documented counts against the imported bank's
   stats/import summary. Any failed or pending operation, count mismatch, or
   missing derived state stops the migration; leave the legacy Service active.

5. Generate a golden set locally from the exported bank, without committing
   personal memory text. Add one reviewed JSON object per line with `query`,
   `language` (`chinese`, `english`, or `mixed`), and
   `relevant_memory_texts`. Values must be copied exactly from the
   `RecallResult.text` fields returned by Hindsight. Memory-unit IDs are
   regenerated by each whole-bank import, so the same text-based set works for
   both candidate and final banks. The synthetic schema/example is
   `examples/hindsight-golden.example.jsonl`; the reviewed file belongs in a
   test-owned or operator-private path and remains untracked.

   Evaluate through the candidate Service (the port-forward above avoids any
   cluster-local DNS assumption):

   ```bash
   : "${BANK:?BANK must be set explicitly (currently observed source bank: yuki-memory)}"
   export GOLDEN=/secure/operator/path/hindsight-golden.jsonl
   python3 scripts/hindsight-recall-eval \
     --url "$CANDIDATE_URL" \
     --bank "$CANDIDATE_BANK" \
     --golden "$GOLDEN" \
     --top-k 5 \
     --format text
   ```

   The evaluator reports per-query hits, grouped Chinese/English/mixed
   Recall@K and MRR, and end-to-end p50/p95 latency. Acceptance requires every
   user-approved query to return a relevant top-K result and p95 no greater
   than one second. Failed/partial responses, malformed JSONL, missing
   relevance, or a p95 over 1000 ms return a non-zero status.

6. When the candidate gate passes, schedule a short write freeze. Stop all
   Hindsight writers, verify that no writes are in flight, and repeat the
   official export/import into a fresh empty canonical target bank. The
   candidate bank is deliberately suffixed and the canonical `$BANK` target is
   still absent, so the import contract's "target bank must not exist" guard is
   satisfied. Reconcile the source/import counts and pending/failed operations
   again, then rerun the reviewed golden set and latency gate. Do not skip this
   second export: it is what makes the final external bank match the frozen pg0
   source.

   ```bash
   : "${BANK:?BANK must be set explicitly (currently observed source bank: yuki-memory)}"
   : "${GOLDEN:?set GOLDEN to the reviewed text golden set before final evaluation}"
   test -n "${EVIDENCE_DIR:-}" && test -n "${FINAL_ARCHIVE:-}" || {
     echo 'set EVIDENCE_DIR and FINAL_ARCHIVE from step 1 before final export' >&2
     exit 1
   }
   # With writes stopped, repeat export and copy it to MULTILINGUAL_POD.
   kubectl --kubeconfig=/etc/rancher/k3s/k3s.yaml -n hindsight \
     exec "$LEGACY_POD" -- \
     hindsight-admin export-bank --bank "$BANK" --output /tmp/hindsight-bank-final.zip
   kubectl --kubeconfig=/etc/rancher/k3s/k3s.yaml -n hindsight \
     cp "$LEGACY_POD:/tmp/hindsight-bank-final.zip" "$FINAL_ARCHIVE"
   kubectl --kubeconfig=/etc/rancher/k3s/k3s.yaml -n hindsight \
     cp "$FINAL_ARCHIVE" "$MULTILINGUAL_POD:/tmp/hindsight-bank-final.zip"
   kubectl --kubeconfig=/etc/rancher/k3s/k3s.yaml -n hindsight \
     exec "$MULTILINGUAL_POD" -- \
     hindsight-admin import-bank --archive /tmp/hindsight-bank-final.zip --target-bank "$BANK"
   unzip -p "$FINAL_ARCHIVE" manifest.json | jq . >"$EVIDENCE_DIR/final-manifest.json"
   python3 scripts/hindsight-recall-eval \
     --url "$CANDIDATE_URL" \
     --bank "$BANK" \
     --golden "$GOLDEN" \
     --top-k 5 \
     --format text
   ```

   The suffixed candidate bank is disposable evaluation data. Remove it only
   after the rollback window with a separately reviewed cleanup operation; do
   not make cleanup part of the cutover.

7. Apply the final stage only after every gate passes:

   ```bash
   just hindsight-final-diff
   just hindsight-final-apply
   just hindsight-final-status
   curl --fail http://hindsight.localhost:17480/health
   curl --fail http://hindsightui.localhost:17480/
   ```

   Final rendering keeps the external StatefulSet and multilingual Deployment
   at one replica, moves the canonical Service selector to multilingual, and
   scales the legacy deployment to zero. It does not delete the legacy PVC,
   PV, or pg0 directory.

## Exact rollback

If health, relevance, latency, or operations checks fail, do not translate or
modify either retained database. Before final apply, simply leave the
candidate stage in place: the canonical Service still selects pg0. After a
final apply, run the local-cluster-guarded rollback target. It scales the
legacy deployment up and waits for it to become Available, replaces the entire
canonical selector with the exact legacy selector, verifies canonical health,
and only then scales the multilingual deployment down:

```bash
just hindsight-rollback
```

The retained pg0 copy remains the rollback source, and the new PostgreSQL
volume remains available for diagnosis. Removing the scaled-down legacy
objects or either host-directory declaration is deferred until the agreed
rollback window ends and requires a later cleanup change.

## Existing clients and verification

Nanocodex uses its configured Hindsight memory bank through the usual:

```text
http://hindsight.localhost:17480/mcp/<bank>/
```

The currently observed source bank is `yuki-memory`; the migration runbook
still requires the operator to set `BANK` explicitly rather than assuming it.

After switching the Home Manager generation, the `naco` Fish function includes
that MCP server and disables Nanocodex browser and cookie imports. The
candidate/final change does not alter this client contract or the codex-bridge
LLM route.

For repository-only verification, run:

```bash
just tanka-test
bash tests/hindsight-render-test
bash tests/init-hindsight-secrets-test
bash tests/hindsight-images-test
bash tests/hindsight-recall-eval-test
bash tests/hindsight-rollback-test
```

The full required Nix checks are `nix-instantiate --parse configuration.nix`,
`statix check .`, `nix --extra-experimental-features 'nix-command flakes' flake check`,
and the WSL system closure build. These checks do not contact a live bank or
Kubernetes cluster.
