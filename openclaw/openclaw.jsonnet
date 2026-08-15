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
  // auto "off": only synthesize when the user explicitly asks for audio
  // (e.g. /tts or a direct request); no per-reply auto synthesis.
  tts: {
    // tagged: 仅当回复含 [[tts:...]] 指令或 [[tts:text]] 块时合成（配合 voice-text skill）
    auto: "tagged",
    persona: "yuki",
    personas: {
      yuki: {
        label: "Yuki",
        description: "24 岁鲸鱼妹妹。中文短句，嘴硬但暖，深水安静 vs 撒娇活泼。用 Volcengine 豆包 TTS；情绪靠 [[tts:emotion=...]] 指令（happy/sad/angry/surprised/fearful/disgusted/neutral 等）+ 文字表情（标点/拖音/语气词）塑造；中文为主，必要时切英文。",
        provider: "volcengine",
        providers: {
          volcengine: {
            resourceId: "seed-tts-1.0",
            speakerVoice: "zh_female_xiaohe_uranus_bigtts",
          },
        },
      },
    },
    provider: "volcengine",
    providers: {
      volcengine: {
        apiKey: "${VOLCENGINE_TTS_API_KEY}",
        resourceId: "seed-tts-1.0",
        // 豆包中文女声（晓禾）；换音色改这一行（控制台看音色 ID）。
        speakerVoice: "zh_female_xiaohe_uranus_bigtts",
      },
      // Soniox 保留为 fallback（英文 TTS / STT 继续用）。
      soniox: {
        apiKey: "${SONIOX_API_KEY}",
        speakerVoice: "Mina",
        language: "zh",
        voice: null,
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
      // Volcengine TTS provider（豆包，bundled plugin）。
      volcengine: { enabled: true },
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
      // 已移除：og / project / src（不暴露给 Yuki）
      og: null,
      project: null,
      src: null,
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
