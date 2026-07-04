{
  config,
  lib,
  ...
}: let
  cfg = config.kosmos.wsl.jellyfin;
  keposCloudflaredCredentialsFile = ../../secrets/cloudflared-kepos-credentials.age;
  haveKeposTunnel =
    config.kosmos.wsl ? keposMatrix
    && config.kosmos.wsl.keposMatrix.enable
    && builtins.pathExists keposCloudflaredCredentialsFile;
in {
  options.kosmos.wsl.jellyfin = {
    enable = lib.mkEnableOption "Jellyfin media server for kosmos-wsl";

    mediaFolder = lib.mkOption {
      type = lib.types.path;
      default = /home/neil/media;
      description = "Local media library path for Jellyfin videos and mixed media.";
    };

    musicFolder = lib.mkOption {
      type = lib.types.path;
      default = /home/neil/music;
      description = "Existing local music library path exposed to Jellyfin.";
    };
  };

  config = lib.mkIf cfg.enable (lib.mkMerge [
    {
      warnings = lib.mkIf (!haveKeposTunnel) [
        ''
          Jellyfin is enabled without the kepos Cloudflare tunnel.
          It will listen locally until kosmos.wsl.keposMatrix is enabled and secrets/cloudflared-kepos-credentials.age exists.
        ''
      ];

      services.jellyfin = {
        enable = true;
        user = "neil";
        group = "users";
        openFirewall = false;
      };

      systemd.tmpfiles.settings.jellyfinMedia = {
        "${toString cfg.mediaFolder}"."d" = {
          mode = "755";
          user = "neil";
          group = "users";
        };
        "${toString cfg.musicFolder}"."d" = {
          mode = "755";
          user = "neil";
          group = "users";
        };
      };
    }

    (lib.mkIf haveKeposTunnel {
      services.cloudflared.tunnels.kepos.ingress."media.guion.io" = "http://127.0.0.1:8096";
    })
  ]);
}
