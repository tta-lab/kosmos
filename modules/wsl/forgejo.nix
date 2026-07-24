{
  config,
  lib,
  pkgs,
  pkgsUnstable,
  ...
}: let
  cfg = config.kosmos.wsl.forgejo;
  keposCloudflaredCredentialsFile = ../../secrets/cloudflared-kepos-credentials.age;
  haveKeposTunnel =
    config.kosmos.wsl ? keposTunnel
    && config.kosmos.wsl.keposTunnel.enable
    && builtins.pathExists keposCloudflaredCredentialsFile;
in {
  options.kosmos.wsl.forgejo = {
    enable = lib.mkEnableOption "Forgejo service for the WSL devops box";

    package = lib.mkOption {
      type = lib.types.package;
      default = pkgsUnstable.forgejo;
      description = "Forgejo package to run. Uses nixpkgs-unstable so restored k3s data from the current Forgejo line is not opened with the older stable package.";
    };

    publicHostname = lib.mkOption {
      type = lib.types.str;
      default = "git.guion.io";
      description = "Public Forgejo hostname exposed through cloudflared.";
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
          It will listen on 127.0.0.1:${toString cfg.port} until kosmos.wsl.keposTunnel is enabled and secrets/cloudflared-kepos-credentials.age exists.
        ''
      ];

      services.forgejo = {
        enable = true;
        inherit (cfg) package stateDir;

        database = {
          type = "sqlite3";
          path = "${cfg.stateDir}/data/forgejo.db";
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
