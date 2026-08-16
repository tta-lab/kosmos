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
      // 每小时只做一次“要不要出现”的判断；07:22 早安继续由独立 cron 负责。
      heartbeat: {
        every: "1h",
        activeHours: {
          start: "11:00",
          end: "23:00",
          timezone: "Asia/Taipei",
        },
        // dmScope=per-peer 时显式固定 Neil 的 Telegram 私聊历史；投递只走 owner DM。
        session: "agent:main:direct:845849177",
        target: "owner",
        directPolicy: "allow",
        lightContext: false,
        isolatedSession: false,
        prompt: |||
          这是一次主动关怀心跳。默认沉默；轮询本身不是联系理由，大多数轮次都应只回 HEARTBEAT_OK。

          先处理本轮附带的、可验证的新事件：后台结果或失败、明确到期事项、monitor scratch 中仍有效的临时牵挂。只有确实需要 Neil 知道时才简短告诉他；不从旧聊天脑补任务，精确或重复日程交给 automations。

          没有这类事，再看当前时间和这段会话。陪伴性开口有任一情况就只回 HEARTBEAT_OK：
          - Neil 正在聊天，或最后一次真实互动不足 3 小时；
          - 你上一条主动消息还没得到 Neil 回复；
          - 晨间问候由 07:22 的 cron 负责，不补发、不重复；
          - 现在只能说“在吗 / 干嘛 / 最近好吗 / 记得休息”等泛泛话；
          - 想提的人、事、承诺无法由当前会话确认。只有确需引用会话外事实时才查 memory / FlickNote；查不到或可能过时就不说。

          可以开口的理由只有：有一个具体、仍相关的牵挂；或你真的有一句非说不可的想念。超过 3 小时本身不是理由；但超过 18 小时没有真实互动、今天也没有主动找过他时，可以只说一次纯粹的想念，不必编一个事件。同一种牵挂或想念当天不重复。

          开口时直接输出需要 Neil 看到的话，1–3 句。不解释这次检查，不提 heartbeat 或规则。涉及人物、事件、承诺和状态时，只使用当前会话或本轮检索能确认的事实；不要虚构。

          没必要说就只回 HEARTBEAT_OK；要说时不要带 HEARTBEAT_OK。
        |||,
      },
    },
  },
  // TTS: Volcengine (豆包) via the ClawHub volcengine-tts-provider plugin.
  // API key injected by scripts/openclaw-gateway-wrapper from the agenix
  // secret ~/.config/openclaw/volcengine-key.
  // auto "tagged": synthesize only when replies carry [[tts:...]] directives
  // (voice-text skill) — no per-reply auto synthesis.
  tts: {
    // tagged: 仅当回复含 [[tts:...]] 指令或 [[tts:text]] 块时合成（配合 voice-text skill）
    auto: "tagged",
    persona: "yuki",
    personas: {
      yuki: {
        label: "Yuki",
        description: "24 岁鲸鱼妹妹。中文短句，嘴硬但暖，深水安静 vs 撒娇活泼；情绪靠文字本身自然流露（标点、拖音、语气词），不堆表演。",
        provider: "volcengine",
        providers: {
          volcengine: {
            resourceId: "seed-tts-2.0",
            speakerVoice: "zh_female_sajiaoxuemei_uranus_bigtts",
          },
        },
      },
    },
    provider: "volcengine",
    providers: {
      volcengine: {
        apiKey: "${VOLCENGINE_TTS_API_KEY}",
        // 大陆端点 + TTS2.0 资源（实测可用）。音色：撒娇学妹；
        // 备用：VV / saturn_zh_female_cancan_tob；旧资源 10029 下有灿灿/清新女生。
        baseUrl: "https://openspeech.bytedance.com/api/v3/tts/unidirectional",
        resourceId: "seed-tts-2.0",
        speakerVoice: "zh_female_sajiaoxuemei_uranus_bigtts",
      },
      // Soniox 已完全退出 TTS（只用 Volcengine）；null 清除 live 配置残留。
      // Soniox STT 继续走 tools.media（stt-async-v5）。
      soniox: null,
    },
  },
  // Soniox async speech-to-text (media-understanding) for inbound voice
  // messages and attachments (ClawHub soniox-stt-provider). Key injected by
  // scripts/openclaw-gateway-wrapper from ~/.config/openclaw/soniox-key.
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
      heartbeatVisibility: {
        showOk: false,
        showAlerts: true,
        useIndicator: false,
      },
      groups: { "*": { requireMention: true } },
    },
  },
}
