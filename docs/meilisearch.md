# Meilisearch

The local K3s instance runs the official `getmeili/meilisearch` image as a
single-replica Deployment in the `meilisearch` namespace. Its data is retained
at `/var/lib/kosmos-k3s/meilisearch/data` through the static
`meilisearch-data` PVC.

Meilisearch is available to trusted local clients at
`http://meilisearch.localhost:17480`. Kepos publishes that host only to the
`mac` peer, which reaches it through its usual subscriber gateway at the same
URL. The service is plaintext inside the authenticated Kepos network, so send
the master key only in an HTTPS-equivalent trusted-client context.

## Master key

`just meilisearch-secrets` generates a random 64-hex-character master key only
when `meilisearch/meilisearch-master-key` does not already exist. It never
prints the value and Tanka never renders a Secret.

To intentionally retrieve it for a client, run this command interactively on
the WSL host. Do not paste its output into shell history, source control, or
logs:

```bash
KUBECONFIG=/etc/rancher/k3s/k3s.yaml \
  kubectl get secret meilisearch-master-key -n meilisearch \
  -o jsonpath='{.data.MEILI_MASTER_KEY}' | base64 --decode; echo
```

Use it as the client header `Authorization: Bearer <master-key>`. Create
scoped Meilisearch API keys for applications instead of distributing the
master key.

## Operations

```bash
just meilisearch-show
just meilisearch-diff
just meilisearch-deploy
just meilisearch-status
```

`meilisearch-deploy` initializes the key if necessary, applies the workload,
updates the canonical gateway and CoreDNS route, verifies the Deployment and
health endpoint, then atomically renders the Kepos policy.
