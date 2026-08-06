# Hindsight

Hindsight 0.8.6 runs as one local k3s workload with its embedded pg0 database.
The API and MCP endpoint are available only at `http://127.0.0.1:8888`; the
control-plane UI is available only at `http://127.0.0.1:9999`.

## Secret

Agents must not read or decrypt the LLM key. Create or replace the encrypted
secret interactively:

```bash
agenix -e secrets/hindsight-env.age -i ~/.ssh/agenix_ed25519
```

Enter exactly one env-file line:

```text
HINDSIGHT_API_LLM_API_KEY=<DeepSeek API key>
```

Validate the encrypted file without printing the key:

```bash
agenix -d secrets/hindsight-env.age -i ~/.ssh/agenix_ed25519 \
  | bash scripts/sync-hindsight-secret --validate-only -
```

The manifest owns the non-secret policy: DeepSeek, `deepseek-v4-flash`, and the stable
worker ID `hindsight`. The NixOS unit synchronizes only the validated key into
the local `hindsight/hindsight-env` Kubernetes Secret.

Outbound LLM traffic uses the Mihomo listener exposed to Pods at
`10.42.0.1:7890`; cluster and loopback traffic bypasses it.

## Deploy

NixOS owns the retained host directory and agenix Secret synchronization.
Tanka owns the Kubernetes workload. Deploy in this order:

```bash
nh os switch . -H wsl --ask
sudo systemctl restart hindsight-secret-sync.service
sudo systemctl status hindsight-secret-sync.service --no-pager
just hindsight-diff
just hindsight-deploy
just hindsight-status
```

The first image pull is large. The image is pinned to the signed Hindsight
0.8.6 multi-architecture digest and already contains its default embedding and
reranker models. Offline model flags prevent runtime model drift; do not mount
an empty volume over `/home/hindsight/.cache/huggingface`.

## Verify

```bash
curl --fail http://127.0.0.1:8888/health
curl --fail http://127.0.0.1:9999/
just hindsight-logs
```

Nanocodex uses the personal `hermes` memory bank through:

```text
http://localhost:8888/mcp/hermes/
```

After switching the Home Manager generation, the `naco` Fish function includes
that MCP server and disables Nanocodex browser and cookie imports.

## Storage and upgrades

Embedded pg0 data is retained at `/var/lib/kosmos-k3s/hindsight`. The PV uses
the `Retain` reclaim policy, but the directory remains on the WSL virtual disk
and is not an off-host backup. Stop the deployment before copying or restoring
it.

The default local embedding model is English-focused. Changing the embedding
provider or model after storing memories requires an explicit migration and
re-embedding plan; do not change it as a routine image upgrade.
