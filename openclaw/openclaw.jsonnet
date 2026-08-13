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
  // ACP: run external coding harnesses (pi via pi-acp adapter) as subagents.
  // OpenClaw owns sessions/channels/delivery; the harness owns its tools.
  acp: {
    enabled: true,
    dispatch: { enabled: true },
    backend: "acpx",
    defaultAgent: "pi",
    allowedAgents: ["pi"],
    maxConcurrentSessions: 4,
    runtime: { ttlMinutes: 120 },
  },
  // deepseek provider comes from the @openclaw/deepseek-provider plugin
  // (installed via \`openclaw plugins install\`); its model catalog provides
  // the correct context windows (deepseek-v4-flash: 1M ctx / 384K max).
  plugins: {
    slots: { memory: "hindsight-openclaw" },
    entries: {
      "memory-core": { enabled: false },
      // ACP runtime backend: runs pi (pi-acp adapter) as a harness subagent.
      // Non-interactive sessions cannot click permission prompts, so approve
      // writes/exec headlessly; deny degrades gracefully instead of crashing.
      // No mcpServers here: pi-acp does not support ACP MCP injection. pi
      // loads its own MCP servers (incl. miniflux RSS) via mcporter, which
      // imports [mcp_servers.*] from ~/.codex/config.toml.
      acpx: {
        enabled: true,
        config: {
          permissionMode: "approve-all",
          nonInteractivePermissions: "deny",
          timeoutSeconds: 180,
          probeAgent: "pi",
        },
      },
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
