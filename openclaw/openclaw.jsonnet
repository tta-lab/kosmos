// OpenClaw gateway config — SSOT, generated from jsonnet.
// Deploy with: just openclaw-deploy
// Installed via npm (official); gateway service managed by \`openclaw gateway
// install --wrapper\` (scripts/openclaw-gateway-wrapper); the wrapper injects
// agenix-decrypted secrets from ~/.config/openclaw/* into the gateway env.
{
  gateway: {
    mode: "local",
    controlUi: { allowedOrigins: ["http://openclaw.localhost:17480"] },
  },
  agents: {
    defaults: {
      model: { primary: "deepseek/deepseek-v4-flash" },
      workspace: "/home/neil/.openclaw/workspace",
    },
  },
  // deepseek provider comes from the @openclaw/deepseek-provider plugin
  // (installed via \`openclaw plugins install\`); its model catalog provides
  // the correct context windows (deepseek-v4-flash: 1M ctx / 384K max).
  plugins: {
    slots: { memory: "hindsight-openclaw" },
    entries: {
      "memory-core": { enabled: false },
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
      // miniflux-mcp (tssujt/miniflux-mcp v0.4.0, built into ~/go/bin).
      // OpenClaw spawns MCP stdio children with only the configured server
      // env (no gateway env inheritance), so MINIFLUX_PASSWORD is injected by
      // scripts/miniflux-mcp-wrapper from the agenix-decrypted file
      // (~/.config/openclaw/miniflux-password) — it never lands in this json.
      miniflux: {
        command: "miniflux-mcp-wrapper",
        args: [],
        env: {
          MINIFLUX_URL: "http://miniflux.localhost:17480",
          MINIFLUX_USERNAME: "admin",
        },
      },
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
