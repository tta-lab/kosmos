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

Use it as the client header `Authorization: Bearer <master-key>`. Scoped
Meilisearch API keys remain the usual choice for applications. The trusted WSL
Codex for Love service below is an explicit exception: it receives the master
key through agenix at the operator's direction.

## Codex for Love FlickLog master key

`codex-for-love-prod.service` receives the shared Meilisearch URL and its
FlickLog master key only when `secrets/codex-for-love-prod.env.age` exists. The key is
decrypted for the service as `/run/agenix/codex-for-love-prod.env`; it must not
be added to a Home Manager file or a shell profile.

Fish reads the same agenix environment file, while Home Manager supplies
`FLICKLOG_MEILI_URL` as a session variable. A new Fish shell therefore also
gets both values for direct `flicklog` use without a second encrypted copy of
the master key.

Retrieve the master key interactively with the command in the preceding
section, then create the encrypted environment file:

```bash
agenix -e secrets/codex-for-love-prod.env.age
```

Its complete plaintext content is one line:

```text
FLICKLOG_MEILI_KEY=<Meilisearch master key>
```

After the encrypted file is committed and the WSL configuration is activated,
the production partner receives:

```text
FLICKLOG_MEILI_URL=http://meilisearch.localhost:17480/
FLICKLOG_MEILI_KEY=<master key from the agenix environment file>
```

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
