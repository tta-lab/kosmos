{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.kosmos.wsl.woodpecker;
  serverEnvironmentAgeFile = ../../secrets/woodpecker-server-env.age;
  agentEnvironmentAgeFile = ../../secrets/woodpecker-agent-env.age;
  haveDefaultSecrets =
    builtins.pathExists serverEnvironmentAgeFile
    && builtins.pathExists agentEnvironmentAgeFile;
  effectiveServerEnvironmentFile =
    if cfg.serverEnvironmentFile != null
    then cfg.serverEnvironmentFile
    else if haveDefaultSecrets
    then config.age.secrets.woodpecker-server-env.path
    else null;
  effectiveAgentEnvironmentFile =
    if cfg.agentEnvironmentFile != null
    then cfg.agentEnvironmentFile
    else if haveDefaultSecrets
    then config.age.secrets.woodpecker-agent-env.path
    else null;
  haveSecrets = effectiveServerEnvironmentFile != null && effectiveAgentEnvironmentFile != null;
in {
  options.kosmos.wsl.woodpecker = {
    enable = lib.mkEnableOption "Woodpecker CI server and local WSL agent";

    publicHostname = lib.mkOption {
      type = lib.types.str;
      default = "ci-wsl.guion.io";
      description = "Public staging hostname for Woodpecker.";
    };

    port = lib.mkOption {
      type = lib.types.port;
      default = 9000;
      description = "Local Woodpecker server port.";
    };

    forgejoUrl = lib.mkOption {
      type = lib.types.str;
      default = "https://git-wsl.guion.io";
      description = "Forgejo URL used by Woodpecker's Forgejo/Gitea integration.";
    };

    serverEnvironmentFile = lib.mkOption {
      type = lib.types.nullOr lib.types.path;
      default = null;
      description = "Environment file containing WOODPECKER_AGENT_SECRET and Forgejo OAuth secret values for the server. Null uses secrets/woodpecker-server-env.age when present.";
    };

    agentEnvironmentFile = lib.mkOption {
      type = lib.types.nullOr lib.types.path;
      default = null;
      description = "Environment file containing WOODPECKER_AGENT_SECRET for the local agent. Null uses secrets/woodpecker-agent-env.age when present.";
    };

    enableCloudflared = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Expose Woodpecker through cloudflared. Keep off until Forgejo staging is proven.";
    };
  };

  config = lib.mkIf cfg.enable (lib.mkMerge [
    {
      warnings = lib.mkIf (!haveSecrets) [
        ''
          WSL Woodpecker is enabled without environment files.
          Create secrets/woodpecker-server-env.age and secrets/woodpecker-agent-env.age, or provide kosmos.wsl.woodpecker.serverEnvironmentFile and agentEnvironmentFile.
        ''
      ];
    }

    (lib.mkIf haveSecrets {
      age.secrets = lib.mkIf haveDefaultSecrets {
        woodpecker-server-env = {
          file = serverEnvironmentAgeFile;
          owner = "root";
          group = "root";
          mode = "0400";
        };

        woodpecker-agent-env = {
          file = agentEnvironmentAgeFile;
          owner = "root";
          group = "root";
          mode = "0400";
        };
      };

      services.woodpecker-server = {
        enable = true;
        environment = {
          WOODPECKER_HOST = "https://${cfg.publicHostname}";
          WOODPECKER_SERVER_ADDR = "127.0.0.1:${toString cfg.port}";
          WOODPECKER_FORGEJO = "true";
          WOODPECKER_FORGEJO_URL = cfg.forgejoUrl;
          WOODPECKER_OPEN = "false";
          WOODPECKER_ADMIN = "neil";
          WOODPECKER_ENVIRONMENT = "_EXPERIMENTAL_DAGGER_RUNNER_HOST:unix:///run/dagger/engine.sock";
        };
        environmentFile = [
          effectiveServerEnvironmentFile
        ];
      };

      services.woodpecker-agents.agents.wsl-podman = {
        enable = true;
        environment = {
          WOODPECKER_SERVER = "127.0.0.1:${toString cfg.port}";
          WOODPECKER_BACKEND = "docker";
          WOODPECKER_CONNECT_RETRY_COUNT = "1";
          WOODPECKER_BACKEND_DOCKER_VOLUMES = "/run/dagger:/run/dagger";
          DOCKER_HOST = "unix:///run/podman/podman.sock";
        };
        environmentFile = [
          effectiveAgentEnvironmentFile
        ];
        extraGroups = [
          "podman"
        ];
        path = with pkgs; [
          bash
          coreutils
          git
          git-lfs
          woodpecker-plugin-git
        ];
      };
    })

    (lib.mkIf (haveSecrets && cfg.enableCloudflared) {
      services.cloudflared.tunnels.kepos.ingress.${cfg.publicHostname} = "http://127.0.0.1:${toString cfg.port}";
    })
  ]);
}
