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

    registries = {
      ${cfg.internalRegistryHost}.http = true;
      "docker.io".mirrors = cfg.dockerHubMirrors;
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
      export _EXPERIMENTAL_DAGGER_RUNNER_HOST="''${_EXPERIMENTAL_DAGGER_RUNNER_HOST:-${cfg.runnerHost}}"
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

    internalRegistryHost = lib.mkOption {
      type = lib.types.str;
      default = "host.containers.internal:3000";
      description = "Forgejo Packages host as seen from the Dagger engine container for WSL-local HTTP publishes.";
    };

    dockerHubMirrors = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [
        "mirror.gcr.io"
      ];
      description = "Registry mirrors used by Dagger for Docker Hub image pulls.";
    };

    dnsBridgeAddress = lib.mkOption {
      type = lib.types.str;
      default = "10.88.0.1";
      description = "Podman bridge gateway address exposed to the Dagger engine as a DNS server.";
    };

    dnsUpstreams = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [
        "https://1.1.1.1/dns-query"
        "https://1.0.0.1/dns-query"
      ];
      description = "DNS-over-HTTPS upstreams used only by the Dagger engine resolver.";
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
          "--dns=${cfg.dnsBridgeAddress}"
        ];
      };
    };

    environment.systemPackages = [
      daggerWrapper
    ];

    environment.etc."dagger/engine.json".source = engineConfig;

    systemd = {
      services = {
        dagger-dnsproxy = {
          description = "Dagger-only DNS proxy on the Podman bridge";
          after = [
            "network-online.target"
          ];
          wants = [
            "network-online.target"
          ];
          wantedBy = [
            "multi-user.target"
          ];
          path = with pkgs; [
            bash
            coreutils
            gnugrep
            iproute2
            dnsproxy
          ];
          script = ''
            set -euo pipefail

            for _ in $(seq 1 30); do
              if ip -o addr show | grep -q ' ${cfg.dnsBridgeAddress}/'; then
                break
              fi
              sleep 1
            done

            if ! ip -o addr show | grep -q ' ${cfg.dnsBridgeAddress}/'; then
              echo "timed out waiting for ${cfg.dnsBridgeAddress}" >&2
              exit 1
            fi

            exec dnsproxy \
              --listen=${cfg.dnsBridgeAddress} \
              --port=53 \
              --cache \
              ${lib.concatMapStringsSep " \\\n              " (upstream: "--upstream=${lib.escapeShellArg upstream}") cfg.dnsUpstreams}
          '';
          serviceConfig = {
            Restart = "always";
            RestartSec = "5s";
          };
        };

        podman-dagger-engine = {
          after = [
            "dagger-dnsproxy.service"
          ];
          wants = [
            "dagger-dnsproxy.service"
          ];
        };
      };

      tmpfiles.rules = [
        "d '${cfg.stateDir}' 0775 root users - -"
        "d '${cfg.stateDir}/config' 0775 root users - -"
        "d '${cfg.stateDir}/config/dagger' 0775 root users - -"
        "d '${cfg.stateDir}/cache' 0775 root users - -"
        "d '/run/dagger' 0775 root users - -"
        "L+ '${cfg.stateDir}/config/dagger/engine.json' - - - - /etc/dagger/engine.json"
      ];
    };
  };
}
