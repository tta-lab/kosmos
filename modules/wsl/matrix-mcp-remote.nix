{
  config,
  lib,
  pkgs,
  pkgsUnstable,
  ...
}: let
  cfg = config.kosmos.wsl.matrixMcpRemote;
  kinds = builtins.filter (kind: config.age.secrets ? "matrix-${kind}.env") ["shio" "serein"];
  node = lib.getExe pkgsUnstable.nodejs_24;
  runtime = "${node} ${../../scripts/matrix-for-agent-runtime.mjs}";
  directory = "%t/matrix-mcp-remote";
  environment = ["PATH=${lib.makeBinPath [pkgs.cloudflared]}:/run/current-system/sw/bin"] ++ lib.mapAttrsToList (name: value: "${name}=${value}") config.kosmos.wsl.proxy.environment;
  safety = {
    UMask = "0077";
    NoNewPrivileges = true;
    PrivateTmp = true;
    StandardInput = "null";
    TimeoutStopSec = 15;
    KillMode = "control-group";
  };
  inputs = lib.genAttrs (map (kind: "matrix-mcp-input-${kind}") kinds) (name: let
    kind = lib.removePrefix "matrix-mcp-input-" name;
  in {
    Unit.Description = "Prepare private Matrix ${kind} input";
    Service =
      safety
      // {
        Type = "oneshot";
        EnvironmentFile = [config.age.secrets."matrix-${kind}.env".path];
        # Clear manager-inherited inputs; only this identity's file may supply them.
        Environment =
          environment
          ++ [
            "MATRIX_HOMESERVER_URL="
            "MATRIX_ACCESS_TOKEN="
            "MATRIX_WEBHOOK_URL="
            "MATRIX_WEBHOOK_BEARER_TOKEN="
          ];
        UnsetEnvironment = [
          "MATRIX_WEBHOOK_URL="
          "MATRIX_WEBHOOK_BEARER_TOKEN="
        ];
        ExecStart = "${runtime} prepare ${directory} ${kind}";
        TimeoutStartSec = 15;
      };
  });
in {
  options.kosmos.wsl.matrixMcpRemote = {
    enable = lib.mkEnableOption "unified dynamic-token Matrix gateway";
    hostname = lib.mkOption {
      type = lib.types.str;
      default = "matrix-mcp.lamplit.run";
      description = "Public Cloudflare Tunnel hostname; DNS is operator-provisioned.";
    };
    artifact = lib.mkOption {
      type = lib.types.str;
      default = "/home/neil/.local/share/matrix-for-agent/releases/17fe5c59c0b4b47cac515883127c9d933e8f0566/cli.js";
      description = "Immutable approved multi-identity Node bundle; provisioned separately by the operator.";
    };
  };
  config = lib.mkIf cfg.enable (lib.mkMerge [
    {
      age.secrets = lib.genAttrs (map (kind: "matrix-${kind}.env") (builtins.filter (kind: builtins.pathExists (../../secrets + "/matrix-${kind}.env.age")) ["shio" "serein"])) (name: {
        file = ../../secrets + "/${name}.age";
        owner = "neil";
        group = "users";
        mode = "0400";
      });
      warnings = lib.optional (kinds == []) "Matrix gateway has no declared identity secret; no service or ingress is enabled.";
    }
    (lib.mkIf (kinds != []) {
      home-manager.users.neil.systemd.user.services =
        inputs
        // {
          matrix-mcp-remote = {
            Unit = {
              Description = "Unified Matrix for Agent Streamable HTTP gateway";
              After = ["network-online.target"];
              ConditionPathExists = [cfg.artifact];
            };
            Install.WantedBy = ["default.target"];
            Service =
              safety
              // {
                RuntimeDirectory = "matrix-mcp-remote";
                RuntimeDirectoryMode = "0700";
                WorkingDirectory = directory;
                Environment = environment;
                # Blocking starts rerun each inactive oneshot on every startup/retry.
                ExecStartPre = ["${runtime} init ${directory} ${lib.escapeShellArg cfg.artifact}"] ++ map (kind: "${pkgs.systemd}/bin/systemctl --user start matrix-mcp-input-${kind}.service") kinds;
                ExecStart = "${runtime} run ${directory} ${node} ${lib.escapeShellArg cfg.artifact} ${lib.concatStringsSep " " kinds}";
                ExecStopPost = "${pkgs.systemd}/bin/systemctl --user stop ${lib.concatMapStringsSep " " (kind: "matrix-mcp-input-${kind}.service") kinds}";
                Restart = "on-failure";
                RestartSec = 5;
                TimeoutStartSec = 40;
              };
          };
        };
    })
  ]);
}
