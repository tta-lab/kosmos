{
  config,
  lib,
  pkgs,
  pkgsUnstable,
  ...
}: let
  cfg = config.kosmos.wsl.forgejo;
  keposCloudflaredCredentialsFile = ../../secrets/cloudflared-kepos-credentials.age;
  forgejoBackupReplicate = pkgs.writeScript "forgejo-backup-replicate" (builtins.readFile ../../scripts/forgejo-backup-replicate);
  haveKeposTunnel =
    config.kosmos.wsl ? keposMatrix
    && config.kosmos.wsl.keposMatrix.enable
    && builtins.pathExists keposCloudflaredCredentialsFile;
in {
  options.kosmos.wsl.forgejo = {
    enable = lib.mkEnableOption "Forgejo staging service for the WSL devops box";

    package = lib.mkOption {
      type = lib.types.package;
      default = pkgsUnstable.forgejo;
      description = "Forgejo package to run. Uses nixpkgs-unstable so restored k3s data from the current Forgejo line is not opened with the older stable package.";
    };

    publicHostname = lib.mkOption {
      type = lib.types.str;
      default = "git-wsl.guion.io";
      description = "Public staging hostname exposed through cloudflared.";
    };

    port = lib.mkOption {
      type = lib.types.port;
      default = 3000;
      description = "Local Forgejo HTTP port.";
    };

    stateDir = lib.mkOption {
      type = lib.types.str;
      default = "/var/lib/forgejo";
      description = "Forgejo persistent state directory.";
    };

    backupDir = lib.mkOption {
      type = lib.types.str;
      default = "/var/backup/forgejo";
      description = "Forgejo dump directory. Final backups should move to the NUC data disk.";
    };

    backupReplicaDir = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      description = "Secondary backup directory on the NUC data disk. Null disables automatic dump replication.";
    };

    backupReplicaCalendar = lib.mkOption {
      type = lib.types.str;
      default = "hourly";
      description = "systemd OnCalendar value for Forgejo dump replication when backupReplicaDir is set.";
    };

    enableCloudflared = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Expose Forgejo through the existing WSL Cloudflare tunnel when the tunnel secret exists.";
    };

    enableInternalRegistryProxy = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Expose Forgejo HTTP only on the Podman bridge gateway so the Dagger engine can publish to Packages without Cloudflare.";
    };

    internalRegistryAddress = lib.mkOption {
      type = lib.types.str;
      default = "10.88.0.1";
      description = "Podman bridge gateway address used by host.containers.internal from the Dagger engine container.";
    };

    internalRegistryPort = lib.mkOption {
      type = lib.types.port;
      default = 3000;
      description = "Internal registry proxy port bound on the Podman bridge gateway.";
    };
  };

  config = lib.mkIf cfg.enable (lib.mkMerge [
    {
      warnings = lib.mkIf (cfg.enableCloudflared && !haveKeposTunnel) [
        ''
          WSL Forgejo is enabled without the kepos Cloudflare tunnel.
          It will listen on 127.0.0.1:${toString cfg.port} until kosmos.wsl.keposMatrix is enabled and secrets/cloudflared-kepos-credentials.age exists.
        ''
      ];

      services.forgejo = {
        enable = true;
        inherit (cfg) package stateDir;

        database = {
          type = "sqlite3";
          path = "${cfg.stateDir}/data/forgejo.db";
        };

        dump = {
          enable = true;
          inherit (cfg) backupDir;
          type = "tar.zst";
        };

        lfs.enable = true;

        settings = {
          DEFAULT.APP_NAME = "Guion DevOps";

          server = {
            DOMAIN = cfg.publicHostname;
            ROOT_URL = "https://${cfg.publicHostname}/";
            HTTP_ADDR = "127.0.0.1";
            HTTP_PORT = cfg.port;
            DISABLE_SSH = true;
            LFS_START_SERVER = true;
          };

          service = {
            DISABLE_REGISTRATION = true;
            REQUIRE_SIGNIN_VIEW = true;
          };

          packages = {
            ENABLED = true;
          };

          session = {
            COOKIE_SECURE = true;
          };

          actions = {
            ENABLED = false;
          };
        };
      };
    }

    (lib.mkIf (cfg.enableCloudflared && haveKeposTunnel) {
      services.cloudflared.tunnels.kepos.ingress.${cfg.publicHostname} = "http://127.0.0.1:${toString cfg.port}";
    })

    (lib.mkIf cfg.enableInternalRegistryProxy {
      systemd.services.forgejo-internal-registry-proxy = {
        description = "Forgejo Packages proxy for WSL-local Dagger publishes";
        after = [
          "network-online.target"
          "forgejo.service"
        ];
        wants = [
          "network-online.target"
          "forgejo.service"
        ];
        wantedBy = [
          "multi-user.target"
        ];
        path = with pkgs; [
          coreutils
          gnugrep
          iproute2
          socat
        ];
        serviceConfig = {
          Type = "simple";
          Restart = "always";
          RestartSec = "5s";
          ExecStartPre = pkgs.writeShellScript "wait-for-podman-bridge-address" ''
            for _ in $(seq 1 30); do
              if ip -o addr show | grep -q ' ${cfg.internalRegistryAddress}/'; then
                exit 0
              fi
              sleep 1
            done

            echo "timed out waiting for ${cfg.internalRegistryAddress}" >&2
            exit 1
          '';
          ExecStart = "${pkgs.socat}/bin/socat TCP-LISTEN:${toString cfg.internalRegistryPort},bind=${cfg.internalRegistryAddress},fork,reuseaddr TCP:127.0.0.1:${toString cfg.port}";
        };
      };
    })

    (lib.mkIf (cfg.backupReplicaDir != null) {
      systemd.services.forgejo-backup-replicate = {
        description = "Replicate Forgejo dumps to the NUC data disk";
        after = [
          "forgejo-dump.service"
        ];
        unitConfig.RequiresMountsFor = [
          cfg.backupReplicaDir
        ];
        path = with pkgs; [
          coreutils
          findutils
          gawk
          gnused
          sudo
        ];
        serviceConfig = {
          Type = "oneshot";
          ExecStart = "${pkgs.bash}/bin/bash ${forgejoBackupReplicate} --source-dir ${lib.escapeShellArg cfg.backupDir} --state-dir ${lib.escapeShellArg cfg.stateDir} --target-dir ${lib.escapeShellArg cfg.backupReplicaDir}";
        };
      };

      systemd.timers.forgejo-backup-replicate = {
        description = "Replicate Forgejo dumps to the NUC data disk";
        wantedBy = [
          "timers.target"
        ];
        timerConfig = {
          OnCalendar = cfg.backupReplicaCalendar;
          Persistent = true;
          Unit = "forgejo-backup-replicate.service";
        };
      };
    })
  ]);
}
