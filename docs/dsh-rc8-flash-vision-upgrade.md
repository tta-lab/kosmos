# DSH rc.8 + Flash Vision upgrade

**Checked:** 2026-08-22. Deployment procedure and primary-source evidence for Kosmos; no credentials are included.

## Conclusion

Upgrade the standalone runtime to the explicitly requested `@deepseek-ai/dsh@0.1.0-rc.8` using the fresh-staging/atomic-swap procedure in [`dsh-deployment.md`](dsh-deployment.md). Do not change the systemd unit, secret handling, Kepos exposure, or MCP executable setup. Add the model rows below to the existing immutable `modules/wsl/deepseek-harness-mcp.cordis.yml`; the same `--patch` overlay can carry both MCP and model configuration.

DeepSeek’s current official Models & Pricing page still lists the exact model ID **`deepseek-v4-flash-vision-exp`** and describes it as experimental with image input. The current Vision guide says it is the only vision model, accepts images in user messages, and uses the OpenAI-compatible image content format. [Models & Pricing](https://api-docs.deepseek.com/quick_start/pricing) · [Vision](https://api-docs.deepseek.com/guides/vision)

The smallest safe model overlay is an **id-targeted replacement** (not another `insert`; DSH replaces a matched row’s whole `config`, so the catalog must retain both existing models):

```yaml
- id: agent-default-model
  config:
    provider: deepseek-official
    model: deepseek-v4-flash-vision-exp

- id: llm-deepseek
  config:
    models:
      - id: deepseek-v4-flash
        name: DeepSeek-V4-Flash
        contextWindow: 1000000
      - id: deepseek-v4-pro
        name: DeepSeek-V4-Pro
        contextWindow: 1000000
      - id: deepseek-v4-flash-vision-exp
        name: DeepSeek-V4-Flash-Vision-Exp
        inputModalities: [text, image]
```

This makes the vision model selectable and the default for newly resolved agents without forcing a user’s saved model selection. The explicit `inputModalities` row is required: rc.8’s DeepSeek adapter treats omitted/unlisted models as text-only before attachment or network work. [rc.8 `llm-deepseek` source](https://github.com/deepseek-ai/deepseek-harness/blob/dsh-v0.1.0-rc.8/packages/llm/llm-deepseek/src/index.ts) · [rc.8 provider README](https://github.com/deepseek-ai/deepseek-harness/blob/dsh-v0.1.0-rc.8/packages/llm/llm-deepseek/README.md) · [rc.8 default-model README](https://github.com/deepseek-ai/deepseek-harness/blob/dsh-v0.1.0-rc.8/packages/core/agent-default-model/README.md)

## Verified facts and risks

- npm publishes `@deepseek-ai/dsh@0.1.0-rc.8`; tarball integrity is `sha512-VQU5NlomrKLRgcXuOf+sxWFvqxPA8q9vMhrKPlPPXiOJEhGlGlAdiyxZvZxkCVI+v0zbhe21cY3/luLyxpSzzA==`. The registry’s current `latest` tag is newer (`0.1.1-rc.2`), so use rc.8 exactly for this reference-compatible target rather than following `latest`. [npm registry metadata](https://registry.npmjs.org/@deepseek-ai/dsh)
- The official DSH rc.7 and rc.8 source revisions are [`dsh-v0.1.0-rc.7`](https://github.com/deepseek-ai/deepseek-harness/tree/dsh-v0.1.0-rc.7) and [`dsh-v0.1.0-rc.8`](https://github.com/deepseek-ai/deepseek-harness/tree/dsh-v0.1.0-rc.8). The MCP client `index.ts` and `transport.ts` are unchanged between those revisions: Kosmos’s `stdio`, `command`, `args`, `cwd`, and non-secret `env` rows remain compatible. The rc.8 client still requires valid `serverName`/`transport` rows and starts the existing host-managed children; it does not install them. [MCP README](https://github.com/deepseek-ai/deepseek-harness/blob/dsh-v0.1.0-rc.8/packages/mcp/mcp-client/README.md) · [MCP source](https://github.com/deepseek-ai/deepseek-harness/blob/dsh-v0.1.0-rc.8/packages/mcp/mcp-client/src/index.ts) · [transport source](https://github.com/deepseek-ai/deepseek-harness/blob/dsh-v0.1.0-rc.8/packages/mcp/mcp-client/src/transport.ts)
- DSH remains a developer preview. The main residual risk is the whole dependency tree changing during a fresh install, plus any existing user `llm-deepseek` settings override replacing this catalog. Treat the immutable overlay as the source of truth and verify the effective composition in a test-owned `DSH_HOME`; do not use the remote Web settings plane.
- Documentation availability is not account entitlement. DeepSeek’s official `GET /models` endpoint is the account/endpoint availability check. [Lists Models](https://api-docs.deepseek.com/api/list-models)

## Proposed staging and verification

Perform deployment in this order. First update the tracked immutable overlay with the two rows above, but **stage and validate rc.8 before activating that overlay**: the present rc.7 adapter is text-only and rejects image content.

```bash
npm view @deepseek-ai/dsh@0.1.0-rc.8 version dist.integrity dist.tarball
mkdir -p /home/neil/.local/share/dsh-runtime.new
cd /home/neil/.local/share/dsh-runtime.new
bun add --exact @deepseek-ai/dsh@0.1.0-rc.8
bun pm trust --all
node -e "console.log(require('./node_modules/@deepseek-ai/dsh/package.json').version)"
node -e "require('koffi')"
```

Before swapping, validate the changed overlay against the staging tree using a disposable home, not the live `DSH_HOME`:

```bash
tmp_home="$(mktemp -d)"
DSH_HOME="$tmp_home" \
  node /home/neil/.local/share/dsh-runtime.new/node_modules/@deepseek-ai/dsh/lib/bin.js \
  --profile web \
  --patch "$PWD/modules/wsl/deepseek-harness-mcp.cordis.yml" \
  --dump-config \
  | grep -E 'agent-default-model|llm-deepseek|deepseek-v4-flash-vision-exp|inputModalities'
rm -rf "$tmp_home"
```

Then use the documented atomic swap while the deployed Nix overlay is still the old MCP-only one, restart `dsh`, and confirm the normal service/MCP checklist. With rc.8 now active, run the repository checks and activate the changed immutable overlay (normally after its branch/PR has merged):

```bash
nix-instantiate --parse configuration.nix
statix check .
nix --extra-experimental-features 'nix-command flakes' flake check
nh os switch . -H wsl --ask
```

After activation, re-run `systemctl --user is-active dsh`, `ss -tlnp | grep 3080`, `pgrep -af 'flicknote mcp|miniflux-mcp'`, and recent `journalctl --user -u dsh`, then open a **new** Web session to confirm MCP discovery and the vision-model default. Existing sessions and a saved local model selection can retain the prior model. A real API smoke test should use a user-supplied key without logging it; `/models` can confirm account availability before sending a small test image.

The final deployment decision is therefore: **pin and stage rc.8; add exactly the two id-targeted rows above; preserve the existing MCP rows and service boundary; deploy the runtime before the new overlay; then verify effective configuration and both MCP children.**
