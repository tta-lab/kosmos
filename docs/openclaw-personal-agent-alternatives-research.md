# OpenClaw alternatives for a single long-term companion agent

Research date: 2026-08-28. This is a primary-source comparison of self-hosted
projects for one personal agent: reliable tool loop, MCP, a small scheduler,
vision input, TTS, a genuinely usable phone surface, and *passive* long-term
memory. “Mobile” means either an installable PWA or a real mobile chat client;
it does not mean merely that a desktop page happens to render on a narrow
screen.

## Recommendation

**Pilot Hermes Agent first, with Telegram or WhatsApp as the mobile client and
Hindsight as its external memory provider.** It is the closest direct replacement: its
official documentation describes a learning loop that writes curated memory,
searches past sessions, and models the user; it also has MCP, cron delivery to
the messaging channels, image/vision routing, and TTS. Most importantly for
passive memory, its eight memory-provider plugins do pre-turn recall and
post-turn/session-end persistence automatically — not merely “an MCP tool the
model might remember to call.” [Hermes README](https://github.com/NousResearch/hermes-agent/blob/306db2776c6b6f1acc85c31c4dabba3263f0e9fd/README.md#L19-L29)
· [memory providers](https://hermes-agent.nousresearch.com/docs/user-guide/features/memory-providers)
· [mobile messaging](https://hermes-agent.nousresearch.com/docs/user-guide/messaging).

Use **Open WebUI** instead if release maturity and a polished installable PWA
matter more than a companion-native agent runtime. It meets every requested
surface in one product, has the oldest/most established core here, and has good
extension seams; its personal-memory automation is less purpose-built than
Hermes’s. [Open WebUI features](https://github.com/open-webui/open-webui/blob/d3e8bf3405e848cfba377814d0aa7ba7290e414d/README.md#L36-L56)

Neither recommendation needs subagents or multiple agent personas. Keep one
persona/profile, enable only the required tools/MCP servers, and leave
delegation features off. A single enduring conversation is a product/config
choice, rather than a reason to retain OpenClaw’s multi-session topology.

## Capability matrix

| Project | Single-agent loop and passive memory | MCP and schedule | Image input / TTS | Mobile surface | Stability assessment |
|---|---|---|---|---|---|
| **Hermes Agent** | Purpose-built learning loop: agent-curated `MEMORY.md`/`USER.md`, automatic saves, FTS5 session search, periodic learning nudges. Eight optional external-memory providers, including self-hostable OpenViking, Mem0 OSS, Hindsight local, and local SQLite Holographic. | stdio, HTTP, and OAuth HTTP MCP; built-in cron with channel delivery. | Messaging-channel photos reach vision models as pixels (or are described for text-only models); TTS and STT are supported on the messaging platforms. | Telegram, WhatsApp, Signal, Discord, Slack are the phone apps. This is the strongest real-phone UX; no separate web app is needed. | **Young but feature-complete.** Created 2025-07-22; it ships frequent date-versioned releases. Its large and fast-moving public issue/PR queue means a pinned pilot is prudent. |
| **Open WebUI** | Built-in persistent memories across conversations; a background-review option exists but defaults off. Vector knowledge bases are separate from personal facts. | MCP/MCPO/OpenAPI servers; recurring prompt automations and calendar. | Officially supports file/image upload for model analysis, plus multiple TTS/STT engines. | Responsive PWA, installable on iOS/Android. | **Most mature core.** Created 2023-10-06; broad deployment base. It is also a very large, rapidly evolving product: read upgrade notes and back up DB before schema migrations. |
| **Moltis** | Built-in `MEMORY.md` plus searchable session exports; auto/explicit user-profile writing; hybrid vector + FTS backends. | stdio and remote MCP; built-in cron. | Rust source has multimodal user content, web image-input and vision tests; built-in TTS/STT providers. | iOS/Android-installable PWA with push notifications. | **Very young, feature-rich.** Created 2026-01-29, with near-daily releases. It is a promising direct OpenClaw-style server, but too new to make the stability-first default. |
| **AnythingLLM** | Good document/RAG memory (workspace vector DB) and on-device mobile RAG, but not an equally strong automatic relationship-memory loop. | MCP plus agentic cron jobs. | Built-in TTS. Official material checked documents image *generation* but did not establish chat image-to-model input; treat that as a blocker until a release-specific smoke test proves it. | Actual Android app (Google Play/APK); iOS is explicitly not supported yet. Mobile must sync to a server for custom MCP/tools. | **Mature general app.** Created 2023-06-04, stable 1.x releases. Best if Android is sufficient and vision can be verified, not the first companion pick. |
| **nanobot** | Small, readable tool loop and memory, but no verified passive external-memory integration. | MCP and cron/one-off automations. | WebUI accepts images and voice input; no official TTS-output support found (only STT). | Mobile-optimized WebUI or familiar chat apps. | **Minimal baseline**, but fails the TTS requirement without an add-on. |
| **LibreChat** | Mature chat/agent application, but memory is not as companion-specific. | MCP; a schedules engine exists but is still new/RC-level. | Image analysis and TTS/STT. | Responsive CSS only; no official PWA/native-app commitment found. | Viable desktop-first fallback, not the strongest phone-first choice. |

### Evidence by project

- **Hermes:** its README explicitly calls out the learning loop, channel gateway,
  cron, and OpenClaw migration; it also imports `SOUL.md`, `MEMORY.md`,
  `USER.md`, skills, and TTS assets. [README](https://github.com/NousResearch/hermes-agent/blob/306db2776c6b6f1acc85c31c4dabba3263f0e9fd/README.md#L19-L29)
  · [migration](https://github.com/NousResearch/hermes-agent/blob/306db2776c6b6f1acc85c31c4dabba3263f0e9fd/README.md#L187-L211).
  The official memory page specifies bounded, agent-managed memory and session
  search; the provider page specifies automatic context injection, async
  prefetch/turn sync, session-end extraction, and mirrored writes for an active
  provider. [memory](https://hermes-agent.nousresearch.com/docs/user-guide/features/memory)
  · [providers](https://hermes-agent.nousresearch.com/docs/user-guide/features/memory-providers).
  MCP, cron, vision and TTS are respectively documented
  [here](https://hermes-agent.nousresearch.com/docs/user-guide/features/mcp),
  [here](https://hermes-agent.nousresearch.com/docs/user-guide/features/cron),
  [here](https://hermes-agent.nousresearch.com/docs/user-guide/features/vision),
  and [here](https://hermes-agent.nousresearch.com/docs/user-guide/features/tts).

- **Open WebUI:** its maintained feature list explicitly states MCP, persistent
  memory, recurring automations, PWA, and multiple STT/TTS engines.
  [README](https://github.com/open-webui/open-webui/blob/d3e8bf3405e848cfba377814d0aa7ba7290e414d/README.md#L36-L56)
  · [image analysis](https://docs.openwebui.com/features/)
  · [automations](https://docs.openwebui.com/features/chat-conversations/chat-features/automations/)
  · [PWA installation](https://docs.openwebui.com/getting-started/open-webui-as-app/).
  The current code exposes an API at `/api/v1/memories`; it also has
  `ENABLE_MEMORY_BACKGROUND_REVIEW` (default `False`) and a ten-turn default
  review interval, so passive extraction needs an intentional opt-in.
  [memory config](https://github.com/open-webui/open-webui/blob/d3e8bf3405e848cfba377814d0aa7ba7290e414d/backend/open_webui/config.py#L423-L428)
  · [memory API](https://github.com/open-webui/open-webui/blob/d3e8bf3405e848cfba377814d0aa7ba7290e414d/backend/open_webui/main.py#L846-L851).

- **Moltis:** its README lists a dedicated agent-loop crate, PWA with push,
  MCP, cron, voice I/O and long-term memory.
  [README](https://github.com/moltis-org/moltis/blob/fee006b78a370fed9d9a33e38ec150424ef4887d/README.md#L79-L131).
  Its memory docs specify session export, hybrid built-in storage, auto profile
  writes and optional QMD/Zvec backends; this is enough for personal memory
  without a separate server. [memory](https://github.com/moltis-org/moltis/blob/fee006b78a370fed9d9a33e38ec150424ef4887d/docs/src/memory.md)
  · [MCP](https://github.com/moltis-org/moltis/blob/fee006b78a370fed9d9a33e38ec150424ef4887d/docs/src/mcp.md)
  · [PWA](https://github.com/moltis-org/moltis/blob/fee006b78a370fed9d9a33e38ec150424ef4887d/docs/src/mobile-pwa.md)
  · [voice](https://github.com/moltis-org/moltis/blob/fee006b78a370fed9d9a33e38ec150424ef4887d/docs/src/voice.md).

- **AnythingLLM:** its official README links scheduled tasks, MCP and TTS,
  while its official Android source/docs confirm the native client and make the
  server-sync restriction explicit. [README](https://github.com/Mintplex-Labs/anything-llm/blob/35c58d89907e675a8c4fb10544c19be0f050f611/README.md#L59-L75)
  · [TTS](https://github.com/Mintplex-Labs/anything-llm/blob/35c58d89907e675a8c4fb10544c19be0f050f611/README.md#L149-L155)
  · [mobile source](https://github.com/Mintplex-Labs/anythingllm-mobile/blob/1282a8c70f338cc33b070a5a51b3cfb89bbdf2d0/README.md#L38-L79)
  · [mobile docs](https://github.com/Mintplex-Labs/anythingllm-docs/blob/9c536021ae62548d1bd45d0e0e8143238005e49c/pages/mobile/overview.mdx#L16-L27)
  · [MCP docs](https://github.com/Mintplex-Labs/anythingllm-docs/blob/9c536021ae62548d1bd45d0e0e8143238005e49c/pages/mcp-compatibility/overview.mdx#L22-L40)
  · [cron builder](https://github.com/Mintplex-Labs/anythingllm-docs/blob/9c536021ae62548d1bd45d0e0e8143238005e49c/pages/scheduled-jobs/scheduling.mdx#L9-L23).

- **nanobot:** the project describes its small core agent loop, MCP, cron,
  chat platforms and mobile-oriented WebUI in its official README; its own
  automation and WebUI docs establish scheduling and image/voice input.
  [README](https://github.com/HKUDS/nanobot/blob/559b2d2e5dfbd94cdb0854ee40fab0c32c327e7f/README.md#L37-L68)
  · [automations](https://github.com/HKUDS/nanobot/blob/559b2d2e5dfbd94cdb0854ee40fab0c32c327e7f/docs/automations.md)
  · [WebUI](https://github.com/HKUDS/nanobot/blob/559b2d2e5dfbd94cdb0854ee40fab0c32c327e7f/docs/webui.md).

## Passive memory and a <=10k LOC extension boundary

An MCP memory server by itself is **not** passive memory: the model can skip a
`search`/`remember` tool call. A companion needs both retrieval before a turn
and persistence after a turn, with an inspectable/deleteable source of truth.

- **Hermes is the only evaluated *companion-native* option that already supplies
  this lifecycle for external OSS memory.** Select one provider in `hermes memory setup`; for a
  self-hosted stack, choose OpenViking, Mem0 OSS, local Hindsight, or
  Holographic. No add-on is required. A small custom provider plugin is a
  reasonable <=10k-LOC task if those eight are insufficient; the documented
  plugin system and `agentskills.io` compatibility are the intended seam.
  [plugins](https://hermes-agent.nousresearch.com/docs/user-guide/features/plugins)
  · [skills](https://hermes-agent.nousresearch.com/docs/user-guide/features/skills).

- **Open WebUI is the best <=10k-LOC customisation target.** Its Filters,
  Actions, Pipes, Tools and Skills are public plugin surfaces, and an action can
  call an external memory service while the built-in memory API remains the
  editable local fallback. A small “before chat retrieve / after chat retain”
  Filter or an MCP-backed tool policy is realistic; it is integration work, not
  a mobile-client rewrite. Confirm the desired hook timing in a prototype — an
  ordinary tool alone does not guarantee passive writes.
  [extensibility](https://docs.openwebui.com/features/extensibility/)
  · [plugins](https://docs.openwebui.com/features/extensibility/plugin/).

- **Moltis has MCP and lifecycle hooks, so an external-memory bridge is likely
  small; however, changing its Rust core or PWA for a new user flow is not a
  low-risk <=10k-LOC bet while the API is still evolving.** Prefer its built-in
  memory first and a standalone MCP bridge second.

- **AnythingLLM can add a Node custom agent skill or connect an MCP server, but
  its own docs warn that custom skills are newly supported and may have bugs or
  missing features.** A server-side bridge is plausible; adding reliable image
  analysis to both Android client and server is a product-core change, not a
  small extension. [custom-skill warning](https://github.com/Mintplex-Labs/anythingllm-docs/blob/9c536021ae62548d1bd45d0e0e8143238005e49c/pages/agent/custom/introduction.mdx#L8-L39).

## Hindsight: preferred integration and why it does not remove compaction

The existing local Hindsight deployment already exposes an API/MCP route and
has retained storage; see [the local deployment note](hindsight.md). The goal
is to use Hindsight as an **additive, durable knowledge graph**, not to replace
the chat runtime's own short-term transcript.

### Best path: Hermes's supported Hindsight provider

This needs configuration, not a new adapter. Hermes's memory-provider docs
explicitly describe its Hindsight provider as retaining full conversation turns
(including tool calls) with session-level document tracking. Its documented
defaults include `auto_retain: true`, `auto_recall: true`, and
`retain_async: true`; Hindsight can be local rather than cloud. The generic
provider contract also keeps the small built-in memory active alongside the
external provider. Thus it preserves every turn in Hindsight asynchronously,
retrieves relevant graph memory before the next turn, and does not entrust
memory writes to the model deciding to use an MCP tool. [Hermes Hindsight
provider](https://hermes-agent.nousresearch.com/docs/user-guide/features/memory-providers)
· [Hermes base memory](https://hermes-agent.nousresearch.com/docs/user-guide/features/memory).

For the first pilot, configure only one Hermes profile/persona and one
Hindsight bank/namespace. Verify that two separate Telegram/WhatsApp turns
are present in Hindsight, then begin a fresh local session and ask a question
whose answer requires a fact from the first session. Do not enable other
external memory providers at the same time: Hermes documents one active
external provider, with built-in memory still additive.

### If Hermes is rejected: an adapter design that remains small and reliable

The adapter must be a lifecycle integration rather than simply an MCP server.
Give it a stable `turn_id` (profile + canonical conversation + source message
or UUID) and persist that identifier with a local transactional outbox.

1. **Pre-turn, synchronously:** derive a retrieval query from the new user
   message and compact session summary; call Hindsight recall with a short,
   bounded deadline; inject only scored, attributable results into an extra
   system/context block. On timeout, continue the chat and record the recall
   failure rather than blocking the user.
2. **Post-turn, asynchronously:** place the user message, assistant answer,
   relevant tool/result summaries, image metadata, and session/turn identifiers
   in the durable outbox *before* acknowledging success. A worker sends these
   to Hindsight, retries idempotently by `turn_id`, and records permanent
   failures for review. It must not make the chat response wait on embeddings
   or graph extraction.
3. **At session end and before local compaction:** enqueue a current summary
   and a checkpoint reference. Raw historical turns remain in Hindsight; local
   compaction can therefore be aggressive without deleting the long-term
   source of truth.

This is comfortably below 10k LOC when kept as one adapter and outbox, but the
correct host seam matters:

| Host | Pre-turn recall seam | Post-turn retain seam | Assessment for *every* turn |
|---|---|---|---|
| **Moltis** | `BeforeLLMCall` is a modifying hook with the full message array; append recalled Hindsight context there. | `AfterLLMCall`, `MessageSent`, `SessionEnd`, and `BeforeCompaction` provide lifecycle events; have their shell hook enqueue to the worker, never synchronously embed. | Technically clean and small. Its hook protocol is explicit stdin/stdout plus timeouts, and supports blocking/modifying pre-call hooks. The risk is product maturity, not lack of a seam. [hooks](https://github.com/moltis-org/moltis/blob/fee006b78a370fed9d9a33e38ec150424ef4887d/docs/src/hooks.md) |
| **Open WebUI** | A server-admin Filter's request/inlet path can call recall and augment the request before model invocation. | Its response/outlet path enqueues the immutable turn into the worker. Functions have full request/response lifecycle access, persistent state and user metadata. | **Best custom-adapter host**: this is a plugin, not a fork. Do not ship it as an ordinary MCP Tool, since that only makes recall/retain optional to the model. Review and locally pin the Python plugin because Open WebUI plugins execute arbitrary server-side code. [plugin API](https://docs.openwebui.com/features/extensibility/plugin/) |
| **AnythingLLM** | A custom Node skill or MCP tool is model-invoked, not a pre-agent lifecycle hook. | The same problem applies to retain: the model can fail to call it, and scheduled jobs only provide delayed/batch capture. | **Not recommended for the stated guarantee.** Its official custom-skill interface is useful for Hindsight search/write commands, but cannot reliably retain every normal chat turn without server-core middleware or an out-of-process gateway that owns all message ingress. That is a fork/integration risk, not a <=10k stable add-on. [skill interface](https://github.com/Mintplex-Labs/anythingllm-docs/blob/9c536021ae62548d1bd45d0e0e8143238005e49c/pages/agent/custom/developer-guide.mdx#L19-L40) |

## DSH and Pi Coding Agent

**DSH is now a plausible Hindsight-first agent core, but not the better
phone-first companion product; Pi is a strong component, not a replacement
core.** This distinction matters because DSH's memory integration is no longer
MCP-only, whereas Pi's companion surfaces would all have to be supplied by us.

| Requirement | DeepSeek Harness (DSH) | Pi Coding Agent |
|---|---|---|
| Agent loop / extension seam | Plugin-first Cordis harness; native lifecycle events and a Web profile. | Deliberately minimal terminal coding harness, with TypeScript extensions and interactive, print/JSON, RPC and SDK modes. |
| Hindsight | **Official native Hindsight plugin**: session start can seed a project bank; `agent/pre-step` injects the integration's automatic context; `agent/turn-stopping` asynchronously writes the completed exchange. It registers native `hindsight_*` tools, so persistence does not depend on model tool choice. The current automatic context is a once-per-session low-budget `reflect`, not an LLM recall on every message. [integration](https://hindsight.vectorize.io/sdks/integrations/coding-agents) · [adapter source](https://github.com/vectorize-io/hindsight/blob/20e66093dc5b27cc2fee94e1a924ea20ecb73dc7/hindsight-integrations/coding-agents/src/dsh.ts) · [reflect cadence](https://github.com/vectorize-io/hindsight/blob/20e66093dc5b27cc2fee94e1a924ea20ecb73dc7/hindsight-integrations/coding-agents/src/core/hook.ts) | No official Pi integration. Pi's documented `before_agent_start`, `context`, `message_end`, `agent_settled`, session and compaction events are sufficient for our own adapter, but that adapter and a durable outbox would be ours to operate. [extensions](https://github.com/earendil-works/pi-mono/blob/main/packages/coding-agent/docs/extensions.md) |
| MCP | First-party MCP client for stdio and Streamable HTTP; tools only, no MCP resources/prompts. [DSH MCP reference](https://github.com/deepseek-ai/deepseek-harness/blob/master/packages/mcp/mcp-client/README.md) | Not a Pi-core feature. Kosmos currently imports it through the community `pi-mcp-adapter`; this is an extension dependency, not an agent-loop lifecycle guarantee. [local Pi setup](../README.md#pi-coding-agent) |
| Image input | Yes when the selected model declares image input; the deployed DSH vision configuration records this explicitly. [local DSH vision note](dsh-rc8-flash-vision-upgrade.md) | Yes in the TUI/RPC for vision-capable models (clipboard, drag/drop, or API content blocks), but that is terminal ingress rather than a phone chat attachment flow. [Pi session format](https://github.com/earendil-works/pi-mono/blob/main/packages/coding-agent/docs/session-format.md) |
| Simple schedule | An opt-in DSH Web scheduling example supplies durable, session-scoped `after`/`at` reminders. It is not a verified recurring cron/push-delivery system; daily jobs still need a small external timer/worker. [example index](https://github.com/deepseek-ai/deepseek-harness/blob/master/examples/README.md) | No built-in scheduler. A `systemd` timer can start Pi, but a useful scheduled reply still needs a channel/UI bridge. |
| Phone and TTS | The installed Web profile is reachable from the Pixel through Kepos, but upstream treats narrow-phone UI as a work item and the usable mobile layouts are community plugins. Current Kosmos voice input also relies on a third-party plugin with a known manifest workaround; no stable built-in TTS surface was established. [deployment](dsh-deployment.md) · [mobile issue](https://github.com/deepseek-ai/deepseek-harness/discussions/1721) | Android support is a Termux guide, not a mobile chat client; no documented core TTS. A good phone client, voice pipeline and push delivery would be separate products. [Pi README](https://github.com/earendil-works/pi-mono/blob/main/packages/coding-agent/README.md) |
| Stability / recommended role | Upstream still labels DSH a developer preview. Pin it and use its official Hindsight plugin only after an end-to-end compatibility test with the local deployment. It is a good **desktop/Web coding-and-tool agent core**, not the stability-first phone companion. [local deployment status](dsh-deployment.md) | Pi's compact, well-documented extension API makes it a good **coding agent or embedded worker**. Turning it into the companion gateway would add a mobile channel, persistent service, scheduler, TTS and memory outbox—well beyond the requested small gap-filling layer. |

### DSH: the important update

Use `@vectorize-io/hindsight-coding-agents` rather than a generic Hindsight MCP
entry if DSH is piloted. “Official coding-agents integration” means this is a
Vectorize-maintained package—not a DSH built-in—and it is installed as a native
Cordis bundle. It binds `agent/session-start`, `agent/pre-step`,
`agent/turn-stopping`, and `agent/disposed`, and registers the `hindsight_*`
tools directly in DSH. Thus automatic session write-back does not depend on the
model deciding to call an MCP tool. Install it into the Web profile with
`dsh plugin --profile web add @vectorize-io/hindsight-coding-agents` (or use
the package installer); its memory configuration is separate, in
`~/.hindsight/coding-agent.json`. [DSH wiring](https://github.com/vectorize-io/hindsight/blob/20e66093dc5b27cc2fee94e1a924ea20ecb73dc7/hindsight-integrations/coding-agents/cordis.patch.yml) · [DSH adapter](https://github.com/vectorize-io/hindsight/blob/20e66093dc5b27cc2fee94e1a924ea20ecb73dc7/hindsight-integrations/coding-agents/src/dsh.ts)

#### DSH agent, session, and bank mapping

The association is **not** `DSH persona/agent → one bank`, nor
`DSH session → one bank`. DSH's long-lived Web process can serve several
workspaces, and the plugin resolves a bank from each session's
`session.header.cwd`. By default it uses the worktree-aware repository name:

```text
one DSH Web process
  session A: cwd=/work/kosmos, id=A ─┐
  session B: cwd=/work/kosmos, id=B ─┼─ coding-agent::kosmos
  session C: cwd=/work/other,  id=C ─── coding-agent::other
```

Resolution order is: `mapPathToBank` (longest absolute-path prefix), static
`bankId`, then the default `coding-agent::{gitProject}`. Linked worktrees use
their main repository name, so they share the default bank. A DSH persona or
per-session agent preset is not part of the key; separate personas in the same
workspace share memory. If persona isolation is wanted, use different mapped
workspaces or add a small Cordis routing plugin. [bank algorithm](https://github.com/vectorize-io/hindsight/blob/20e66093dc5b27cc2fee94e1a924ea20ecb73dc7/hindsight-integrations/coding-agents/src/core/bank.ts) · [per-workspace DSH runtime](https://github.com/vectorize-io/hindsight/blob/20e66093dc5b27cc2fee94e1a924ea20ecb73dc7/hindsight-integrations/coding-agents/src/dsh.ts)

Within the selected bank, every DSH session has its own durable document,
`conversation:<session-id>`. At each completed turn the plugin rereads the
full DSH event log and asynchronously upserts/appends the accumulated session;
the write has deterministic operation IDs for retry deduplication. It retains
human user/assistant text and compact tool-call records, but excludes
plugin-injected context and raw tool results, preventing recalled context from
being fed back into the graph. Subagent-origin sessions are deliberately
skipped. Consequently, many independent DSH sessions can safely contribute to
and read one personal bank while retaining session-level provenance.
[write-back protocol](https://github.com/vectorize-io/hindsight/blob/20e66093dc5b27cc2fee94e1a924ea20ecb73dc7/hindsight-integrations/coding-agents/src/core/chat.ts) · [DSH transcript filter](https://github.com/vectorize-io/hindsight/blob/20e66093dc5b27cc2fee94e1a924ea20ecb73dc7/hindsight-integrations/coding-agents/src/core/transcript-dsh.ts) · [async DSH lifecycle](https://github.com/vectorize-io/hindsight/blob/20e66093dc5b27cc2fee94e1a924ea20ecb73dc7/hindsight-integrations/coding-agents/src/core/runtime.ts)

The current official plugin is designed for coding memory, not a classic
pre-turn `recall` loop. On the first human prompt of a session it normally
runs one low-budget `reflect`; it caches the result for that session. Later
turns refresh only the knowledge-page roster on the configured cadence (ten
turns by default), and the model may use native tools to search pages or run a
deeper reflect. Set `autoReflect: false` to remove this automatic LLM
synthesis entirely. This is much lighter than “call an LLM recall for every
message,” but also means an always-on personal semantic-recall policy would be
a small, intentional extension—not a feature already supplied by this plugin.
[automatic-context implementation](https://github.com/vectorize-io/hindsight/blob/20e66093dc5b27cc2fee94e1a924ea20ecb73dc7/hindsight-integrations/coding-agents/src/core/hook.ts)

#### Recommended companion routing

Keep ordinary coding repositories in their default per-repository banks. Create
one dedicated, stable DSH companion workspace, start companion sessions there,
and route only that path to one personal bank. The path routing avoids silently
mixing unrelated coding transcripts into relationship memory while still
letting every new companion session share the same bank. Its bank-specific
settings should disable code-oriented git seeding and surveys, preserve session
retention, and add provenance for future filtering:

```jsonc
// ~/.hindsight/coding-agent.json
{
  "apiUrl": "http://hindsight.localhost:17480",
  "harnesses": {
    "dsh": {
      "mapPathToBank": {
        "/absolute/path/to/companion-workspace": "neil::companion"
      },
      "banks": {
        "neil::companion": {
          "autoSeed": false,
          "codebaseSurvey": false,
          "gitIngest": "none",
          "autoReflect": false,
          "retainSessions": true,
          "retainTags": ["surface:dsh", "workspace:{gitProject}"],
          "retainMetadata": {
            "workspace": "{gitProject}",
            "dsh_session": "{sessionId}"
          }
        }
      }
    }
  }
}
```

If DSH will be used *only* as the companion, the smaller alternative is
`"bankId": "neil::companion", "dynamicBankId": false` in its `dsh` override;
then every DSH workspace and session shares that bank. The path-mapped design is
safer when DSH continues to be used as a coding tool. As DSH is a persistent
plugin host, restart its service after changing this file so already-cached
workspace runtimes do not retain the old configuration. [configuration and
bank recipes](https://hindsight.vectorize.io/sdks/integrations/coding-agents)

This integration currently declares `@vectorize-io/hindsight-all` `^0.8.6`,
which has the same lower bound as Kosmos's local **0.8.6** Hindsight server, but
that is not an end-to-end guarantee. Pin the plugin for a pilot and verify one
write, one fresh-session retrieval, an outage/retry, and a long session before
changing the deployed Hindsight image. [package manifest](https://github.com/vectorize-io/hindsight/blob/20e66093dc5b27cc2fee94e1a924ea20ecb73dc7/hindsight-integrations/coding-agents/package.json) · [local version and endpoint](hindsight.md)

### Pi: a small custom memory adapter is feasible, the companion is not

A Pi extension can synchronously recall in `before_agent_start` (or `context`)
and add a context message before the model call. It can capture final user and
assistant messages at `agent_settled`, enqueue them by deterministic turn ID,
and use the session/compaction hooks for checkpoints. With an external durable
worker, that memory slice is plausibly 1–3k LOC and meets the passive-memory
contract. It should not instead expose Hindsight only as an MCP tool.

That does **not** create a usable companion. Pi has no supplied inbound mobile
channel, PWA/API chat service, persistent job runner, push delivery or TTS.
Implementing and operating those boundaries safely is the large part of an
OpenClaw replacement, not a <=10k-LOC extension. Pi therefore remains valuable
alongside the companion—for coding, controlled jobs, or a tool-capable worker—
rather than as its gateway.

## Hindsight support: what is actually official

“MCP compatible” means a client can see Hindsight tools; it does **not** mean
the client automatically recalls before each message and durably retains after
each response. The following inventory separates those cases. “Official” means
published by Vectorize/Hindsight or built into the named host—not merely a
gallery package.

| Integration class | Officially supported hosts / package | Passive-memory strength |
|---|---|---|
| Host-native lifecycle | **Hermes** native Hindsight provider; **OpenClaw** `@vectorize-io/hindsight-openclaw`; **DSH** through `@vectorize-io/hindsight-coding-agents`. Hermes has context/hybrid modes; OpenClaw defaults `autoRecall` and `autoRetain` on; DSH binds Cordis pre-step and turn-stop events. | Hermes/OpenClaw meet the automatic pre-turn-recall + post-turn-write shape. DSH automatically writes and has a lifecycle seam, but its current default context is once-session `reflect`, not every-turn recall; it remains coding/workspace-oriented. [Hermes comparison](https://hindsight.vectorize.io/guides/2026/06/02/comparison-hermes-native-memory-provider-vs-mcp-memory) · [OpenClaw plugin](https://github.com/vectorize-io/hindsight/tree/main/hindsight-integrations/openclaw) · [DSH adapter](https://github.com/vectorize-io/hindsight/blob/20e66093dc5b27cc2fee94e1a924ea20ecb73dc7/hindsight-integrations/coding-agents/src/dsh.ts) |
| Official coding-agent wrapper | One `hindsight-coding-agents` package covers Claude Code, Codex CLI, Cursor CLI, GitHub Copilot CLI, OpenCode, Kilo CLI, Cline CLI, Antigravity CLI, Devin CLI, Grok Build, Prime Agent and DSH, using each host's hooks or plugin API. | It performs automatic project/session ingestion. Its current default is one initial low-budget `reflect` plus knowledge-page tools/roster, not a general every-turn recall policy; it is designed for project banks, not a multi-channel personal companion. [supported hosts and mechanisms](https://hindsight.vectorize.io/sdks/integrations/coding-agents) |
| Official framework adapters with an automatic seam | **LangGraph** has recall/retain nodes and a `BaseStore`; **CrewAI** has an `ExternalMemory` storage backend, so its own lifecycle searches at task start and saves outputs at task end. | Good primitives for building a custom companion, but they do not supply a mobile product, channels or TTS. [LangGraph](https://hindsight.vectorize.io/sdks/integrations/langgraph) · [CrewAI](https://hindsight.vectorize.io/sdks/integrations/crewai) |
| Official SDK/tool adapters | Python/TypeScript Hindsight clients and adapters for LangChain, LlamaIndex, Pydantic AI, OpenAI Agents SDK, Google ADK, Agno, Strands, AutoGen, Microsoft Agent Framework, Vercel AI SDK and Haystack. Several expose `retain`/`recall`/`reflect` as callable tools; the host application must wire lifecycle hooks unless its adapter explicitly provides nodes/store/callbacks. | Do not assume passive memory from tool registration alone. [official SDK inventory](https://github.com/vectorize-io/hindsight#readme) |
| Generic MCP | Any MCP client (including a plain Pi MCP extension) can connect to Hindsight's MCP server. | Model-invoked tools only; insufficient for the requested every-turn guarantee without a host lifecycle adapter. [MCP contract](https://hindsight.vectorize.io/blog/2026/03/04/mcp-agent-memory) |
| Pi specifically | Hindsight does **not** list a first-party standalone Pi integration. Its own Omnigent page calls Pi support “community, via epimetheus”; Omnigent can broker tools but is explicitly multi-harness orchestration, which is not wanted here. | Use a small owned Pi extension only if Pi is retained for its coding role; do not treat this community path as a stable companion-memory substrate. [Omnigent matrix](https://hindsight.vectorize.io/sdks/integrations/omnigent) |

For the normal per-turn path choose Hindsight `recall`, not `reflect`:
Hindsight documents recall as retrieval/reranking without an LLM call, whereas
retain and reflect use LLM work. Keep recall bounded and fail-open; reserve
reflect for a periodic or explicitly requested synthesis. [recall versus
reflect](https://hindsight.vectorize.io/blog/2026/07/24/recall-vs-reflect)

Hindsight **does not and should not eliminate main-chat context compaction**.
The active model context must stay bounded for latency, cost, and prompt-cache
stability. Hindsight retains and retrieves *relevant* historical material; it
cannot put every past token into the current prompt. Keep ordinary local
compaction/session summaries enabled, retain the pre-compaction turn data to
Hindsight, and use the pre-turn recall budget as the bridge between long-term
graph memory and the current agent loop.

## Stability evidence and rollout choice

GitHub repository metadata is a coarse maturity signal, not a quality proof:
Open WebUI dates to 2023, AnythingLLM to 2023, Hermes to July 2025, and Moltis
to January 2026. All four are MIT except Open WebUI’s repository declares no
SPDX identifier in GitHub metadata; verify the exact release license before a
redistribution decision. [Open WebUI metadata](https://api.github.com/repos/open-webui/open-webui)
· [AnythingLLM metadata](https://api.github.com/repos/Mintplex-Labs/anything-llm)
· [Hermes metadata](https://api.github.com/repos/NousResearch/hermes-agent)
· [Moltis metadata](https://api.github.com/repos/moltis-org/moltis).

For a stability-first rollout, pin a Hermes release, put it behind the existing
authenticated gateway, use one Telegram/WhatsApp identity, and test one
vision message, one TTS reply, one MCP tool invocation, one scheduled delivery,
and a multi-day external-memory recall. Keep Open WebUI as the fallback pilot if
the messaging-first client is less important than a conventional PWA.

## Excluded despite attractive features

- **LobeHub** has MCP, scheduling, vision and TTS/STT, but its Community
  License is not an OSI open-source license and its product is centred on agent
  teams; it adds complexity not requested. [license](https://github.com/lobehub/lobehub/blob/main/LICENSE).
- **Home Assistant Assist** has exceptional Android/iOS apps, automations,
  TTS and MCP client support, but is not a general long-running companion-agent
  runtime. It is better considered as a home-control MCP endpoint.
