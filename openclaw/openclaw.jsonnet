// Declarative OpenClaw gateway config patch — generated from Jsonnet.
// The deploy target preserves OpenClaw-managed metadata and credentials.
// Deploy with: just openclaw-deploy
// Installed via npm (official); gateway service managed by \`openclaw gateway
// install --wrapper\` (scripts/openclaw-gateway-wrapper); the wrapper injects
// agenix-decrypted secrets from ~/.config/openclaw/* into the gateway env.
{
  gateway: {
    mode: "local",
    controlUi: { allowedOrigins: ["http://openclaw.localhost:17480"] },
    auth: {
      token: {
        source: "env",
        provider: "default",
        id: "OPENCLAW_GATEWAY_TOKEN",
      },
    },
  },
  // Give each DM peer a stable identity for user-scoped Hindsight banks.
  session: { dmScope: "per-peer" },
  agents: {
    defaults: {
      model: { primary: "deepseek/deepseek-v4-flash" },
      workspace: "/home/neil/.openclaw/workspace",
    },
  },
  // Soniox TTS via the bundled soniox plugin (gateway runs from the openclaw
  // fork checkout; root `tts` key requires 2026.8+). MP3 audio files, native
  // Opus voice notes, 16 kHz PCM telephony.
  // The API key is injected by scripts/openclaw-gateway-wrapper from the
  // agenix secret ~/.config/openclaw/soniox-key.
  tts: {
    auto: "always",
    provider: "soniox",
    providers: {
      soniox: {
        apiKey: "${SONIOX_API_KEY}",
        voice: "Adrian",
        language: "en",
      },
    },
  },
  // Soniox async speech-to-text (media-understanding) for inbound voice
  // messages and attachments; same SONIOX_API_KEY as TTS.
  tools: {
    media: {
      models: [
        { provider: "soniox", model: "stt-async-v5", capabilities: ["audio"] },
      ],
      audio: { enabled: true },
    },
  },
  // ACP (pi subagent harness) is intentionally not used. Explicit null keeps
  // the key pruned from the live config on every deploy (config patch treats
  // null as delete; plain absence would leave stale keys behind).
  acp: null,
  // deepseek provider comes from the @openclaw/deepseek-provider plugin
  // (installed via \`openclaw plugins install\`); its model catalog provides
  // the correct context windows (deepseek-v4-flash: 1M ctx / 384K max).
  plugins: {
    slots: { memory: "hindsight-openclaw" },
    entries: {
      "memory-core": { enabled: false },
      // ACP runtime backend: bundled in 2026.8.1; explicitly disabled (same
      // pattern as memory-core) since the ACP to pi subagent wiring is unused.
      acpx: { enabled: false },
      "hindsight-openclaw": {
        enabled: true,
        hooks: { allowConversationAccess: true },
        config: {
          hindsightApiUrl: "http://hindsight.localhost:17480",
          dynamicBankGranularity: ["user"],
          retainMission: "Keep Neil's life details: plans, moods, important dates, things he says about himself, his work, and us.",
        },
      },
    },
  },
  mcp: {
    servers: {
      flicknote: { command: "flicknote", args: ["mcp"] },
      web: { command: "web", args: ["mcp"] },
      og: { command: "og", args: ["mcp"] },
      project: { command: "project", args: ["mcp"] },
      src: { command: "src", args: ["mcp"] },
      // RSS (miniflux) is intentionally NOT an OpenClaw MCP server: queries
      // go through the pi ACP harness (pi loads miniflux via mcporter from
      // ~/.codex/config.toml), so full-content responses never enter Yuki's
      // context — pi returns title-only lists.
    },
  },
  channels: {
    telegram: {
      // Explicit enable: the runtime auto-enable for configured channels
      // stopped firing once plugins.entries was populated, so set it directly.
      enabled: true,
      allowFrom: [845849177],
      groups: { "*": { requireMention: true } },
    },
  },
}
