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
        MusicFolder = "/music";
        BaseUrl = "https://music.guion.io";
        EnableDownloads = false;
        EnableSharing = false;
        EnableInsightsCollector = false;
      };
    };

    systemd.services.navidrome.serviceConfig.BindReadOnlyPaths =
      lib.mkForce
      ([
          "${config.security.pki.caBundle}:/etc/ssl/certs/ca-certificates.crt"
          builtins.storeDir
          "/etc"
          "${toString cfg.musicFolder}:/music"
        ]
        ++ lib.optionals config.services.resolved.enable [
          "/run/systemd/resolve/stub-resolv.conf"
          "/run/systemd/resolve/resolv.conf"
        ]);
  };
}
