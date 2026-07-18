{
  config,
  lib,
  pkgs,
  pkgsUnstable,
  ...
}: let
  cfg = config.kosmos.wsl.woodpecker;
  hostProxyUrl = config.kosmos.wsl.mihomoProxyUrl or "http://127.0.0.1:7890";
  jobProxyUrl = lib.replaceStrings ["127.0.0.1"] ["host.containers.internal"] hostProxyUrl;
  serverEnvironmentAgeFile = ../../secrets/woodpecker-server-env.age;
  agentEnvironmentAgeFile = ../../secrets/woodpecker-agent-env.age;
  defaultServerEnvironmentFile = "/run/agenix/woodpecker-server-env";
  defaultAgentEnvironmentFile = "/run/agenix/woodpecker-agent-env";
  haveDefaultSecrets =
    builtins.pathExists serverEnvironmentAgeFile
    && builtins.pathExists agentEnvironmentAgeFile;
  effectiveServerEnvironmentFile =
    if cfg.serverEnvironmentFile != null
    then cfg.serverEnvironmentFile
    else if haveDefaultSecrets
    then defaultServerEnvironmentFile
    else null;
  effectiveAgentEnvironmentFile =
    if cfg.agentEnvironmentFile != null
    then cfg.agentEnvironmentFile
    else if haveDefaultSecrets
    then defaultAgentEnvironmentFile
    else null;
  haveSecrets = effectiveServerEnvironmentFile != null && effectiveAgentEnvironmentFile != null;
  agentNames =
    [
      "wsl-podman"
    ]
    ++ map (index: "wsl-podman-${toString index}") (lib.range 2 cfg.agentCount);
  mkAgent = index: {
    enable = true;
    package = pkgsUnstable.woodpecker-agent;
    environment = {
      WOODPECKER_SERVER = "127.0.0.1:${toString cfg.grpcPort}";
      WOODPECKER_BACKEND = "docker";
      WOODPECKER_AGENT_CONFIG_FILE = "";
      WOODPECKER_CONNECT_RETRY_COUNT = "1";
      WOODPECKER_HEALTHCHECK_ADDR = "127.0.0.1:${toString (9000 + index)}";
      WOODPECKER_BACKEND_DOCKER_VOLUMES = "/run/dagger:/run/dagger";
      DOCKER_HOST = "unix:///run/podman/podman.sock";
      HTTP_PROXY = hostProxyUrl;
      HTTPS_PROXY = hostProxyUrl;
      ALL_PROXY = hostProxyUrl;
      NO_PROXY = "localhost,127.0.0.1,::1";
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
  agentServiceDependencies = {
    after = [
      "podman.socket"
      "podman-dagger-engine.service"
      "forgejo-internal-registry-proxy.service"
    ];
    wants = [
      "podman.socket"
      "podman-dagger-engine.service"
      "forgejo-internal-registry-proxy.service"
    ];
  };
in {
  options.kosmos.wsl.woodpecker = {
    enable = lib.mkEnableOption "Woodpecker CI server and local WSL agent";

    publicHostname = lib.mkOption {
      type = lib.types.str;
      default = "ci.guion.io";
      description = "Public Woodpecker hostname exposed through cloudflared.";
    };

    port = lib.mkOption {
      type = lib.types.port;
      default = 8000;
      description = "Local Woodpecker HTTP server port.";
    };

    grpcPort = lib.mkOption {
      type = lib.types.port;
      default = 9000;
      description = "Local Woodpecker gRPC port used by agents.";
    };

    forgejoUrl = lib.mkOption {
      type = lib.types.str;
      default = "http://127.0.0.1:3000";
      description = "Local Forgejo API URL used by Woodpecker's Forgejo/Gitea integration.";
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

    agentCount = lib.mkOption {
      type = lib.types.ints.positive;
      default = 3;
      description = "Number of local WSL Woodpecker agents to run in parallel.";
    };

    enableCloudflared = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Expose Woodpecker through cloudflared.";
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
          path = defaultServerEnvironmentFile;
        };

        woodpecker-agent-env = {
          file = agentEnvironmentAgeFile;
          owner = "root";
          group = "root";
          mode = "0400";
          path = defaultAgentEnvironmentFile;
        };
      };

      services.woodpecker-server = {
        enable = true;
        package = pkgsUnstable.woodpecker-server;
        environment = {
          WOODPECKER_HOST = "https://${cfg.publicHostname}";
          WOODPECKER_SERVER_ADDR = "127.0.0.1:${toString cfg.port}";
          WOODPECKER_GRPC_ADDR = "127.0.0.1:${toString cfg.grpcPort}";
          WOODPECKER_FORGEJO = "true";
          WOODPECKER_FORGEJO_URL = cfg.forgejoUrl;
          WOODPECKER_OPEN = "false";
          WOODPECKER_ADMIN = "neil";
          WOODPECKER_ENVIRONMENT = "_EXPERIMENTAL_DAGGER_RUNNER_HOST:unix:///run/dagger/engine.sock";
          WOODPECKER_BACKEND_HTTP_PROXY = jobProxyUrl;
          WOODPECKER_BACKEND_HTTPS_PROXY = jobProxyUrl;
          WOODPECKER_BACKEND_NO_PROXY = "localhost,127.0.0.1,::1,host.containers.internal";
        };
        environmentFile = [
          effectiveServerEnvironmentFile
        ];
      };

      services.woodpecker-agents.agents = lib.listToAttrs (
        lib.imap1 (index: name: lib.nameValuePair name (mkAgent index)) agentNames
      );

      systemd.services = lib.listToAttrs (
        map (name: lib.nameValuePair "woodpecker-agent-${name}" agentServiceDependencies) agentNames
      );
    })

    (lib.mkIf (haveSecrets && cfg.enableCloudflared) {
      services.cloudflared.tunnels.kepos.ingress.${cfg.publicHostname} = "http://127.0.0.1:${toString cfg.port}";
    })
  ]);
}
