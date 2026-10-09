{
  config,
  lib,
  pkgs,
  pkgsUnstable,
  ...
}: let
  cfg = config.kosmos.wsl.matrixMcpCfl;
  checkout = "/home/neil/code/projects/lamplitisles/matrix-for-agent";
  artifact = "${checkout}/dist/cli.js";
  secretFile = ../../secrets + "/matrix-shio.env.age";
  haveEnv = config.age.secrets ? "matrix-shio.env";
  start = pkgs.writeShellScript "matrix-for-agent-cfl-start" ''
    exec ${pkgs.bash}/bin/bash ${../../scripts/matrix-for-agent-cfl-run} ${lib.getExe pkgsUnstable.nodejs_24} ${lib.escapeShellArg artifact}
  '';
in {
  options.kosmos.wsl.matrixMcpCfl = {
    enable = lib.mkEnableOption "independent loopback Shio Matrix service for CFL production";
  };

  config = lib.mkIf cfg.enable (lib.mkMerge [
    {
      age.secrets = lib.optionalAttrs (builtins.pathExists secretFile) {
        "matrix-shio.env" = {
          file = secretFile;
          owner = "neil";
          group = "users";
          mode = "0400";
        };
      };
      warnings = lib.optional (!haveEnv) "Shio Matrix is waiting for secrets/matrix-shio.env.age; no CFL Matrix service or prod credential wiring is enabled.";
    }
    (lib.mkIf haveEnv {
      home-manager.users.neil.systemd.user.services.matrix-mcp-cfl = {
        Unit = {
          Description = "Shio Matrix for Agent loopback HTTP service";
          After = ["network-online.target"];
          ConditionPathExists = [artifact];
        };
        Install.WantedBy = ["default.target"];
        Service = {
          WorkingDirectory = checkout;
          ExecStart = start;
          EnvironmentFile = [config.age.secrets."matrix-shio.env".path];
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
