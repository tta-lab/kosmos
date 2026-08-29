# Hindsight

Hindsight 0.9.2 runs as one local k3s workload with its embedded pg0 database.
The canonical gateway and Kepos publish two distinct endpoints:

- API and MCP: `http://hindsight.localhost:17480`
- Control Plane: `http://hindsightui.localhost:17480`

The workload has no direct host ports. Caddy selects the API or UI by hostname,
and both Kepos service IDs allow only the named Mac subscriber. Hindsight has
no application API key because the local k3s network and that Mac-only Kepos
boundary are the intended trust model.

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

The manifest owns the non-secret policy: DeepSeek, `deepseek-v4-flash`, the
fast RRF recall reranker, and the stable worker ID `hindsight`. The NixOS unit
synchronizes only the validated key into
the local `hindsight/hindsight-env` Kubernetes Secret.

Outbound LLM traffic uses the Mihomo Pod endpoint from
`modules/wsl/proxy-topology.json`; cluster and loopback traffic bypass it.

## Deploy

NixOS owns the retained host directory and agenix Secret synchronization.
Tanka owns the canonical gateway and Kubernetes workload. Deploy in this order:

```bash
nh os switch . -H wsl --ask
sudo systemctl restart hindsight-secret-sync.service
sudo systemctl status hindsight-secret-sync.service --no-pager
just diff
just apply
just hindsight-diff
just hindsight-deploy
just hindsight-status
just kepos-status
```

The first image pull is large. The image is pinned to the signed Hindsight
0.9.2 multi-architecture digest and already contains its default embedding and
reranker models. Offline model flags prevent runtime model drift; do not mount
an empty volume over `/home/hindsight/.cache/huggingface`.

## Verify

```bash
curl --fail http://hindsight.localhost:17480/health
curl --fail http://hindsightui.localhost:17480/
just hindsight-logs
```

Nanocodex uses the personal `hermes` memory bank through:

```text
http://hindsight.localhost:17480/mcp/hermes/
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
