{
  config,
  lib,
  ...
}: let
  cfg = config.kosmos.wsl.navidrome;
in {
  options.kosmos.wsl.navidrome = {
    enable = lib.mkEnableOption "Navidrome music server for kosmos-wsl";

    musicFolder = lib.mkOption {
      type = lib.types.path;
      default = /home/neil/music;
      description = "Local music library path exposed read-only to Navidrome.";
    };
  };

  config = lib.mkIf cfg.enable {
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

    services.cloudflared.tunnels.kepos.ingress."music.guion.io" = "http://127.0.0.1:4533";
  };
}
