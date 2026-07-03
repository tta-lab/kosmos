{
  config,
  lib,
  ...
}: let
  cfg = config.kosmos.wsl.navidrome;
  keposCloudflaredCredentialsFile = ../../secrets/cloudflared-kepos-credentials.age;
  haveKeposTunnel =
    config.kosmos.wsl ? keposMatrix
    && config.kosmos.wsl.keposMatrix.enable
    && builtins.pathExists keposCloudflaredCredentialsFile;
in {
  options.kosmos.wsl.navidrome = {
    enable = lib.mkEnableOption "Navidrome music server for kosmos-wsl";

    musicFolder = lib.mkOption {
      type = lib.types.path;
      default = /home/neil/music;
      description = "Local music library path exposed read-only to Navidrome.";
    };
  };

  config = lib.mkIf cfg.enable (lib.mkMerge [
    {
      warnings = lib.mkIf (!haveKeposTunnel) [
        ''
          Navidrome is enabled without the kepos Cloudflare tunnel.
          It will listen locally only until kosmos.wsl.keposMatrix is enabled and secrets/cloudflared-kepos-credentials.age exists.
        ''
      ];

      services.navidrome = {
        enable = true;
        user = "neil";
        group = "users";

        settings = {
          Address = "127.0.0.1";
          Port = 4533;
          MusicFolder = toString cfg.musicFolder;
          BaseUrl = "https://music.guion.io";
          EnableDownloads = false;
          EnableSharing = false;
          EnableInsightsCollector = false;
        };
      };
    }

    (lib.mkIf haveKeposTunnel {
      services.cloudflared.tunnels.kepos.ingress."music.guion.io" = "http://127.0.0.1:4533";
    })
  ]);
}
