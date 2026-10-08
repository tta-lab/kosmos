{
  config,
  lib,
  pkgs,
  pkgsUnstable,
  ...
}: let
  cfg = config.kosmos.wsl.matrixMcpRemote;
  checkout = "/home/neil/code/projects/lamplitisles/matrix-for-agent";
  artifact = "${checkout}/dist/cli.js";
  secretFile = ../../secrets/matrix-for-agent.env.age;
  haveEnv = config.age.secrets ? "matrix-for-agent.env";
  start = pkgs.writeShellScript "matrix-for-agent-start" ''
    exec ${pkgs.bash}/bin/bash ${../../scripts/matrix-for-agent-run} ${lib.getExe pkgsUnstable.nodejs_24} ${lib.escapeShellArg artifact}
  '';
in {
  options.kosmos.wsl.matrixMcpRemote = {
    enable = lib.mkEnableOption "direct authenticated Matrix for Agent HTTP service";
    hostname = lib.mkOption {
      type = lib.types.str;
      default = "matrix-mcp.guion.io";
      description = "Public Cloudflare Tunnel hostname; DNS is operator-provisioned.";
    };
  };

  config = lib.mkIf cfg.enable (lib.mkMerge [
    {
      age.secrets = lib.optionalAttrs (builtins.pathExists secretFile) {
        "matrix-for-agent.env" = {
          file = secretFile;
          owner = "neil";
          group = "users";
          mode = "0400";
        };
      };
      warnings = lib.optional (!haveEnv) "Matrix MCP remote is waiting for secrets/matrix-for-agent.env.age; no service or ingress is enabled.";
    }
    (lib.mkIf haveEnv {
      home-manager.users.neil.systemd.user.services.matrix-mcp-remote = {
        Unit = {
          Description = "Matrix for Agent Streamable HTTP service";
          After = ["network-online.target"];
          ConditionPathExists = [artifact];
        };
        Install.WantedBy = ["default.target"];
        Service = {
          WorkingDirectory = checkout;
          ExecStart = start;
          EnvironmentFile = [config.age.secrets."matrix-for-agent.env".path];
          Environment = ["PATH=${lib.makeBinPath [pkgs.cloudflared]}:/run/current-system/sw/bin"] ++ lib.mapAttrsToList (name: value: "${name}=${value}") config.kosmos.wsl.proxy.environment;
          Restart = "on-failure";
          RestartSec = 5;
          KillMode = "control-group";
          TimeoutStopSec = 15;
          UMask = "0077";
          NoNewPrivileges = true;
          PrivateTmp = true;
          StandardInput = "null";
        };
      };
    })
  ]);
}
