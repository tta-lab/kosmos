# Hindsight

Hindsight 0.9.2 runs as one local k3s workload with its embedded pg0 database.
The canonical gateway and Kepos publish two distinct endpoints:

- API and MCP: `http://hindsight.localhost:17480`
- Control Plane: `http://hindsightui.localhost:17480`

The workload has no direct host ports. Caddy selects the API or UI by hostname,
and both Kepos service IDs allow only the named Mac subscriber. Hindsight has
no application API key because the local k3s network and that Mac-only Kepos
boundary are the intended trust model.

## LLM provider

The manifest owns the complete non-secret LLM policy:

- provider: `openai-responses`;
- base URL: `http://codex-bridge.localhost:17480/hindsight`;
- model: `gpt-5.6-luna`;
- reasoning effort: `xhigh`;
- retain and consolidation LLM timeout: 300 seconds per attempt;
- recall reranker: `rrf`.

The OpenAI SDK appends `/responses`, so requests reach the Bridge's fixed
`/hindsight/responses` route through the canonical Caddy gateway. The API-key value
in the manifest is deliberately a non-secret initializer placeholder. The
Bridge removes caller authorization and injects its own managed OAuth identity;
Hindsight has no OpenAI or DeepSeek credential.

Only the asynchronous retain and consolidation paths receive the longer
timeout. Their larger prompts can legitimately keep `luna` at `xhigh` busy for
more than Hindsight's 120-second global default; allowing them to finish avoids
paying for retries of the same request. Other LLM operations retain the global
default so an interactive failure cannot occupy a request for five minutes.

Outbound LLM traffic uses the Mihomo Pod endpoint from
`modules/wsl/proxy-topology.json`; cluster and loopback traffic bypass it.

## Deploy

NixOS owns the Hindsight data directory. Tanka owns the canonical gateway and
Kubernetes workloads. Deploy in this order:

```bash
nh os switch . -H wsl --ask
just codex-bridge-diff
just codex-bridge-deploy
just diff
just apply
just hindsight-diff
just hindsight-deploy
just hindsight-status
just kepos-policy-render
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
