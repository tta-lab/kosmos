{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.kosmos.wsl.keetMcp;
  checkout = "/home/neil/code/projects/lamplitisles/keet-for-agent";
  gateway = "${checkout}/packages/keet-mcp/dist/cli.js";
  runtime = "/home/neil/.local/share/keet-runtime/4.22.0-linux-x64";
  sereinRoot = "/home/neil/.local/state/keet-mcp-serein";
in {
  options.kosmos.wsl.keetMcp.enable = lib.mkEnableOption "independent Keet MCP identity gateways";

  config = lib.mkIf cfg.enable {
    home-manager.users.neil.systemd.user.services = {
      keet-mcp = {
        Unit = {
          Description = "Keet MCP gateway using retired DSH identity";
          After = ["network-online.target"];
        };
        Install.WantedBy = ["default.target"];
        Service = {
          ExecStart = "/run/current-system/sw/bin/node ${gateway}";
          EnvironmentFile = ["/home/neil/.local/state/keet-mcp/gateway.env"];
          Restart = "on-failure";
          RestartSec = 5;
          UMask = "0077";
        };
      };

      keet-mcp-serein = {
        Unit = {
          Description = "Keet MCP gateway for Serein";
          After = ["network-online.target"];
        };
        Install.WantedBy = ["default.target"];
        Service = {
          ExecStartPre = "${pkgs.coreutils}/bin/install -d -m 0700 ${sereinRoot} ${sereinRoot}/identity ${sereinRoot}/state ${sereinRoot}/workspace";
          ExecStart = "/run/current-system/sw/bin/node ${gateway}";
          Environment = [
            "KEET_MCP_RUNTIME_DIR=${runtime}"
            "KEET_MCP_IDENTITY_DIR=${sereinRoot}/identity"
            "KEET_MCP_WORKSPACE_ROOT=${sereinRoot}/workspace"
            "KEET_MCP_STATE_DIR=${sereinRoot}/state"
            "KEET_MCP_LISTEN=127.0.0.1:8767"
          ];
          EnvironmentFile = [config.age.secrets."keet-mcp-serein.env".path];
          Restart = "on-failure";
          RestartSec = 5;
          UMask = "0077";
        };
      };
    };
  };
}
