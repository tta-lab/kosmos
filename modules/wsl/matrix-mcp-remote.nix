{
  config,
  lib,
  pkgs,
  pkgsUnstable,
  ...
}: let
  cfg = config.kosmos.wsl.matrixMcpRemote;
  root = "/home/neil/.local/state/matrix-mcp-remote";
  configHome = "${root}/config";
  matrixConfig = "${configHome}/matrix-mcp/config.json";
  supergateway = pkgs.callPackage ../../packages/supergateway {};
  secretFile = ../../secrets/matrix-mcp-remote-key.age;
  haveKey = config.age.secrets ? matrix-mcp-remote-key;
  matrix = pkgs.writeShellApplication {
    name = "matrix-mcp-remote";
    runtimeInputs = [pkgsUnstable.uv pkgs.util-linux];
    text = ''
      exec ${pkgs.bash}/bin/bash ${../../scripts/matrix-mcp-remote-run} ${lib.escapeShellArg root} uvx --from matrix-mcp==0.9.0 matrix-mcp serve --transport stdio
    '';
  };
in {
  options.kosmos.wsl.matrixMcpRemote = {
    enable = lib.mkEnableOption "independent authenticated Matrix MCP gateway";
    hostname = lib.mkOption {
      type = lib.types.str;
      default = "matrix-mcp.guion.io";
      description = "Public Cloudflare Tunnel hostname; DNS is operator-provisioned.";
    };
  };

  config = lib.mkIf cfg.enable (lib.mkMerge [
    {
      age.secrets = lib.optionalAttrs (builtins.pathExists secretFile) {
        matrix-mcp-remote-key = {
          file = secretFile;
          owner = "neil";
          group = "users";
          mode = "0400";
        };
      };
      home-manager.users.neil.home.packages = [supergateway matrix];
      warnings = lib.optional (!haveKey) "Matrix MCP remote is waiting for secrets/matrix-mcp-remote-key.age; no service or ingress is enabled.";
    }
    (lib.mkIf haveKey {
      home-manager.users.neil.systemd.user.services.matrix-mcp-remote = {
        Unit = {
          Description = "Independent Matrix MCP Streamable HTTP gateway";
          After = ["network-online.target"];
          ConditionPathExists = [matrixConfig];
        };
        Install.WantedBy = ["default.target"];
        Service = {
          ExecStartPre = "${pkgs.coreutils}/bin/install -d -m 0700 ${root} ${configHome} ${configHome}/matrix-mcp ${root}/data ${root}/cache";
          ExecStart = "${lib.getExe supergateway} --stdio ${lib.getExe matrix} --outputTransport streamableHttp --host 127.0.0.1 --port 8768 --streamableHttpPath /mcp --apiKeyFile ${config.age.secrets.matrix-mcp-remote-key.path} --logLevel none";
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
