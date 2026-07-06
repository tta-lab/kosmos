{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.kosmos.wsl.dagger;
  engineConfig = pkgs.writeText "dagger-engine.json" (builtins.toJSON {
    gc = {
      inherit
        (cfg.gc)
        maxUsedSpace
        minFreeSpace
        reservedSpace
        sweepSize
        ;
    };
  });
  daggerWrapper = pkgs.writeShellApplication {
    name = "dagger";
    runtimeInputs = [
      cfg.package
    ];
    text = ''
      export XDG_CONFIG_HOME="${cfg.stateDir}/config"
      export XDG_CACHE_HOME="${cfg.stateDir}/cache"
      export _EXPERIMENTAL_DAGGER_RUNNER_HOST="${cfg.runnerHost}"
      exec ${lib.getExe cfg.package} "$@"
    '';
  };
in {
  options.kosmos.wsl.dagger = {
    enable = lib.mkEnableOption "Dagger CLI and engine cache policy for the WSL devops box";

    package = lib.mkOption {
      type = lib.types.package;
      default = pkgs.callPackage ../../packages/dagger-cli {};
      description = "Pinned Dagger CLI package. The CLI starts the matching registry.dagger.io/engine image through Podman/Docker.";
    };

    stateDir = lib.mkOption {
      type = lib.types.str;
      default = "/var/lib/dagger";
      description = "Shared Dagger engine state and CLI cache root.";
    };

    engineImage = lib.mkOption {
      type = lib.types.str;
      default = "registry.dagger.io/engine:v${cfg.package.version}";
      description = "Dagger engine image. Keep this version aligned with the CLI package.";
    };

    runnerHost = lib.mkOption {
      type = lib.types.str;
      default = "tcp://127.0.0.1:8080";
      description = "Runner endpoint used by the local Dagger CLI wrapper.";
    };

    listenAddress = lib.mkOption {
      type = lib.types.str;
      default = "127.0.0.1";
      description = "Host address used for the local Dagger engine TCP port.";
    };

    port = lib.mkOption {
      type = lib.types.port;
      default = 8080;
      description = "Local Dagger engine TCP port.";
    };

    gc = {
      maxUsedSpace = lib.mkOption {
        type = lib.types.str;
        default = "100GB";
        description = "Dagger engine GC max used space.";
      };

      reservedSpace = lib.mkOption {
        type = lib.types.str;
        default = "10GB";
        description = "Dagger engine GC reserved space.";
      };

      minFreeSpace = lib.mkOption {
        type = lib.types.str;
        default = "20%";
        description = "Dagger engine GC target free space.";
      };

      sweepSize = lib.mkOption {
        type = lib.types.str;
        default = "50%";
        description = "Dagger engine GC sweep size.";
      };
    };
  };

  config = lib.mkIf cfg.enable {
    virtualisation.oci-containers = {
      backend = lib.mkDefault "podman";

      containers.dagger-engine = {
        image = cfg.engineImage;
        pull = "missing";
        privileged = true;
        ports = [
          "${cfg.listenAddress}:${toString cfg.port}:8080"
        ];
        volumes = [
          "${cfg.stateDir}:/var/lib/dagger"
          "/etc/dagger/engine.json:/etc/dagger/engine.json:ro"
          "/run/dagger:/run/dagger"
        ];
        cmd = [
          "--addr"
          "tcp://0.0.0.0:8080"
          "--addr"
          "unix:///run/dagger/engine.sock"
        ];
        extraOptions = [
          "--pids-limit=-1"
        ];
      };
    };

    environment.systemPackages = [
      daggerWrapper
    ];

    environment.etc."dagger/engine.json".source = engineConfig;

    systemd.tmpfiles.rules = [
      "d '${cfg.stateDir}' 0775 root users - -"
      "d '${cfg.stateDir}/config' 0775 root users - -"
      "d '${cfg.stateDir}/config/dagger' 0775 root users - -"
      "d '${cfg.stateDir}/cache' 0775 root users - -"
      "d '/run/dagger' 0775 root users - -"
      "C '${cfg.stateDir}/config/dagger/engine.json' 0664 root users - ${engineConfig}"
    ];
  };
}
