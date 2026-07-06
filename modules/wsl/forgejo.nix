{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.kosmos.wsl.forgejo;
  keposCloudflaredCredentialsFile = ../../secrets/cloudflared-kepos-credentials.age;
  haveKeposTunnel =
    config.kosmos.wsl ? keposMatrix
    && config.kosmos.wsl.keposMatrix.enable
    && builtins.pathExists keposCloudflaredCredentialsFile;
in {
  options.kosmos.wsl.forgejo = {
    enable = lib.mkEnableOption "Forgejo staging service for the WSL devops box";

    package = lib.mkOption {
      type = lib.types.package;
      default = pkgs.forgejo;
      description = "Forgejo package to run. Use the non-LTS package for staging so it is closer to current Forgejo releases.";
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

    enableCloudflared = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Expose Forgejo through the existing WSL Cloudflare tunnel when the tunnel secret exists.";
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
  ]);
}
